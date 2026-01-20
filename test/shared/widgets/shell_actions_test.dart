import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:soliplex_frontend/shared/widgets/shell_actions.dart';

import '../../helpers/test_helpers.dart';

void main() {
  group('SettingsButton', () {
    testWidgets('navigates to /settings when tapped', (tester) async {
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (_, __) => const Scaffold(body: SettingsButton()),
          ),
          GoRoute(
            path: '/settings',
            builder: (_, __) => const Text('Settings Page'),
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp.router(routerConfig: router, theme: testThemeData),
      );
      await tester.tap(find.byIcon(Icons.settings));
      await tester.pumpAndSettle();

      expect(find.text('Settings Page'), findsOneWidget);
    });
  });

  group('standardActions', () {
    test('includes SettingsButton for /rooms path', () {
      final actions = standardActions('/rooms');

      expect(actions, hasLength(1));
      expect(actions.first, isA<SettingsButton>());
    });

    test('includes SettingsButton for /rooms/:roomId path', () {
      final actions = standardActions('/rooms/abc-123');

      expect(actions, hasLength(1));
      expect(actions.first, isA<SettingsButton>());
    });

    test('includes SettingsButton for root path', () {
      final actions = standardActions('/');

      expect(actions, hasLength(1));
      expect(actions.first, isA<SettingsButton>());
    });

    test('excludes SettingsButton for /settings path', () {
      final actions = standardActions('/settings');

      expect(actions, isEmpty);
    });

    test('excludes SettingsButton for /settings/backend-versions path', () {
      final actions = standardActions('/settings/backend-versions');

      expect(actions, isEmpty);
    });
  });
}
