import 'package:soliplex_schema/src/field_schema.dart';
import 'package:soliplex_schema/src/object_schema.dart';

/// Parses a raw JSON Schema map into an [ObjectSchema].
///
/// Handles:
/// - `$ref` → `$defs` resolution (scoped per schema)
/// - `anyOf: [{type: T}, {type: null}]` → nullable
/// - `anyOf: [{$ref: ...}, {type: null}]` → nullable object
/// - `items` for arrays (scalar, object, and nested arrays)
/// - `additionalProperties` for maps
/// - `default` values
/// - `required` field sets
/// - `num` → `int`/`double` coercion
/// - `format` keyword preservation
class SchemaParser {
  /// Parses a JSON Schema object into an [ObjectSchema].
  ///
  /// The [schema] should be a decoded JSON Schema with `type: "object"`
  /// and `properties`.
  ObjectSchema parse(Map<String, dynamic> schema) {
    final defs = _parseDefs(schema);
    return _parseObject(schema, defs);
  }

  /// Extracts `$defs` from a schema and parses each into an
  /// [ObjectSchema].
  Map<String, ObjectSchema> _parseDefs(Map<String, dynamic> schema) {
    final rawDefs = schema[r'$defs'] as Map<String, dynamic>?;
    if (rawDefs == null) return const {};

    // Two-pass: first create empty placeholders, then fill them.
    // This allows circular $ref (unlikely but safe).
    final defs = <String, ObjectSchema>{};
    for (final entry in rawDefs.entries) {
      final defSchema = entry.value as Map<String, dynamic>;
      defs[entry.key] = _parseObject(defSchema, defs);
    }
    return defs;
  }

  /// Parses an object schema (has `properties`).
  ObjectSchema _parseObject(
    Map<String, dynamic> schema,
    Map<String, ObjectSchema> defs,
  ) {
    final properties =
        schema['properties'] as Map<String, dynamic>? ?? const {};
    final requiredList = schema['required'] as List<dynamic>? ?? const [];
    final requiredSet = requiredList.cast<String>().toSet();

    final fields = <String, FieldSchema>{};
    for (final entry in properties.entries) {
      final propSchema = entry.value as Map<String, dynamic>;
      fields[entry.key] = _parseField(
        entry.key,
        propSchema,
        defs,
        isRequired: requiredSet.contains(entry.key),
      );
    }

    return ObjectSchema(
      fields: fields,
      title: schema['title'] as String?,
      description: schema['description'] as String?,
    );
  }

  /// Parses a single property schema into a [FieldSchema].
  FieldSchema _parseField(
    String name,
    Map<String, dynamic> schema,
    Map<String, ObjectSchema> defs, {
    bool isRequired = false,
  }) {
    final defaultValue = schema['default'];
    final title = schema['title'] as String?;
    final description = schema['description'] as String?;
    final format = schema['format'] as String?;

    // Check for $ref first (direct object reference).
    if (schema.containsKey(r'$ref')) {
      final resolved = _resolveRef(schema[r'$ref'] as String, defs);
      return FieldSchema(
        name: name,
        type: FieldType.object,
        required: isRequired,
        defaultValue: defaultValue,
        title: title,
        description: description,
        objectSchema: resolved,
      );
    }

    // Check for anyOf (nullable pattern).
    final anyOf = schema['anyOf'] as List<dynamic>?;
    if (anyOf != null) {
      return _parseAnyOf(
        name,
        anyOf.cast<Map<String, dynamic>>(),
        defs,
        isRequired: isRequired,
        defaultValue: defaultValue,
        title: title,
        description: description,
        format: format,
      );
    }

    // Standard type-based parsing.
    final type = schema['type'] as String?;
    return _parseTyped(
      name,
      type ?? 'object',
      schema,
      defs,
      isRequired: isRequired,
      defaultValue: defaultValue,
      title: title,
      description: description,
      format: format,
    );
  }

  /// Parses an `anyOf` schema (nullable pattern).
  ///
  /// Recognizes `anyOf: [{type/ref: T}, {type: null}]`.
  FieldSchema _parseAnyOf(
    String name,
    List<Map<String, dynamic>> anyOf,
    Map<String, ObjectSchema> defs, {
    bool isRequired = false,
    Object? defaultValue,
    String? title,
    String? description,
    String? format,
  }) {
    // Filter out the null variant.
    final nonNull = anyOf.where((s) => s['type'] != 'null').toList();

    if (nonNull.length != 1) {
      // Unexpected anyOf shape — treat as nullable object.
      return FieldSchema(
        name: name,
        type: FieldType.object,
        nullable: true,
        required: isRequired,
        defaultValue: defaultValue,
        title: title,
        description: description,
      );
    }

    final inner = nonNull.first;
    final hasNull = anyOf.length > nonNull.length;

    // anyOf with $ref → nullable object.
    if (inner.containsKey(r'$ref')) {
      final resolved = _resolveRef(inner[r'$ref'] as String, defs);
      return FieldSchema(
        name: name,
        type: FieldType.object,
        nullable: hasNull,
        required: isRequired,
        defaultValue: defaultValue,
        title: title,
        description: description,
        objectSchema: resolved,
      );
    }

    // anyOf with type.
    final innerType = inner['type'] as String?;

    // anyOf with array type (nullable array).
    if (innerType == 'array') {
      final itemInfo = _parseArrayItems(inner, defs);
      return FieldSchema(
        name: name,
        type: FieldType.array,
        nullable: hasNull,
        required: isRequired,
        defaultValue: defaultValue,
        title: title,
        description: description,
        itemSchema: itemInfo.objectSchema,
        itemType: itemInfo.scalarType,
        nestedItemSchema: itemInfo.nestedItemSchema,
      );
    }

    // anyOf with scalar type.
    final fieldType = _mapType(innerType ?? 'string');
    final innerFormat = inner['format'] as String? ?? format;
    return FieldSchema(
      name: name,
      type: fieldType,
      nullable: hasNull,
      required: isRequired,
      defaultValue: defaultValue,
      title: title,
      description: description,
      format: innerFormat,
    );
  }

  /// Parses a schema with an explicit `type` field.
  FieldSchema _parseTyped(
    String name,
    String type,
    Map<String, dynamic> schema,
    Map<String, ObjectSchema> defs, {
    bool isRequired = false,
    Object? defaultValue,
    String? title,
    String? description,
    String? format,
  }) {
    switch (type) {
      case 'array':
        final itemInfo = _parseArrayItems(schema, defs);
        return FieldSchema(
          name: name,
          type: FieldType.array,
          required: isRequired,
          defaultValue: defaultValue,
          title: title,
          description: description,
          itemSchema: itemInfo.objectSchema,
          itemType: itemInfo.scalarType,
          nestedItemSchema: itemInfo.nestedItemSchema,
        );

      case 'object':
        // Check for additionalProperties (map pattern).
        final additionalProperties = schema['additionalProperties'];
        if (additionalProperties is Map<String, dynamic>) {
          final valueInfo = _parseMapValue(additionalProperties, defs);
          return FieldSchema(
            name: name,
            type: FieldType.map,
            required: isRequired,
            defaultValue: defaultValue,
            title: title,
            description: description,
            valueType: valueInfo.scalarType,
            valueObjectSchema: valueInfo.objectSchema,
          );
        }

        // Regular nested object with properties.
        final nested = _parseObject(schema, defs);
        return FieldSchema(
          name: name,
          type: FieldType.object,
          required: isRequired,
          defaultValue: defaultValue,
          title: title,
          description: description,
          objectSchema: nested,
        );

      default:
        return FieldSchema(
          name: name,
          type: _mapType(type),
          required: isRequired,
          defaultValue: defaultValue,
          title: title,
          description: description,
          format: format,
        );
    }
  }

  /// Parses array `items` into item type info.
  _ArrayItemInfo _parseArrayItems(
    Map<String, dynamic> schema,
    Map<String, ObjectSchema> defs,
  ) {
    final items = schema['items'];
    if (items == null) {
      return const _ArrayItemInfo(scalarType: FieldType.object);
    }

    final itemsMap = items as Map<String, dynamic>;

    // $ref items → object array.
    if (itemsMap.containsKey(r'$ref')) {
      final resolved = _resolveRef(itemsMap[r'$ref'] as String, defs);
      return _ArrayItemInfo(objectSchema: resolved);
    }

    final itemType = itemsMap['type'] as String?;

    // Nested array (array of arrays).
    if (itemType == 'array') {
      final nestedField = _parseField('_nested', itemsMap, defs);
      return _ArrayItemInfo(nestedItemSchema: nestedField);
    }

    // Scalar items.
    if (itemType != null && itemType != 'object') {
      return _ArrayItemInfo(scalarType: _mapType(itemType));
    }

    // Inline object items.
    if (itemsMap.containsKey('properties')) {
      final objectSchema = _parseObject(itemsMap, defs);
      return _ArrayItemInfo(objectSchema: objectSchema);
    }

    return const _ArrayItemInfo(scalarType: FieldType.object);
  }

  /// Parses `additionalProperties` value schema.
  _MapValueInfo _parseMapValue(
    Map<String, dynamic> schema,
    Map<String, ObjectSchema> defs,
  ) {
    if (schema.containsKey(r'$ref')) {
      final resolved = _resolveRef(schema[r'$ref'] as String, defs);
      return _MapValueInfo(objectSchema: resolved);
    }

    final type = schema['type'] as String?;
    if (type != null) {
      return _MapValueInfo(scalarType: _mapType(type));
    }

    return const _MapValueInfo(scalarType: FieldType.object);
  }

  /// Resolves a `$ref` string like `#/$defs/Citation` to an
  /// [ObjectSchema].
  ObjectSchema? _resolveRef(
    String ref,
    Map<String, ObjectSchema> defs,
  ) {
    // Expected format: "#/$defs/TypeName"
    final parts = ref.split('/');
    if (parts.length >= 3 && parts[1] == r'$defs') {
      return defs[parts[2]];
    }
    return null;
  }

  /// Maps a JSON Schema type string to a [FieldType].
  FieldType _mapType(String type) {
    return switch (type) {
      'string' => FieldType.string,
      'integer' => FieldType.integer,
      'number' => FieldType.number,
      'boolean' => FieldType.boolean,
      'object' => FieldType.object,
      'array' => FieldType.array,
      _ => FieldType.string,
    };
  }
}

/// Internal helper for array item parsing results.
class _ArrayItemInfo {
  const _ArrayItemInfo({
    this.objectSchema,
    this.scalarType,
    this.nestedItemSchema,
  });

  final ObjectSchema? objectSchema;
  final FieldType? scalarType;
  final FieldSchema? nestedItemSchema;
}

/// Internal helper for map value parsing results.
class _MapValueInfo {
  const _MapValueInfo({this.objectSchema, this.scalarType});

  final ObjectSchema? objectSchema;
  final FieldType? scalarType;
}
