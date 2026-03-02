import 'package:soliplex_schema/src/feature_schema.dart';
import 'package:soliplex_schema/src/object_schema.dart';
import 'package:soliplex_schema/src/schema_parser.dart';
import 'package:soliplex_schema/src/schema_state_view.dart';

/// Cache of parsed feature schemas: roomId → featureName →
/// [FeatureSchema].
///
/// Schemas are parsed once on registration and reused for every
/// state view created.
class FeatureSchemaRegistry {
  final _cache = <String, Map<String, FeatureSchema>>{};
  final _parser = SchemaParser();

  /// Registers feature schemas for a room from the raw API response.
  ///
  /// [roomId] is the room identifier.
  /// [rawFeatures] is the map of feature name → raw feature object
  /// as returned by `GET /rooms/{roomId}/feature_schemas`.
  ///
  /// Each raw feature object has shape:
  /// ```json
  /// {
  ///   "name": "haiku.rag.chat",
  ///   "description": "...",
  ///   "source": "SERVER",
  ///   "json_schema": { ... }
  /// }
  /// ```
  void register(
    String roomId,
    Map<String, Map<String, dynamic>> rawFeatures,
  ) {
    final features = <String, FeatureSchema>{};
    for (final entry in rawFeatures.entries) {
      final raw = entry.value;
      final jsonSchema =
          raw['json_schema'] as Map<String, dynamic>? ?? const {};
      final objectSchema = _parser.parse(jsonSchema);

      features[entry.key] = FeatureSchema(
        name: raw['name'] as String? ?? entry.key,
        description: raw['description'] as String? ?? '',
        source: FeatureSource.fromString(
          raw['source'] as String? ?? 'EITHER',
        ),
        objectSchema: objectSchema,
      );
    }
    _cache[roomId] = features;
  }

  /// Returns the [FeatureSchema] for [featureName] in [roomId],
  /// or `null` if not registered.
  FeatureSchema? getSchema(String roomId, String featureName) {
    return _cache[roomId]?[featureName];
  }

  /// Returns all registered feature schemas for [roomId].
  Map<String, FeatureSchema> getSchemas(String roomId) {
    return _cache[roomId] ?? const {};
  }

  /// Whether schemas have been registered for [roomId].
  bool hasRoom(String roomId) => _cache.containsKey(roomId);

  /// Creates a [SchemaStateView] for [featureName] in [roomId]
  /// using the given [aguiState].
  ///
  /// The [aguiState] is the full AG-UI state map. This method
  /// extracts the feature-specific sub-map and wraps it with the
  /// parsed schema.
  ///
  /// Returns `null` if the feature is not registered or absent
  /// from the state.
  SchemaStateView? viewFor(
    String roomId,
    String featureName,
    Map<String, dynamic> aguiState,
  ) {
    final featureSchema = getSchema(roomId, featureName);
    if (featureSchema == null) return null;

    final data = aguiState[featureName];
    if (data == null || data is! Map<String, dynamic>) return null;

    return SchemaStateView(data, featureSchema.objectSchema);
  }

  /// Creates a [SchemaStateView] directly from a feature's data
  /// map and its [ObjectSchema].
  ///
  /// Use this when you already have the schema (e.g., from
  /// [getSchema]) and the feature-specific data map.
  static SchemaStateView viewFromSchema(
    Map<String, dynamic> data,
    ObjectSchema schema,
  ) {
    return SchemaStateView(data, schema);
  }

  /// Removes cached schemas for [roomId].
  void evict(String roomId) {
    _cache.remove(roomId);
  }

  /// Removes all cached schemas.
  void clear() {
    _cache.clear();
  }
}
