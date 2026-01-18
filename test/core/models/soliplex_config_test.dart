import 'package:flutter_test/flutter_test.dart';
import 'package:soliplex_frontend/core/models/features.dart';
import 'package:soliplex_frontend/core/models/route_config.dart';
import 'package:soliplex_frontend/core/models/soliplex_config.dart';
import 'package:soliplex_frontend/core/models/theme_config.dart';

void main() {
  group('SoliplexConfig', () {
    test('default constructor has Soliplex defaults', () {
      const config = SoliplexConfig();

      expect(config.appName, equals('Soliplex'));
      expect(config.defaultBackendUrl, equals('https://api.soliplex.ai'));
      expect(config.features, equals(const Features()));
      expect(config.theme, equals(const ThemeConfig()));
      expect(config.routes, equals(const RouteConfig()));
    });

    test('custom values are preserved', () {
      const config = SoliplexConfig(
        appName: 'MyBrand',
        defaultBackendUrl: 'https://api.mybrand.com',
        features: Features(enableHttpInspector: false),
        routes: RouteConfig(initialRoute: '/rooms'),
      );

      expect(config.appName, equals('MyBrand'));
      expect(config.defaultBackendUrl, equals('https://api.mybrand.com'));
      expect(config.features.enableHttpInspector, isFalse);
      expect(config.routes.initialRoute, equals('/rooms'));
    });

    test('copyWith creates copy with replaced values', () {
      const original = SoliplexConfig();
      final modified = original.copyWith(
        appName: 'NewName',
        features: const Features(enableQuizzes: false),
      );

      expect(modified.appName, equals('NewName'));
      expect(modified.features.enableQuizzes, isFalse);
      expect(modified.defaultBackendUrl, equals('https://api.soliplex.ai'));
      expect(modified.theme, equals(const ThemeConfig()));
    });

    test('copyWith preserves original when no changes', () {
      const original = SoliplexConfig();
      final copy = original.copyWith();

      expect(copy, equals(original));
    });

    test('equality works correctly', () {
      const a = SoliplexConfig();
      const b = SoliplexConfig();
      const c = SoliplexConfig(appName: 'Different');

      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });

    test('hashCode is consistent with equality', () {
      const a = SoliplexConfig();
      const b = SoliplexConfig();
      const c = SoliplexConfig(appName: 'Different');

      expect(a.hashCode, equals(b.hashCode));
      expect(a.hashCode, isNot(equals(c.hashCode)));
    });

    test('toString returns readable representation', () {
      const config = SoliplexConfig(appName: 'TestApp');

      expect(config.toString(), contains('SoliplexConfig'));
      expect(config.toString(), contains('appName: TestApp'));
      expect(config.toString(), contains('defaultBackendUrl'));
    });
  });
}
