import 'package:soliplex_interpreter_monty/soliplex_interpreter_monty.dart';
import 'package:soliplex_scripting/soliplex_scripting.dart';
import 'package:test/test.dart';

import '../helpers.dart';

void main() {
  group('PluginRegistry', () {
    late PluginRegistry registry;

    setUp(() {
      registry = PluginRegistry();
    });

    test('register accepts valid plugin', () {
      registry.register(_SimplePlugin('foo', ['foo_bar']));
      expect(registry.plugins, hasLength(1));
      expect(registry.plugins.first.namespace, 'foo');
    });

    test('register rejects empty namespace', () {
      expect(
        () => registry.register(_SimplePlugin('', ['_a'])),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('register rejects namespace exceeding 32 chars', () {
      final long = 'a' * 33;
      expect(
        () => registry.register(_SimplePlugin(long, ['${long}_fn'])),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('register rejects invalid namespace characters', () {
      expect(
        () => registry.register(_SimplePlugin('Foo', ['Foo_a'])),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('register rejects reserved namespace', () {
      expect(
        () => registry.register(
          _SimplePlugin('introspection', ['introspection_a']),
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('register rejects duplicate namespace', () {
      registry.register(_SimplePlugin('foo', ['foo_a']));
      expect(
        () => registry.register(_SimplePlugin('foo', ['foo_b'])),
        throwsA(isA<StateError>()),
      );
    });

    test('register rejects function without namespace prefix', () {
      expect(
        () => registry.register(_SimplePlugin('foo', ['bar_baz'])),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('register rejects duplicate function names across plugins', () {
      registry.register(_SimplePlugin('alpha', ['alpha_fn']));
      // Second plugin has same function name — hits prefix check first for
      // non-legacy plugins, so use a legacy plugin to reach the collision.
      expect(
        () => registry.register(
          _LegacyPlugin('beta', ['alpha_fn'], {'alpha_fn'}),
        ),
        throwsA(isA<StateError>()),
      );
    });

    group('LegacyUnprefixedPlugin', () {
      test('allows legacy names that skip prefix', () {
        registry.register(
          _LegacyPlugin(
            'platform',
            ['host_invoke', 'sleep'],
            {'host_invoke', 'sleep'},
          ),
        );
        expect(registry.plugins, hasLength(1));
      });

      test('still enforces prefix on non-legacy names', () {
        expect(
          () => registry.register(
            _LegacyPlugin('platform', ['host_invoke', 'oops'], {'host_invoke'}),
          ),
          throwsA(isA<ArgumentError>()),
        );
      });
    });

    group('attachTo', () {
      test('registers all plugin functions onto bridge', () async {
        registry
          ..register(_SimplePlugin('alpha', ['alpha_one', 'alpha_two']))
          ..register(_SimplePlugin('beta', ['beta_x']));

        final bridge = RecordingBridge();
        await registry.attachTo(bridge);

        final names = bridge.registered.map((f) => f.schema.name).toSet();
        expect(names, containsAll(['alpha_one', 'alpha_two', 'beta_x']));
        // Plus 2 introspection builtins (list_functions, help).
        expect(bridge.registered, hasLength(5));
      });

      test('includes extra functions in registration', () async {
        registry.register(_SimplePlugin('foo', ['foo_bar']));

        final bridge = RecordingBridge();
        await registry.attachTo(
          bridge,
          extraFunctions: [
            HostFunction(
              schema: const HostFunctionSchema(
                name: 'custom_extra',
                description: 'Extra.',
              ),
              handler: (args) async => null,
            ),
          ],
        );

        final names = bridge.registered.map((f) => f.schema.name).toSet();
        expect(names, contains('custom_extra'));
      });

      test('calls onRegister on each plugin', () async {
        final plugin = _LifecyclePlugin('lc');
        registry.register(plugin);

        final bridge = RecordingBridge();
        await registry.attachTo(bridge);

        expect(plugin.registerCalls, 1);
      });
    });

    group('disposeAll', () {
      test('calls onDispose on each plugin', () async {
        final p1 = _LifecyclePlugin('one');
        final p2 = _LifecyclePlugin('two');
        registry
          ..register(p1)
          ..register(p2);

        await registry.disposeAll();

        expect(p1.disposeCalls, 1);
        expect(p2.disposeCalls, 1);
      });
    });
  });
}

class _SimplePlugin extends MontyPlugin {
  _SimplePlugin(this._namespace, this._names);

  final String _namespace;
  final List<String> _names;

  @override
  String get namespace => _namespace;

  @override
  List<HostFunction> get functions => [
        for (final name in _names)
          HostFunction(
            schema: HostFunctionSchema(name: name, description: name),
            handler: (args) async => null,
          ),
      ];
}

class _LegacyPlugin extends MontyPlugin with LegacyUnprefixedPlugin {
  _LegacyPlugin(this._namespace, this._names, this.legacyNames);

  final String _namespace;
  final List<String> _names;

  @override
  String get namespace => _namespace;

  @override
  final Set<String> legacyNames;

  @override
  List<HostFunction> get functions => [
        for (final name in _names)
          HostFunction(
            schema: HostFunctionSchema(name: name, description: name),
            handler: (args) async => null,
          ),
      ];
}

class _LifecyclePlugin extends MontyPlugin {
  _LifecyclePlugin(this._namespace);

  final String _namespace;
  int registerCalls = 0;
  int disposeCalls = 0;

  @override
  String get namespace => _namespace;

  @override
  List<HostFunction> get functions => [
        HostFunction(
          schema:
              HostFunctionSchema(name: '${_namespace}_fn', description: 'test'),
          handler: (args) async => null,
        ),
      ];

  @override
  Future<void> onRegister(MontyBridge bridge) async {
    await super.onRegister(bridge);
    registerCalls++;
  }

  @override
  Future<void> onDispose() async {
    await super.onDispose();
    disposeCalls++;
  }
}
