import 'package:flutter_test/flutter_test.dart';
import 'package:soliplex_monty/src/data/df_registry.dart';
import 'package:soliplex_monty/src/functions/df_functions.dart';

void main() {
  group('buildDfFunctions', () {
    late DfRegistry registry;

    setUp(() {
      registry = DfRegistry();
    });

    test('returns 37 functions', () {
      final fns = buildDfFunctions(registry);
      expect(fns, hasLength(37));
    });

    test('all function names are unique', () {
      final fns = buildDfFunctions(registry);
      final names = fns.map((f) => f.schema.name).toSet();
      expect(names, hasLength(37));
    });

    group('schema coverage', () {
      test('df_create has data and columns params', () {
        final fns = buildDfFunctions(registry);
        final create = fns.firstWhere((f) => f.schema.name == 'df_create');
        final paramNames = create.schema.params.map((p) => p.name).toList();
        expect(paramNames, ['data', 'columns']);
        expect(create.schema.params[0].isRequired, isTrue);
        expect(create.schema.params[1].isRequired, isFalse);
      });

      test('df_filter has handle, column, op, value params', () {
        final fns = buildDfFunctions(registry);
        final filter = fns.firstWhere((f) => f.schema.name == 'df_filter');
        final paramNames = filter.schema.params.map((p) => p.name).toList();
        expect(paramNames, ['handle', 'column', 'op', 'value']);
      });

      test('df_dispose_all has no params', () {
        final fns = buildDfFunctions(registry);
        final disposeAll =
            fns.firstWhere((f) => f.schema.name == 'df_dispose_all');
        expect(disposeAll.schema.params, isEmpty);
      });
    });

    group('handler smoke tests', () {
      test('df_create returns a handle', () async {
        final fns = buildDfFunctions(registry);
        final create = fns.firstWhere((f) => f.schema.name == 'df_create');
        final handle = await create.handler({
          'data': <Object?>[
            <String, Object?>{'a': 1, 'b': 2},
            <String, Object?>{'a': 3, 'b': 4},
          ],
          'columns': null,
        });
        expect(handle, isA<int>());
        expect(handle! as int, isPositive);
      });

      test('df_head returns rows', () async {
        final fns = buildDfFunctions(registry);
        final create = fns.firstWhere((f) => f.schema.name == 'df_create');
        final head = fns.firstWhere((f) => f.schema.name == 'df_head');

        final handle = (await create.handler({
          'data': <Object?>[
            <String, Object?>{'x': 1},
            <String, Object?>{'x': 2},
            <String, Object?>{'x': 3},
          ],
          'columns': null,
        }))! as int;

        final rows = await head.handler({
          'handle': handle,
          'n': 2,
        });
        expect(rows, isA<List<Object?>>());
        expect((rows! as List<Object?>).length, 2);
      });

      test('df_shape returns [rows, cols]', () async {
        final fns = buildDfFunctions(registry);
        final create = fns.firstWhere((f) => f.schema.name == 'df_create');
        final shape = fns.firstWhere((f) => f.schema.name == 'df_shape');

        final handle = (await create.handler({
          'data': <Object?>[
            <String, Object?>{'a': 1, 'b': 2},
          ],
          'columns': null,
        }))! as int;

        final result = await shape.handler({'handle': handle});
        expect(result, [1, 2]);
      });

      test('df_dispose returns null', () async {
        final fns = buildDfFunctions(registry);
        final create = fns.firstWhere((f) => f.schema.name == 'df_create');
        final dispose = fns.firstWhere((f) => f.schema.name == 'df_dispose');

        final handle = (await create.handler({
          'data': <Object?>[
            <String, Object?>{'a': 1},
          ],
          'columns': null,
        }))! as int;

        final result = await dispose.handler({'handle': handle});
        expect(result, isNull);
      });

      test('df_dispose_all returns null', () async {
        final fns = buildDfFunctions(registry);
        final disposeAll =
            fns.firstWhere((f) => f.schema.name == 'df_dispose_all');

        final result = await disposeAll.handler({});
        expect(result, isNull);
      });

      test('df_filter creates filtered DataFrame', () async {
        final fns = buildDfFunctions(registry);
        final create = fns.firstWhere((f) => f.schema.name == 'df_create');
        final filter = fns.firstWhere((f) => f.schema.name == 'df_filter');
        final head = fns.firstWhere((f) => f.schema.name == 'df_head');

        final handle = (await create.handler({
          'data': <Object?>[
            <String, Object?>{'name': 'Alice', 'age': 30},
            <String, Object?>{'name': 'Bob', 'age': 25},
            <String, Object?>{'name': 'Carol', 'age': 35},
          ],
          'columns': null,
        }))! as int;

        final filteredHandle = (await filter.handler({
          'handle': handle,
          'column': 'age',
          'op': '>',
          'value': 28,
        }))! as int;

        final rows = (await head.handler({
          'handle': filteredHandle,
          'n': 10,
        }))! as List<Object?>;

        expect(rows.length, 2);
      });

      test('df_concat merges multiple DataFrames', () async {
        final fns = buildDfFunctions(registry);
        final create = fns.firstWhere((f) => f.schema.name == 'df_create');
        final concat = fns.firstWhere((f) => f.schema.name == 'df_concat');
        final shape = fns.firstWhere((f) => f.schema.name == 'df_shape');

        final h1 = (await create.handler({
          'data': <Object?>[
            <String, Object?>{'x': 1},
          ],
          'columns': null,
        }))! as int;
        final h2 = (await create.handler({
          'data': <Object?>[
            <String, Object?>{'x': 2},
            <String, Object?>{'x': 3},
          ],
          'columns': null,
        }))! as int;

        final concatHandle = (await concat.handler({
          'handles': <Object?>[h1, h2],
        }))! as int;

        final result = await shape.handler({'handle': concatHandle});
        expect(result, [3, 1]);
      });
    });
  });
}
