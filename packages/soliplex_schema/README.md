# soliplex_schema

Runtime parsing of JSON Schemas for AG-UI features with typed, safe views for accessing feature state. This is the client-side contract and access layer for dynamic feature data sent from the server.

## Quick Start

```bash
cd packages/soliplex_schema
dart pub get
dart test
dart format . --set-exit-if-changed
dart analyze --fatal-infos
```

## Architecture

### Schema Parsing and Registration

- `SchemaParser` -- Parses a raw JSON Schema map into a structured `ObjectSchema`, resolving `$ref`s and other keywords.
- `FeatureSchemaRegistry` -- A global cache for parsed schemas, organized by room ID and feature name.

### Schema Models

- `FeatureSchema` -- Represents the complete schema for a single AG-UI feature, including metadata and the root `ObjectSchema`.
- `ObjectSchema` -- Represents a parsed JSON schema `object` type, containing a map of its `FieldSchema` properties.
- `FieldSchema` -- Represents a single property within an `ObjectSchema`, detailing its type, constraints, and nested schemas.
- `FeatureSource` -- An enum (`CLIENT`, `SERVER`, `EITHER`) that specifies which system has write-ownership of a feature's state.
- `FieldType` -- An enum representing the fundamental JSON Schema data types (`string`, `object`, `array`, etc.).

### State Access

- `SchemaStateView` -- A zero-copy, typed wrapper over a `Map<String, dynamic>` that provides safe, lenient access to feature state according to its `ObjectSchema`.

## Dependencies

- `meta` -- For annotations like `@immutable` to enforce class contracts.

## Example

```dart
import 'package:soliplex_schema/soliplex_schema.dart';

void main() {
  // 1. Initialize the registry.
  final registry = FeatureSchemaRegistry();

  // 2. Register schemas for a room (e.g., from an API call).
  final roomId = 'room123';
  final rawFeatureSchemas = {
    'my_feature': {
      'name': 'my_feature',
      'description': 'A sample feature.',
      'source': 'SERVER',
      'json_schema': {
        'type': 'object',
        'properties': {
          'title': {'type': 'string', 'default': 'Untitled'},
          'is_enabled': {'type': 'boolean'},
        },
        'required': ['is_enabled'],
      },
    },
  };
  registry.register(roomId, rawFeatureSchemas);

  // 3. Get a typed view for the current feature state.
  final aguiState = {
    'my_feature': {
      'title': 'My Awesome Feature',
      'is_enabled': true,
    },
  };

  final featureView = registry.viewFor(roomId, 'my_feature', aguiState);

  if (featureView != null) {
    // 4. Safely access data.
    final title = featureView.getScalar<String>('title');
    final isEnabled = featureView.getScalar<bool>('is_enabled');
    print('Title: $title, Enabled: $isEnabled');
  }
}
```
