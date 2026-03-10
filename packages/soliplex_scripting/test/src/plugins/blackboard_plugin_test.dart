import 'package:soliplex_agent/soliplex_agent.dart' show FakeBlackboardApi;
import 'package:soliplex_scripting/soliplex_scripting.dart';
import 'package:test/test.dart';

import '../helpers.dart';

void main() {
  group('BlackboardPlugin', () {
    late FakeBlackboardApi blackboardApi;
    late BlackboardPlugin plugin;

    setUp(() {
      blackboardApi = FakeBlackboardApi();
      plugin = BlackboardPlugin(blackboardApi: blackboardApi);
    });

    test('namespace is blackboard', () {
      expect(plugin.namespace, 'blackboard');
    });

    test('provides 3 functions', () {
      expect(plugin.functions, hasLength(3));
      final names = plugin.functions.map((f) => f.schema.name).toSet();
      expect(
        names,
        containsAll([
          'blackboard_write',
          'blackboard_read',
          'blackboard_keys',
        ]),
      );
    });

    test('registers onto bridge via PluginRegistry', () async {
      final bridge = RecordingBridge();
      final registry = PluginRegistry()..register(plugin);
      await registry.attachTo(bridge);

      final names = bridge.registered.map((f) => f.schema.name).toSet();
      expect(names, contains('blackboard_write'));
    });

    group('handler delegation', () {
      late Map<String, HostFunction> byName;

      setUp(() {
        byName = {for (final f in plugin.functions) f.schema.name: f};
      });

      test('blackboard_write delegates to BlackboardApi.write', () async {
        await byName['blackboard_write']!.handler({
          'key': 'score',
          'value': 42,
        });

        expect(blackboardApi.store['score'], 42);
      });

      test('blackboard_write accepts null value', () async {
        await byName['blackboard_write']!.handler({
          'key': 'cleared',
          'value': null,
        });

        expect(blackboardApi.store['cleared'], isNull);
      });

      test('blackboard_read delegates to BlackboardApi.read', () async {
        blackboardApi.store['greeting'] = 'hello';

        final result = await byName['blackboard_read']!.handler({
          'key': 'greeting',
        });

        expect(result, 'hello');
      });

      test('blackboard_read returns null for missing key', () async {
        final result = await byName['blackboard_read']!.handler({
          'key': 'absent',
        });

        expect(result, isNull);
      });

      test('blackboard_keys returns all keys', () async {
        blackboardApi.store['a'] = 1;
        blackboardApi.store['b'] = 2;

        final result = await byName['blackboard_keys']!.handler({});

        expect(result, isA<List<String>>());
        expect(result! as List<String>, containsAll(['a', 'b']));
      });

      test('blackboard_keys returns empty list for empty store', () async {
        final result = await byName['blackboard_keys']!.handler({});

        expect(result, <String>[]);
      });
    });

    group('schemas', () {
      late Map<String, HostFunction> byName;

      setUp(() {
        byName = {for (final f in plugin.functions) f.schema.name: f};
      });

      test('blackboard_write has key and optional value', () {
        final schema = byName['blackboard_write']!.schema;
        expect(schema.params, hasLength(2));
        expect(schema.params[0].name, 'key');
        expect(schema.params[0].type, HostParamType.string);
        expect(schema.params[1].name, 'value');
        expect(schema.params[1].type, HostParamType.any);
        expect(schema.params[1].isRequired, isFalse);
      });

      test('blackboard_read has key param', () {
        final schema = byName['blackboard_read']!.schema;
        expect(schema.params, hasLength(1));
        expect(schema.params[0].name, 'key');
      });

      test('blackboard_keys has no params', () {
        final schema = byName['blackboard_keys']!.schema;
        expect(schema.params, isEmpty);
      });
    });
  });
}
