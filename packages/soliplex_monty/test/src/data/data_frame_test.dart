import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:soliplex_monty/src/data/data_frame.dart';

void main() {
  group('DataFrame', () {
    late DataFrame df;

    setUp(() {
      df = const DataFrame([
        {'name': 'Alice', 'age': 30, 'score': 90},
        {'name': 'Bob', 'age': 25, 'score': 85},
        {'name': 'Carol', 'age': 35, 'score': 92},
        {'name': 'Dave', 'age': 28, 'score': 88},
        {'name': 'Eve', 'age': 32, 'score': 95},
      ]);
    });

    group('construction', () {
      test('creates from rows', () {
        expect(df.length, 5);
        expect(df.columnCount, 3);
      });

      test('empty DataFrame', () {
        const empty = DataFrame([]);
        expect(empty.length, 0);
        expect(empty.columns, isEmpty);
        expect(empty.columnCount, 0);
      });
    });

    group('properties', () {
      test('columns returns first row keys', () {
        expect(df.columns, ['name', 'age', 'score']);
      });

      test('length returns row count', () {
        expect(df.length, 5);
      });

      test('columnCount returns column count', () {
        expect(df.columnCount, 3);
      });
    });

    group('head/tail', () {
      test('head returns first 5 by default', () {
        expect(df.head().length, 5);
      });

      test('head with custom n', () {
        expect(df.head(2).length, 2);
        expect(df.head(2).rows.first['name'], 'Alice');
      });

      test('tail returns last 5 by default', () {
        expect(df.tail().length, 5);
      });

      test('tail with custom n', () {
        final result = df.tail(2);
        expect(result.length, 2);
        expect(result.rows.first['name'], 'Dave');
        expect(result.rows.last['name'], 'Eve');
      });
    });

    group('select', () {
      test('selects specific columns', () {
        final result = df.select(['name', 'age']);
        expect(result.columns, ['name', 'age']);
        expect(result.rows.first.containsKey('score'), isFalse);
      });
    });

    group('filter', () {
      test('== operator', () {
        final result = df.filter('name', '==', 'Alice');
        expect(result.length, 1);
        expect(result.rows.first['name'], 'Alice');
      });

      test('!= operator', () {
        final result = df.filter('name', '!=', 'Alice');
        expect(result.length, 4);
      });

      test('> operator', () {
        final result = df.filter('age', '>', 30);
        expect(result.length, 2);
      });

      test('>= operator', () {
        final result = df.filter('age', '>=', 30);
        expect(result.length, 3);
      });

      test('< operator', () {
        final result = df.filter('age', '<', 30);
        expect(result.length, 2);
      });

      test('<= operator', () {
        final result = df.filter('age', '<=', 30);
        expect(result.length, 3);
      });

      test('contains operator', () {
        final result = df.filter('name', 'contains', 'a');
        // Carol, Dave have 'a' in them (case-sensitive)
        expect(result.length, 2);
      });

      test('throws on unknown operator', () {
        expect(
          () => df.filter('age', '~', 30),
          throwsArgumentError,
        );
      });
    });

    group('sort', () {
      test('ascending by default', () {
        final result = df.sort('age');
        expect(result.rows.first['name'], 'Bob');
        expect(result.rows.last['name'], 'Carol');
      });

      test('descending', () {
        final result = df.sort('age', ascending: false);
        expect(result.rows.first['name'], 'Carol');
        expect(result.rows.last['name'], 'Bob');
      });
    });

    group('groupAgg', () {
      test('sum aggregation', () {
        const grouped = DataFrame([
          {'dept': 'A', 'sales': 10},
          {'dept': 'A', 'sales': 20},
          {'dept': 'B', 'sales': 30},
        ]);
        final result = grouped.groupAgg(['dept'], {'sales': 'sum'});
        expect(result.length, 2);
        final deptA = result.rows.firstWhere((r) => r['dept'] == 'A');
        expect(deptA['sales'], 30);
      });

      test('mean aggregation', () {
        const grouped = DataFrame([
          {'dept': 'A', 'sales': 10},
          {'dept': 'A', 'sales': 20},
        ]);
        final result = grouped.groupAgg(['dept'], {'sales': 'mean'});
        expect(result.rows.first['sales'], 15.0);
      });

      test('count aggregation', () {
        const grouped = DataFrame([
          {'dept': 'A', 'sales': 10},
          {'dept': 'A', 'sales': 20},
          {'dept': 'B', 'sales': 30},
        ]);
        final result = grouped.groupAgg(['dept'], {'sales': 'count'});
        final deptA = result.rows.firstWhere((r) => r['dept'] == 'A');
        expect(deptA['sales'], 2);
      });
    });

    group('addColumn', () {
      test('adds column with values', () {
        final result = df.addColumn('grade', ['A', 'B', 'A', 'B', 'A']);
        expect(result.columns, contains('grade'));
        expect(result.rows.first['grade'], 'A');
      });
    });

    group('drop', () {
      test('drops specified columns', () {
        final result = df.drop(['score']);
        expect(result.columns, ['name', 'age']);
      });
    });

    group('rename', () {
      test('renames columns', () {
        final result = df.rename({'name': 'full_name'});
        expect(result.columns, contains('full_name'));
        expect(result.columns, isNot(contains('name')));
      });
    });

    group('merge', () {
      test('inner merge', () {
        const left = DataFrame([
          {'id': 1, 'name': 'Alice'},
          {'id': 2, 'name': 'Bob'},
          {'id': 3, 'name': 'Carol'},
        ]);
        const right = DataFrame([
          {'id': 1, 'dept': 'Eng'},
          {'id': 2, 'dept': 'Sales'},
        ]);
        final result = left.merge(right, ['id']);
        expect(result.length, 2);
        expect(result.rows.first['name'], 'Alice');
        expect(result.rows.first['dept'], 'Eng');
      });
    });

    group('concat', () {
      test('concatenates DataFrames', () {
        const df1 = DataFrame([
          {'x': 1},
        ]);
        const df2 = DataFrame([
          {'x': 2},
        ]);
        final result = df1.concat([df2]);
        expect(result.length, 2);
      });
    });

    group('fillna', () {
      test('fills null values', () {
        const withNulls = DataFrame([
          {'a': 1, 'b': null},
          {'a': null, 'b': 2},
        ]);
        final result = withNulls.fillna(0);
        expect(result.rows[0]['b'], 0);
        expect(result.rows[1]['a'], 0);
      });
    });

    group('dropna', () {
      test('drops rows with nulls', () {
        const withNulls = DataFrame([
          {'a': 1, 'b': 2},
          {'a': null, 'b': 2},
          {'a': 3, 'b': 4},
        ]);
        final result = withNulls.dropna();
        expect(result.length, 2);
      });
    });

    group('transpose', () {
      test('transposes rows and columns', () {
        const small = DataFrame([
          {'a': 1, 'b': 2},
          {'a': 3, 'b': 4},
        ]);
        final result = small.transpose();
        expect(result.length, 2);
        expect(result.rows.first['column'], 'a');
        expect(result.rows.first['row_0'], 1);
        expect(result.rows.first['row_1'], 3);
      });

      test('empty DataFrame transposes to empty', () {
        const empty = DataFrame([]);
        expect(empty.transpose().length, 0);
      });
    });

    group('sample', () {
      test('returns n rows', () {
        final result = df.sample(3);
        expect(result.length, 3);
      });

      test('clamps to available rows', () {
        final result = df.sample(100);
        expect(result.length, 5);
      });
    });

    group('nlargest', () {
      test('returns largest n by column', () {
        final result = df.nlargest(2, 'age');
        expect(result.length, 2);
        expect(result.rows.first['name'], 'Carol'); // age 35
        expect(result.rows.last['name'], 'Eve'); // age 32
      });
    });

    group('nsmallest', () {
      test('returns smallest n by column', () {
        final result = df.nsmallest(2, 'age');
        expect(result.length, 2);
        expect(result.rows.first['name'], 'Bob'); // age 25
        expect(result.rows.last['name'], 'Dave'); // age 28
      });
    });

    group('aggregation', () {
      test('computeMean for single column', () {
        expect(df.computeMean('age'), 30.0);
      });

      test('computeMean for all columns', () {
        final result = df.computeMean()! as Map<String, dynamic>;
        expect(result.containsKey('age'), isTrue);
        expect(result.containsKey('score'), isTrue);
      });

      test('computeSum for single column', () {
        expect(df.computeSum('age'), 150);
      });

      test('computeMin for single column', () {
        expect(df.computeMin('age'), 25);
      });

      test('computeMax for single column', () {
        expect(df.computeMax('age'), 35);
      });

      test('computeStd for single column', () {
        final std = df.computeStd('age')! as double;
        // std of [30, 25, 35, 28, 32] ≈ 3.81
        expect(std, closeTo(3.81, 0.01));
      });

      test('computeStd returns null for < 2 values', () {
        const single = DataFrame([
          {'x': 5},
        ]);
        expect(single.computeStd('x'), isNull);
      });
    });

    group('describe', () {
      test('returns stats for numeric columns', () {
        final desc = df.describe();
        expect(desc.containsKey('age'), isTrue);
        expect(desc['age']!['count'], 5);
        expect(desc['age']!['mean'], 30.0);
        expect(desc['age']!['min'], 25);
        expect(desc['age']!['max'], 35);
      });
    });

    group('corr', () {
      test('returns correlation matrix', () {
        final result = df.corr();
        expect(result.length, 2); // age, score
        final ageRow = result.rows.firstWhere((r) => r['column'] == 'age');
        // Self-correlation should be ~1.0
        expect(ageRow['age'] as double, closeTo(1.0, 0.001));
      });
    });

    group('export', () {
      test('toCsv', () {
        final csv = df.toCsv();
        expect(csv, startsWith('name,age,score'));
        expect(csv, contains('Alice'));
      });

      test('toCsv empty', () {
        expect(const DataFrame([]).toCsv(), '');
      });

      test('toJson', () {
        final json = df.toJson();
        final decoded = jsonDecode(json) as List;
        expect(decoded.length, 5);
      });
    });

    group('columnValues', () {
      test('returns values for column', () {
        expect(
          df.columnValues('name'),
          ['Alice', 'Bob', 'Carol', 'Dave', 'Eve'],
        );
      });
    });

    group('unique', () {
      test('returns unique values', () {
        const dup = DataFrame([
          {'x': 'a'},
          {'x': 'b'},
          {'x': 'a'},
        ]);
        expect(dup.unique('x'), hasLength(2));
      });
    });

    group('valueCounts', () {
      test('counts occurrences', () {
        const dup = DataFrame([
          {'x': 'a'},
          {'x': 'b'},
          {'x': 'a'},
        ]);
        final counts = dup.valueCounts('x');
        expect(counts['a'], 2);
        expect(counts['b'], 1);
      });
    });
  });
}
