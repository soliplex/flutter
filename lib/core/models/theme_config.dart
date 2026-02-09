import 'package:meta/meta.dart';
import 'package:soliplex_frontend/design/tokens/colors.dart';

/// Theme configuration for customizing app appearance.
///
/// Wraps [SoliplexColors] for light and dark modes, allowing white-label
/// apps to provide custom color schemes while preserving the theme structure.
@immutable
class ThemeConfig {
  /// Creates a theme configuration with optional custom colors.
  ///
  /// If colors are not provided, defaults to the standard Soliplex palette.
  const ThemeConfig({
    this.lightColors = lightSoliplexColors,
    this.darkColors = darkSoliplexColors,
  });

  /// Color palette for light mode.
  final SoliplexColors lightColors;

  /// Color palette for dark mode.
  final SoliplexColors darkColors;

  /// Creates a copy with the specified fields replaced.
  ThemeConfig copyWith({
    SoliplexColors? lightColors,
    SoliplexColors? darkColors,
  }) {
    return ThemeConfig(
      lightColors: lightColors ?? this.lightColors,
      darkColors: darkColors ?? this.darkColors,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ThemeConfig &&
          runtimeType == other.runtimeType &&
          lightColors == other.lightColors &&
          darkColors == other.darkColors;

  @override
  int get hashCode => Object.hash(lightColors, darkColors);

  @override
  String toString() => 'ThemeConfig(lightColors: $lightColors, '
      'darkColors: $darkColors)';
}
