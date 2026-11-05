import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../data/datasources/iod_sensor_acquisition_service.dart';
import '../../data/repositories/iod_experiment_storage.dart';
import '../../domain/models/ground_truth_label.dart';
import '../../domain/models/iod_prediction.dart';
import '../../domain/models/iod_record_entry.dart';
import '../../domain/models/iod_sensor_snapshot.dart';
import '../../domain/services/iod_composite_classifier.dart';

class IodState {
  final bool isRecording;
  final String? sessionId;
  final IodPrediction currentPrediction;
  final IodSensorSnapshot? latestSnapshot;
  final GroundTruthEnvironment? activeGroundTruth;
  final int totalSamplesCount;
  final String? statusMessage;

  const IodState({
    this.isRecording = false,
    this.sessionId,
    required this.currentPrediction,
    this.latestSnapshot,
    this.activeGroundTruth,
    this.totalSamplesCount = 0,
    this.statusMessage,
  });

  IodState copyWith({
    bool? isRecording,
    String? sessionId,
    IodPrediction? currentPrediction,
    IodSensorSnapshot? latestSnapshot,
    GroundTruthEnvironment? activeGroundTruth,
    int? totalSamplesCount,
    String? statusMessage,
  }) {
    return IodState(
      isRecording: isRecording ?? this.isRecording,
      sessionId: sessionId ?? this.sessionId,
      currentPrediction: currentPrediction ?? this.currentPrediction,
      latestSnapshot: latestSnapshot ?? this.latestSnapshot,
      activeGroundTruth: activeGroundTruth ?? this.activeGroundTruth,
      totalSamplesCount: totalSamplesCount ?? this.totalSamplesCount,
      statusMessage: statusMessage ?? this.statusMessage,
    );
  }
}

final iodStorageProvider = Provider<IodExperimentStorage>((ref) {
  return IodExperimentStorage();
});

final iodAcquisitionServiceProvider =
    Provider<IodSensorAcquisitionService>((ref) {
  final service = IodSensorAcquisitionService();
  ref.onDispose(() => service.dispose());
  return service;
});

final iodClassifierProvider = Provider<IodCompositeClassifier>((ref) {
  return IodCompositeClassifier();
});

final iodControllerProvider =
    StateNotifierProvider<IodController, IodState>((ref) {
  final acquisition = ref.watch(iodAcquisitionServiceProvider);
  final storage = ref.watch(iodStorageProvider);
  final classifier = ref.watch(iodClassifierProvider);
  return IodController(
    acquisitionService: acquisition,
    storage: storage,
    classifier: classifier,
  );
});

class IodController extends StateNotifier<IodState> {
  final IodSensorAcquisitionService _acquisition;
  final IodExperimentStorage _storage;
  final IodCompositeClassifier _classifier;

  StreamSubscription<IodSensorSnapshot>? _snapshotSub;
  int _epochCounter = 0;
  GroundTruthEnvironment? _currentGroundTruth;
  String? _currentGroundTruthNote;

  IodController({
    required IodSensorAcquisitionService acquisitionService,
    required IodExperimentStorage storage,
    required IodCompositeClassifier classifier,
  })  : _acquisition = acquisitionService,
        _storage = storage,
        _classifier = classifier,
        super(
          IodState(
            currentPrediction: IodPrediction.unknown(
              reason: 'initialized_idle',
            ),
          ),
        );

  /// Starts IOD recording linked to the active workout session ID.
  void startSession(String sessionId) {
    if (state.isRecording) stopSession();

    _epochCounter = 0;
    _currentGroundTruth = null;
    _currentGroundTruthNote = null;
    _classifier.reset();

    state = state.copyWith(
      isRecording: true,
      sessionId: sessionId,
      totalSamplesCount: 0,
      activeGroundTruth: null,
      statusMessage: 'Recording started',
    );

    _acquisition.start();
    _snapshotSub?.cancel();
    _snapshotSub = _acquisition.snapshotStream.listen(_handleSnapshot);
  }

  /// Stops IOD acquisition and detaches stream listeners.
  void stopSession() {
    _snapshotSub?.cancel();
    _snapshotSub = null;
    _acquisition.stop();

    state = state.copyWith(
      isRecording: false,
      statusMessage: 'Recording stopped',
    );
  }

  /// Ingests a new GPS fix into the acquisition layer.
  void onPositionUpdate(Position position) {
    _acquisition.updatePosition(position);
  }

  /// Ingests step count delta.
  void onStepDelta(int delta) {
    _acquisition.addStepDelta(delta);
  }

  /// Manually marks a ground-truth environment label during field recording.
  Future<void> markGroundTruth(
    GroundTruthEnvironment env, {
    String? note,
    String? transitionDescription,
  }) async {
    _currentGroundTruth = env;
    _currentGroundTruthNote = note;

    state = state.copyWith(
      activeGroundTruth: env,
      statusMessage: 'Ground truth: ${env.code}',
    );

    final sessionId = state.sessionId;
    if (sessionId != null) {
      final event = GroundTruthEvent(
        timestamp: DateTime.now(),
        environment: env,
        note: note,
        transitionDescription: transitionDescription,
      );
      await _storage.appendGroundTruthEvent(sessionId, event);
    }
  }

  void _handleSnapshot(IodSensorSnapshot snapshot) {
    if (!state.isRecording) return;

    final prediction = _classifier.predict(snapshot);
    final sessionId = state.sessionId ?? 'unknown_session';

    final entry = IodRecordEntry(
      sessionId: sessionId,
      epochIndex: _epochCounter++,
      timestamp: snapshot.timestamp,
      snapshot: snapshot,
      prediction: prediction,
      groundTruth: _currentGroundTruth,
      groundTruthNote: _currentGroundTruthNote,
    );

    // Persist entry asynchronously without blocking UI or tracking loop
    _storage.appendRecord(entry);

    state = state.copyWith(
      currentPrediction: prediction,
      latestSnapshot: snapshot,
      totalSamplesCount: _epochCounter,
    );
  }

  /// Exports current session to CSV.
  Future<String?> exportCsv() async {
    final sessionId = state.sessionId;
    if (sessionId == null) return null;
    final file = await _storage.exportSessionToCsv(sessionId);
    return file.path;
  }

  /// Exports current session to JSON.
  Future<String?> exportJson() async {
    final sessionId = state.sessionId;
    if (sessionId == null) return null;
    final file = await _storage.exportSessionToJson(sessionId);
    return file.path;
  }

  @override
  void dispose() {
    _snapshotSub?.cancel();
    super.dispose();
  }
}
