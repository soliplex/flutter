import 'package:flutter_test/flutter_test.dart';
import 'package:soliplex_frontend/core/models/font_config.dart';

void main() {
  group('FontConfig', () {
    test('default constructor has all null fields', () {
      const config = FontConfig();

      expect(config.bodyFont, isNull);
      expect(config.displayFont, isNull);
      expect(config.brandFont, isNull);
    });

    test('custom fonts are preserved', () {
      const config = FontConfig(
        bodyFont: 'Inter',
        displayFont: 'Hyprsalvo',
        brandFont: 'Tactical',
      );

      expect(config.bodyFont, 'Inter');
      expect(config.displayFont, 'Hyprsalvo');
      expect(config.brandFont, 'Tactical');
    });

    test('partial fonts leave others null', () {
      const config = FontConfig(bodyFont: 'Roboto');

      expect(config.bodyFont, 'Roboto');
      expect(config.displayFont, isNull);
      expect(config.brandFont, isNull);
    });

    group('copyWith', () {
      test('replaces specified fields', () {
        const original = FontConfig(bodyFont: 'Inter');
        final modified = original.copyWith(displayFont: 'Playfair');

        expect(modified.bodyFont, 'Inter');
        expect(modified.displayFont, 'Playfair');
        expect(modified.brandFont, isNull);
      });

      test('preserves original when no changes', () {
        const original = FontConfig(
          bodyFont: 'Inter',
          displayFont: 'Hyprsalvo',
        );
        final copy = original.copyWith();

        expect(copy, equals(original));
      });

      test('clearBodyFont resets to null', () {
        const original = FontConfig(bodyFont: 'Inter');
        final modified = original.copyWith(clearBodyFont: true);

        expect(modified.bodyFont, isNull);
      });

      test('clearDisplayFont resets to null', () {
        const original = FontConfig(displayFont: 'Hyprsalvo');
        final modified = original.copyWith(clearDisplayFont: true);

        expect(modified.displayFont, isNull);
      });

      test('clearBrandFont resets to null', () {
        const original = FontConfig(brandFont: 'Tactical');
        final modified = original.copyWith(clearBrandFont: true);

        expect(modified.brandFont, isNull);
      });

      test('clear flag takes precedence over new value', () {
        const original = FontConfig(bodyFont: 'Inter');
        final modified = original.copyWith(
          bodyFont: 'Roboto',
          clearBodyFont: true,
        );

        expect(modified.bodyFont, isNull);
      });
    });

    group('equality', () {
      test('equal when all fields match', () {
        const a = FontConfig(bodyFont: 'Inter', displayFont: 'Hyprsalvo');
        const b = FontConfig(bodyFont: 'Inter', displayFont: 'Hyprsalvo');

        expect(a, equals(b));
      });

      test('equal when both default', () {
        const a = FontConfig();
        const b = FontConfig();

        expect(a, equals(b));
      });

      test('not equal when bodyFont differs', () {
        const a = FontConfig(bodyFont: 'Inter');
        const b = FontConfig(bodyFont: 'Roboto');

        expect(a, isNot(equals(b)));
      });

      test('not equal when displayFont differs', () {
        const a = FontConfig(displayFont: 'Hyprsalvo');
        const b = FontConfig();

        expect(a, isNot(equals(b)));
      });

      test('not equal when brandFont differs', () {
        const a = FontConfig(brandFont: 'Tactical');
        const b = FontConfig();

        expect(a, isNot(equals(b)));
      });
    });

    test('hashCode is consistent with equality', () {
      const a = FontConfig(bodyFont: 'Inter', displayFont: 'Hyprsalvo');
      const b = FontConfig(bodyFont: 'Inter', displayFont: 'Hyprsalvo');

      expect(a.hashCode, equals(b.hashCode));
    });

    test('toString returns readable representation', () {
      const config = FontConfig(bodyFont: 'Inter');
      final str = config.toString();

      expect(str, contains('FontConfig'));
      expect(str, contains('bodyFont'));
      expect(str, contains('displayFont'));
      expect(str, contains('brandFont'));
    });
  });
}
