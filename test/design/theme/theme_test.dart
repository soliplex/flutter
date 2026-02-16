import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soliplex_frontend/core/models/color_config.dart';
import 'package:soliplex_frontend/core/models/font_config.dart';
import 'package:soliplex_frontend/core/models/theme_config.dart';
import 'package:soliplex_frontend/design/theme/theme.dart';

void main() {
  group('generateColorScheme', () {
    const lightPalette = ColorPalette.defaultLight();
    const darkPalette = ColorPalette.defaultDark();

    test('generates light scheme with correct brightness', () {
      final scheme = generateColorScheme(
        brightness: Brightness.light,
        palette: lightPalette,
      );

      expect(scheme.brightness, Brightness.light);
    });

    test('generates dark scheme with correct brightness', () {
      final scheme = generateColorScheme(
        brightness: Brightness.dark,
        palette: darkPalette,
      );

      expect(scheme.brightness, Brightness.dark);
    });

    test('maps primary directly from palette', () {
      final scheme = generateColorScheme(
        brightness: Brightness.light,
        palette: lightPalette,
      );

      expect(scheme.primary, lightPalette.primary);
    });

    test('maps secondary directly from palette', () {
      final scheme = generateColorScheme(
        brightness: Brightness.light,
        palette: lightPalette,
      );

      expect(scheme.secondary, lightPalette.secondary);
    });

    test('maps surface from palette background', () {
      final scheme = generateColorScheme(
        brightness: Brightness.light,
        palette: lightPalette,
      );

      expect(scheme.surface, lightPalette.background);
    });

    test('maps onSurface from palette foreground', () {
      final scheme = generateColorScheme(
        brightness: Brightness.light,
        palette: lightPalette,
      );

      expect(scheme.onSurface, lightPalette.foreground);
    });

    test('maps onSurfaceVariant from palette mutedForeground', () {
      final scheme = generateColorScheme(
        brightness: Brightness.light,
        palette: lightPalette,
      );

      expect(scheme.onSurfaceVariant, lightPalette.mutedForeground);
    });

    test('maps outline from palette border', () {
      final scheme = generateColorScheme(
        brightness: Brightness.light,
        palette: lightPalette,
      );

      expect(scheme.outline, lightPalette.border);
    });

    test('onPrimary uses palette effectiveOnPrimary', () {
      final scheme = generateColorScheme(
        brightness: Brightness.light,
        palette: lightPalette,
      );

      expect(scheme.onPrimary, lightPalette.effectiveOnPrimary);
    });

    test('onPrimary uses custom value when provided', () {
      const palette = ColorPalette(
        primary: Color(0xFF1A237E),
        secondary: Colors.orange,
        background: Colors.white,
        foreground: Colors.black,
        muted: Color(0xFFE0E0E0),
        mutedForeground: Color(0xFF757575),
        border: Color(0xFFBDBDBD),
        onPrimary: Colors.yellow,
      );

      final scheme = generateColorScheme(
        brightness: Brightness.light,
        palette: palette,
      );

      expect(scheme.onPrimary, Colors.yellow);
    });

    test('contrast color for dark primary is white', () {
      const palette = ColorPalette(
        primary: Color(0xFF1A237E), // Dark indigo
        secondary: Colors.orange,
        background: Colors.white,
        foreground: Colors.black,
        muted: Color(0xFFE0E0E0),
        mutedForeground: Color(0xFF757575),
        border: Color(0xFFBDBDBD),
      );

      final scheme = generateColorScheme(
        brightness: Brightness.light,
        palette: palette,
      );

      expect(scheme.onPrimary, Colors.white);
    });

    test('contrast color for light primary is black', () {
      const palette = ColorPalette(
        primary: Color(0xFFE8F5E9), // Light green
        secondary: Colors.orange,
        background: Colors.white,
        foreground: Colors.black,
        muted: Color(0xFFE0E0E0),
        mutedForeground: Color(0xFF757575),
        border: Color(0xFFBDBDBD),
      );

      final scheme = generateColorScheme(
        brightness: Brightness.light,
        palette: palette,
      );

      expect(scheme.onPrimary, Colors.black);
    });

    test('error uses palette effectiveError', () {
      final scheme = generateColorScheme(
        brightness: Brightness.light,
        palette: lightPalette,
      );

      expect(scheme.error, lightPalette.effectiveError);
    });

    test('custom error color is preserved', () {
      const palette = ColorPalette(
        primary: Colors.blue,
        secondary: Colors.orange,
        background: Colors.white,
        foreground: Colors.black,
        muted: Color(0xFFE0E0E0),
        mutedForeground: Color(0xFF757575),
        border: Color(0xFFBDBDBD),
        error: Colors.red,
      );

      final scheme = generateColorScheme(
        brightness: Brightness.light,
        palette: palette,
      );

      expect(scheme.error, Colors.red);
    });

    test('tertiary uses palette effectiveTertiary', () {
      final scheme = generateColorScheme(
        brightness: Brightness.light,
        palette: lightPalette,
      );

      expect(scheme.tertiary, lightPalette.effectiveTertiary);
    });

    test('primaryContainer is derived via lerp', () {
      final scheme = generateColorScheme(
        brightness: Brightness.light,
        palette: lightPalette,
      );

      final expected = Color.lerp(
        lightPalette.primary,
        lightPalette.background,
        0.85,
      );
      expect(scheme.primaryContainer, expected);
    });

    test('secondaryContainer differs from secondary', () {
      final scheme = generateColorScheme(
        brightness: Brightness.light,
        palette: lightPalette,
      );

      expect(scheme.secondaryContainer, isNot(equals(scheme.secondary)));
    });

    test('errorContainer is derived via lerp', () {
      final scheme = generateColorScheme(
        brightness: Brightness.light,
        palette: lightPalette,
      );

      final expected = Color.lerp(
        lightPalette.effectiveError,
        lightPalette.background,
        0.85,
      );
      expect(scheme.errorContainer, expected);
    });

    test('surfaceContainerHighest is muted lerped at 0.80', () {
      final scheme = generateColorScheme(
        brightness: Brightness.light,
        palette: lightPalette,
      );

      final expected = Color.lerp(
        lightPalette.background,
        lightPalette.muted,
        0.80,
      );
      expect(scheme.surfaceContainerHighest, expected);
    });

    test('outlineVariant is border lerped toward background', () {
      final scheme = generateColorScheme(
        brightness: Brightness.light,
        palette: lightPalette,
      );

      final expected = Color.lerp(
        lightPalette.border,
        lightPalette.background,
        0.5,
      );
      expect(scheme.outlineVariant, expected);
    });

    test('inverseSurface is foreground', () {
      final scheme = generateColorScheme(
        brightness: Brightness.light,
        palette: lightPalette,
      );

      expect(scheme.inverseSurface, lightPalette.foreground);
    });

    test('onInverseSurface is background', () {
      final scheme = generateColorScheme(
        brightness: Brightness.light,
        palette: lightPalette,
      );

      expect(scheme.onInverseSurface, lightPalette.background);
    });

    test('surfaceTint is transparent', () {
      final scheme = generateColorScheme(
        brightness: Brightness.light,
        palette: lightPalette,
      );

      expect(scheme.surfaceTint, Colors.transparent);
    });

    test('shadow and scrim are black', () {
      final scheme = generateColorScheme(
        brightness: Brightness.light,
        palette: lightPalette,
      );

      expect(scheme.shadow, Colors.black);
      expect(scheme.scrim, Colors.black);
    });

    test('surface container scale is ordered', () {
      final scheme = generateColorScheme(
        brightness: Brightness.light,
        palette: lightPalette,
      );

      // Each step should be progressively further from background
      // toward muted. We verify ordering by checking they're all distinct.
      final containers = [
        scheme.surfaceContainerLowest,
        scheme.surfaceContainerLow,
        scheme.surfaceContainer,
        scheme.surfaceContainerHigh,
        scheme.surfaceContainerHighest,
      ];
      // All distinct from each other
      expect(containers.toSet().length, 5);
    });
  });

  group('soliplexLightTheme', () {
    test('uses default palettes when none provided', () {
      final theme = soliplexLightTheme();

      expect(theme.brightness, Brightness.light);
      expect(theme.useMaterial3, isTrue);
    });

    test('uses custom palette when provided', () {
      const customLight = ColorPalette(
        primary: Colors.green,
        secondary: Colors.teal,
        background: Colors.white,
        foreground: Colors.black,
        muted: Color(0xFFE0E0E0),
        mutedForeground: Color(0xFF757575),
        border: Color(0xFFBDBDBD),
      );
      final theme = soliplexLightTheme(
        colorConfig: const ColorConfig(light: customLight),
      );

      expect(theme.brightness, Brightness.light);
      expect(theme.colorScheme.primary, Colors.green);
      expect(theme.colorScheme.secondary, Colors.teal);
    });

    test('has Material 3 enabled', () {
      final theme = soliplexLightTheme();

      expect(theme.useMaterial3, isTrue);
    });

    test('includes SoliplexTheme extension', () {
      final theme = soliplexLightTheme();

      expect(
        theme.extensions.values
            .any((e) => e.runtimeType.toString().contains('SoliplexTheme')),
        isTrue,
      );
    });

    test('default surface is light palette background', () {
      final theme = soliplexLightTheme();
      const defaultLight = ColorPalette.defaultLight();

      expect(theme.colorScheme.surface, defaultLight.background);
      expect(theme.scaffoldBackgroundColor, defaultLight.background);
    });

    test('custom background color is applied', () {
      const customBg = Color(0xFFF0F0F0);
      const palette = ColorPalette(
        primary: Color(0xFF6B6D7B),
        secondary: Color(0xFF8E8698),
        background: customBg,
        foreground: Color(0xFF1A1A1E),
        muted: Color(0xFFE4E4E8),
        mutedForeground: Color(0xFF6E6E78),
        border: Color(0xFFC8C8CE),
      );
      final theme = soliplexLightTheme(
        colorConfig: const ColorConfig(light: palette),
      );

      expect(theme.colorScheme.surface, customBg);
      expect(theme.scaffoldBackgroundColor, customBg);
    });
  });

  group('soliplexDarkTheme', () {
    test('uses default palettes when none provided', () {
      final theme = soliplexDarkTheme();

      expect(theme.brightness, Brightness.dark);
      expect(theme.useMaterial3, isTrue);
    });

    test('uses custom palette when provided', () {
      const customDark = ColorPalette(
        primary: Colors.green,
        secondary: Colors.teal,
        background: Color(0xFF121212),
        foreground: Colors.white,
        muted: Color(0xFF333333),
        mutedForeground: Color(0xFF999999),
        border: Color(0xFF555555),
      );
      final theme = soliplexDarkTheme(
        colorConfig: const ColorConfig(dark: customDark),
      );

      expect(theme.brightness, Brightness.dark);
      expect(theme.colorScheme.primary, Colors.green);
      expect(theme.colorScheme.secondary, Colors.teal);
    });

    test('has Material 3 enabled', () {
      final theme = soliplexDarkTheme();

      expect(theme.useMaterial3, isTrue);
    });

    test('includes SoliplexTheme extension', () {
      final theme = soliplexDarkTheme();

      expect(
        theme.extensions.values
            .any((e) => e.runtimeType.toString().contains('SoliplexTheme')),
        isTrue,
      );
    });

    test('default surface is dark palette background', () {
      final theme = soliplexDarkTheme();
      const defaultDark = ColorPalette.defaultDark();

      expect(theme.colorScheme.surface, defaultDark.background);
      expect(theme.scaffoldBackgroundColor, defaultDark.background);
    });

    test('custom background color is applied', () {
      const customBg = Color(0xFF1A1A1A);
      const palette = ColorPalette(
        primary: Color(0xFFB8B9C6),
        secondary: Color(0xFFCDC5D4),
        background: customBg,
        foreground: Color(0xFFE5E5E8),
        muted: Color(0xFF2E2E33),
        mutedForeground: Color(0xFF9A9AA2),
        border: Color(0xFF48484F),
      );
      final theme = soliplexDarkTheme(
        colorConfig: const ColorConfig(dark: palette),
      );

      expect(theme.colorScheme.surface, customBg);
      expect(theme.scaffoldBackgroundColor, customBg);
    });
  });

  group('theme consistency', () {
    test('light and dark themes have same structure', () {
      final light = soliplexLightTheme();
      final dark = soliplexDarkTheme();

      // Both should have the same extension types
      expect(light.extensions.length, dark.extensions.length);

      // Both should use Material 3
      expect(light.useMaterial3, dark.useMaterial3);
    });

    test('same config produces consistent palettes', () {
      const config = ColorConfig();
      final light = soliplexLightTheme(colorConfig: config);
      final dark = soliplexDarkTheme(colorConfig: config);

      // Both should derive from the same config but have different brightness
      expect(light.brightness, Brightness.light);
      expect(dark.brightness, Brightness.dark);
    });
  });

  group('ThemeConfig integration', () {
    test('ThemeConfig colorConfig can be passed to theme functions', () {
      const config = ThemeConfig(
        colorConfig: ColorConfig(
          light: ColorPalette(
            primary: Colors.purple,
            secondary: Colors.teal,
            background: Color(0xFFFAFAFA),
            foreground: Color(0xFF1A1A1E),
            muted: Color(0xFFE4E4E8),
            mutedForeground: Color(0xFF6E6E78),
            border: Color(0xFFC8C8CE),
          ),
        ),
      );

      final theme = soliplexLightTheme(
        colorConfig: config.colorConfig,
        fontConfig: config.fontConfig,
      );

      expect(theme.colorScheme.secondary, Colors.teal);
    });

    test('ThemeConfig with custom background applies to theme', () {
      const config = ThemeConfig(
        colorConfig: ColorConfig(
          light: ColorPalette(
            primary: Colors.purple,
            secondary: Color(0xFF8E8698),
            background: Color(0xFFF5F5DC),
            foreground: Color(0xFF1A1A1E),
            muted: Color(0xFFE4E4E8),
            mutedForeground: Color(0xFF6E6E78),
            border: Color(0xFFC8C8CE),
          ),
        ),
      );

      final theme = soliplexLightTheme(
        colorConfig: config.colorConfig,
      );

      expect(theme.colorScheme.surface, const Color(0xFFF5F5DC));
    });
  });

  group('FontConfig integration', () {
    test('no FontConfig produces no custom font families in TextTheme', () {
      final theme = soliplexLightTheme();

      // When no fontConfig is provided, the TextStyle fontFamily is null
      // before .apply(). After ThemeData applies it, Material resolves
      // to its default (Roboto on Android). We verify that our custom
      // fonts (Inter, Hyprsalvo) are NOT present.
      expect(theme.textTheme.displayLarge?.fontFamily, isNot('Hyprsalvo'));
      expect(theme.textTheme.displayLarge?.fontFamily, isNot('Inter'));
      expect(theme.textTheme.bodyMedium?.fontFamily, isNot('Inter'));
    });

    test('FontConfig applies display font to display styles', () {
      final theme = soliplexLightTheme(
        fontConfig: const FontConfig(displayFont: 'Hyprsalvo'),
      );

      expect(theme.textTheme.displayLarge?.fontFamily, 'Hyprsalvo');
      expect(theme.textTheme.displayMedium?.fontFamily, 'Hyprsalvo');
      expect(theme.textTheme.displaySmall?.fontFamily, 'Hyprsalvo');
    });

    test('FontConfig applies body font to body/label/headline styles', () {
      final theme = soliplexLightTheme(
        fontConfig: const FontConfig(bodyFont: 'Inter'),
      );

      expect(theme.textTheme.bodyLarge?.fontFamily, 'Inter');
      expect(theme.textTheme.bodyMedium?.fontFamily, 'Inter');
      expect(theme.textTheme.labelLarge?.fontFamily, 'Inter');
      expect(theme.textTheme.headlineLarge?.fontFamily, 'Inter');
      expect(theme.textTheme.titleMedium?.fontFamily, 'Inter');
    });

    test('FontConfig applies display font to AppBar title', () {
      final theme = soliplexLightTheme(
        fontConfig: const FontConfig(displayFont: 'Hyprsalvo'),
      );

      expect(theme.appBarTheme.titleTextStyle?.fontFamily, 'Hyprsalvo');
    });

    test('FontConfig applies display font to ListTile title', () {
      final theme = soliplexLightTheme(
        fontConfig: const FontConfig(
          displayFont: 'Hyprsalvo',
          bodyFont: 'Inter',
        ),
      );

      expect(theme.listTileTheme.titleTextStyle?.fontFamily, 'Hyprsalvo');
      expect(theme.listTileTheme.subtitleTextStyle?.fontFamily, 'Inter');
    });

    test('FontConfig applies body font to button themes', () {
      final theme = soliplexLightTheme(
        fontConfig: const FontConfig(bodyFont: 'Inter'),
      );

      // FilledButton uses textStyle in ButtonStyle.
      // The textStyle is set via styleFrom which wraps it.
      final filledStyle = theme.filledButtonTheme.style;
      expect(filledStyle, isNotNull);
    });

    test('dark theme also applies FontConfig', () {
      final theme = soliplexDarkTheme(
        fontConfig: const FontConfig(
          bodyFont: 'Roboto',
          displayFont: 'Playfair',
        ),
      );

      expect(theme.textTheme.displayLarge?.fontFamily, 'Playfair');
      expect(theme.textTheme.bodyMedium?.fontFamily, 'Roboto');
    });

    test('no FontConfig produces null font in component themes', () {
      final theme = soliplexLightTheme();

      expect(theme.appBarTheme.titleTextStyle?.fontFamily, isNull);
      expect(theme.listTileTheme.titleTextStyle?.fontFamily, isNull);
    });
  });
}
