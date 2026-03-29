import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:soliplex_frontend/features/auth/signed_out_screen.dart';

import '../../helpers/test_helpers.dart';

Widget _createApp() {
  final router = GoRouter(
    initialLocation: '/signedout',
    routes: [
      GoRoute(
        path: '/signedout',
        builder: (_, __) => const SignedOutScreen(),
      ),
      GoRoute(path: '/login', builder: (_, __) => const Text('Login')),
    ],
  );

  return MaterialApp.router(theme: testThemeData, routerConfig: router);
}

void main() {
  group('SignedOutScreen', () {
    testWidgets('renders heading text', (tester) async {
      await tester.pumpWidget(_createApp());
      await tester.pumpAndSettle();

      expect(find.text('You have been signed out'), findsOneWidget);
    });

    testWidgets('renders sign in button', (tester) async {
      await tester.pumpWidget(_createApp());
      await tester.pumpAndSettle();

      expect(find.text('Sign in again'), findsOneWidget);
    });

    testWidgets('renders logout icon', (tester) async {
      await tester.pumpWidget(_createApp());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.logout), findsOneWidget);
    });

    testWidgets('tapping button navigates to /login', (tester) async {
      await tester.pumpWidget(_createApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sign in again'));
      await tester.pumpAndSettle();

      expect(find.text('Login'), findsOneWidget);
      expect(find.text('You have been signed out'), findsNothing);
    });
  });
}
