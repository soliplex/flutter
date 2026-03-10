import 'package:soliplex_scripting/soliplex_scripting.dart';
import 'package:test/test.dart';

import '../helpers.dart';

void main() {
  group('StreamPlugin', () {
    late StreamRegistry streamRegistry;
    late StreamPlugin plugin;

    setUp(() {
      streamRegistry = StreamRegistry();
      plugin = StreamPlugin(streamRegistry: streamRegistry);
    });

    test('namespace is stream', () {
      expect(plugin.namespace, 'stream');
    });

    test('provides 3 functions', () {
      expect(plugin.functions, hasLength(3));
      final names = plugin.functions.map((f) => f.schema.name).toSet();
      expect(
        names,
        containsAll(['stream_subscribe', 'stream_next', 'stream_close']),
      );
    });

    test('registers onto bridge via PluginRegistry', () async {
      final bridge = RecordingBridge();
      final registry = PluginRegistry()..register(plugin);
      await registry.attachTo(bridge);

      final names = bridge.registered.map((f) => f.schema.name).toSet();
      expect(names, contains('stream_subscribe'));
    });

    group('schemas', () {
      late Map<String, HostFunction> byName;

      setUp(() {
        byName = {for (final f in plugin.functions) f.schema.name: f};
      });

      test('stream_subscribe has name param', () {
        final schema = byName['stream_subscribe']!.schema;
        expect(schema.params, hasLength(1));
        expect(schema.params[0].name, 'name');
        expect(schema.params[0].type, HostParamType.string);
      });

      test('stream_next has handle param', () {
        final schema = byName['stream_next']!.schema;
        expect(schema.params, hasLength(1));
        expect(schema.params[0].name, 'handle');
        expect(schema.params[0].type, HostParamType.integer);
      });

      test('stream_close has handle param', () {
        final schema = byName['stream_close']!.schema;
        expect(schema.params, hasLength(1));
        expect(schema.params[0].name, 'handle');
        expect(schema.params[0].type, HostParamType.integer);
      });
    });
  });
}
