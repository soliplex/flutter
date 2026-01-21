import 'package:flutter_test/flutter_test.dart';
import 'package:soliplex_frontend/core/models/features.dart';

void main() {
  group('Features', () {
    test('default constructor enables all features', () {
      const features = Features();

      expect(features.enableHttpInspector, isTrue);
      expect(features.enableQuizzes, isTrue);
      expect(features.enableSettings, isTrue);
      expect(features.showVersionInfo, isTrue);
    });

    test('minimal constructor disables all features', () {
      const features = Features.minimal();

      expect(features.enableHttpInspector, isFalse);
      expect(features.enableQuizzes, isFalse);
      expect(features.enableSettings, isFalse);
      expect(features.showVersionInfo, isFalse);
    });

    test('copyWith creates copy with replaced values', () {
      const original = Features();
      final modified = original.copyWith(enableHttpInspector: false);

      expect(modified.enableHttpInspector, isFalse);
      expect(modified.enableQuizzes, isTrue);
      expect(modified.enableSettings, isTrue);
      expect(modified.showVersionInfo, isTrue);
    });

    test('copyWith preserves original when no changes', () {
      const original = Features();
      final copy = original.copyWith();

      expect(copy, equals(original));
    });

    test('equality works correctly', () {
      const a = Features();
      const b = Features();
      const c = Features(enableHttpInspector: false);

      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });

    test('hashCode is consistent with equality', () {
      const a = Features();
      const b = Features();
      const c = Features(enableHttpInspector: false);

      expect(a.hashCode, equals(b.hashCode));
      expect(a.hashCode, isNot(equals(c.hashCode)));
    });

    test('toString returns readable representation', () {
      const features = Features(enableHttpInspector: false);

      expect(features.toString(), contains('enableHttpInspector: false'));
      expect(features.toString(), contains('enableQuizzes: true'));
    });
  });
}
