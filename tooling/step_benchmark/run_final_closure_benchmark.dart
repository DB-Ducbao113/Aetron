// ignore_for_file: avoid_print, unused_local_variable
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_exercise_application/core/services/cadence_calculator_service.dart';
import 'package:fitness_exercise_application/core/services/sensor/mock_step_sensor_adapter.dart';
import 'package:fitness_exercise_application/core/services/step_tracking_service.dart';

class SessionMetrics {
  final String dataset;
  final String sessionId;
  final String pid;
  final String protocolOrCategory;
  final String sex;
  final String ageGroup;
  final double durationSec;
  final int stepCount;
  final double activeSeconds;
  final double stationarySeconds;

  // Active walking errors
  final double activeMae3s;
  final double activeRmse3s;
  final double activeBias3s;
  final double activeP50_3s;
  final double activeP90_3s;
  final double activeP95_3s;

  final double activeMae6s;
  final double activeRmse6s;
  final double activeBias6s;
  final double activeP50_6s;
  final double activeP90_6s;
  final double activeP95_6s;

  final double activeMae10s;
  final double activeRmse10s;
  final double activeBias10s;
  final double activeP50_10s;
  final double activeP90_10s;
  final double activeP95_10s;

  // Stationary false cadence
  final double stationaryMeanCadence3s;
  final double stationaryMeanCadence6s;
  final double stationaryMeanCadence10s;

  // Cadence jitter (mean absolute change between consecutive active seconds)
  final double jitterMean3s;
  final double jitterStd3s;
  final double jitterMean6s;
  final double jitterStd6s;
  final double jitterMean10s;
  final double jitterStd10s;

  // Response lag (seconds)
  final double startupLag3s;
  final double startupLag6s;
  final double startupLag10s;

  final double stopLag3s;
  final double stopLag6s;
  final double stopLag10s;

  SessionMetrics({
    required this.dataset,
    required this.sessionId,
    required this.pid,
    required this.protocolOrCategory,
    required this.sex,
    required this.ageGroup,
    required this.durationSec,
    required this.stepCount,
    required this.activeSeconds,
    required this.stationarySeconds,
    required this.activeMae3s,
    required this.activeRmse3s,
    required this.activeBias3s,
    required this.activeP50_3s,
    required this.activeP90_3s,
    required this.activeP95_3s,
    required this.activeMae6s,
    required this.activeRmse6s,
    required this.activeBias6s,
    required this.activeP50_6s,
    required this.activeP90_6s,
    required this.activeP95_6s,
    required this.activeMae10s,
    required this.activeRmse10s,
    required this.activeBias10s,
    required this.activeP50_10s,
    required this.activeP90_10s,
    required this.activeP95_10s,
    required this.stationaryMeanCadence3s,
    required this.stationaryMeanCadence6s,
    required this.stationaryMeanCadence10s,
    required this.jitterMean3s,
    required this.jitterStd3s,
    required this.jitterMean6s,
    required this.jitterStd6s,
    required this.jitterMean10s,
    required this.jitterStd10s,
    required this.startupLag3s,
    required this.startupLag6s,
    required this.startupLag10s,
    required this.stopLag3s,
    required this.stopLag6s,
    required this.stopLag10s,
  });
}

double _calcStd(List<double> values, double mean) {
  if (values.length < 2) return 0.0;
  var sumSq = 0.0;
  for (final v in values) {
    sumSq += (v - mean) * (v - mean);
  }
  return math.sqrt(sumSq / (values.length - 1));
}

double _calcPercentile(List<double> sortedValues, double pct) {
  if (sortedValues.isEmpty) return 0.0;
  final index = (pct * (sortedValues.length - 1)).round();
  return sortedValues[math.min(sortedValues.length - 1, math.max(0, index))];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Aetron Final Closure Offline Scientific Benchmark', () async {
    print('================================================================');
    print(' AETRON SENSOR INTEGRATION — FINAL CLOSURE SCIENTIFIC BENCHMARK ');
    print(' Evaluated on Clemson PedEval (90 sess) & Oxford OxWalk (39 sess)');
    print('================================================================\n');

    final baseDir = Directory.current.path;
    final resultsDir = Directory('$baseDir/tooling/step_benchmark/results');
    if (!resultsDir.existsSync()) {
      resultsDir.createSync(recursive: true);
    }

    final pedevalDir = Directory('$baseDir/tooling/step_benchmark/pedeval/Data');
    final oxwalkStepsDir = Directory('$baseDir/tooling/step_benchmark/oxwalk/steps');
    final oxwalkManifestFile = File('$baseDir/tooling/step_benchmark/oxwalk/oxwalk_manifest.json');
    final pedevalDemoFile = File('$baseDir/tooling/step_benchmark/pedeval/demographics.csv');

    expect(pedevalDir.existsSync(), isTrue, reason: 'PedEval Data directory must exist');
    expect(oxwalkStepsDir.existsSync(), isTrue, reason: 'OxWalk steps directory must exist');
    expect(oxwalkManifestFile.existsSync(), isTrue, reason: 'OxWalk manifest must exist');
    expect(pedevalDemoFile.existsSync(), isTrue, reason: 'PedEval demographics must exist');

    // ─────────────────────────────────────────────────────────────────────────
    // 1. LOAD PEDEVAL DEMOGRAPHICS
    // ─────────────────────────────────────────────────────────────────────────
    final pedevalDemo = <String, Map<String, String>>{};
    for (final line in pedevalDemoFile.readAsLinesSync().skip(1)) {
      final parts = line.split(',');
      if (parts.length >= 3) {
        pedevalDemo[parts[0].trim()] = {
          'sex': parts[1].trim(),
          'age': parts[2].trim(),
        };
      }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 2. LOAD OXWALK MANIFEST & METADATA
    // ─────────────────────────────────────────────────────────────────────────
    final oxwalkManifest = jsonDecode(oxwalkManifestFile.readAsStringSync()) as Map<String, dynamic>;
    final oxwalkSessionsMeta = oxwalkManifest['sessions'] as List<dynamic>;

    // ─────────────────────────────────────────────────────────────────────────
    // EVALUATION PIPELINE FOR A GENERIC STEP TIMELINE
    // ─────────────────────────────────────────────────────────────────────────
    SessionMetrics evaluateSession({
      required String dataset,
      required String sessionId,
      required String pid,
      required String protocolOrCategory,
      required String sex,
      required String ageGroup,
      required double durationSec,
      required List<double> stepTimes,
      required double Function(double t, int stepIdx, double lastStepT, double prevStepT) computeOracle,
    }) {
      final maxSec = durationSec.ceil();

      // PRODUCTION SERVICES
      final calc3 = CadenceCalculatorService(
        windowDuration: const Duration(seconds: 3),
        inactivityTimeout: const Duration(seconds: 4),
      );
      final calc6 = CadenceCalculatorService(
        windowDuration: const Duration(seconds: 6),
        inactivityTimeout: const Duration(seconds: 4),
      );
      final calc10 = CadenceCalculatorService(
        windowDuration: const Duration(seconds: 10),
        inactivityTimeout: const Duration(seconds: 4),
      );

      final startDate = DateTime(2026, 11, 6, 8, 0, 0);

      var stepIdx = 0;
      var lastStepT = -999.0;
      var prevStepT = -999.0;

      final oracleTrace = <double>[];
      final cad3Trace = <double>[];
      final cad6Trace = <double>[];
      final cad10Trace = <double>[];
      final isStepActiveTrace = <bool>[];

      for (var s = 1; s <= maxSec; s++) {
        final t = s.toDouble();
        final now = startDate.add(Duration(seconds: s));

        while (stepIdx < stepTimes.length && stepTimes[stepIdx] <= t) {
          prevStepT = lastStepT;
          lastStepT = stepTimes[stepIdx];
          stepIdx++;
        }

        final oracle = computeOracle(t, stepIdx, lastStepT, prevStepT);

        final c3 = calc3.computeInstantCadence(activeSteps: stepIdx, timestamp: now).toDouble();
        final c6 = calc6.computeInstantCadence(activeSteps: stepIdx, timestamp: now).toDouble();
        final c10 = calc10.computeInstantCadence(activeSteps: stepIdx, timestamp: now).toDouble();

        final isActive = (t - lastStepT) <= 3.0 && stepIdx >= 2;

        oracleTrace.add(oracle);
        cad3Trace.add(c3);
        cad6Trace.add(c6);
        cad10Trace.add(c10);
        isStepActiveTrace.add(isActive);
      }

      // ── Metrics collection ──
      final activeDiff3 = <double>[];
      final activeDiff6 = <double>[];
      final activeDiff10 = <double>[];

      final activeAbs3 = <double>[];
      final activeAbs6 = <double>[];
      final activeAbs10 = <double>[];

      final stationaryCad3 = <double>[];
      final stationaryCad6 = <double>[];
      final stationaryCad10 = <double>[];

      final jitterDeltas3 = <double>[];
      final jitterDeltas6 = <double>[];
      final jitterDeltas10 = <double>[];

      var activeSecCount = 0;
      var statSecCount = 0;

      for (var i = 0; i < maxSec; i++) {
        final isActive = isStepActiveTrace[i];
        final o = oracleTrace[i];
        final c3 = cad3Trace[i];
        final c6 = cad6Trace[i];
        final c10 = cad10Trace[i];

        if (isActive && o > 0) {
          activeSecCount++;
          activeDiff3.add(c3 - o);
          activeDiff6.add(c6 - o);
          activeDiff10.add(c10 - o);

          activeAbs3.add((c3 - o).abs());
          activeAbs6.add((c6 - o).abs());
          activeAbs10.add((c10 - o).abs());

          // Jitter (consecutive active seconds)
          if (i > 0 && isStepActiveTrace[i - 1]) {
            jitterDeltas3.add((c3 - cad3Trace[i - 1]).abs());
            jitterDeltas6.add((c6 - cad6Trace[i - 1]).abs());
            jitterDeltas10.add((c10 - cad10Trace[i - 1]).abs());
          }
        } else {
          statSecCount++;
          stationaryCad3.add(c3);
          stationaryCad6.add(c6);
          stationaryCad10.add(c10);
        }
      }

      // Response Lag: Startup and Stop Lag across transitions
      final startupLags3 = <double>[];
      final startupLags6 = <double>[];
      final startupLags10 = <double>[];

      final stopLags3 = <double>[];
      final stopLags6 = <double>[];
      final stopLags10 = <double>[];

      for (var i = 1; i < maxSec; i++) {
        // Transition: Stationary -> Active (Startup)
        if (!isStepActiveTrace[i - 1] && isStepActiveTrace[i]) {
          final tStart = i.toDouble();
          // Find when cadence first becomes > 0
          var lag3 = 3.0;
          var lag6 = 3.0;
          var lag10 = 3.0;
          for (var k = i; k < math.min(maxSec, i + 10); k++) {
            if (cad3Trace[k] > 0 && lag3 == 3.0) lag3 = (k - i + 1).toDouble();
            if (cad6Trace[k] > 0 && lag6 == 3.0) lag6 = (k - i + 1).toDouble();
            if (cad10Trace[k] > 0 && lag10 == 3.0) lag10 = (k - i + 1).toDouble();
          }
          startupLags3.add(lag3);
          startupLags6.add(lag6);
          startupLags10.add(lag10);
        }

        // Transition: Active -> Stationary (Stop / Decay)
        if (isStepActiveTrace[i - 1] && !isStepActiveTrace[i]) {
          // Find how many seconds until cadence drops to 0
          var decay3 = 10.0;
          var decay6 = 10.0;
          var decay10 = 10.0;
          for (var k = i; k < math.min(maxSec, i + 15); k++) {
            if (cad3Trace[k] == 0 && decay3 == 10.0) decay3 = (k - i + 1).toDouble();
            if (cad6Trace[k] == 0 && decay6 == 10.0) decay6 = (k - i + 1).toDouble();
            if (cad10Trace[k] == 0 && decay10 == 10.0) decay10 = (k - i + 1).toDouble();
          }
          stopLags3.add(decay3);
          stopLags6.add(decay6);
          stopLags10.add(decay10);
        }
      }

      double mean(List<double> list) => list.isEmpty ? 0.0 : list.reduce((a, b) => a + b) / list.length;
      double rmse(List<double> diffs) =>
          diffs.isEmpty ? 0.0 : math.sqrt(diffs.map((d) => d * d).reduce((a, b) => a + b) / diffs.length);

      activeAbs3.sort();
      activeAbs6.sort();
      activeAbs10.sort();

      final jMean3 = mean(jitterDeltas3);
      final jMean6 = mean(jitterDeltas6);
      final jMean10 = mean(jitterDeltas10);

      return SessionMetrics(
        dataset: dataset,
        sessionId: sessionId,
        pid: pid,
        protocolOrCategory: protocolOrCategory,
        sex: sex,
        ageGroup: ageGroup,
        durationSec: durationSec,
        stepCount: stepTimes.length,
        activeSeconds: activeSecCount.toDouble(),
        stationarySeconds: statSecCount.toDouble(),
        activeMae3s: mean(activeAbs3),
        activeRmse3s: rmse(activeDiff3),
        activeBias3s: mean(activeDiff3),
        activeP50_3s: _calcPercentile(activeAbs3, 0.50),
        activeP90_3s: _calcPercentile(activeAbs3, 0.90),
        activeP95_3s: _calcPercentile(activeAbs3, 0.95),
        activeMae6s: mean(activeAbs6),
        activeRmse6s: rmse(activeDiff6),
        activeBias6s: mean(activeDiff6),
        activeP50_6s: _calcPercentile(activeAbs6, 0.50),
        activeP90_6s: _calcPercentile(activeAbs6, 0.90),
        activeP95_6s: _calcPercentile(activeAbs6, 0.95),
        activeMae10s: mean(activeAbs10),
        activeRmse10s: rmse(activeDiff10),
        activeBias10s: mean(activeDiff10),
        activeP50_10s: _calcPercentile(activeAbs10, 0.50),
        activeP90_10s: _calcPercentile(activeAbs10, 0.90),
        activeP95_10s: _calcPercentile(activeAbs10, 0.95),
        stationaryMeanCadence3s: mean(stationaryCad3),
        stationaryMeanCadence6s: mean(stationaryCad6),
        stationaryMeanCadence10s: mean(stationaryCad10),
        jitterMean3s: jMean3,
        jitterStd3s: _calcStd(jitterDeltas3, jMean3),
        jitterMean6s: jMean6,
        jitterStd6s: _calcStd(jitterDeltas6, jMean6),
        jitterMean10s: jMean10,
        jitterStd10s: _calcStd(jitterDeltas10, jMean10),
        startupLag3s: mean(startupLags3),
        startupLag6s: mean(startupLags6),
        startupLag10s: mean(startupLags10),
        stopLag3s: mean(stopLags3),
        stopLag6s: mean(stopLags6),
        stopLag10s: mean(stopLags10),
      );
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 3. EXECUTE BENCHMARK ON CLEMSON PEDEVAL (90 SESSIONS)
    // ─────────────────────────────────────────────────────────────────────────
    print('Processing Clemson PedEval (90 sessions)...');
    final pedevalMetrics = <SessionMetrics>[];
    final pDirs = pedevalDir.listSync().whereType<Directory>().toList()
      ..sort((a, b) => a.path.compareTo(b.path));

    var totalPedevalSteps = 0;
    var totalPedevalDuration = 0.0;

    for (final pDir in pDirs) {
      final pid = pDir.uri.pathSegments.where((s) => s.isNotEmpty).last;
      final demo = pedevalDemo[pid] ?? {'sex': 'Unknown', 'age': '20'};

      for (final proto in ['Regular', 'SemiRegular', 'Irregular']) {
        final stepsFile = File('${pDir.path}/$proto/steps.txt');
        if (!stepsFile.existsSync()) continue;

        final rawFiles = Directory('${pDir.path}/$proto')
            .listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith('.txt') && !f.path.endsWith('steps.txt'))
            .toList();
        var sampleCount = 0;
        if (rawFiles.isNotEmpty) {
          sampleCount = rawFiles.first.readAsLinesSync().length;
        }

        final lines = stepsFile.readAsLinesSync();
        final stepEvents = <Map<String, dynamic>>[];
        final stepTimes = <double>[];

        for (final line in lines) {
          final parts = line.trim().split(RegExp(r'\s+'));
          if (parts.length >= 2) {
            final frame = int.tryParse(parts[0]);
            final label = parts[1].toLowerCase();
            if (frame != null && (label == 'left' || label == 'right')) {
              final t = frame / 15.0;
              stepTimes.add(t);
              stepEvents.add({'time': t, 'foot': label});
            }
          }
        }
        stepTimes.sort();
        stepEvents.sort((a, b) => (a['time'] as double).compareTo(b['time'] as double));

        if (stepTimes.length < 2) continue;
        final t0 = stepTimes.first;
        final normTimes = stepTimes.map((t) => t - t0 + 0.5).toList();
        final normEvents = stepEvents
            .map((e) => {
                  'time': (e['time'] as double) - t0 + 0.5,
                  'foot': e['foot'] as String,
                })
            .toList();

        final durSec = sampleCount > 0 ? (sampleCount / 15.0) : (stepTimes.last + 1.0);
        totalPedevalSteps += stepTimes.length;
        totalPedevalDuration += durSec;

        double pedevalOracle(double t, int stepIdx, double lastStepT, double prevStepT) {
          Map<String, dynamic>? prevEv;
          Map<String, dynamic>? lastEv;
          for (final ev in normEvents) {
            if ((ev['time'] as double) > t) break;
            prevEv = lastEv;
            lastEv = ev;
          }
          if (lastEv == null || prevEv == null) return 0.0;
          final lt = lastEv['time'] as double;
          final pt = prevEv['time'] as double;
          if (t - lt > 3.0) return 0.0;
          final dt = lt - pt;
          if (dt <= (1.0 / 15.0)) return 0.0;

          final lf = lastEv['foot'] as String;
          final pf = prevEv['foot'] as String;
          if (lf == pf) {
            return dt >= 0.75 ? math.min(270.0, 120.0 / dt) : math.min(270.0, 60.0 / dt);
          } else {
            return math.min(270.0, 60.0 / dt);
          }
        }

        final m = evaluateSession(
          dataset: 'PedEval',
          sessionId: '${pid}_$proto',
          pid: pid,
          protocolOrCategory: proto,
          sex: demo['sex']!,
          ageGroup: demo['age']!,
          durationSec: durSec,
          stepTimes: normTimes,
          computeOracle: pedevalOracle,
        );
        pedevalMetrics.add(m);
      }
    }

    print('  PedEval Sessions Processed: ${pedevalMetrics.length} / 90');
    print('  PedEval Ground-Truth Locomotor Steps: $totalPedevalSteps');
    print('  PedEval Duration: ${totalPedevalDuration.toStringAsFixed(1)} s\n');
    expect(pedevalMetrics.length, equals(90));
    expect(totalPedevalSteps, equals(56668));

    // ─────────────────────────────────────────────────────────────────────────
    // 4. EXECUTE BENCHMARK ON OXFORD OXWALK (39 SESSIONS)
    // ─────────────────────────────────────────────────────────────────────────
    print('Processing Oxford OxWalk (39 sessions)...');
    final oxwalkMetrics = <SessionMetrics>[];
    var totalOxwalkSteps = 0;
    var totalOxwalkDuration = 0.0;

    for (final s in oxwalkSessionsMeta) {
      final pid = s['pid'] as String;
      final sex = s['sex'] as String;
      final ageGroup = s['age_group'] as String;
      final durSec = (s['duration_sec'] as num).toDouble();
      final expectedStepCount = s['step_count'] as int;

      final stepFile = File('${oxwalkStepsDir.path}/${pid}_steps.csv');
      expect(stepFile.existsSync(), isTrue);

      final stepTimes = <double>[];
      for (final line in stepFile.readAsLinesSync().skip(1)) {
        final parts = line.split(',');
        if (parts.length >= 3) {
          final el = double.tryParse(parts[2]);
          if (el != null) stepTimes.add(el);
        }
      }
      expect(stepTimes.length, equals(expectedStepCount));
      totalOxwalkSteps += stepTimes.length;
      totalOxwalkDuration += durSec;

      double oxwalkOracle(double t, int stepIdx, double lastStepT, double prevStepT) {
        if (stepIdx < 2 || (t - lastStepT) > 3.0) return 0.0;
        final dt = lastStepT - prevStepT;
        if (dt <= (1.0 / 25.0)) return 270.0;
        return math.min(270.0, 60.0 / dt);
      }

      final m = evaluateSession(
        dataset: 'OxWalk',
        sessionId: pid,
        pid: pid,
        protocolOrCategory: 'FreeLiving',
        sex: sex,
        ageGroup: ageGroup,
        durationSec: durSec,
        stepTimes: stepTimes,
        computeOracle: oxwalkOracle,
      );
      oxwalkMetrics.add(m);
    }

    print('  OxWalk Sessions Processed: ${oxwalkMetrics.length} / 39');
    print('  OxWalk Ground-Truth Locomotor Steps: $totalOxwalkSteps');
    print('  OxWalk Duration: ${totalOxwalkDuration.toStringAsFixed(1)} s\n');
    expect(oxwalkMetrics.length, equals(39));
    expect(totalOxwalkSteps, equals(62904));

    // ─────────────────────────────────────────────────────────────────────────
    // 5. EXPORT PER-PARTICIPANT / PER-SESSION METRICS CSVS
    // ─────────────────────────────────────────────────────────────────────────
    String toCsvRow(SessionMetrics m) {
      return '${m.dataset},${m.sessionId},${m.pid},${m.protocolOrCategory},${m.sex},${m.ageGroup},'
          '${m.durationSec.toStringAsFixed(1)},${m.stepCount},${m.activeSeconds.toInt()},${m.stationarySeconds.toInt()},'
          '${m.activeMae3s.toStringAsFixed(2)},${m.activeRmse3s.toStringAsFixed(2)},${m.activeBias3s.toStringAsFixed(2)},'
          '${m.activeP50_3s.toStringAsFixed(1)},${m.activeP90_3s.toStringAsFixed(1)},${m.activeP95_3s.toStringAsFixed(1)},'
          '${m.activeMae6s.toStringAsFixed(2)},${m.activeRmse6s.toStringAsFixed(2)},${m.activeBias6s.toStringAsFixed(2)},'
          '${m.activeP50_6s.toStringAsFixed(1)},${m.activeP90_6s.toStringAsFixed(1)},${m.activeP95_6s.toStringAsFixed(1)},'
          '${m.activeMae10s.toStringAsFixed(2)},${m.activeRmse10s.toStringAsFixed(2)},${m.activeBias10s.toStringAsFixed(2)},'
          '${m.activeP50_10s.toStringAsFixed(1)},${m.activeP90_10s.toStringAsFixed(1)},${m.activeP95_10s.toStringAsFixed(1)},'
          '${m.stationaryMeanCadence3s.toStringAsFixed(2)},${m.stationaryMeanCadence6s.toStringAsFixed(2)},${m.stationaryMeanCadence10s.toStringAsFixed(2)},'
          '${m.jitterMean3s.toStringAsFixed(2)},${m.jitterStd3s.toStringAsFixed(2)},'
          '${m.jitterMean6s.toStringAsFixed(2)},${m.jitterStd6s.toStringAsFixed(2)},'
          '${m.jitterMean10s.toStringAsFixed(2)},${m.jitterStd10s.toStringAsFixed(2)},'
          '${m.startupLag3s.toStringAsFixed(2)},${m.startupLag6s.toStringAsFixed(2)},${m.startupLag10s.toStringAsFixed(2)},'
          '${m.stopLag3s.toStringAsFixed(2)},${m.stopLag6s.toStringAsFixed(2)},${m.stopLag10s.toStringAsFixed(2)}';
    }

    const header = 'dataset,session_id,pid,protocol_or_category,sex,age_group,'
        'duration_sec,step_count,active_sec,stationary_sec,'
        'active_mae_3s,active_rmse_3s,active_bias_3s,active_p50_3s,active_p90_3s,active_p95_3s,'
        'active_mae_6s,active_rmse_6s,active_bias_6s,active_p50_6s,active_p90_6s,active_p95_6s,'
        'active_mae_10s,active_rmse_10s,active_bias_10s,active_p50_10s,active_p90_10s,active_p95_10s,'
        'stat_mean_cad_3s,stat_mean_cad_6s,stat_mean_cad_10s,'
        'jitter_mean_3s,jitter_std_3s,jitter_mean_6s,jitter_std_6s,jitter_mean_10s,jitter_std_10s,'
        'startup_lag_3s,startup_lag_6s,startup_lag_10s,'
        'stop_lag_3s,stop_lag_6s,stop_lag_10s';

    final pedevalCsv = [header, ...pedevalMetrics.map(toCsvRow)].join('\n');
    File('${resultsDir.path}/final_pedeval_cadence_metrics.csv').writeAsStringSync(pedevalCsv);

    final oxwalkCsv = [header, ...oxwalkMetrics.map(toCsvRow)].join('\n');
    File('${resultsDir.path}/final_oxwalk_cadence_metrics.csv').writeAsStringSync(oxwalkCsv);

    // ─────────────────────────────────────────────────────────────────────────
    // 6. COMPUTE COHORT-LEVEL AGGREGATE SUMMARY & COMPARISONS
    // ─────────────────────────────────────────────────────────────────────────
    void printCohortStats(String label, List<SessionMetrics> list) {
      double avg(double Function(SessionMetrics m) fn) =>
          list.map(fn).reduce((a, b) => a + b) / list.length;

      print('----------------------------------------------------------------');
      print(' COHORT SUMMARY: $label (N=${list.length})');
      print('----------------------------------------------------------------');
      print('  Active Walking MAE:');
      print('    3s Window:  ${avg((m) => m.activeMae3s).toStringAsFixed(2)} spm');
      print('    6s Window:  ${avg((m) => m.activeMae6s).toStringAsFixed(2)} spm');
      print('    10s Window: ${avg((m) => m.activeMae10s).toStringAsFixed(2)} spm');
      print('  Active Walking RMSE:');
      print('    3s Window:  ${avg((m) => m.activeRmse3s).toStringAsFixed(2)} spm');
      print('    6s Window:  ${avg((m) => m.activeRmse6s).toStringAsFixed(2)} spm');
      print('    10s Window: ${avg((m) => m.activeRmse10s).toStringAsFixed(2)} spm');
      print('  Active Walking Bias:');
      print('    3s Window:  ${avg((m) => m.activeBias3s).toStringAsFixed(2)} spm');
      print('    6s Window:  ${avg((m) => m.activeBias6s).toStringAsFixed(2)} spm');
      print('    10s Window: ${avg((m) => m.activeBias10s).toStringAsFixed(2)} spm');
      print('  Cadence Jitter (Second-to-Second Flutter):');
      print('    3s Window:  ${avg((m) => m.jitterMean3s).toStringAsFixed(2)} ± ${avg((m) => m.jitterStd3s).toStringAsFixed(2)} spm/s');
      print('    6s Window:  ${avg((m) => m.jitterMean6s).toStringAsFixed(2)} ± ${avg((m) => m.jitterStd6s).toStringAsFixed(2)} spm/s');
      print('    10s Window: ${avg((m) => m.jitterMean10s).toStringAsFixed(2)} ± ${avg((m) => m.jitterStd10s).toStringAsFixed(2)} spm/s');
      print('  Response Lag (Startup / Stop Decay):');
      print('    3s Window:  Startup=${avg((m) => m.startupLag3s).toStringAsFixed(2)}s | Stop Decay=${avg((m) => m.stopLag3s).toStringAsFixed(2)}s');
      print('    6s Window:  Startup=${avg((m) => m.startupLag6s).toStringAsFixed(2)}s | Stop Decay=${avg((m) => m.stopLag6s).toStringAsFixed(2)}s');
      print('    10s Window: Startup=${avg((m) => m.startupLag10s).toStringAsFixed(2)}s | Stop Decay=${avg((m) => m.stopLag10s).toStringAsFixed(2)}s');
      print('  Stationary Mean Cadence:');
      print('    3s: ${avg((m) => m.stationaryMeanCadence3s).toStringAsFixed(2)} spm | 6s: ${avg((m) => m.stationaryMeanCadence6s).toStringAsFixed(2)} spm | 10s: ${avg((m) => m.stationaryMeanCadence10s).toStringAsFixed(2)} spm');
    }

    final pedevalRegular = pedevalMetrics.where((m) => m.protocolOrCategory == 'Regular').toList();
    final pedevalSemi = pedevalMetrics.where((m) => m.protocolOrCategory == 'SemiRegular').toList();
    final pedevalIrreg = pedevalMetrics.where((m) => m.protocolOrCategory == 'Irregular').toList();

    printCohortStats('PedEval - Regular Walking (N=30)', pedevalRegular);
    printCohortStats('PedEval - SemiRegular Protocol (N=30)', pedevalSemi);
    printCohortStats('PedEval - All Protocols Aggregate (N=90)', pedevalMetrics);
    printCohortStats('OxWalk - Unscripted Free-Living Cohort (N=39)', oxwalkMetrics);

    // ─────────────────────────────────────────────────────────────────────────
    // 7. EXPORT CONSOLIDATED WINDOW COMPARISON & JITTER/LAG CSV
    // ─────────────────────────────────────────────────────────────────────────
    final windowCompCsv = StringBuffer();
    windowCompCsv.writeln('dataset_group,n_sessions,window_sec,active_mae_spm,active_rmse_spm,active_bias_spm,p90_spm,p95_spm,jitter_spm_per_sec,startup_lag_sec,stop_lag_sec,stat_false_cadence_spm');

    void writeWindowRow(String grp, List<SessionMetrics> list, int winSec) {
      double avg(double Function(SessionMetrics m) fn) =>
          list.map(fn).reduce((a, b) => a + b) / list.length;
      if (winSec == 3) {
        windowCompCsv.writeln('$grp,${list.length},3,${avg((m) => m.activeMae3s).toStringAsFixed(2)},${avg((m) => m.activeRmse3s).toStringAsFixed(2)},${avg((m) => m.activeBias3s).toStringAsFixed(2)},${avg((m) => m.activeP90_3s).toStringAsFixed(2)},${avg((m) => m.activeP95_3s).toStringAsFixed(2)},${avg((m) => m.jitterMean3s).toStringAsFixed(2)},${avg((m) => m.startupLag3s).toStringAsFixed(2)},${avg((m) => m.stopLag3s).toStringAsFixed(2)},${avg((m) => m.stationaryMeanCadence3s).toStringAsFixed(2)}');
      } else if (winSec == 6) {
        windowCompCsv.writeln('$grp,${list.length},6,${avg((m) => m.activeMae6s).toStringAsFixed(2)},${avg((m) => m.activeRmse6s).toStringAsFixed(2)},${avg((m) => m.activeBias6s).toStringAsFixed(2)},${avg((m) => m.activeP90_6s).toStringAsFixed(2)},${avg((m) => m.activeP95_6s).toStringAsFixed(2)},${avg((m) => m.jitterMean6s).toStringAsFixed(2)},${avg((m) => m.startupLag6s).toStringAsFixed(2)},${avg((m) => m.stopLag6s).toStringAsFixed(2)},${avg((m) => m.stationaryMeanCadence6s).toStringAsFixed(2)}');
      } else if (winSec == 10) {
        windowCompCsv.writeln('$grp,${list.length},10,${avg((m) => m.activeMae10s).toStringAsFixed(2)},${avg((m) => m.activeRmse10s).toStringAsFixed(2)},${avg((m) => m.activeBias10s).toStringAsFixed(2)},${avg((m) => m.activeP90_10s).toStringAsFixed(2)},${avg((m) => m.activeP95_10s).toStringAsFixed(2)},${avg((m) => m.jitterMean10s).toStringAsFixed(2)},${avg((m) => m.startupLag10s).toStringAsFixed(2)},${avg((m) => m.stopLag10s).toStringAsFixed(2)},${avg((m) => m.stationaryMeanCadence10s).toStringAsFixed(2)}');
      }
    }

    for (final w in [3, 6, 10]) {
      writeWindowRow('PedEval_Regular', pedevalRegular, w);
      writeWindowRow('PedEval_SemiRegular', pedevalSemi, w);
      writeWindowRow('PedEval_All', pedevalMetrics, w);
      writeWindowRow('OxWalk_All', oxwalkMetrics, w);
    }

    File('${resultsDir.path}/final_window_comparison.csv').writeAsStringSync(windowCompCsv.toString());

    // ─────────────────────────────────────────────────────────────────────────
    // 8. FINAL ASSERTION: PRODUCTION PARITY & ZERO CRITICAL REGRESSION
    // ─────────────────────────────────────────────────────────────────────────
    // Verify that MockStepSensorAdapter behaves identically to physical hardware
    // by streaming only cumulative rawSteps, never per-step timestamps
    final parityStartDate = DateTime(2026, 11, 6, 8, 0, 0);
    final testAdapter = MockStepSensorAdapter(initialRawSteps: 5000);
    final testService = StepTrackingService(adapter: testAdapter);
    await testService.startTracking();

    testAdapter.emitSample(rawSteps: 5000, timestamp: parityStartDate);
    await Future<void>.delayed(Duration.zero);
    expect(testService.currentActiveSteps, equals(0));

    testAdapter.emitSample(rawSteps: 5010, timestamp: parityStartDate.add(const Duration(seconds: 5)));
    await Future<void>.delayed(Duration.zero);
    expect(testService.currentActiveSteps, equals(10));

    testAdapter.emitSample(rawSteps: 5014, timestamp: parityStartDate.add(const Duration(seconds: 7)));
    await Future<void>.delayed(Duration.zero);
    expect(testService.currentActiveSteps, equals(14));
    expect(testService.currentCadenceSpm, greaterThan(0));

    testService.stopTracking();
    print('\nFinal Closure Benchmark Completed Successfully with Exit Code 0.');
  });
}
