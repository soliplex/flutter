// TEMPORARY: Chart renderer for debug REPL —
// remove after validation.

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:soliplex_frontend/features/debug/debug_chart_config.dart';

/// Renders a [DebugChartConfig] as an fl_chart widget.
class DebugChartRenderer extends StatelessWidget {
  const DebugChartRenderer({required this.config, super.key});

  final DebugChartConfig config;

  @override
  Widget build(BuildContext context) => switch (config) {
        final LineChartConfig c => _LineChartView(config: c),
        final BarChartConfig c => _BarChartView(config: c),
        final ScatterChartConfig c => _ScatterChartView(config: c),
      };
}

class _LineChartView extends StatelessWidget {
  const _LineChartView({required this.config});
  final LineChartConfig config;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return LineChart(
      LineChartData(
        lineBarsData: [
          LineChartBarData(
            spots: [
              for (final p in config.points) FlSpot(p.x, p.y),
            ],
            isCurved: true,
            color: color,
          ),
        ],
        titlesData: _titlesData(
          config.xLabel,
          config.yLabel,
        ),
        borderData: FlBorderData(show: true),
      ),
    );
  }
}

class _BarChartView extends StatelessWidget {
  const _BarChartView({required this.config});
  final BarChartConfig config;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.tertiary;
    return BarChart(
      BarChartData(
        barGroups: [
          for (var i = 0; i < config.values.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: config.values[i],
                  color: color,
                  width: 16,
                ),
              ],
            ),
        ],
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            axisNameWidget: Text(
              config.xLabel,
              style: const TextStyle(fontSize: 11),
            ),
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, _) {
                final i = value.toInt();
                if (i < 0 || i >= config.labels.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    config.labels[i],
                    style: const TextStyle(
                      fontSize: 10,
                    ),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            axisNameWidget: Text(
              config.yLabel,
              style: const TextStyle(fontSize: 11),
            ),
            sideTitles: const SideTitles(
              showTitles: true,
              reservedSize: 40,
            ),
          ),
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
        ),
        gridData: const FlGridData(),
        borderData: FlBorderData(show: true),
      ),
    );
  }
}

class _ScatterChartView extends StatelessWidget {
  const _ScatterChartView({required this.config});
  final ScatterChartConfig config;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.secondary;
    return ScatterChart(
      ScatterChartData(
        scatterSpots: [
          for (final p in config.points)
            ScatterSpot(
              p.x,
              p.y,
              dotPainter: FlDotCirclePainter(
                color: color,
                radius: 10,
              ),
            ),
        ],
        titlesData: _titlesData(
          config.xLabel,
          config.yLabel,
        ),
        gridData: const FlGridData(),
        borderData: FlBorderData(show: true),
      ),
    );
  }
}

FlTitlesData _titlesData(String xLabel, String yLabel) => FlTitlesData(
      bottomTitles: AxisTitles(
        axisNameWidget: Text(
          xLabel,
          style: const TextStyle(fontSize: 11),
        ),
        sideTitles: const SideTitles(
          showTitles: true,
          reservedSize: 28,
        ),
      ),
      leftTitles: AxisTitles(
        axisNameWidget: Text(
          yLabel,
          style: const TextStyle(fontSize: 11),
        ),
        sideTitles: const SideTitles(
          showTitles: true,
          reservedSize: 40,
        ),
      ),
      topTitles: const AxisTitles(),
      rightTitles: const AxisTitles(),
    );
