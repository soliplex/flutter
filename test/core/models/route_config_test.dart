import 'package:flutter_test/flutter_test.dart';
import 'package:soliplex_frontend/core/models/route_config.dart';

void main() {
  group('RouteConfig', () {
    test('default constructor shows all routes and sets defaults', () {
      const config = RouteConfig();

      expect(config.showHomeRoute, isTrue);
      expect(config.showRoomsRoute, isTrue);
      expect(config.initialRoute, equals('/'));
      expect(config.authenticatedLandingRoute, equals('/rooms'));
    });

    test('custom initial route is preserved', () {
      const config = RouteConfig(initialRoute: '/rooms');

      expect(config.initialRoute, equals('/rooms'));
    });

    test('custom authenticatedLandingRoute is preserved', () {
      const config = RouteConfig(authenticatedLandingRoute: '/settings');

      expect(config.authenticatedLandingRoute, equals('/settings'));
    });

    test('copyWith creates copy with replaced values', () {
      const original = RouteConfig();
      final modified = original.copyWith(
        showHomeRoute: false,
        initialRoute: '/rooms',
        authenticatedLandingRoute: '/settings',
      );

      expect(modified.showHomeRoute, isFalse);
      expect(modified.showRoomsRoute, isTrue);
      expect(modified.initialRoute, equals('/rooms'));
      expect(modified.authenticatedLandingRoute, equals('/settings'));
    });

    test('copyWith preserves original when no changes', () {
      const original = RouteConfig();
      final copy = original.copyWith();

      expect(copy, equals(original));
    });

    test('equality works correctly', () {
      const a = RouteConfig();
      const b = RouteConfig();
      const c = RouteConfig(showHomeRoute: false, initialRoute: '/rooms');
      const d = RouteConfig(authenticatedLandingRoute: '/settings');

      expect(a, equals(b));
      expect(a, isNot(equals(c)));
      expect(a, isNot(equals(d)));
    });

    test('hashCode is consistent with equality', () {
      const a = RouteConfig();
      const b = RouteConfig();
      const c = RouteConfig(showHomeRoute: false, initialRoute: '/rooms');
      const d = RouteConfig(authenticatedLandingRoute: '/settings');

      expect(a.hashCode, equals(b.hashCode));
      expect(a.hashCode, isNot(equals(c.hashCode)));
      expect(a.hashCode, isNot(equals(d.hashCode)));
    });

    test('toString returns readable representation', () {
      const config = RouteConfig(
        showHomeRoute: false,
        initialRoute: '/rooms',
        authenticatedLandingRoute: '/settings',
      );

      expect(config.toString(), contains('showHomeRoute: false'));
      expect(config.toString(), contains('initialRoute: /rooms'));
      expect(config.toString(), contains('authenticatedLandingRoute: /settings'));
    });

    group('initialRoute validation', () {
      test('allows / when showHomeRoute is true', () {
        expect(
          () => const RouteConfig(),
          returnsNormally,
        );
      });

      test('allows /rooms when showRoomsRoute is true', () {
        expect(
          () => const RouteConfig(initialRoute: '/rooms'),
          returnsNormally,
        );
      });

      test('asserts when both main routes disabled', () {
        expect(
          () => RouteConfig(showHomeRoute: false, showRoomsRoute: false),
          throwsA(isA<AssertionError>()),
        );
      });

      test('allows only home route', () {
        expect(
          () => const RouteConfig(showRoomsRoute: false),
          returnsNormally,
        );
      });

      test('allows only rooms route', () {
        expect(
          () => const RouteConfig(showHomeRoute: false),
          returnsNormally,
        );
      });

      test('allows room-specific routes', () {
        expect(
          () => const RouteConfig(
            showRoomsRoute: false,
            initialRoute: '/rooms/123',
          ),
          returnsNormally,
        );
      });
    });
  });
}
