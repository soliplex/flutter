import 'package:soliplex_agent/soliplex_agent.dart' show FormApi;
import 'package:soliplex_scripting/soliplex_scripting.dart';
import 'package:test/test.dart';

import '../helpers.dart';

void main() {
  group('FormPlugin', () {
    late _FakeFormApi formApi;
    late FormPlugin plugin;

    setUp(() {
      formApi = _FakeFormApi();
      plugin = FormPlugin(formApi: formApi);
    });

    test('namespace is form', () {
      expect(plugin.namespace, 'form');
    });

    test('provides 2 functions', () {
      expect(plugin.functions, hasLength(2));
      final names = plugin.functions.map((f) => f.schema.name).toSet();
      expect(names, containsAll(['form_create', 'form_set_errors']));
    });

    test('registers onto bridge via PluginRegistry', () async {
      final bridge = RecordingBridge();
      final registry = PluginRegistry()..register(plugin);
      await registry.attachTo(bridge);

      final names = bridge.registered.map((f) => f.schema.name).toSet();
      expect(names, contains('form_create'));
    });

    group('handlers', () {
      late Map<String, HostFunction> byName;

      setUp(() {
        byName = {for (final f in plugin.functions) f.schema.name: f};
      });

      test('form_create delegates to FormApi.createForm', () async {
        final result = await byName['form_create']!.handler({
          'fields': <Object?>[
            <String, Object?>{'name': 'email', 'type': 'text'},
          ],
        });

        expect(result, 1);
        expect(formApi.createFormCalled, isTrue);
      });

      test('form_set_errors delegates to FormApi.setFormErrors', () async {
        await byName['form_set_errors']!.handler({
          'handle': 1,
          'errors': <String, Object?>{'email': 'invalid'},
        });

        expect(formApi.setErrorsCalled, isTrue);
      });

      test('form_set_errors rejects non-map errors', () async {
        await expectLater(
          byName['form_set_errors']!.handler({
            'handle': 1,
            'errors': 'not a map',
          }),
          throwsA(isA<ArgumentError>()),
        );
      });
    });

    group('schemas', () {
      late Map<String, HostFunction> byName;

      setUp(() {
        byName = {for (final f in plugin.functions) f.schema.name: f};
      });

      test('form_create has fields list param', () {
        final schema = byName['form_create']!.schema;
        expect(schema.params, hasLength(1));
        expect(schema.params[0].name, 'fields');
        expect(schema.params[0].type, HostParamType.list);
      });

      test('form_set_errors has handle and errors', () {
        final schema = byName['form_set_errors']!.schema;
        expect(schema.params, hasLength(2));
        expect(schema.params[0].name, 'handle');
        expect(schema.params[0].type, HostParamType.integer);
        expect(schema.params[1].name, 'errors');
        expect(schema.params[1].type, HostParamType.map);
      });
    });
  });
}

class _FakeFormApi implements FormApi {
  bool createFormCalled = false;
  bool setErrorsCalled = false;

  @override
  int createForm(List<Map<String, Object?>> fields) {
    createFormCalled = true;
    return 1;
  }

  @override
  bool setFormErrors(int handle, Map<String, String> errors) {
    setErrorsCalled = true;
    return true;
  }
}
