import 'package:flutter/material.dart';
import 'package:soliplex_frontend/design/color/color_scheme_extensions.dart';
import 'package:soliplex_logging/soliplex_logging.dart';

/// Color-coded badge displaying a [LogLevel] label.
///
/// Uses [SymbolicColors] for consistent theming:
/// - fatal/error -> danger (red)
/// - warning -> warning (orange)
/// - info -> info (blue)
/// - debug/trace -> outline (muted)
class LogLevelBadge extends StatelessWidget {
  const LogLevelBadge({required this.level, super.key});

  final LogLevel level;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = _colorForLevel(level, colorScheme);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        level.label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  static Color _colorForLevel(LogLevel level, ColorScheme colorScheme) {
    return switch (level) {
      LogLevel.fatal || LogLevel.error => colorScheme.danger,
      LogLevel.warning => colorScheme.warning,
      LogLevel.info => colorScheme.info,
      LogLevel.debug || LogLevel.trace => colorScheme.outline,
    };
  }
}
