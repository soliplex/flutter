import 'package:flutter_test/flutter_test.dart';
import 'package:soliplex_monty/src/data/data_frame.dart';
import 'package:soliplex_monty/src/data/df_registry.dart';

void main() {
  group('DfRegistry', () {
    late DfRegistry registry;

    setUp(() {
      registry = DfRegistry();
    });

    group('register / get', () {
      test('registers and retrieves a DataFrame', () {
        const df = DataFrame([
          {'a': 1},
        ]);
        final handle = registry.register(df);
        expect(handle, isPositive);
        expect(registry.get(handle).rows, df.rows);
      });

      test('throws on missing handle', () {
        expect(() => registry.get(999), throwsArgumentError);
      });
    });

    group('dispose', () {
      test('removes a handle', () {
        final handle = registry.register(
          const DataFrame([
            {'a': 1},
          ]),
        );
        registry.dispose(handle);
        expect(() => registry.get(handle), throwsArgumentError);
      });

      test('disposeAll clears all handles', () {
        final h1 = registry.register(
          const DataFrame([
            {'a': 1},
          ]),
        );
        final h2 = registry.register(
          const DataFrame([
            {'b': 2},
          ]),
        );
        registry.disposeAll();
        expect(() => registry.get(h1), throwsArgumentError);
        expect(() => registry.get(h2), throwsArgumentError);
      });
    });

    group('create', () {
      test('from list of maps', () {
        final handle = registry.create([
          {'name': 'Alice', 'age': 30},
          {'name': 'Bob', 'age': 25},
        ]);
        final df = registry.get(handle);
        expect(df.length, 2);
        expect(df.columns, ['name', 'age']);
      });

      test('from list of lists with columns', () {
        final handle = registry.create(
          [
            ['Alice', 30],
            ['Bob', 25],
          ],
          ['name', 'age'],
        );
        final df = registry.get(handle);
        expect(df.length, 2);
        expect(df.rows.first['name'], 'Alice');
        expect(df.rows.first['age'], 30);
      });

      test('throws on invalid data', () {
        expect(() => registry.create('invalid'), throwsArgumentError);
        expect(() => registry.create([]), throwsArgumentError);
      });

      test('coerces numeric strings in map values', () {
        final handle = registry.create([
          {'value': '42'},
        ]);
        final df = registry.get(handle);
        expect(df.rows.first['value'], 42);
      });

      test('coerces non-string map keys to string', () {
        final handle = registry.create([
          {1: 'one', 2: 'two'},
        ]);
        final df = registry.get(handle);
        expect(df.columns, ['1', '2']);
      });
    });

    group('fromCsv', () {
      test('parses headers and rows', () {
        const csv = 'name,age,score\nAlice,30,90\nBob,25,85';
        final handle = registry.fromCsv(csv);
        final df = registry.get(handle);
        expect(df.length, 2);
        expect(df.columns, ['name', 'age', 'score']);
        expect(df.rows.first['name'], 'Alice');
        expect(df.rows.first['age'], 30);
      });

      test('handles empty CSV', () {
        final handle = registry.fromCsv('');
        expect(registry.get(handle).length, 0);
      });

      test('parses booleans', () {
        const csv = 'flag\ntrue\nfalse';
        final handle = registry.fromCsv(csv);
        final df = registry.get(handle);
        expect(df.rows[0]['flag'], true);
        expect(df.rows[1]['flag'], false);
      });

      test('parses null/None as null', () {
        const csv = 'x\nnull\nNone';
        final handle = registry.fromCsv(csv);
        final df = registry.get(handle);
        expect(df.rows[0]['x'], isNull);
        expect(df.rows[1]['x'], isNull);
      });
    });

    group('fromJson', () {
      test('parses JSON array of objects', () {
        const json = '[{"a": 1, "b": 2}, {"a": 3, "b": 4}]';
        final handle = registry.fromJson(json);
        final df = registry.get(handle);
        expect(df.length, 2);
        expect(df.rows.first['a'], 1);
      });

      test('throws on non-array JSON', () {
        expect(() => registry.fromJson('{"a": 1}'), throwsArgumentError);
      });
    });

    group('_coerceValue', () {
      test('coerces nested structures via create', () {
        final handle = registry.create([
          {
            'nested': {'key': '42'},
          },
        ]);
        final df = registry.get(handle);
        final nested = df.rows.first['nested'] as Map<String, dynamic>;
        expect(nested['key'], 42);
      });

      test('coerces list values via create', () {
        final handle = registry.create([
          {
            'tags': ['1', '2', 'hello'],
          },
        ]);
        final df = registry.get(handle);
        final tags = df.rows.first['tags'] as List<Object?>;
        expect(tags[0], 1);
        expect(tags[1], 2);
        expect(tags[2], 'hello');
      });
    });
  });
}
