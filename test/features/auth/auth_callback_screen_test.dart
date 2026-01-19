import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:soliplex_frontend/core/auth/auth_flow.dart' show AuthException;
import 'package:soliplex_frontend/core/auth/auth_notifier.dart';
import 'package:soliplex_frontend/core/auth/auth_provider.dart';
import 'package:soliplex_frontend/core/auth/auth_state.dart';
import 'package:soliplex_frontend/core/auth/callback_params.dart';
import 'package:soliplex_frontend/core/auth/oidc_issuer.dart';
import 'package:soliplex_frontend/features/auth/auth_callback_screen.dart';

import '../../helpers/test_helpers.dart';

/// Creates a test app with GoRouter for testing navigation.
Widget _createAppWithRouter({
  required Widget home,
  required List<dynamic> overrides,
}) {
  final router = GoRouter(
    initialLocation: '/callback',
    routes: [
      GoRoute(path: '/callback', builder: (_, __) => home),
      GoRoute(path: '/rooms', builder: (_, __) => const Text('Rooms')),
    ],
  );

  return UncontrolledProviderScope(
    container: ProviderContainer(overrides: overrides.cast()),
    child: MaterialApp.router(theme: testThemeData, routerConfig: router),
  );
}

class _MockAuthNotifier extends Notifier<AuthState> implements AuthNotifier {
  _MockAuthNotifier({
    this.shouldThrowAuthException = false,
    this.shouldThrowGenericException = false,
  });

  final bool shouldThrowAuthException;
  final bool shouldThrowGenericException;

  bool completeWebAuthCalled = false;
  String? lastAccessToken;
  String? lastRefreshToken;
  int? lastExpiresIn;

  @override
  AuthState build() => const Unauthenticated();

  @override
  String? get accessToken => null;

  @override
  bool get needsRefresh => false;

  @override
  Future<void> signIn(OidcIssuer issuer) async {}

  @override
  Future<void> signOut() async {}

  @override
  Future<void> refreshIfExpiringSoon() async {}

  @override
  Future<bool> tryRefresh() async => false;

  @override
  Future<void> completeWebAuth({
    required String accessToken,
    String? refreshToken,
    int? expiresIn,
  }) async {
    completeWebAuthCalled = true;
    lastAccessToken = accessToken;
    lastRefreshToken = refreshToken;
    lastExpiresIn = expiresIn;

    if (shouldThrowAuthException) {
      throw const AuthException('Pre-auth state expired');
    }
    if (shouldThrowGenericException) {
      throw Exception('Network error');
    }
  }

  @override
  Future<void> enterNoAuthMode() async {}

  @override
  void exitNoAuthMode() {}
}

void main() {
  group('AuthCallbackScreen', () {
    testWidgets('shows error when OAuth error in params', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          home: const AuthCallbackScreen(),
          overrides: [
            capturedCallbackParamsProvider.overrideWithValue(
              const WebCallbackParams(
                error: 'access_denied',
                errorDescription: 'User cancelled login',
              ),
            ),
            authProvider.overrideWith(_MockAuthNotifier.new),
          ],
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Sign In Failed'), findsOneWidget);
      expect(find.text('User cancelled login'), findsOneWidget);
      expect(find.text('Back to Login'), findsOneWidget);
    });

    testWidgets('shows error code when no description', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          home: const AuthCallbackScreen(),
          overrides: [
            capturedCallbackParamsProvider.overrideWithValue(
              const WebCallbackParams(error: 'server_error'),
            ),
            authProvider.overrideWith(_MockAuthNotifier.new),
          ],
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Sign In Failed'), findsOneWidget);
      expect(find.text('server_error'), findsOneWidget);
    });

    testWidgets('shows error when access token missing', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          home: const AuthCallbackScreen(),
          overrides: [
            capturedCallbackParamsProvider.overrideWithValue(
              const WebCallbackParams(),
            ),
            authProvider.overrideWith(_MockAuthNotifier.new),
          ],
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Sign In Failed'), findsOneWidget);
      expect(find.text('Authentication failed: missing token'), findsOneWidget);
    });

    testWidgets('shows error for NoCallbackParams', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          home: const AuthCallbackScreen(),
          overrides: [
            capturedCallbackParamsProvider.overrideWithValue(
              const NoCallbackParams(),
            ),
            authProvider.overrideWith(_MockAuthNotifier.new),
          ],
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Sign In Failed'), findsOneWidget);
      expect(
        find.text('Invalid callback: no authentication data'),
        findsOneWidget,
      );
    });

    testWidgets('calls completeWebAuth with tokens on success', (tester) async {
      late _MockAuthNotifier mockNotifier;

      await tester.pumpWidget(
        _createAppWithRouter(
          home: const AuthCallbackScreen(),
          overrides: [
            capturedCallbackParamsProvider.overrideWithValue(
              const WebCallbackParams(
                accessToken: 'test-access-token',
                refreshToken: 'test-refresh-token',
                expiresIn: 3600,
              ),
            ),
            authProvider.overrideWith(() {
              return mockNotifier = _MockAuthNotifier();
            }),
          ],
        ),
      );

      // Allow async _processCallback to run and navigate
      await tester.pumpAndSettle();

      expect(mockNotifier.completeWebAuthCalled, isTrue);
      expect(mockNotifier.lastAccessToken, 'test-access-token');
      expect(mockNotifier.lastRefreshToken, 'test-refresh-token');
      expect(mockNotifier.lastExpiresIn, 3600);

      // Verify navigation occurred - we should now be on /rooms
      expect(find.text('Rooms'), findsOneWidget);
    });

    testWidgets('shows error when completeWebAuth throws AuthException',
        (tester) async {
      await tester.pumpWidget(
        createTestApp(
          home: const AuthCallbackScreen(),
          overrides: [
            capturedCallbackParamsProvider.overrideWithValue(
              const WebCallbackParams(accessToken: 'test-token'),
            ),
            authProvider.overrideWith(
              () => _MockAuthNotifier(shouldThrowAuthException: true),
            ),
          ],
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Sign In Failed'), findsOneWidget);
      expect(find.text('Pre-auth state expired'), findsOneWidget);
    });

    testWidgets('shows generic error when completeWebAuth throws Exception',
        (tester) async {
      await tester.pumpWidget(
        createTestApp(
          home: const AuthCallbackScreen(),
          overrides: [
            capturedCallbackParamsProvider.overrideWithValue(
              const WebCallbackParams(accessToken: 'test-token'),
            ),
            authProvider.overrideWith(
              () => _MockAuthNotifier(shouldThrowGenericException: true),
            ),
          ],
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Sign In Failed'), findsOneWidget);
      expect(
        find.text('Failed to complete authentication. Please try again.'),
        findsOneWidget,
      );
    });
  });
}
