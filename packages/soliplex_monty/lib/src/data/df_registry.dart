import 'dart:convert';

import 'package:soliplex_monty/src/data/data_frame.dart';

/// Handle-based DataFrame storage.
///
/// Python receives integer handle IDs and passes them back to subsequent
/// calls. Each Monty thread gets its own [DfRegistry] so DataFrames are
/// isolated per conversation.
class DfRegistry {
  int _nextId = 1;
  final _store = <int, DataFrame>{};

  /// Register a [DataFrame] and return its handle ID.
  int register(DataFrame df) {
    final id = _nextId++;
    _store[id] = df;
    return id;
  }

  /// Get a [DataFrame] by handle ID.
  ///
  /// Throws [ArgumentError] if no DataFrame with [id] exists.
  DataFrame get(int id) {
    final df = _store[id];
    if (df == null) {
      throw ArgumentError('No DataFrame with handle $id');
    }
    return df;
  }

  /// Dispose a single handle.
  void dispose(int id) => _store.remove(id);

  /// Dispose all handles and reset IDs.
  void disposeAll() {
    _store.clear();
    _nextId = 1;
  }

  /// Create a [DataFrame] from rows.
  ///
  /// If [data] is a list of maps, use directly.
  /// If [data] is a list of lists with [columns], convert to maps.
  ///
  /// Handles Monty's serialization where maps may have non-String keys
  /// and values may need type coercion.
  int create(Object? data, [List<String>? columns]) {
    if (data is List && data.isNotEmpty) {
      if (data.first is Map) {
        final rows = <Map<String, dynamic>>[];
        for (final item in data) {
          final src = item! as Map<Object?, Object?>;
          final row = <String, dynamic>{};
          for (final entry in src.entries) {
            row[entry.key.toString()] = _coerceValue(entry.value);
          }
          rows.add(row);
        }
        return register(DataFrame(rows));
      }
      if (data.first is List && columns != null) {
        final rows = <Map<String, dynamic>>[];
        for (final item in data) {
          final srcRow = item! as List<Object?>;
          final map = <String, dynamic>{};
          for (var i = 0; i < columns.length && i < srcRow.length; i++) {
            map[columns[i]] = _coerceValue(srcRow[i]);
          }
          rows.add(map);
        }
        return register(DataFrame(rows));
      }
    }
    throw ArgumentError(
      'df_create expects a list of maps or '
      'a list of lists with column names. '
      'Got: ${data.runtimeType}',
    );
  }

  /// Coerce a value from Monty into a clean Dart type.
  static Object? _coerceValue(Object? v) {
    if (v == null) return null;
    if (v is num) return v;
    if (v is bool) return v;
    if (v is String) {
      final asNum = num.tryParse(v);
      if (asNum != null) return asNum;
      return v;
    }
    if (v is List) return v.map(_coerceValue).toList();
    if (v is Map) {
      return <String, dynamic>{
        for (final e in v.entries) e.key.toString(): _coerceValue(e.value),
      };
    }
    return v;
  }

  /// Parse CSV string into a [DataFrame].
  int fromCsv(String csv, [String delimiter = ',']) {
    final lines = const LineSplitter().convert(csv.trim());
    if (lines.isEmpty) return register(const DataFrame([]));
    final headers = lines.first.split(delimiter).map((s) => s.trim()).toList();
    final rows = <Map<String, dynamic>>[];
    for (final line in lines.skip(1)) {
      if (line.trim().isEmpty) continue;
      final values = line.split(delimiter);
      final row = <String, dynamic>{};
      for (var i = 0; i < headers.length; i++) {
        final raw = i < values.length ? values[i].trim() : '';
        row[headers[i]] = _parseValue(raw);
      }
      rows.add(row);
    }
    return register(DataFrame(rows));
  }

  /// Parse JSON string into a [DataFrame].
  int fromJson(String jsonStr) {
    final data = jsonDecode(jsonStr);
    if (data is List) {
      final rows = <Map<String, dynamic>>[];
      for (final item in data) {
        final src = item as Map<Object?, Object?>;
        final row = <String, dynamic>{};
        for (final entry in src.entries) {
          row[entry.key.toString()] = _coerceValue(entry.value);
        }
        rows.add(row);
      }
      return register(DataFrame(rows));
    }
    throw ArgumentError('df_from_json expects a JSON array of objects');
  }

  /// Try to parse a string to int, double, bool, or leave as String.
  static Object? _parseValue(String raw) {
    if (raw.isEmpty) return null;
    final asInt = int.tryParse(raw);
    if (asInt != null) return asInt;
    final asDouble = double.tryParse(raw);
    if (asDouble != null) return asDouble;
    if (raw == 'true') return true;
    if (raw == 'false') return false;
    if (raw == 'null' || raw == 'None') return null;
    // Strip surrounding quotes if present
    if ((raw.startsWith('"') && raw.endsWith('"')) ||
        (raw.startsWith("'") && raw.endsWith("'"))) {
      return raw.substring(1, raw.length - 1);
    }
    return raw;
  }
}
