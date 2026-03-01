import 'package:soliplex_schema/soliplex_schema.dart';
import 'package:test/test.dart';

void main() {
  late FeatureSchemaRegistry registry;

  setUp(() {
    registry = FeatureSchemaRegistry();
  });

  group('FeatureSchemaRegistry', () {
    test('register and retrieve schema', () {
      registry.register('room-1', {
        'haiku.rag.chat': {
          'name': 'haiku.rag.chat',
          'description': 'Chat state',
          'source': 'SERVER',
          'json_schema': {
            'type': 'object',
            'properties': {
              'summary': {'type': 'string', 'default': ''},
            },
          },
        },
      });

      expect(registry.hasRoom('room-1'), isTrue);
      expect(registry.hasRoom('room-2'), isFalse);

      final schema = registry.getSchema('room-1', 'haiku.rag.chat');
      expect(schema, isNotNull);
      expect(schema!.name, 'haiku.rag.chat');
      expect(schema.description, 'Chat state');
      expect(schema.source, FeatureSource.server);
      expect(schema.objectSchema['summary'], isNotNull);
    });

    test('getSchemas returns all features for room', () {
      registry.register('room-1', {
        'feature_a': {
          'name': 'feature_a',
          'description': 'A',
          'source': 'CLIENT',
          'json_schema': {
            'type': 'object',
            'properties': <String, dynamic>{},
          },
        },
        'feature_b': {
          'name': 'feature_b',
          'description': 'B',
          'source': 'EITHER',
          'json_schema': {
            'type': 'object',
            'properties': <String, dynamic>{},
          },
        },
      });

      final schemas = registry.getSchemas('room-1');
      expect(schemas, hasLength(2));
      expect(schemas.keys, containsAll(['feature_a', 'feature_b']));
    });

    test('returns null for unregistered room/feature', () {
      expect(registry.getSchema('room-1', 'missing'), isNull);
      expect(registry.getSchemas('room-1'), isEmpty);
    });

    test('viewFor creates SchemaStateView', () {
      registry.register('room-1', {
        'my_feature': {
          'name': 'my_feature',
          'description': 'Test',
          'source': 'SERVER',
          'json_schema': {
            'type': 'object',
            'properties': {
              'value': {'type': 'string'},
            },
          },
        },
      });

      final aguiState = <String, dynamic>{
        'my_feature': {'value': 'hello'},
      };

      final view = registry.viewFor('room-1', 'my_feature', aguiState);
      expect(view, isNotNull);
      expect(view!.getScalar<String>('value'), 'hello');
    });

    test('viewFor returns null for missing feature in state', () {
      registry.register('room-1', {
        'my_feature': {
          'name': 'my_feature',
          'description': 'Test',
          'source': 'SERVER',
          'json_schema': {
            'type': 'object',
            'properties': <String, dynamic>{},
          },
        },
      });

      final view = registry.viewFor(
        'room-1',
        'my_feature',
        const <String, dynamic>{},
      );
      expect(view, isNull);
    });

    test('viewFor returns null for unregistered feature', () {
      final view = registry.viewFor(
        'room-1',
        'missing',
        const <String, dynamic>{},
      );
      expect(view, isNull);
    });

    test('evict removes room', () {
      registry.register('room-1', {
        'f': {
          'name': 'f',
          'description': '',
          'source': 'SERVER',
          'json_schema': {
            'type': 'object',
            'properties': <String, dynamic>{},
          },
        },
      });

      expect(registry.hasRoom('room-1'), isTrue);
      registry.evict('room-1');
      expect(registry.hasRoom('room-1'), isFalse);
    });

    test('clear removes all rooms', () {
      registry
        ..register('room-1', {
          'f': {
            'name': 'f',
            'description': '',
            'source': 'SERVER',
            'json_schema': {
              'type': 'object',
              'properties': <String, dynamic>{},
            },
          },
        })
        ..register('room-2', {
          'g': {
            'name': 'g',
            'description': '',
            'source': 'CLIENT',
            'json_schema': {
              'type': 'object',
              'properties': <String, dynamic>{},
            },
          },
        })
        ..clear();
      expect(registry.hasRoom('room-1'), isFalse);
      expect(registry.hasRoom('room-2'), isFalse);
    });

    test('FeatureSource.fromString parses values', () {
      expect(FeatureSource.fromString('CLIENT'), FeatureSource.client);
      expect(FeatureSource.fromString('SERVER'), FeatureSource.server);
      expect(FeatureSource.fromString('EITHER'), FeatureSource.either);
      expect(FeatureSource.fromString('client'), FeatureSource.client);
      expect(
        FeatureSource.fromString('unknown'),
        FeatureSource.either,
      );
    });

    test('viewFromSchema creates view directly', () {
      final schema = SchemaParser().parse({
        'type': 'object',
        'properties': {
          'x': {'type': 'integer'},
        },
      });

      final view = FeatureSchemaRegistry.viewFromSchema(
        {'x': 42},
        schema,
      );
      expect(view.getScalar<int>('x'), 42);
    });
  });
}
