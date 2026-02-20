import 'package:flutter_test/flutter_test.dart';
import 'package:soliplex_frontend/core/models/consent_notice.dart';
import 'package:soliplex_frontend/core/models/features.dart';
import 'package:soliplex_frontend/core/models/logo_config.dart';
import 'package:soliplex_frontend/core/models/route_config.dart';
import 'package:soliplex_frontend/core/models/soliplex_config.dart';
import 'package:soliplex_frontend/core/models/theme_config.dart';

void main() {
  group('SoliplexConfig', () {
    test('constructor requires logo and has other defaults', () {
      const config = SoliplexConfig(logo: LogoConfig.soliplex);

      expect(config.logo, equals(LogoConfig.soliplex));
      expect(config.appName, equals('Soliplex'));
      expect(config.defaultBackendUrl, 'http://localhost:8000');
      expect(config.features, equals(const Features()));
      expect(config.theme, equals(const ThemeConfig()));
      expect(config.routes, equals(const RouteConfig()));
      expect(config.consentNotice, isNull);
    });

    test('custom values are preserved', () {
      const customLogo = LogoConfig(assetPath: 'assets/custom.png');
      const config = SoliplexConfig(
        logo: customLogo,
        appName: 'MyBrand',
        defaultBackendUrl: 'https://api.mybrand.com',
        features: Features(enableHttpInspector: false),
        routes: RouteConfig(initialRoute: '/rooms'),
      );

      expect(config.appName, equals('MyBrand'));
      expect(config.defaultBackendUrl, equals('https://api.mybrand.com'));
      expect(config.logo, equals(customLogo));
      expect(config.features.enableHttpInspector, isFalse);
      expect(config.routes.initialRoute, equals('/rooms'));
    });

    test('copyWith creates copy with replaced values', () {
      const original = SoliplexConfig(logo: LogoConfig.soliplex);
      const newLogo = LogoConfig(assetPath: 'assets/new.png');
      final modified = original.copyWith(
        appName: 'NewName',
        logo: newLogo,
        features: const Features(enableQuizzes: false),
      );

      expect(modified.appName, equals('NewName'));
      expect(modified.logo, equals(newLogo));
      expect(modified.features.enableQuizzes, isFalse);
      expect(modified.defaultBackendUrl, 'http://localhost:8000');
      expect(modified.theme, equals(const ThemeConfig()));
    });

    test('copyWith preserves original when no changes', () {
      const original = SoliplexConfig(logo: LogoConfig.soliplex);
      final copy = original.copyWith();

      expect(copy, equals(original));
    });

    test('equality works correctly', () {
      const a = SoliplexConfig(logo: LogoConfig.soliplex);
      const b = SoliplexConfig(logo: LogoConfig.soliplex);
      const c = SoliplexConfig(logo: LogoConfig.soliplex, appName: 'Different');

      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });

    test('hashCode is consistent with equality', () {
      const a = SoliplexConfig(logo: LogoConfig.soliplex);
      const b = SoliplexConfig(logo: LogoConfig.soliplex);
      const c = SoliplexConfig(logo: LogoConfig.soliplex, appName: 'Different');

      expect(a.hashCode, equals(b.hashCode));
      expect(a.hashCode, isNot(equals(c.hashCode)));
    });

    test('toString returns readable representation', () {
      const config = SoliplexConfig(
        logo: LogoConfig.soliplex,
        appName: 'TestApp',
      );

      expect(config.toString(), contains('SoliplexConfig'));
      expect(config.toString(), contains('appName: TestApp'));
      expect(config.toString(), contains('defaultBackendUrl'));
      expect(config.toString(), contains('logo'));
    });

    group('consentNotice', () {
      test('custom consentNotice is preserved', () {
        const notice = ConsentNotice(title: 'Notice', body: 'Body');
        const config = SoliplexConfig(
          logo: LogoConfig.soliplex,
          consentNotice: notice,
        );

        expect(config.consentNotice, equals(notice));
      });

      test('copyWith with consentNotice', () {
        const original = SoliplexConfig(logo: LogoConfig.soliplex);
        const notice = ConsentNotice(title: 'Notice', body: 'Body');
        final modified = original.copyWith(consentNotice: notice);

        expect(modified.consentNotice, equals(notice));
        expect(modified.appName, equals(original.appName));
      });

      test('equality includes consentNotice', () {
        const notice = ConsentNotice(title: 'Notice', body: 'Body');
        const a = SoliplexConfig(
          logo: LogoConfig.soliplex,
          consentNotice: notice,
        );
        const b = SoliplexConfig(
          logo: LogoConfig.soliplex,
          consentNotice: notice,
        );
        const c = SoliplexConfig(logo: LogoConfig.soliplex);

        expect(a, equals(b));
        expect(a, isNot(equals(c)));
      });
    });
  });
}
