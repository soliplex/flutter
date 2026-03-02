import 'package:meta/meta.dart';
import 'package:soliplex_schema/src/field_schema.dart';

/// Parsed JSON Schema object with its field map.
@immutable
class ObjectSchema {
  const ObjectSchema({
    required this.fields,
    this.title,
    this.description,
  });

  /// Fields keyed by JSON property name (snake_case).
  final Map<String, FieldSchema> fields;

  /// The `title` keyword from the schema.
  final String? title;

  /// The `description` keyword from the schema.
  final String? description;

  /// Returns the [FieldSchema] for [name], or `null` if absent.
  FieldSchema? operator [](String name) => fields[name];
}
