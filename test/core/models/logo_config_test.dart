import 'package:flutter_test/flutter_test.dart';
import 'package:soliplex_frontend/core/models/logo_config.dart';

void main() {
  group('LogoConfig', () {
    test('requires non-empty assetPath', () {
      const config = LogoConfig(assetPath: 'assets/logo.png');

      expect(config.assetPath, equals('assets/logo.png'));
      expect(config.package, isNull);
    });

    test('asserts on empty assetPath', () {
      expect(
        () => LogoConfig(assetPath: ''),
        throwsA(isA<AssertionError>()),
      );
    });

    test('accepts optional package', () {
      const config = LogoConfig(
        assetPath: 'assets/logo.png',
        package: 'my_package',
      );

      expect(config.assetPath, equals('assets/logo.png'));
      expect(config.package, equals('my_package'));
    });

    test('soliplex uses library bundled assets', () {
      const config = LogoConfig.soliplex;

      expect(config.assetPath, equals('assets/branding/logo_1024.png'));
      expect(config.package, equals('soliplex_frontend'));
    });

    test('equality works correctly', () {
      const a = LogoConfig(assetPath: 'assets/logo.png', package: 'pkg');
      const b = LogoConfig(assetPath: 'assets/logo.png', package: 'pkg');
      const c = LogoConfig(assetPath: 'assets/other.png', package: 'pkg');
      const d = LogoConfig(assetPath: 'assets/logo.png', package: 'other');
      const e = LogoConfig(assetPath: 'assets/logo.png');

      expect(a, equals(b));
      expect(a, isNot(equals(c)));
      expect(a, isNot(equals(d)));
      expect(a, isNot(equals(e)));
    });

    test('hashCode is consistent with equality', () {
      const a = LogoConfig(assetPath: 'assets/logo.png', package: 'pkg');
      const b = LogoConfig(assetPath: 'assets/logo.png', package: 'pkg');
      const c = LogoConfig(assetPath: 'assets/other.png', package: 'pkg');

      expect(a.hashCode, equals(b.hashCode));
      expect(a.hashCode, isNot(equals(c.hashCode)));
    });

    test('toString returns readable representation', () {
      const config = LogoConfig(assetPath: 'assets/logo.png', package: 'pkg');

      expect(config.toString(), contains('LogoConfig'));
      expect(config.toString(), contains('assetPath: assets/logo.png'));
      expect(config.toString(), contains('package: pkg'));
    });

    test('toString handles null package', () {
      const config = LogoConfig(assetPath: 'assets/logo.png');

      expect(config.toString(), contains('package: null'));
    });
  });
}
