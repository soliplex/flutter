import 'dart:convert';
import 'dart:math';

import 'package:meta/meta.dart';

/// Simple in-memory DataFrame backed by `List<Map<String, dynamic>>`.
///
/// Pure Dart — no Flutter or platform imports.
@immutable
class DataFrame {
  /// Creates a [DataFrame] from a list of row maps.
  const DataFrame(this.rows);

  /// The data rows.
  final List<Map<String, dynamic>> rows;

  /// Column names derived from the first row, or empty if no rows.
  List<String> get columns =>
      rows.isEmpty ? const [] : rows.first.keys.toList();

  /// Number of rows.
  int get length => rows.length;

  /// Number of columns.
  int get columnCount => columns.length;

  /// Return first [n] rows as a new DataFrame.
  DataFrame head([int n = 5]) => DataFrame(rows.take(n).toList());

  /// Return last [n] rows as a new DataFrame.
  DataFrame tail([int n = 5]) =>
      DataFrame(rows.skip(max(0, rows.length - n)).toList());

  /// Select specific columns.
  DataFrame select(List<String> cols) => DataFrame([
        for (final row in rows) {for (final c in cols) c: row[c]},
      ]);

  /// Filter rows where [column] [op] [value].
  DataFrame filter(String column, String op, Object? value) {
    bool test(Object? cell) => switch (op) {
          '==' => cell == value,
          '!=' => cell != value,
          '>' => _cmp(cell, value) > 0,
          '>=' => _cmp(cell, value) >= 0,
          '<' => _cmp(cell, value) < 0,
          '<=' => _cmp(cell, value) <= 0,
          'contains' => cell.toString().contains(value.toString()),
          _ => throw ArgumentError('Unknown op: $op'),
        };
    return DataFrame(rows.where((r) => test(r[column])).toList());
  }

  /// Sort by [column].
  DataFrame sort(String column, {bool ascending = true}) {
    final sorted = List<Map<String, dynamic>>.of(rows)
      ..sort((a, b) {
        final cmp = _cmp(a[column], b[column]);
        return ascending ? cmp : -cmp;
      });
    return DataFrame(sorted);
  }

  /// Group by [groupCols] and aggregate with [aggMap].
  ///
  /// [aggMap] maps column names to aggregation functions:
  /// `"sum"`, `"mean"`, `"min"`, `"max"`, `"count"`.
  DataFrame groupAgg(List<String> groupCols, Map<String, String> aggMap) {
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final row in rows) {
      final key = groupCols.map((c) => '${row[c]}').join('|');
      (groups[key] ??= []).add(row);
    }

    final result = <Map<String, dynamic>>[];
    for (final entry in groups.entries) {
      final groupRows = entry.value;
      final out = <String, dynamic>{};
      for (final c in groupCols) {
        out[c] = groupRows.first[c];
      }
      for (final MapEntry(key: col, value: fn) in aggMap.entries) {
        final vals = groupRows.map((r) => r[col]).whereType<num>().toList();
        out[col] = switch (fn) {
          'sum' => vals.fold<num>(0, (a, b) => a + b),
          'mean' =>
            vals.isEmpty ? 0 : vals.fold<num>(0, (a, b) => a + b) / vals.length,
          'min' => vals.isEmpty ? null : vals.reduce(min),
          'max' => vals.isEmpty ? null : vals.reduce(max),
          'count' => groupRows.length,
          _ => throw ArgumentError('Unknown agg: $fn'),
        };
      }
      result.add(out);
    }
    return DataFrame(result);
  }

  /// Add a column with the given values.
  DataFrame addColumn(String name, List<Object?> values) {
    final out = <Map<String, dynamic>>[];
    for (var i = 0; i < rows.length; i++) {
      out.add({...rows[i], name: i < values.length ? values[i] : null});
    }
    return DataFrame(out);
  }

  /// Drop columns.
  DataFrame drop(List<String> cols) => DataFrame([
        for (final row in rows)
          {
            for (final e in row.entries)
              if (!cols.contains(e.key)) e.key: e.value,
          },
      ]);

  /// Rename columns.
  DataFrame rename(Map<String, String> mapping) => DataFrame([
        for (final row in rows)
          {for (final e in row.entries) (mapping[e.key] ?? e.key): e.value},
      ]);

  /// Merge with another DataFrame on [onCols] column(s).
  DataFrame merge(
    DataFrame other,
    List<String> onCols, {
    String how = 'inner',
  }) {
    final result = <Map<String, dynamic>>[];
    for (final left in rows) {
      for (final right in other.rows) {
        final match = onCols.every((c) => left[c] == right[c]);
        if (match) {
          result.add({...left, ...right});
        }
      }
    }
    if (how == 'left') {
      for (final left in rows) {
        final hasMatch = result.any(
          (r) => onCols.every((c) => r[c] == left[c]),
        );
        if (!hasMatch) result.add({...left});
      }
    }
    return DataFrame(result);
  }

  /// Concatenate multiple DataFrames.
  DataFrame concat(List<DataFrame> others) {
    final all = [...rows];
    for (final df in others) {
      all.addAll(df.rows);
    }
    return DataFrame(all);
  }

  /// Fill null values.
  DataFrame fillna(Object? value) => DataFrame([
        for (final row in rows)
          {for (final e in row.entries) e.key: e.value ?? value},
      ]);

  /// Drop rows with any null values.
  DataFrame dropna() =>
      DataFrame(rows.where((r) => r.values.every((v) => v != null)).toList());

  /// Transpose.
  DataFrame transpose() {
    if (rows.isEmpty) return const DataFrame([]);
    final cols = columns;
    final result = <Map<String, dynamic>>[];
    for (final col in cols) {
      final row = <String, dynamic>{'column': col};
      for (var i = 0; i < rows.length; i++) {
        row['row_$i'] = rows[i][col];
      }
      result.add(row);
    }
    return DataFrame(result);
  }

  /// Random sample of [n] rows.
  DataFrame sample(int n) {
    final rng = Random();
    final indices = List.generate(rows.length, (i) => i)..shuffle(rng);
    return DataFrame(
      indices.take(min(n, rows.length)).map((i) => rows[i]).toList(),
    );
  }

  /// Largest [n] by [column].
  DataFrame nlargest(int n, String column) =>
      sort(column, ascending: false).head(n);

  /// Smallest [n] by [column].
  DataFrame nsmallest(int n, String column) => sort(column).head(n);

  /// Values for a single column.
  List<Object?> columnValues(String column) =>
      rows.map((r) => r[column]).toList();

  /// Unique values in a column.
  List<Object?> unique(String column) => columnValues(column).toSet().toList();

  /// Value counts for a column.
  Map<String, int> valueCounts(String column) {
    final counts = <String, int>{};
    for (final row in rows) {
      final key = '${row[column]}';
      counts[key] = (counts[key] ?? 0) + 1;
    }
    return counts;
  }

  // -- Aggregation helpers ---------------------------------------------------

  List<num> _numericValues(String column) =>
      rows.map((r) => r[column]).whereType<num>().toList();

  /// Mean of a column, or all numeric columns if [column] is null.
  Object? computeMean([String? column]) {
    if (column != null) {
      final vals = _numericValues(column);
      return vals.isEmpty
          ? null
          : vals.fold<num>(0, (a, b) => a + b) / vals.length;
    }
    return {
      for (final c in columns)
        if (_numericValues(c).isNotEmpty) c: computeMean(c),
    };
  }

  /// Sum of a column, or all numeric columns if [column] is null.
  Object? computeSum([String? column]) {
    if (column != null) {
      return _numericValues(column).fold<num>(0, (a, b) => a + b);
    }
    return {
      for (final c in columns)
        if (_numericValues(c).isNotEmpty) c: computeSum(c),
    };
  }

  /// Min of a column, or all numeric columns if [column] is null.
  Object? computeMin([String? column]) {
    if (column != null) {
      final vals = _numericValues(column);
      return vals.isEmpty ? null : vals.reduce(min);
    }
    return {
      for (final c in columns)
        if (_numericValues(c).isNotEmpty) c: computeMin(c),
    };
  }

  /// Max of a column, or all numeric columns if [column] is null.
  Object? computeMax([String? column]) {
    if (column != null) {
      final vals = _numericValues(column);
      return vals.isEmpty ? null : vals.reduce(max);
    }
    return {
      for (final c in columns)
        if (_numericValues(c).isNotEmpty) c: computeMax(c),
    };
  }

  /// Standard deviation of a column, or all numeric columns.
  Object? computeStd([String? column]) {
    if (column != null) {
      final vals = _numericValues(column);
      if (vals.length < 2) return null;
      final mean = vals.fold<num>(0, (a, b) => a + b) / vals.length;
      final variance = vals
              .map((v) => (v - mean) * (v - mean))
              .fold<num>(0, (a, b) => a + b) /
          (vals.length - 1);
      return sqrt(variance);
    }
    return {
      for (final c in columns)
        if (_numericValues(c).isNotEmpty) c: computeStd(c),
    };
  }

  /// Describe: count, mean, std, min, max for each numeric column.
  Map<String, Map<String, num?>> describe() {
    final result = <String, Map<String, num?>>{};
    for (final col in columns) {
      final vals = _numericValues(col);
      if (vals.isEmpty) continue;
      final n = vals.length;
      final mean = vals.fold<num>(0, (a, b) => a + b) / n;
      final stdVal = n < 2
          ? null
          : sqrt(
              vals
                      .map((v) => (v - mean) * (v - mean))
                      .fold<num>(0, (a, b) => a + b) /
                  (n - 1),
            );
      result[col] = {
        'count': n,
        'mean': mean,
        'std': stdVal,
        'min': vals.reduce(min),
        'max': vals.reduce(max),
      };
    }
    return result;
  }

  /// Correlation matrix for numeric columns.
  DataFrame corr() {
    final numCols = columns.where((c) => _numericValues(c).isNotEmpty).toList();
    final result = <Map<String, dynamic>>[];
    for (final c1 in numCols) {
      final row = <String, dynamic>{'column': c1};
      final v1 = _numericValues(c1);
      final m1 = v1.fold<num>(0, (a, b) => a + b) / v1.length;
      for (final c2 in numCols) {
        final v2 = _numericValues(c2);
        final m2 = v2.fold<num>(0, (a, b) => a + b) / v2.length;
        final n = min(v1.length, v2.length);
        var cov = 0.0;
        var s1 = 0.0;
        var s2 = 0.0;
        for (var i = 0; i < n; i++) {
          cov += (v1[i] - m1) * (v2[i] - m2);
          s1 += (v1[i] - m1) * (v1[i] - m1);
          s2 += (v2[i] - m2) * (v2[i] - m2);
        }
        final denom = sqrt(s1) * sqrt(s2);
        row[c2] = denom == 0 ? 0.0 : cov / denom;
      }
      result.add(row);
    }
    return DataFrame(result);
  }

  /// Export to CSV string.
  String toCsv() {
    if (rows.isEmpty) return '';
    final cols = columns;
    final buf = StringBuffer(cols.join(','));
    for (final row in rows) {
      buf
        ..write('\n')
        ..write(cols.map((c) => row[c] ?? '').join(','));
    }
    return buf.toString();
  }

  /// Export to JSON string.
  String toJson() => jsonEncode(rows);

  static int _cmp(Object? a, Object? b) {
    if (a == null && b == null) return 0;
    if (a == null) return -1;
    if (b == null) return 1;
    if (a is num && b is num) return a.compareTo(b);
    return a.toString().compareTo(b.toString());
  }
}
