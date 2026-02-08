import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soliplex_frontend/core/models/theme_config.dart';
import 'package:soliplex_frontend/design/tokens/colors.dart';

void main() {
  group('ThemeConfig', () {
    test('default constructor uses Soliplex colors', () {
      const config = ThemeConfig();

      expect(config.lightColors, equals(lightSoliplexColors));
      expect(config.darkColors, equals(darkSoliplexColors));
    });

    test('custom colors are preserved', () {
      const customLight = SoliplexColors(
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

      const config = ThemeConfig(lightColors: customLight);

      expect(config.lightColors, equals(customLight));
      expect(config.darkColors, equals(darkSoliplexColors));
    });

    test('copyWith creates copy with replaced values', () {
      const original = ThemeConfig();

      const customDark = SoliplexColors(
        background: Colors.black,
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

      final modified = original.copyWith(darkColors: customDark);

      expect(modified.lightColors, equals(lightSoliplexColors));
      expect(modified.darkColors, equals(customDark));
    });

    test('copyWith preserves original when no changes', () {
      const original = ThemeConfig();
      final copy = original.copyWith();

      expect(copy, equals(original));
    });

    test('equality works correctly', () {
      const a = ThemeConfig();
      const b = ThemeConfig();

      expect(a, equals(b));
    });

    test('hashCode is consistent with equality', () {
      const a = ThemeConfig();
      const b = ThemeConfig();

      expect(a.hashCode, equals(b.hashCode));
    });

    test('toString returns readable representation', () {
      const config = ThemeConfig();

      expect(config.toString(), contains('ThemeConfig'));
      expect(config.toString(), contains('lightColors'));
      expect(config.toString(), contains('darkColors'));
    });
  });
}
