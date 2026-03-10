import 'package:soliplex_dataframe/soliplex_dataframe.dart';
import 'package:soliplex_scripting/soliplex_scripting.dart';
import 'package:test/test.dart';

import '../helpers.dart';

void main() {
  group('DfPlugin', () {
    late DfPlugin plugin;

    setUp(() {
      plugin = DfPlugin(dfRegistry: DfRegistry());
    });

    test('namespace is df', () {
      expect(plugin.namespace, 'df');
    });

    test('provides 37 functions', () {
      expect(plugin.functions, hasLength(37));
    });

    test('all function names start with df_', () {
      for (final fn in plugin.functions) {
        expect(fn.schema.name, startsWith('df_'));
      }
    });

    test('registers onto bridge via PluginRegistry', () async {
      final bridge = RecordingBridge();
      final registry = PluginRegistry()..register(plugin);
      await registry.attachTo(bridge);

      final names = bridge.registered.map((f) => f.schema.name).toSet();
      expect(names, contains('df_create'));
      expect(names, contains('df_head'));
      expect(names, contains('df_filter'));
      // 37 df + 2 introspection
      expect(bridge.registered, hasLength(39));
    });

    test('df_create creates via DfRegistry', () async {
      final byName = {
        for (final f in plugin.functions) f.schema.name: f,
      };

      final result = await byName['df_create']!.handler({
        'data': <Object?>[
          <String, Object?>{'a': 1, 'b': 2},
        ],
        'columns': null,
      });

      expect(result, isA<int>());
      expect(result! as int, isPositive);
    });

    test('df_head returns rows', () async {
      final byName = {
        for (final f in plugin.functions) f.schema.name: f,
      };

      final handle = (await byName['df_create']!.handler({
        'data': <Object?>[
          <String, Object?>{'x': 1},
          <String, Object?>{'x': 2},
          <String, Object?>{'x': 3},
        ],
        'columns': null,
      }))! as int;

      final rows = await byName['df_head']!.handler({
        'handle': handle,
        'n': 2,
      });
      expect(rows, isA<List<Object?>>());
      expect((rows! as List<Object?>).length, 2);
    });
  });
}
