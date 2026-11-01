import 'dart:math' as math;

import 'package:fitness_exercise_application/features/workout/domain/entities/workout_session.dart';
import 'package:fitness_exercise_application/features/workout/domain/services/gps_validation_models.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

enum TrackingGpsDecisionType { skip, seedRoute, resetAnchor, acceptRoute }

class TrackingGpsDecision {
  final TrackingGpsDecisionType type;
  final LatLng livePoint;
  final LatLng? previewPoint;
  final String? skipReason;
  final double segmentMeters;
  final double rawSegmentMeters;
  final double routeSegmentMeters;
  final double candidateSpeedKmh;
  final bool shouldAddDistance;
  final bool shouldBreakRouteForDisplay;
  final double gpsGapDurationSec;
  final GpsPointOutcome outcome;
  final GpsRejectReason reason;

  const TrackingGpsDecision({
    required this.type,
    required this.livePoint,
    required this.previewPoint,
    this.skipReason,
    this.segmentMeters = 0,
    this.rawSegmentMeters = 0,
    this.routeSegmentMeters = 0,
    this.candidateSpeedKmh = 0,
    this.shouldAddDistance = true,
    this.shouldBreakRouteForDisplay = false,
    this.gpsGapDurationSec = 0,
    this.outcome = GpsPointOutcome.accepted,
    this.reason = GpsRejectReason.none,
  });
}

class StepTrackingDecision {
  final int delta;
  final bool shouldActivateGpsFallback;

  const StepTrackingDecision({
    required this.delta,
    required this.shouldActivateGpsFallback,
  });
}

class IndoorStepContribution {
  final double addedDistanceMeters;
  final double? instantSpeedKmh;

  const IndoorStepContribution({
    required this.addedDistanceMeters,
    required this.instantSpeedKmh,
  });
}

class ActivityConsistencyAssessment {
  final bool shouldInvalidateResult;
  final String? reason;
  final double minExpectedAvgSpeedKmh;
  final double maxExpectedAvgSpeedKmh;

  const ActivityConsistencyAssessment({
    required this.shouldInvalidateResult,
    required this.reason,
    required this.minExpectedAvgSpeedKmh,
    required this.maxExpectedAvgSpeedKmh,
  });
}

class SegmentThreshold {
  final double minPaceSecPerKm;
  final double maxPaceSecPerKm;

  const SegmentThreshold({
    required this.minPaceSecPerKm,
    required this.maxPaceSecPerKm,
  });
}

class GpsWorkoutAnalysisInput {
  final List<Position> rawPositions;
  final String activityType;
  final int totalDurationSec;
  final double fallbackDistanceMeters;

  const GpsWorkoutAnalysisInput({
    required this.rawPositions,
    required this.activityType,
    required this.totalDurationSec,
    required this.fallbackDistanceMeters,
  });
}

class WorkoutTrackingEngine {
  const WorkoutTrackingEngine();

  /// Historical main baseline uses a 5s accepted-fix gap policy.
  /// NOTE: stationary fixes rejected by validation may appear as a GPS gap;
  /// baseline parity does not itself fix that distinction.
  static const double kStaleSignalGapThresholdSec = 5.0;

  TrackingGpsDecision evaluateGpsUpdate({
    required Position position,
    required String activityType,
    required List<LatLng> routePoints,
    required LatLng? currentLatLng,
    required LatLng? distanceAnchorPoint,
    required DateTime? lastAcceptedPositionTime,
    // Real raw-signal interruption duration. Null keeps legacy callers' behavior.
    // The live recorder passes 0 when raw GPS is flowing, even if validation
    // has not accepted a moving point for a long stationary interval.
    double? rawGpsGapDurationSec,
    required bool shouldResetAnchorOnResume,
    bool wasGpsSignalWeak = false,
    bool debugLocationMode = false,
  }) {
    final livePoint = LatLng(position.latitude, position.longitude);
    final previewAccuracy = debugLocationMode
        ? 100.0
        : getPreviewAccuracy(activityType);
    final allowPreviewUpdate = position.accuracy <= previewAccuracy * 3.0;
    final previewPoint = allowPreviewUpdate ? livePoint : currentLatLng;
    final maxAccuracy = debugLocationMode
        ? 100.0
        : getMaxRouteAccuracy(activityType);

    if (routePoints.isEmpty) {
      final initialFixAccuracy = getInitialFixAccuracy(activityType);
      if (position.accuracy > initialFixAccuracy) {
        return TrackingGpsDecision(
          type: TrackingGpsDecisionType.skip,
          livePoint: livePoint,
          previewPoint: previewPoint,
          skipReason:
              'waiting_for_better_first_fix acc=${position.accuracy.toStringAsFixed(1)}m > ${initialFixAccuracy.toStringAsFixed(1)}m',
          outcome: GpsPointOutcome.softRejected,
          reason: GpsRejectReason.waitingForBetterFirstFix,
        );
      }
      return TrackingGpsDecision(
        type: TrackingGpsDecisionType.seedRoute,
        livePoint: livePoint,
        previewPoint: livePoint,
        outcome: GpsPointOutcome.accepted,
      );
    }

    if (shouldResetAnchorOnResume) {
      return TrackingGpsDecision(
        type: TrackingGpsDecisionType.resetAnchor,
        livePoint: livePoint,
        previewPoint: livePoint,
        outcome: GpsPointOutcome.accepted,
      );
    }

    final minSegmentMeters = debugLocationMode
        ? 0.25
        : getMinSegmentMeters(activityType);
    final maxSpeedMs = getHardGpsSpikeSpeedMs();
    final lastPoint = routePoints.last;
    final rawDistanceAnchor = distanceAnchorPoint ?? lastPoint;
    final rawSegmentMeters = Geolocator.distanceBetween(
      rawDistanceAnchor.latitude,
      rawDistanceAnchor.longitude,
      livePoint.latitude,
      livePoint.longitude,
    );
    final routeSegmentMeters = Geolocator.distanceBetween(
      lastPoint.latitude,
      lastPoint.longitude,
      livePoint.latitude,
      livePoint.longitude,
    );
    final segmentMeters = rawSegmentMeters;

    if (position.accuracy > maxAccuracy) {
      return TrackingGpsDecision(
        type: TrackingGpsDecisionType.skip,
        livePoint: livePoint,
        previewPoint: previewPoint,
        skipReason:
            'accuracy=${position.accuracy.toStringAsFixed(2)}m > $maxAccuracy',
        segmentMeters: segmentMeters,
        rawSegmentMeters: rawSegmentMeters,
        routeSegmentMeters: routeSegmentMeters,
        outcome: GpsPointOutcome.softRejected,
        reason: GpsRejectReason.lowAccuracy,
      );
    }

    if (position.speed > 0 && position.speed > maxSpeedMs) {
      return TrackingGpsDecision(
        type: TrackingGpsDecisionType.skip,
        livePoint: livePoint,
        previewPoint: previewPoint,
        skipReason:
            'gps_speed_hard_spike=${position.speed.toStringAsFixed(2)}m/s > ${maxSpeedMs.toStringAsFixed(2)}m/s',
        segmentMeters: segmentMeters,
        rawSegmentMeters: rawSegmentMeters,
        routeSegmentMeters: routeSegmentMeters,
        outcome: GpsPointOutcome.hardRejected,
        reason: GpsRejectReason.gpsSpeedHardSpike,
      );
    }

    final previousAcceptedTime = lastAcceptedPositionTime;
    final timeDeltaSec = previousAcceptedTime == null
        ? 0.0
        : position.timestamp.difference(previousAcceptedTime).inMilliseconds /
              1000.0;
    // Accepted-fix age alone is NOT a signal outage: stationary/filtered fixes
    // can keep the raw stream healthy. Actual blackout is based on raw fixes.
    final signalGapSec = rawGpsGapDurationSec ?? timeDeltaSec;
    if (signalGapSec > kStaleSignalGapThresholdSec) {
      return TrackingGpsDecision(
        type: TrackingGpsDecisionType.acceptRoute,
        livePoint: livePoint,
        previewPoint: previewPoint,
        segmentMeters: 0,
        rawSegmentMeters: rawSegmentMeters,
        routeSegmentMeters: routeSegmentMeters,
        candidateSpeedKmh: 0,
        shouldAddDistance: false,
        shouldBreakRouteForDisplay: true,
        gpsGapDurationSec: signalGapSec,
        outcome: GpsPointOutcome.signalGap,
        reason: GpsRejectReason.staleSignalGap,
      );
    }

    if (segmentMeters < minSegmentMeters) {
      return TrackingGpsDecision(
        type: TrackingGpsDecisionType.skip,
        livePoint: livePoint,
        previewPoint: previewPoint,
        skipReason:
            'segment=${segmentMeters.toStringAsFixed(2)}m < $minSegmentMeters',
        segmentMeters: segmentMeters,
        rawSegmentMeters: rawSegmentMeters,
        routeSegmentMeters: routeSegmentMeters,
        outcome: GpsPointOutcome.softRejected,
        reason: GpsRejectReason.tinySegment,
      );
    }

    if (!debugLocationMode &&
        _shouldBreakLiveRouteForDisplay(
          activityType: activityType,
          accuracyMeters: position.accuracy,
          timeDeltaSec: timeDeltaSec,
          routeSegmentMeters: routeSegmentMeters,
          wasGpsSignalWeak: wasGpsSignalWeak,
        )) {
      return TrackingGpsDecision(
        type: TrackingGpsDecisionType.acceptRoute,
        livePoint: livePoint,
        previewPoint: previewPoint,
        segmentMeters: 0,
        rawSegmentMeters: rawSegmentMeters,
        routeSegmentMeters: routeSegmentMeters,
        candidateSpeedKmh: 0,
        shouldAddDistance: false,
        shouldBreakRouteForDisplay: true,
        gpsGapDurationSec: timeDeltaSec,
        outcome: GpsPointOutcome.signalGap,
        reason: GpsRejectReason.staleSignalGap,
      );
    }

    if (timeDeltaSec > 0) {
      final impliedSpeed = segmentMeters / timeDeltaSec;
      if (impliedSpeed > maxSpeedMs * 1.2) {
        return TrackingGpsDecision(
          type: TrackingGpsDecisionType.skip,
          livePoint: livePoint,
          previewPoint: previewPoint,
          skipReason:
              'implied_speed_hard_spike=${impliedSpeed.toStringAsFixed(2)}m/s',
          segmentMeters: segmentMeters,
          rawSegmentMeters: rawSegmentMeters,
          routeSegmentMeters: routeSegmentMeters,
          outcome: GpsPointOutcome.hardRejected,
          reason: GpsRejectReason.impliedSpeedHardSpike,
        );
      }
    }

    final canUseBearingFilter = routePoints.length >= 2;
    if (canUseBearingFilter) {
      final previousBearing = computeBearing(
        routePoints[routePoints.length - 2],
        lastPoint,
      );
      final currentBearing = computeBearing(lastPoint, livePoint);
      final delta = bearingDelta(previousBearing, currentBearing);
      if (delta > 120.0 && rawSegmentMeters < 20.0) {
        return TrackingGpsDecision(
          type: TrackingGpsDecisionType.skip,
          livePoint: livePoint,
          previewPoint: previewPoint,
          skipReason: 'bearing_delta=${delta.toStringAsFixed(1)}deg',
          segmentMeters: segmentMeters,
          rawSegmentMeters: rawSegmentMeters,
          routeSegmentMeters: routeSegmentMeters,
          outcome: GpsPointOutcome.hardRejected,
          reason: GpsRejectReason.headingSpike,
        );
      }
    }

    final sensorSpeedKmh = position.speed > 0
        ? position.speed.clamp(0.0, 50.0) * 3.6
        : 0.0;
    final segmentSpeedKmh = timeDeltaSec > 0
        ? (segmentMeters / timeDeltaSec) * 3.6
        : sensorSpeedKmh;
    final candidateSpeedKmh = segmentSpeedKmh > 0
        ? segmentSpeedKmh
        : sensorSpeedKmh;

    return TrackingGpsDecision(
      type: TrackingGpsDecisionType.acceptRoute,
      livePoint: livePoint,
      previewPoint: previewPoint,
      segmentMeters: segmentMeters,
      rawSegmentMeters: rawSegmentMeters,
      routeSegmentMeters: routeSegmentMeters,
      candidateSpeedKmh: candidateSpeedKmh,
      outcome: GpsPointOutcome.accepted,
    );
  }

  bool _shouldBreakLiveRouteForDisplay({
    required String activityType,
    required double accuracyMeters,
    required double timeDeltaSec,
    required double routeSegmentMeters,
    required bool wasGpsSignalWeak,
  }) {
    if (routeSegmentMeters <= 0) return false;

    final normalized = activityType.toLowerCase();
    final jumpMeters = _liveRecoveryJumpMeters(normalized);
    final weakAccuracy = _weakLiveAccuracyMeters(normalized);
    final plausibleSpeedMs = _plausibleLiveSpeedMs(normalized);
    final impliedSpeedMs = timeDeltaSec > 0
        ? routeSegmentMeters / timeDeltaSec
        : 0.0;

    if (wasGpsSignalWeak && routeSegmentMeters >= jumpMeters * 0.65) {
      return true;
    }
    if (accuracyMeters >= weakAccuracy && routeSegmentMeters >= jumpMeters) {
      return true;
    }
    if (timeDeltaSec >= 2.0 &&
        routeSegmentMeters >= jumpMeters &&
        impliedSpeedMs > plausibleSpeedMs) {
      return true;
    }
    return false;
  }

  double _liveRecoveryJumpMeters(String activityType) {
    switch (activityType) {
      case 'cycling':
        return 70.0;
      case 'running':
        return 34.0;
      case 'walking':
        return 24.0;
      default:
        return 30.0;
    }
  }

  double _weakLiveAccuracyMeters(String activityType) {
    switch (activityType) {
      case 'cycling':
        return 28.0;
      case 'running':
        return 32.0;
      case 'walking':
        return 34.0;
      default:
        return 30.0;
    }
  }

  double _plausibleLiveSpeedMs(String activityType) {
    switch (activityType) {
      case 'cycling':
        return 15.0;
      case 'running':
        return 7.0;
      case 'walking':
        return 3.2;
      default:
        return 6.0;
    }
  }

  StepTrackingDecision evaluateStepUpdate({
    required int sessionSteps,
    required int currentStepCount,
    required String activityType,
    required bool requiresGpsTracking,
    required bool gpsFallbackActive,
    required String recordingSource,
    required DateTime? lastAcceptedPositionTime,
    required DateTime now,
  }) {
    final delta = sessionSteps - currentStepCount;
    if (delta <= 0) {
      return const StepTrackingDecision(
        delta: 0,
        shouldActivateGpsFallback: false,
      );
    }

    final secondsSinceGps = lastAcceptedPositionTime == null
        ? 999
        : now.difference(lastAcceptedPositionTime).inSeconds;
    final shouldActivateGpsFallback =
        requiresGpsTracking &&
        supportsStepFallback(activityType) &&
        !gpsFallbackActive &&
        recordingSource == 'gps' &&
        sessionSteps >= 8 &&
        secondsSinceGps >= 12;

    return StepTrackingDecision(
      delta: delta,
      shouldActivateGpsFallback: shouldActivateGpsFallback,
    );
  }

  /// Step counts are a valid distance fallback only for activities whose
  /// distance model is based on strides. Cycling must remain GPS-based: a
  /// noisy pedalling/phone-motion step count must never switch it to indoor
  /// fallback and falsely auto-pause the session.
  bool supportsStepFallback(String activityType) {
    switch (activityType.toLowerCase()) {
      case 'running':
      case 'walking':
        return true;
      default:
        return false;
    }
  }

  IndoorStepContribution computeIndoorStepContribution({
    required int stepDelta,
    required double strideLengthMeters,
    required DateTime now,
    required DateTime? lastStepTime,
  }) {
    final addedDistanceMeters = stepDelta * strideLengthMeters;
    double? instantSpeedKmh;
    if (lastStepTime != null) {
      final secondsSinceLastStep =
          now.difference(lastStepTime).inMilliseconds / 1000.0;
      if (secondsSinceLastStep > 0) {
        instantSpeedKmh = (addedDistanceMeters / secondsSinceLastStep) * 3.6;
      }
    }
    return IndoorStepContribution(
      addedDistanceMeters: addedDistanceMeters,
      instantSpeedKmh: instantSpeedKmh,
    );
  }

  bool isMoving(double speedKmh, String activityType) {
    return speedKmh >= getMinMovingSpeedKmh(activityType);
  }

  ActivityConsistencyAssessment assessActivityConsistency({
    required String activityType,
    required double avgSpeedKmh,
    required double distanceKm,
    required int durationSec,
  }) {
    final normalizedActivity = activityType.toLowerCase();
    final minExpectedAvgSpeedKmh = getMinExpectedAverageSpeedKmh(
      normalizedActivity,
    );
    final maxExpectedAvgSpeedKmh = getMaxExpectedAverageSpeedKmh(
      normalizedActivity,
    );

    // Ignore very short/noisy sessions and let backend decide later.
    if (durationSec < 180 || distanceKm < 0.2 || avgSpeedKmh <= 0) {
      return ActivityConsistencyAssessment(
        shouldInvalidateResult: false,
        reason: null,
        minExpectedAvgSpeedKmh: minExpectedAvgSpeedKmh,
        maxExpectedAvgSpeedKmh: maxExpectedAvgSpeedKmh,
      );
    }

    if (avgSpeedKmh < minExpectedAvgSpeedKmh) {
      return ActivityConsistencyAssessment(
        shouldInvalidateResult: true,
        reason: 'avg_speed_too_low_for_$normalizedActivity',
        minExpectedAvgSpeedKmh: minExpectedAvgSpeedKmh,
        maxExpectedAvgSpeedKmh: maxExpectedAvgSpeedKmh,
      );
    }

    if (avgSpeedKmh > maxExpectedAvgSpeedKmh) {
      return ActivityConsistencyAssessment(
        shouldInvalidateResult: true,
        reason: 'avg_speed_too_high_for_$normalizedActivity',
        minExpectedAvgSpeedKmh: minExpectedAvgSpeedKmh,
        maxExpectedAvgSpeedKmh: maxExpectedAvgSpeedKmh,
      );
    }

    return ActivityConsistencyAssessment(
      shouldInvalidateResult: false,
      reason: null,
      minExpectedAvgSpeedKmh: minExpectedAvgSpeedKmh,
      maxExpectedAvgSpeedKmh: maxExpectedAvgSpeedKmh,
    );
  }

  double getMinMovingSpeedKmh(String activityType) {
    switch (activityType.toLowerCase()) {
      case 'walking':
        return 0.10;
      case 'cycling':
        return 0.4;
      case 'running':
      default:
        return 0.20;
    }
  }

  double getHardGpsSpikeSpeedMs() {
    return 80.0;
  }

  double getMinExpectedAverageSpeedKmh(String activityType) {
    switch (activityType) {
      case 'walking':
        return 1.5;
      case 'cycling':
        return 8.0;
      case 'running':
        return 5.5;
      default:
        return 0.0;
    }
  }

  double getMaxExpectedAverageSpeedKmh(String activityType) {
    switch (activityType) {
      case 'walking':
        return 9.0;
      case 'cycling':
        return 45.0;
      case 'running':
        return 24.0;
      default:
        return 60.0;
    }
  }

  double getMinSegmentMeters(String activityType) {
    switch (activityType.toLowerCase()) {
      case 'walking':
        return 0.35;
      case 'cycling':
        return 1.5;
      case 'running':
        return 0.30;
      default:
        return 0.30;
    }
  }

  double getMaxRouteAccuracy(String activityType) {
    switch (activityType.toLowerCase()) {
      case 'cycling':
        return 32.0;
      case 'running':
        return 42.0;
      case 'walking':
        return 50.0;
      default:
        return 35.0;
    }
  }

  double getInitialFixAccuracy(String activityType) {
    switch (activityType.toLowerCase()) {
      case 'cycling':
        return 20.0;
      case 'walking':
        return 18.0;
      case 'running':
      default:
        return 16.0;
    }
  }

  double getPreviewAccuracy(String activityType) {
    switch (activityType.toLowerCase()) {
      case 'cycling':
        return 35.0;
      case 'running':
        return 45.0;
      case 'walking':
        return 60.0;
      default:
        return 45.0;
    }
  }

  double computeBearing(LatLng from, LatLng to) {
    final lat1 = from.latitude * math.pi / 180.0;
    final lat2 = to.latitude * math.pi / 180.0;
    final dLng = (to.longitude - from.longitude) * math.pi / 180.0;
    final y = math.sin(dLng) * math.cos(lat2);
    final x =
        math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLng);
    final bearing = math.atan2(y, x) * 180.0 / math.pi;
    return (bearing + 360.0) % 360.0;
  }

  double bearingDelta(double a, double b) {
    final delta = (a - b).abs();
    return delta > 180 ? 360 - delta : delta;
  }

  String confidenceForAccuracy(double? accuracy) {
    if (accuracy == null || accuracy.isNaN || accuracy.isInfinite) {
      return 'low';
    }
    if (accuracy <= 10.0) return 'high';
    if (accuracy <= 30.0) return 'medium';
    return 'low';
  }

  WorkoutGpsAnalysis analyzeGpsWorkout(GpsWorkoutAnalysisInput input) {
    // Diagnose true GPS outages BEFORE filtering: dropped spikes and tiny fixes
    // must not be reclassified as an unavailable raw sensor stream.
    final rawSorted = List<Position>.from(input.rawPositions)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    final rawSignalGaps = <({DateTime end, double durationSec})>[];
    for (var i = 1; i < rawSorted.length; i++) {
      final dt =
          rawSorted[i].timestamp
              .difference(rawSorted[i - 1].timestamp)
              .inMilliseconds /
          1000.0;
      if (dt > kStaleSignalGapThresholdSec) {
        rawSignalGaps.add((end: rawSorted[i].timestamp, durationSec: dt));
      }
    }

    final filtered = _filterRawPositions(input.rawPositions);
    if (filtered.length < 2) {
      final fallbackKm = (input.fallbackDistanceMeters / 1000).clamp(
        0.0,
        double.infinity,
      );
      return WorkoutGpsAnalysis(
        totalDistanceKm: fallbackKm,
        validDistanceKm: fallbackKm,
        effectivePaceSecPerKm: fallbackKm > 0
            ? input.totalDurationSec / fallbackKm
            : null,
      );
    }

    final thresholds = _segmentThresholdFor(input.activityType);
    final flaggedSegments = <WorkoutFlaggedSegment>[];
    var totalDistanceM = 0.0;
    var validDistanceM = 0.0;
    var suspiciousDistanceM = 0.0;
    var invalidDistanceM = 0.0;
    var restDurationSec = 0.0;
    final gpsGapCount = rawSignalGaps.length;
    final gpsGapDurationSec = rawSignalGaps.fold<double>(
      0.0,
      (sum, gap) => sum + gap.durationSec,
    );

    var segmentStartIndex = 0;
    var segmentDistanceM = 0.0;
    var segmentAccuracySum = filtered.first.accuracy;
    var segmentPointCount = 1;
    var stationaryDurationSec = 0.0;

    for (var i = 1; i < filtered.length; i++) {
      final prev = filtered[i - 1];
      final curr = filtered[i];
      final deltaSec =
          curr.timestamp.difference(prev.timestamp).inMilliseconds / 1000.0;
      if (deltaSec <= 0) {
        continue;
      }

      // A long interval between retained fixes is not necessarily an outage.
      // Break only if the original raw stream actually stopped in this span.
      final crossedRawOutage = rawSignalGaps.any(
        (gap) =>
            gap.end.isAfter(prev.timestamp) && !gap.end.isAfter(curr.timestamp),
      );
      if (crossedRawOutage) {
        _finalizeSegment(
          filtered: filtered,
          startIndex: segmentStartIndex,
          endIndex: i - 1,
          distanceM: segmentDistanceM,
          accuracySum: segmentAccuracySum,
          pointCount: segmentPointCount,
          thresholds: thresholds,
          flaggedSegments: flaggedSegments,
          onValid: (value) => validDistanceM += value,
          onSuspicious: (value) => suspiciousDistanceM += value,
          onInvalid: (value) => invalidDistanceM += value,
          onTotal: (value) => totalDistanceM += value,
        );
        segmentStartIndex = i;
        segmentDistanceM = 0;
        segmentAccuracySum = curr.accuracy;
        segmentPointCount = 1;
        stationaryDurationSec = 0;
        continue;
      }

      final distanceM = Geolocator.distanceBetween(
        prev.latitude,
        prev.longitude,
        curr.latitude,
        curr.longitude,
      );

      if (distanceM < 1.0 || (distanceM / deltaSec) < 0.3) {
        stationaryDurationSec += deltaSec;
      } else {
        if (stationaryDurationSec >= 60.0) {
          restDurationSec += stationaryDurationSec;
        }
        stationaryDurationSec = 0;
      }

      segmentDistanceM += distanceM;
      segmentAccuracySum += curr.accuracy;
      segmentPointCount += 1;

      final segmentDurationSec =
          filtered[i].timestamp
              .difference(filtered[segmentStartIndex].timestamp)
              .inMilliseconds /
          1000.0;
      final shouldCloseByDistance = segmentDistanceM >= 100.0;
      final shouldCloseByTime =
          segmentDurationSec >= 30.0 && segmentDistanceM > 0.0;
      if (!shouldCloseByDistance && !shouldCloseByTime) {
        continue;
      }

      _finalizeSegment(
        filtered: filtered,
        startIndex: segmentStartIndex,
        endIndex: i,
        distanceM: segmentDistanceM,
        accuracySum: segmentAccuracySum,
        pointCount: segmentPointCount,
        thresholds: thresholds,
        flaggedSegments: flaggedSegments,
        onValid: (value) => validDistanceM += value,
        onSuspicious: (value) => suspiciousDistanceM += value,
        onInvalid: (value) => invalidDistanceM += value,
        onTotal: (value) => totalDistanceM += value,
      );
      segmentStartIndex = i;
      segmentDistanceM = 0;
      segmentAccuracySum = curr.accuracy;
      segmentPointCount = 1;
    }

    if (stationaryDurationSec >= 60.0) {
      restDurationSec += stationaryDurationSec;
    }

    _finalizeSegment(
      filtered: filtered,
      startIndex: segmentStartIndex,
      endIndex: filtered.length - 1,
      distanceM: segmentDistanceM,
      accuracySum: segmentAccuracySum,
      pointCount: segmentPointCount,
      thresholds: thresholds,
      flaggedSegments: flaggedSegments,
      onValid: (value) => validDistanceM += value,
      onSuspicious: (value) => suspiciousDistanceM += value,
      onInvalid: (value) => invalidDistanceM += value,
      onTotal: (value) => totalDistanceM += value,
    );

    final normalizedTotalDistanceM = totalDistanceM > 0
        ? totalDistanceM
        : input.fallbackDistanceMeters;
    final suspiciousRatio = normalizedTotalDistanceM <= 0
        ? 0.0
        : suspiciousDistanceM / normalizedTotalDistanceM;
    final segmentValidityFlag = suspiciousRatio > 0.30
        ? WorkoutValidityFlag.unverified
        : suspiciousRatio > 0.10
        ? WorkoutValidityFlag.partial
        : WorkoutValidityFlag.verified;
    final gpsGapRatio = input.totalDurationSec <= 0
        ? 0.0
        : gpsGapDurationSec / input.totalDurationSec;
    final gpsGapValidityFlag = _validityForGpsGaps(
      gapDurationSec: gpsGapDurationSec,
      gapRatio: gpsGapRatio,
    );
    final validityFlag = _leastReliableValidity(
      segmentValidityFlag,
      gpsGapValidityFlag,
    );
    final effectivePaceSecPerKm = validDistanceM > 0
        ? input.totalDurationSec / (validDistanceM / 1000.0)
        : null;

    return WorkoutGpsAnalysis(
      totalDistanceKm: normalizedTotalDistanceM / 1000.0,
      validDistanceKm: validDistanceM / 1000.0,
      suspiciousDistanceKm: suspiciousDistanceM / 1000.0,
      invalidDistanceKm: invalidDistanceM / 1000.0,
      restDurationSec: restDurationSec.round(),
      gpsGapCount: gpsGapCount,
      gpsGapDurationSec: gpsGapDurationSec.round(),
      effectivePaceSecPerKm: effectivePaceSecPerKm,
      suspiciousRatio: suspiciousRatio,
      validityFlag: validityFlag,
      flaggedSegments: flaggedSegments,
    );
  }

  WorkoutValidityFlag _validityForGpsGaps({
    required double gapDurationSec,
    required double gapRatio,
  }) {
    // Short, isolated losses are normal outdoors. A session with more than a
    // third of its duration missing GPS, or a sustained three-minute outage,
    // cannot truthfully be reported as a verified route.
    if (gapRatio >= 0.35 || gapDurationSec >= 180.0) {
      return WorkoutValidityFlag.unverified;
    }
    if (gapRatio >= 0.12 || gapDurationSec >= 45.0) {
      return WorkoutValidityFlag.partial;
    }
    return WorkoutValidityFlag.verified;
  }

  WorkoutValidityFlag _leastReliableValidity(
    WorkoutValidityFlag left,
    WorkoutValidityFlag right,
  ) {
    if (left == WorkoutValidityFlag.unverified ||
        right == WorkoutValidityFlag.unverified) {
      return WorkoutValidityFlag.unverified;
    }
    if (left == WorkoutValidityFlag.partial ||
        right == WorkoutValidityFlag.partial) {
      return WorkoutValidityFlag.partial;
    }
    return WorkoutValidityFlag.verified;
  }

  SegmentThreshold _segmentThresholdFor(String activityType) {
    switch (activityType.toLowerCase()) {
      case 'walking':
        return const SegmentThreshold(
          minPaceSecPerKm: 300,
          maxPaceSecPerKm: 1800,
        );
      case 'cycling':
        return const SegmentThreshold(
          minPaceSecPerKm: 45,
          maxPaceSecPerKm: 600,
        );
      case 'hiking':
        return const SegmentThreshold(
          minPaceSecPerKm: 240,
          maxPaceSecPerKm: 2400,
        );
      case 'running':
      default:
        return const SegmentThreshold(
          minPaceSecPerKm: 150,
          maxPaceSecPerKm: 720,
        );
    }
  }

  List<Position> _filterRawPositions(List<Position> positions) {
    if (positions.length < 2) return List<Position>.from(positions);
    final sorted = List<Position>.from(positions)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    final kept = <Position>[sorted.first];

    for (var i = 1; i < sorted.length; i++) {
      final prev = kept.last;
      final curr = sorted[i];
      final dtSec =
          curr.timestamp.difference(prev.timestamp).inMilliseconds / 1000.0;
      if (dtSec <= 0) continue;

      final distanceM = Geolocator.distanceBetween(
        prev.latitude,
        prev.longitude,
        curr.latitude,
        curr.longitude,
      );
      final impliedSpeedMs = distanceM / dtSec;
      if (distanceM > 500.0 && dtSec < 2.0) {
        continue;
      }
      if (impliedSpeedMs > 80.0 || (curr.speed > 0 && curr.speed > 80.0)) {
        continue;
      }
      kept.add(curr);
    }

    if (kept.length < 3) return kept;

    final result = <Position>[kept.first];
    for (var i = 1; i < kept.length - 1; i++) {
      final prev = result.last;
      final curr = kept[i];
      final next = kept[i + 1];
      final distancePrevCurr = Geolocator.distanceBetween(
        prev.latitude,
        prev.longitude,
        curr.latitude,
        curr.longitude,
      );
      final delta = bearingDelta(
        computeBearing(
          LatLng(prev.latitude, prev.longitude),
          LatLng(curr.latitude, curr.longitude),
        ),
        computeBearing(
          LatLng(curr.latitude, curr.longitude),
          LatLng(next.latitude, next.longitude),
        ),
      );
      if (delta > 120.0 && distancePrevCurr < 20.0) {
        continue;
      }
      result.add(curr);
    }
    result.add(kept.last);
    return result;
  }

  void _finalizeSegment({
    required List<Position> filtered,
    required int startIndex,
    required int endIndex,
    required double distanceM,
    required double accuracySum,
    required int pointCount,
    required SegmentThreshold thresholds,
    required List<WorkoutFlaggedSegment> flaggedSegments,
    required void Function(double value) onValid,
    required void Function(double value) onSuspicious,
    required void Function(double value) onInvalid,
    required void Function(double value) onTotal,
  }) {
    if (endIndex <= startIndex || distanceM <= 0) {
      return;
    }

    final start = filtered[startIndex];
    final end = filtered[endIndex];
    final durationSec =
        end.timestamp.difference(start.timestamp).inMilliseconds / 1000.0;
    if (durationSec <= 0) {
      return;
    }

    final avgAccuracy = pointCount <= 0 ? 999.0 : accuracySum / pointCount;
    final paceSecPerKm = durationSec / (distanceM / 1000.0);
    final avgSpeedMs = distanceM / durationSec;

    WorkoutSegmentStatus status;
    String reason;
    if (avgAccuracy > 50.0) {
      status = WorkoutSegmentStatus.invalid;
      reason = 'low_gps_accuracy';
    } else if (paceSecPerKm < thresholds.minPaceSecPerKm) {
      status = WorkoutSegmentStatus.suspicious;
      reason = 'pace_too_fast';
    } else if (paceSecPerKm > thresholds.maxPaceSecPerKm) {
      status = WorkoutSegmentStatus.invalid;
      reason = 'pace_too_slow';
    } else {
      status = WorkoutSegmentStatus.valid;
      reason = 'valid';
    }

    onTotal(distanceM);
    switch (status) {
      case WorkoutSegmentStatus.valid:
        onValid(distanceM);
        break;
      case WorkoutSegmentStatus.suspicious:
        onSuspicious(distanceM);
        flaggedSegments.add(
          WorkoutFlaggedSegment(
            startTimestamp: start.timestamp.toUtc(),
            endTimestamp: end.timestamp.toUtc(),
            distanceM: distanceM,
            durationSec: durationSec,
            paceSecPerKm: paceSecPerKm,
            avgSpeedMs: avgSpeedMs,
            avgAccuracy: avgAccuracy,
            status: status,
            reason: reason,
          ),
        );
        break;
      case WorkoutSegmentStatus.invalid:
        onInvalid(distanceM);
        flaggedSegments.add(
          WorkoutFlaggedSegment(
            startTimestamp: start.timestamp.toUtc(),
            endTimestamp: end.timestamp.toUtc(),
            distanceM: distanceM,
            durationSec: durationSec,
            paceSecPerKm: paceSecPerKm,
            avgSpeedMs: avgSpeedMs,
            avgAccuracy: avgAccuracy,
            status: status,
            reason: reason,
          ),
        );
        break;
    }
  }
}
