import 'dart:convert';

/// Keeps client research evidence separate from server validation. The full
/// original geometry stays in the cloud client_research_result_json archive;
/// cached metadata intentionally contains only its metrics and audit.
class ScientificResultMetadata {
  const ScientificResultMetadata._();

  static Map<String, dynamic> decode(Object? value) {
    try {
      final data = value is String ? jsonDecode(value) : value;
      return data is Map<String, dynamic>
          ? Map<String, dynamic>.from(data)
          : <String, dynamic>{};
    } on FormatException {
      return <String, dynamic>{};
    }
  }

  static String fromRemote(Map<String, dynamic> row) {
    final server = decode(row['route_match_metrics_json']);
    final client = decode(row['client_research_result_json']);
    if (client['version'] == 1) {
      server['client_research_summary'] = {
        for (final key in [
          'version',
          'session_id',
          'activity_type',
          'mode',
          'distance_km',
          'duration_sec',
          'moving_time_sec',
          'steps',
          'avg_speed_kmh',
          'calories_kcal',
          'reconstruction_status',
          'audit',
        ])
          if (client.containsKey(key)) key: client[key],
      };
      server['scientific_server_processing_status'] = row['processing_status'];
    }
    return jsonEncode(server);
  }

  /// Only a server-finalized scientific row is authoritative over a cached,
  /// now rejected route. Pending rows must not remove the local evidence.
  static bool hasFinalServerVerdict(Object? metadata) {
    final data = decode(metadata);
    return data['scientific_server_processing_status'] == 'client_finalized' &&
        data['client_scientific_reconciliation'] is Map;
  }

  static bool hasResearchSummary(Object? metadata) =>
      decode(metadata)['client_research_summary'] is Map;

  static String mergeCache(String local, String remote) {
    final previous = decode(local);
    final next = decode(remote);
    if (next.isEmpty) return local;
    if (previous['client_research_summary'] is Map &&
        !next.containsKey('client_research_summary')) {
      next['client_research_summary'] = previous['client_research_summary'];
    } else if (previous['scientific_result_version'] == 1 &&
        !next.containsKey('client_research_summary')) {
      // Legacy/pending server row: never discard the local research audit.
      next['client_research_summary'] = {'version': 1, 'audit': previous};
    }
    return jsonEncode(next);
  }
}
