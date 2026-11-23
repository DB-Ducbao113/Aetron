import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../domain/models/ground_truth_label.dart';
import '../../domain/models/iod_record_entry.dart';

/// Local offline persistence for Indoor-Outdoor Detection experimental trials.
///
/// Stores raw empirical time-series in structured JSON Lines (.jsonl) and CSV format
/// directly on device storage, completely bypassing database migrations.
class IodExperimentStorage {
  static const String _kSubdir = 'iod_experiments';
  Directory? _baseDir;

  Future<Directory> _getDirectory() async {
    if (_baseDir != null) return _baseDir!;
    final docsDir = await getApplicationDocumentsDirectory();
    final iodDir = Directory(p.join(docsDir.path, _kSubdir));
    if (!await iodDir.exists()) {
      await iodDir.create(recursive: true);
    }
    _baseDir = iodDir;
    return iodDir;
  }

  /// Appends an empirical record entry to the session's JSON Lines log.
  Future<void> appendRecord(IodRecordEntry entry) async {
    try {
      final dir = await _getDirectory();
      final file = File(p.join(dir.path, 'session_${entry.sessionId}.jsonl'));
      final line = '${jsonEncode(entry.toJson())}\n';
      await file.writeAsString(line, mode: FileMode.append, flush: true);
    } catch (e) {
      debugPrint('[IodStorage] Failed to append record: $e');
    }
  }

  /// Appends a ground-truth marker event to a separate ground-truth ledger.
  /// (Strict isolation ensuring reference labels never contaminate model inputs).
  Future<void> appendGroundTruthEvent(
    String sessionId,
    GroundTruthEvent event,
  ) async {
    try {
      final dir = await _getDirectory();
      final file = File(p.join(dir.path, 'ground_truth_$sessionId.jsonl'));
      final line = '${jsonEncode(event.toJson())}\n';
      await file.writeAsString(line, mode: FileMode.append, flush: true);
    } catch (e) {
      debugPrint('[IodStorage] Failed to append ground truth: $e');
    }
  }

  /// Reads all recorded entries for a session.
  Future<List<IodRecordEntry>> getSessionRecords(String sessionId) async {
    final dir = await _getDirectory();
    final file = File(p.join(dir.path, 'session_$sessionId.jsonl'));
    if (!await file.exists()) return [];

    final lines = await file.readAsLines();
    final entries = <IodRecordEntry>[];
    for (final line in lines) {
      if (line.trim().isEmpty) continue;
      try {
        final json = jsonDecode(line) as Map<String, dynamic>;
        entries.add(IodRecordEntry.fromJson(json));
      } catch (e) {
        debugPrint('[IodStorage] Malformed line skipped: $e');
      }
    }
    return entries;
  }

  /// Reads all ground truth marker events for a session.
  Future<List<GroundTruthEvent>> getSessionGroundTruth(String sessionId) async {
    final dir = await _getDirectory();
    final file = File(p.join(dir.path, 'ground_truth_$sessionId.jsonl'));
    if (!await file.exists()) return [];

    final lines = await file.readAsLines();
    final events = <GroundTruthEvent>[];
    for (final line in lines) {
      if (line.trim().isEmpty) continue;
      try {
        final json = jsonDecode(line) as Map<String, dynamic>;
        events.add(GroundTruthEvent.fromJson(json));
      } catch (e) {
        debugPrint('[IodStorage] Malformed ground truth line skipped: $e');
      }
    }
    return events;
  }

  /// Generates a standardized Comma-Separated Values (CSV) export for Python / R analysis.
  Future<File> exportSessionToCsv(String sessionId) async {
    final records = await getSessionRecords(sessionId);
    final dir = await _getDirectory();
    final exportFile = File(p.join(dir.path, 'export_iod_$sessionId.csv'));

    final buffer = StringBuffer();
    buffer.writeln(IodRecordEntry.csvHeaders().join(','));

    for (final record in records) {
      buffer.writeln(record.toCsvRow().join(','));
    }

    await exportFile.writeAsString(buffer.toString());
    return exportFile;
  }

  /// Generates a formatted JSON array export for web or REST tooling.
  Future<File> exportSessionToJson(String sessionId) async {
    final records = await getSessionRecords(sessionId);
    final dir = await _getDirectory();
    final exportFile = File(p.join(dir.path, 'export_iod_$sessionId.json'));

    final jsonList = records.map((e) => e.toJson()).toList();
    await exportFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(jsonList),
    );
    return exportFile;
  }

  /// Lists all recorded IOD sessions present in local storage.
  Future<List<String>> listSessionIds() async {
    final dir = await _getDirectory();
    final entities = await dir.list().toList();
    final sessionIds = <String>{};

    for (final entity in entities) {
      if (entity is File) {
        final name = p.basename(entity.path);
        if (name.startsWith('session_') && name.endsWith('.jsonl')) {
          final id = name.substring('session_'.length, name.length - '.jsonl'.length);
          sessionIds.add(id);
        }
      }
    }

    return sessionIds.toList();
  }
}

