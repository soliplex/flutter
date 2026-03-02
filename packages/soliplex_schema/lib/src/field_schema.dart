import 'package:meta/meta.dart';
import 'package:soliplex_schema/src/object_schema.dart';

/// The JSON Schema type of a field.
enum FieldType {
  /// A string value.
  string,

  /// An integer value.
  integer,

  /// A floating-point number.
  number,

  /// A boolean value.
  boolean,

  /// A nested object (has its own [ObjectSchema]).
  object,

  /// A homogeneous array.
  array,

  /// A map with string keys (JSON Schema `additionalProperties`).
  map,
}

/// Parsed metadata for one JSON Schema property.
@immutable
class FieldSchema {
  const FieldSchema({
    required this.name,
    required this.type,
    this.nullable = false,
    this.required = false,
    this.defaultValue,
    this.format,
    this.title,
    this.description,
    this.objectSchema,
    this.itemSchema,
    this.itemType,
    this.valueType,
    this.valueObjectSchema,
    this.nestedItemSchema,
  });

  /// The property name as it appears in JSON (snake_case).
  final String name;

  /// The resolved field type.
  final FieldType type;

  /// Whether the field is nullable (`anyOf: [T, null]`).
  final bool nullable;

  /// Whether the field is in the parent's `required` list.
  final bool required;

  /// The default value from the schema, if any.
  final Object? defaultValue;

  /// The `format` keyword (e.g., `"date-time"`).
  final String? format;

  /// The `title` keyword.
  final String? title;

  /// The `description` keyword.
  final String? description;

  /// For [FieldType.object]: the schema of the nested object.
  final ObjectSchema? objectSchema;

  /// For [FieldType.array] with object items: the schema of each item.
  final ObjectSchema? itemSchema;

  /// For [FieldType.array] with scalar items: the scalar type.
  final FieldType? itemType;

  /// For [FieldType.map]: the type of map values.
  final FieldType? valueType;

  /// For [FieldType.map] with object values: the schema of each value.
  final ObjectSchema? valueObjectSchema;

  /// For nested arrays (array of arrays): the inner item schema.
  final FieldSchema? nestedItemSchema;
}
