import 'package:meta/meta.dart';
import 'package:soliplex_schema/src/object_schema.dart';

/// The source that owns a feature's state.
enum FeatureSource {
  /// Only the client can write.
  client,

  /// Only the server can write.
  server,

  /// Both client and server can write.
  either;

  /// Parses a source string from the backend API.
  static FeatureSource fromString(String value) {
    return switch (value.toLowerCase()) {
      'client' => FeatureSource.client,
      'server' => FeatureSource.server,
      _ => FeatureSource.either,
    };
  }
}

/// Domain model for one AG-UI feature schema.
@immutable
class FeatureSchema {
  const FeatureSchema({
    required this.name,
    required this.description,
    required this.source,
    required this.objectSchema,
  });

  /// The feature key in AG-UI state (e.g., `"haiku.rag.chat"`).
  final String name;

  /// Human-readable description from the Pydantic model docstring.
  final String description;

  /// Which side owns writes to this feature's state.
  final FeatureSource source;

  /// The parsed JSON Schema for this feature's state object.
  final ObjectSchema objectSchema;
}
