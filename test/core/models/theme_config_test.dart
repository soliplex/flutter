import 'package:flutter_test/flutter_test.dart';
import 'package:soliplex_frontend/core/models/color_config.dart';
import 'package:soliplex_frontend/core/models/font_config.dart';
import 'package:soliplex_frontend/core/models/theme_config.dart';

void main() {
  group('ThemeConfig', () {
    test('default constructor has null colorConfig and fontConfig', () {
      const config = ThemeConfig();

      expect(config.colorConfig, isNull);
      expect(config.fontConfig, isNull);
    });

    test('colorConfig is preserved', () {
      const config = ThemeConfig(
        colorConfig: ColorConfig(),
      );

      expect(config.colorConfig, isNotNull);
      expect(
        config.colorConfig!.light,
        equals(const ColorPalette.defaultLight()),
      );
    });

    test('fontConfig is preserved', () {
      const config = ThemeConfig(
        fontConfig: FontConfig(bodyFont: 'Inter'),
      );

      expect(config.fontConfig, isNotNull);
      expect(config.fontConfig!.bodyFont, 'Inter');
    });

    test('copyWith replaces colorConfig', () {
      const original = ThemeConfig();
      final modified = original.copyWith(
        colorConfig: const ColorConfig(),
      );

      expect(modified.colorConfig, isNotNull);
      expect(
        modified.colorConfig!.light,
        equals(const ColorPalette.defaultLight()),
      );
    });

    test('copyWith replaces fontConfig', () {
      const original = ThemeConfig();
      final modified = original.copyWith(
        fontConfig: const FontConfig(bodyFont: 'Roboto'),
      );

      expect(modified.fontConfig?.bodyFont, 'Roboto');
    });

    test('copyWith clearColorConfig resets to null', () {
      const original = ThemeConfig(
        colorConfig: ColorConfig(),
      );
      final modified = original.copyWith(clearColorConfig: true);

      expect(modified.colorConfig, isNull);
    });

    test('copyWith clearFontConfig resets to null', () {
      const original = ThemeConfig(
        fontConfig: FontConfig(bodyFont: 'Inter'),
      );
      final modified = original.copyWith(clearFontConfig: true);

      expect(modified.fontConfig, isNull);
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

    test('inequality when colorConfig differs', () {
      const a = ThemeConfig(
        colorConfig: ColorConfig(),
      );
      const b = ThemeConfig();

      expect(a, isNot(equals(b)));
    });

    test('inequality when fontConfig differs', () {
      const a = ThemeConfig(fontConfig: FontConfig(bodyFont: 'Inter'));
      const b = ThemeConfig();

      expect(a, isNot(equals(b)));
    });

    test('hashCode is consistent with equality', () {
      const a = ThemeConfig();
      const b = ThemeConfig();

      expect(a.hashCode, equals(b.hashCode));
    });

    test('hashCode differs when colorConfig differs', () {
      const a = ThemeConfig(
        colorConfig: ColorConfig(),
      );
      const b = ThemeConfig();

      expect(a.hashCode, isNot(equals(b.hashCode)));
    });

    test('hashCode differs when fontConfig differs', () {
      const a = ThemeConfig(fontConfig: FontConfig(bodyFont: 'Inter'));
      const b = ThemeConfig();

      expect(a.hashCode, isNot(equals(b.hashCode)));
    });

    test('toString returns readable representation', () {
      const config = ThemeConfig();

      expect(config.toString(), contains('ThemeConfig'));
      expect(config.toString(), contains('colorConfig'));
      expect(config.toString(), contains('fontConfig'));
    });
  });
}
