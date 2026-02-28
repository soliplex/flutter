import 'package:dart_monty_platform_interface/dart_monty_testing.dart';
import 'package:soliplex_interpreter_monty/src/bridge/default_monty_bridge.dart';
import 'package:soliplex_interpreter_monty/src/bridge/host_function.dart';
import 'package:soliplex_interpreter_monty/src/bridge/host_function_registry.dart';
import 'package:soliplex_interpreter_monty/src/bridge/host_function_schema.dart';
import 'package:soliplex_interpreter_monty/src/bridge/host_param.dart';
import 'package:soliplex_interpreter_monty/src/bridge/host_param_type.dart';
import 'package:test/test.dart';

HostFunction _fn(String name, [String description = '']) => HostFunction(
      schema: HostFunctionSchema(name: name, description: description),
      handler: (args) async => null,
    );

void main() {
  late HostFunctionRegistry registry;

  setUp(() {
    registry = HostFunctionRegistry();
  });

  group('addCategory', () {
    test('adds a category', () {
      registry.addCategory('tools', [_fn('a'), _fn('b')]);

      expect(registry.allFunctions, hasLength(2));
    });

    test('throws on empty name', () {
      expect(
        () => registry.addCategory('', [_fn('a')]),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws on duplicate category name', () {
      registry.addCategory('tools', [_fn('a')]);

      expect(
        () => registry.addCategory('tools', [_fn('b')]),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('allFunctions', () {
    test('returns flat list across categories', () {
      registry
        ..addCategory('cat1', [_fn('a'), _fn('b')])
        ..addCategory('cat2', [_fn('c')]);

      final names = registry.allFunctions.map((f) => f.schema.name).toList();
      expect(names, ['a', 'b', 'c']);
    });

    test('returns empty when no categories', () {
      expect(registry.allFunctions, isEmpty);
    });
  });

  group('schemasByCategory', () {
    test('groups schemas correctly', () {
      registry
        ..addCategory('alpha', [_fn('a1'), _fn('a2')])
        ..addCategory('beta', [_fn('b1')]);

      final schemas = registry.schemasByCategory;
      expect(schemas.keys, containsAll(['alpha', 'beta']));
      expect(schemas['alpha']!.map((s) => s.name), ['a1', 'a2']);
      expect(schemas['beta']!.map((s) => s.name), ['b1']);
    });
  });

  group('registerAllOnto', () {
    test('registers all functions plus introspection builtins', () {
      final mock = MockMontyPlatform();
      final bridge = DefaultMontyBridge(platform: mock);

      addTearDown(bridge.dispose);

      registry
        ..addCategory('tools', [
          HostFunction(
            schema: const HostFunctionSchema(
              name: 'search',
              description: 'Search',
              params: [
                HostParam(name: 'q', type: HostParamType.string),
              ],
            ),
            handler: (args) async => 'found',
          ),
        ])
        ..registerAllOnto(bridge);

      final schemaNames = bridge.schemas.map((s) => s.name).toList();
      expect(schemaNames, contains('search'));
      expect(schemaNames, contains('list_functions'));
      expect(schemaNames, contains('help'));
    });

    test('registers only introspection builtins when empty', () {
      final mock = MockMontyPlatform();
      final bridge = DefaultMontyBridge(platform: mock);

      addTearDown(bridge.dispose);

      registry.registerAllOnto(bridge);

      final schemaNames = bridge.schemas.map((s) => s.name).toList();
      expect(schemaNames, containsAll(['list_functions', 'help']));
      expect(schemaNames, hasLength(2));
    });
  });
}
