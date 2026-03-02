// TEMPORARY: Chart config for debug REPL validation — remove after validation.

import 'dart:math' as math;

/// Lightweight chart configuration for the debug DataFrame REPL.
///
/// Each config holds extracted numeric data ready for rendering.
/// The extraction happens at command time; rendering is stateless.
sealed class DebugChartConfig {
  const DebugChartConfig({
    required this.title,
    required this.xLabel,
    required this.yLabel,
  });

  /// Parses a chart configuration map into the appropriate subtype.
  ///
  /// Throws [FormatException] if `type` is missing or unknown.
  static DebugChartConfig fromMap(Map<String, Object?> map) {
    final type = map['type'];
    if (type is! String) {
      throw FormatException('Chart config missing "type" field', map);
    }
    return switch (type) {
      'line' => LineChartConfig(
          title: map['title'] as String? ?? '',
          xLabel: map['x_label'] as String? ?? 'X',
          yLabel: map['y_label'] as String? ?? 'Y',
          points: _parsePoints(map['points']),
        ),
      'bar' => BarChartConfig(
          title: map['title'] as String? ?? '',
          xLabel: map['x_label'] as String? ?? 'X',
          yLabel: map['y_label'] as String? ?? 'Y',
          labels: (map['labels'] as List?)?.cast<String>() ?? [],
          values: _parseDoubles(map['values']),
        ),
      'scatter' => ScatterChartConfig(
          title: map['title'] as String? ?? '',
          xLabel: map['x_label'] as String? ?? 'X',
          yLabel: map['y_label'] as String? ?? 'Y',
          points: _parsePoints(map['points']),
        ),
      _ => throw FormatException('Unknown chart type: $type', map),
    };
  }

  final String title;
  final String xLabel;
  final String yLabel;
}

List<math.Point<double>> _parsePoints(Object? raw) {
  if (raw is! List) return [];
  return raw.map<math.Point<double>>((item) {
    if (item is List && item.length >= 2) {
      return math.Point(
        (item[0] as num).toDouble(),
        (item[1] as num).toDouble(),
      );
    }
    return const math.Point(0, 0);
  }).toList();
}

List<double> _parseDoubles(Object? raw) {
  if (raw is! List) return [];
  return raw.map((v) => (v as num).toDouble()).toList();
}

/// Line chart: series of (x, y) points connected by lines.
class LineChartConfig extends DebugChartConfig {
  const LineChartConfig({
    required super.title,
    required super.xLabel,
    required super.yLabel,
    required this.points,
  });

  final List<math.Point<double>> points;
}

/// Bar chart: labelled categories with numeric values.
class BarChartConfig extends DebugChartConfig {
  const BarChartConfig({
    required super.title,
    required super.xLabel,
    required super.yLabel,
    required this.labels,
    required this.values,
  });

  final List<String> labels;
  final List<double> values;
}

/// Scatter chart: unconnected (x, y) data points.
class ScatterChartConfig extends DebugChartConfig {
  const ScatterChartConfig({
    required super.title,
    required super.xLabel,
    required super.yLabel,
    required this.points,
  });

  final List<math.Point<double>> points;
}
