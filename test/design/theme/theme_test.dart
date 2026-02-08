import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soliplex_frontend/design/theme/theme.dart';
import 'package:soliplex_frontend/design/tokens/colors.dart';

void main() {
  group('soliplexLightTheme', () {
    test('uses default light colors when no colors provided', () {
      final theme = soliplexLightTheme();

      expect(theme.brightness, Brightness.light);
      expect(theme.colorScheme.primary, lightSoliplexColors.primary);
      expect(theme.colorScheme.onPrimary, lightSoliplexColors.onPrimary);
      expect(theme.scaffoldBackgroundColor, lightSoliplexColors.background);
    });

    test('uses custom colors when provided', () {
      const customColors = SoliplexColors(
        background: Colors.white,
        foreground: Colors.black,
        primary: Colors.blue,
        onPrimary: Colors.white,
        secondary: Colors.grey,
        onSecondary: Colors.black,
        accent: Colors.orange,
        onAccent: Colors.white,
        muted: Colors.grey,
        mutedForeground: Colors.grey,
        destructive: Colors.red,
        onDestructive: Colors.white,
        border: Colors.grey,
        inputBackground: Colors.grey,
        hintText: Colors.grey,
      );

      final theme = soliplexLightTheme(colors: customColors);

      expect(theme.brightness, Brightness.light);
      expect(theme.colorScheme.primary, Colors.blue);
      expect(theme.colorScheme.onPrimary, Colors.white);
      expect(theme.scaffoldBackgroundColor, Colors.white);
    });

    test('has Material 3 enabled', () {
      final theme = soliplexLightTheme();

      expect(theme.useMaterial3, isTrue);
    });

    test('includes SoliplexTheme extension', () {
      final theme = soliplexLightTheme();

      expect(
        theme.extensions.values.any(
          (e) => e.runtimeType.toString().contains('SoliplexTheme'),
        ),
        isTrue,
      );
    });
  });

  group('soliplexDarkTheme', () {
    test('uses default dark colors when no colors provided', () {
      final theme = soliplexDarkTheme();

      expect(theme.brightness, Brightness.dark);
      expect(theme.colorScheme.primary, darkSoliplexColors.primary);
      expect(theme.colorScheme.onPrimary, darkSoliplexColors.onPrimary);
      expect(theme.scaffoldBackgroundColor, darkSoliplexColors.background);
    });

    test('uses custom colors when provided', () {
      const customColors = SoliplexColors(
        background: Color(0xFF1A1A1A),
        foreground: Colors.white,
        primary: Colors.purple,
        onPrimary: Colors.white,
        secondary: Colors.grey,
        onSecondary: Colors.white,
        accent: Colors.orange,
        onAccent: Colors.white,
        muted: Colors.grey,
        mutedForeground: Colors.grey,
        destructive: Colors.red,
        onDestructive: Colors.white,
        border: Colors.grey,
        inputBackground: Colors.grey,
        hintText: Colors.grey,
      );

      final theme = soliplexDarkTheme(colors: customColors);

      expect(theme.brightness, Brightness.dark);
      expect(theme.colorScheme.primary, Colors.purple);
      expect(theme.colorScheme.onPrimary, Colors.white);
      expect(theme.scaffoldBackgroundColor, const Color(0xFF1A1A1A));
    });

    test('has Material 3 enabled', () {
      final theme = soliplexDarkTheme();

      expect(theme.useMaterial3, isTrue);
    });

    test('includes SoliplexTheme extension', () {
      final theme = soliplexDarkTheme();

      expect(
        theme.extensions.values.any(
          (e) => e.runtimeType.toString().contains('SoliplexTheme'),
        ),
        isTrue,
      );
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
  });
}
