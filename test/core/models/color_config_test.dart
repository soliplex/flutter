import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soliplex_frontend/core/models/color_config.dart';

void main() {
  group('ColorPalette', () {
    test('requires all 7 required fields', () {
      const palette = ColorPalette(
        primary: Colors.blue,
        secondary: Colors.orange,
        background: Colors.white,
        foreground: Colors.black,
        muted: Color(0xFFE0E0E0),
        mutedForeground: Color(0xFF757575),
        border: Color(0xFFBDBDBD),
      );

      expect(palette.primary, Colors.blue);
      expect(palette.secondary, Colors.orange);
      expect(palette.background, Colors.white);
      expect(palette.foreground, Colors.black);
      expect(palette.muted, const Color(0xFFE0E0E0));
      expect(palette.mutedForeground, const Color(0xFF757575));
      expect(palette.border, const Color(0xFFBDBDBD));
    });

    test('optional fields default to null', () {
      const palette = ColorPalette(
        primary: Colors.blue,
        secondary: Colors.orange,
        background: Colors.white,
        foreground: Colors.black,
        muted: Color(0xFFE0E0E0),
        mutedForeground: Color(0xFF757575),
        border: Color(0xFFBDBDBD),
      );

      expect(palette.tertiary, isNull);
      expect(palette.error, isNull);
      expect(palette.onPrimary, isNull);
      expect(palette.onSecondary, isNull);
      expect(palette.onTertiary, isNull);
      expect(palette.onError, isNull);
    });

    test('preserves all optional fields when provided', () {
      const palette = ColorPalette(
        primary: Colors.blue,
        secondary: Colors.orange,
        background: Colors.white,
        foreground: Colors.black,
        muted: Color(0xFFE0E0E0),
        mutedForeground: Color(0xFF757575),
        border: Color(0xFFBDBDBD),
        tertiary: Colors.purple,
        error: Colors.red,
        onPrimary: Colors.white,
        onSecondary: Colors.black,
        onTertiary: Colors.white,
        onError: Colors.white,
      );

      expect(palette.tertiary, Colors.purple);
      expect(palette.error, Colors.red);
      expect(palette.onPrimary, Colors.white);
      expect(palette.onSecondary, Colors.black);
      expect(palette.onTertiary, Colors.white);
      expect(palette.onError, Colors.white);
    });

    group('effective getters', () {
      test('effectiveOnPrimary returns onPrimary when set', () {
        const palette = ColorPalette(
          primary: Colors.blue,
          secondary: Colors.orange,
          background: Colors.white,
          foreground: Colors.black,
          muted: Color(0xFFE0E0E0),
          mutedForeground: Color(0xFF757575),
          border: Color(0xFFBDBDBD),
          onPrimary: Colors.yellow,
        );

        expect(palette.effectiveOnPrimary, Colors.yellow);
      });

      test('effectiveOnPrimary computes contrast when null', () {
        const palette = ColorPalette(
          primary: Color(0xFF1A237E), // Dark indigo
          secondary: Colors.orange,
          background: Colors.white,
          foreground: Colors.black,
          muted: Color(0xFFE0E0E0),
          mutedForeground: Color(0xFF757575),
          border: Color(0xFFBDBDBD),
        );

        // Dark primary → white on-color
        expect(palette.effectiveOnPrimary, Colors.white);
      });

      test('effectiveOnPrimary returns black for light primary', () {
        const palette = ColorPalette(
          primary: Color(0xFFE8F5E9), // Light green
          secondary: Colors.orange,
          background: Colors.white,
          foreground: Colors.black,
          muted: Color(0xFFE0E0E0),
          mutedForeground: Color(0xFF757575),
          border: Color(0xFFBDBDBD),
        );

        expect(palette.effectiveOnPrimary, Colors.black);
      });

      test('effectiveTertiary falls back to default grey', () {
        const palette = ColorPalette(
          primary: Colors.blue,
          secondary: Colors.orange,
          background: Colors.white,
          foreground: Colors.black,
          muted: Color(0xFFE0E0E0),
          mutedForeground: Color(0xFF757575),
          border: Color(0xFFBDBDBD),
        );

        expect(palette.effectiveTertiary, const Color(0xFF7B7486));
      });

      test('effectiveError falls back to Material red', () {
        const palette = ColorPalette(
          primary: Colors.blue,
          secondary: Colors.orange,
          background: Colors.white,
          foreground: Colors.black,
          muted: Color(0xFFE0E0E0),
          mutedForeground: Color(0xFF757575),
          border: Color(0xFFBDBDBD),
        );

        expect(palette.effectiveError, const Color(0xFFBA1A1A));
      });

      test('effectiveOnError uses provided value when set', () {
        const palette = ColorPalette(
          primary: Colors.blue,
          secondary: Colors.orange,
          background: Colors.white,
          foreground: Colors.black,
          muted: Color(0xFFE0E0E0),
          mutedForeground: Color(0xFF757575),
          border: Color(0xFFBDBDBD),
          onError: Color(0xFF690005),
        );

        expect(palette.effectiveOnError, const Color(0xFF690005));
      });
    });

    group('defaultLight', () {
      test('has all fields populated', () {
        const palette = ColorPalette.defaultLight();

        expect(palette.primary, const Color(0xFF6B6D7B));
        expect(palette.secondary, const Color(0xFF8E8698));
        expect(palette.background, const Color(0xFFFAFAFA));
        expect(palette.foreground, const Color(0xFF1A1A1E));
        expect(palette.muted, const Color(0xFFE4E4E8));
        expect(palette.mutedForeground, const Color(0xFF6E6E78));
        expect(palette.border, const Color(0xFFC8C8CE));
        expect(palette.tertiary, const Color(0xFF7B7486));
        expect(palette.error, const Color(0xFFBA1A1A));
        expect(palette.onPrimary, const Color(0xFFFFFFFF));
        expect(palette.onSecondary, const Color(0xFFFFFFFF));
        expect(palette.onTertiary, const Color(0xFFFFFFFF));
        expect(palette.onError, const Color(0xFFFFFFFF));
      });
    });

    group('defaultDark', () {
      test('has all fields populated', () {
        const palette = ColorPalette.defaultDark();

        expect(palette.primary, const Color(0xFFB8B9C6));
        expect(palette.secondary, const Color(0xFFCDC5D4));
        expect(palette.background, const Color(0xFF1A1A1D));
        expect(palette.foreground, const Color(0xFFE5E5E8));
        expect(palette.muted, const Color(0xFF2E2E33));
        expect(palette.mutedForeground, const Color(0xFF9A9AA2));
        expect(palette.border, const Color(0xFF48484F));
        expect(palette.tertiary, const Color(0xFFB0A8BA));
        expect(palette.error, const Color(0xFFFFB4AB));
        expect(palette.onPrimary, const Color(0xFF1A1A1E));
        expect(palette.onSecondary, const Color(0xFF1A1A1E));
        expect(palette.onTertiary, const Color(0xFF1A1A1E));
        expect(palette.onError, const Color(0xFF690005));
      });
    });

    group('copyWith', () {
      test('replaces specified fields', () {
        const palette = ColorPalette.defaultLight();
        final modified = palette.copyWith(
          primary: Colors.red,
          error: Colors.pink,
        );

        expect(modified.primary, Colors.red);
        expect(modified.error, Colors.pink);
        // Unchanged fields preserved
        expect(modified.secondary, palette.secondary);
        expect(modified.background, palette.background);
      });

      test('can clear optional fields', () {
        const palette = ColorPalette.defaultLight();
        final cleared = palette.copyWith(
          clearTertiary: true,
          clearError: true,
          clearOnPrimary: true,
          clearOnSecondary: true,
          clearOnTertiary: true,
          clearOnError: true,
        );

        expect(cleared.tertiary, isNull);
        expect(cleared.error, isNull);
        expect(cleared.onPrimary, isNull);
        expect(cleared.onSecondary, isNull);
        expect(cleared.onTertiary, isNull);
        expect(cleared.onError, isNull);
      });

      test('preserves original when no changes', () {
        const palette = ColorPalette.defaultLight();
        final copy = palette.copyWith();

        expect(copy, equals(palette));
      });
    });

    group('equality', () {
      test('equal palettes are equal', () {
        const a = ColorPalette.defaultLight();
        const b = ColorPalette.defaultLight();

        expect(a, equals(b));
      });

      test('different palettes are not equal', () {
        const a = ColorPalette.defaultLight();
        const b = ColorPalette.defaultDark();

        expect(a, isNot(equals(b)));
      });

      test('hashCode is consistent with equality', () {
        const a = ColorPalette.defaultLight();
        const b = ColorPalette.defaultLight();

        expect(a.hashCode, equals(b.hashCode));
      });

      test('hashCode differs when fields differ', () {
        const a = ColorPalette.defaultLight();
        const b = ColorPalette.defaultDark();

        expect(a.hashCode, isNot(equals(b.hashCode)));
      });
    });

    test('toString contains class name and required fields', () {
      const palette = ColorPalette.defaultLight();

      expect(palette.toString(), contains('ColorPalette'));
      expect(palette.toString(), contains('primary'));
      expect(palette.toString(), contains('secondary'));
      expect(palette.toString(), contains('background'));
    });
  });

  group('ColorConfig', () {
    test('default constructor uses default palettes', () {
      const config = ColorConfig();

      expect(config.light, equals(const ColorPalette.defaultLight()));
      expect(config.dark, equals(const ColorPalette.defaultDark()));
    });

    test('custom palettes are preserved', () {
      const customLight = ColorPalette(
        primary: Colors.blue,
        secondary: Colors.orange,
        background: Colors.white,
        foreground: Colors.black,
        muted: Color(0xFFE0E0E0),
        mutedForeground: Color(0xFF757575),
        border: Color(0xFFBDBDBD),
      );
      const config = ColorConfig(light: customLight);

      expect(config.light, equals(customLight));
      expect(config.dark, equals(const ColorPalette.defaultDark()));
    });

    test('copyWith replaces specified palettes', () {
      const config = ColorConfig();
      const customDark = ColorPalette(
        primary: Colors.teal,
        secondary: Colors.cyan,
        background: Color(0xFF121212),
        foreground: Colors.white,
        muted: Color(0xFF333333),
        mutedForeground: Color(0xFF999999),
        border: Color(0xFF555555),
      );

      final modified = config.copyWith(dark: customDark);

      expect(modified.dark, equals(customDark));
      expect(modified.light, equals(config.light));
    });

    test('copyWith preserves original when no changes', () {
      const config = ColorConfig();
      final copy = config.copyWith();

      expect(copy, equals(config));
    });

    test('equality works correctly', () {
      const a = ColorConfig();
      const b = ColorConfig();

      expect(a, equals(b));
    });

    test('inequality when light palette differs', () {
      const customLight = ColorPalette(
        primary: Colors.red,
        secondary: Colors.orange,
        background: Colors.white,
        foreground: Colors.black,
        muted: Color(0xFFE0E0E0),
        mutedForeground: Color(0xFF757575),
        border: Color(0xFFBDBDBD),
      );
      const a = ColorConfig(light: customLight);
      const b = ColorConfig();

      expect(a, isNot(equals(b)));
    });

    test('hashCode is consistent with equality', () {
      const a = ColorConfig();
      const b = ColorConfig();

      expect(a.hashCode, equals(b.hashCode));
    });

    test('toString returns readable representation', () {
      const config = ColorConfig();

      expect(config.toString(), contains('ColorConfig'));
      expect(config.toString(), contains('light'));
      expect(config.toString(), contains('dark'));
    });
  });
}
