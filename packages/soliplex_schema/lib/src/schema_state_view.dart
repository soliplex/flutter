import 'package:meta/meta.dart';
import 'package:soliplex_schema/src/field_schema.dart';
import 'package:soliplex_schema/src/object_schema.dart';

/// Zero-copy typed wrapper over `Map<String, dynamic>` + [ObjectSchema].
///
/// Provides safe, lenient access to AG-UI feature state. Absent fields
/// return schema defaults, then type defaults (null/empty). Cast
/// failures are logged and return null — never throws to the widget
/// layer.
@immutable
class SchemaStateView {
  const SchemaStateView(this._data, this._schema);

  final Map<String, dynamic> _data;
  final ObjectSchema _schema;

  /// The underlying raw data map.
  Map<String, dynamic> get rawData => _data;

  /// The schema this view interprets.
  ObjectSchema get schema => _schema;

  /// Returns the raw value for [field], or `null` if absent.
  dynamic get(String field) => _data[field];

  /// Whether [field] exists in the underlying data (even if null).
  bool hasField(String field) => _data.containsKey(field);

  /// All field names present in the underlying data.
  Iterable<String> get fieldNames => _data.keys;

  /// All field names defined in the schema.
  Iterable<String> get schemaFieldNames => _schema.fields.keys;

  /// Returns a typed scalar value for [field].
  ///
  /// Supports [String], [int], [double], [bool], and [num].
  /// Returns the schema default if the field is absent, or `null`
  /// if no default is defined.
  T? getScalar<T>(String field) {
    final fieldSchema = _schema[field];
    final raw = _data[field];

    if (raw == null) {
      final def = fieldSchema?.defaultValue;
      if (def == null) return null;
      return _coerceScalar<T>(def, field);
    }

    return _coerceScalar<T>(raw, field);
  }

  /// Returns a nested [SchemaStateView] for [field].
  ///
  /// Returns `null` if the field is absent, null, or not a map.
  SchemaStateView? getObject(String field) {
    final fieldSchema = _schema[field];
    final raw = _data[field];

    if (raw == null || raw is! Map<String, dynamic>) return null;
    final objectSchema = fieldSchema?.objectSchema;
    if (objectSchema == null) {
      return SchemaStateView(raw, const ObjectSchema(fields: {}));
    }
    return SchemaStateView(raw, objectSchema);
  }

  /// Returns a list of [SchemaStateView]s for an array-of-objects
  /// [field].
  ///
  /// Returns an empty list if the field is absent, null, or empty.
  List<SchemaStateView> getObjectList(String field) {
    final fieldSchema = _schema[field];
    final raw = _data[field];

    if (raw == null || raw is! List<dynamic>) {
      return _defaultList(fieldSchema);
    }

    final itemSchema =
        fieldSchema?.itemSchema ?? const ObjectSchema(fields: {});

    return raw
        .whereType<Map<String, dynamic>>()
        .map((item) => SchemaStateView(item, itemSchema))
        .toList();
  }

  /// Returns a typed list of scalars for [field].
  ///
  /// Returns an empty list if the field is absent, null, or empty.
  List<T> getScalarList<T>(String field) {
    final fieldSchema = _schema[field];
    final raw = _data[field];

    if (raw == null || raw is! List<dynamic>) {
      final def = fieldSchema?.defaultValue;
      if (def is List) {
        return def.whereType<T>().toList();
      }
      return const [];
    }

    final results = <T>[];
    for (final item in raw) {
      final coerced = _coerceScalar<T>(item, field);
      if (coerced != null) results.add(coerced);
    }
    return results;
  }

  /// Returns a list of lists of [SchemaStateView]s for a nested
  /// array field (e.g., `List<List<Citation>>`).
  ///
  /// Returns an empty list if the field is absent, null, or empty.
  List<List<SchemaStateView>> getNestedObjectList(String field) {
    final fieldSchema = _schema[field];
    final raw = _data[field];

    if (raw == null || raw is! List<dynamic>) return const [];

    final innerField = fieldSchema?.nestedItemSchema;
    final innerObjectSchema =
        innerField?.itemSchema ?? const ObjectSchema(fields: {});

    return raw.map<List<SchemaStateView>>((outerItem) {
      if (outerItem is! List<dynamic>) return const [];
      return outerItem
          .whereType<Map<String, dynamic>>()
          .map((item) => SchemaStateView(item, innerObjectSchema))
          .toList();
    }).toList();
  }

  /// Returns the length of the array at [field], or 0 if absent.
  int getListLength(String field) {
    final raw = _data[field];
    if (raw is List<dynamic>) return raw.length;
    return 0;
  }

  /// Returns a typed map for [field] (JSON Schema
  /// `additionalProperties`).
  ///
  /// Returns an empty map if the field is absent, null, or not a
  /// map.
  Map<String, T> getMap<T>(String field) {
    final fieldSchema = _schema[field];
    final raw = _data[field];

    if (raw == null || raw is! Map<String, dynamic>) {
      final def = fieldSchema?.defaultValue;
      if (def is Map<String, dynamic>) {
        return _coerceMap<T>(def, field);
      }
      return const {};
    }

    return _coerceMap<T>(raw, field);
  }

  /// Returns the raw list of maps for [field] (useful for
  /// forwarding to other APIs that expect untyped data).
  List<Map<String, dynamic>> getRawMapList(String field) {
    final raw = _data[field];
    if (raw == null || raw is! List<dynamic>) return const [];
    return raw.cast<Map<String, dynamic>>();
  }

  // ================================================================
  // Private helpers
  // ================================================================

  List<SchemaStateView> _defaultList(FieldSchema? fieldSchema) {
    if (fieldSchema?.defaultValue is List) return const [];
    return const [];
  }

  T? _coerceScalar<T>(dynamic value, String field) {
    if (value is T) return value;

    // num → int coercion.
    if (T == int && value is num) return value.toInt() as T;

    // num → double coercion.
    if (T == double && value is num) return value.toDouble() as T;

    // String → int tryParse.
    if (T == int && value is String) {
      final parsed = int.tryParse(value);
      if (parsed != null) return parsed as T;
    }

    // String → double tryParse.
    if (T == double && value is String) {
      final parsed = double.tryParse(value);
      if (parsed != null) return parsed as T;
    }

    return null;
  }

  Map<String, T> _coerceMap<T>(
    Map<String, dynamic> raw,
    String field,
  ) {
    final result = <String, T>{};
    for (final entry in raw.entries) {
      final coerced = _coerceScalar<T>(entry.value, field);
      if (coerced != null) {
        result[entry.key] = coerced;
      }
    }
    return result;
  }
}
