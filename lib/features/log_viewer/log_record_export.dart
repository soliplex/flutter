import 'package:soliplex_logging/soliplex_logging.dart';

/// Serialization extension for exporting [LogRecord] to JSON.
///
/// Lives in the feature layer to keep `soliplex_logging` model lean.
extension LogRecordExport on LogRecord {
  /// Converts this record to a JSON-encodable map for JSONL export.
  ///
  /// Timestamps are always UTC ISO 8601. Null optional fields are omitted.
  /// Attributes are recursively coerced to JSON-safe primitives.
  Map<String, Object?> toExportJson() => {
        'timestamp': timestamp.toUtc().toIso8601String(),
        'level': level.name,
        'logger': loggerName,
        'message': message,
        if (attributes.isNotEmpty) 'attributes': _safeAttributes(attributes),
        if (error != null) 'error': error.toString(),
        if (stackTrace != null) 'stackTrace': stackTrace.toString(),
        if (spanId != null) 'spanId': spanId,
        if (traceId != null) 'traceId': traceId,
      };
}

Map<String, Object?> _safeAttributes(Map<String, Object> attributes) {
  final result = <String, Object?>{};
  for (final entry in attributes.entries) {
    result[entry.key] = _coerceValue(entry.value);
  }
  return result;
}

Object? _coerceValue(Object? value) {
  if (value == null || value is String || value is num || value is bool) {
    return value;
  }
  if (value is List) {
    return value.map(_coerceValue).toList();
  }
  if (value is Map) {
    return value.map((k, v) => MapEntry(k.toString(), _coerceValue(v)));
  }
  return value.toString();
}
