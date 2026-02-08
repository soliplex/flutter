import 'package:flutter_test/flutter_test.dart';
import 'package:soliplex_frontend/core/logging/device_alias.dart';

void main() {
  group('generateDeviceAlias', () {
    test('produces three-word hyphenated alias', () {
      final alias = generateDeviceAlias('033a3429-bbf4-4ba7-93ee-815a871c535a');
      final parts = alias.split('-');
      expect(parts.length, 3);
      expect(parts.every((p) => p.isNotEmpty), isTrue);
    });

    test('is deterministic for the same input', () {
      const id = 'a1b2c3d4-e5f6-7890-abcd-ef0123456789';
      final first = generateDeviceAlias(id);
      final second = generateDeviceAlias(id);
      expect(first, second);
    });

    test('produces different aliases for different IDs', () {
      final a = generateDeviceAlias('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa');
      final b = generateDeviceAlias('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb');
      expect(a, isNot(b));
    });

    test('contains only lowercase letters and hyphens', () {
      final alias = generateDeviceAlias('12345678-1234-1234-1234-123456789012');
      expect(alias, matches(RegExp(r'^[a-z]+-[a-z]+-[a-z]+$')));
    });

    test('handles edge-case UUID with all zeros', () {
      final alias = generateDeviceAlias('00000000-0000-0000-0000-000000000000');
      expect(alias.split('-').length, 3);
    });

    test('handles UUID without hyphens', () {
      // Same UUID, no hyphens — should produce same alias as with hyphens.
      final withHyphens =
          generateDeviceAlias('033a3429-bbf4-4ba7-93ee-815a871c535a');
      final without = generateDeviceAlias('033a3429bbf44ba793ee815a871c535a');
      expect(withHyphens, without);
    });
  });
}
