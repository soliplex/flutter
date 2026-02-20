import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:soliplex_client/soliplex_client.dart' show AuthProviderConfig;
import 'package:soliplex_frontend/core/auth/auth_flow.dart'
    show AuthException, AuthRedirectInitiated;
import 'package:soliplex_frontend/core/auth/auth_notifier.dart';
import 'package:soliplex_frontend/core/auth/auth_provider.dart';
import 'package:soliplex_frontend/core/auth/auth_state.dart';
import 'package:soliplex_frontend/core/auth/oidc_issuer.dart';
import 'package:soliplex_frontend/core/models/consent_notice.dart';
import 'package:soliplex_frontend/core/providers/shell_config_provider.dart';
import 'package:soliplex_frontend/features/login/login_screen.dart';

import '../../helpers/test_helpers.dart';

OidcIssuer _createIssuer({
  String id = 'google',
  String name = 'Google',
  String serverUrl = 'https://accounts.google.com',
  String clientId = 'client-123',
  String scope = 'openid email',
}) {
  return OidcIssuer.fromConfig(
    AuthProviderConfig(
      id: id,
      name: name,
      serverUrl: serverUrl,
      clientId: clientId,
      scope: scope,
    ),
  );
}

class _MockAuthNotifier extends Notifier<AuthState> implements AuthNotifier {
  _MockAuthNotifier({
    this.shouldThrowAuthException = false,
    this.shouldThrowRedirect = false,
  });

  final bool shouldThrowAuthException;
  final bool shouldThrowRedirect;
  bool signInCalled = false;
  OidcIssuer? lastIssuer;

  @override
  AuthState build() => const Unauthenticated();

  @override
  String? get accessToken => null;

  @override
  bool get needsRefresh => false;

  @override
  Future<void> signIn(OidcIssuer issuer) async {
    signInCalled = true;
    lastIssuer = issuer;

    if (shouldThrowAuthException) {
      throw const AuthException('Authentication failed');
    }
    if (shouldThrowRedirect) {
      throw const AuthRedirectInitiated();
    }
  }

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
  }) async {}

  @override
  Future<void> enterNoAuthMode() async {}

  @override
  void exitNoAuthMode() {}
}

/// Creates a test app with GoRouter for testing navigation.
Widget _createAppWithRouter({
  required Widget home,
  required List<dynamic> overrides,
}) {
  final router = GoRouter(
    initialLocation: '/login',
    routes: [
      GoRoute(path: '/login', builder: (_, __) => home),
      GoRoute(
        path: '/rooms',
        builder: (_, __) => const Scaffold(body: Text('Rooms Screen')),
      ),
    ],
  );

  return UncontrolledProviderScope(
    container: ProviderContainer(
      overrides: [
        shellConfigProvider.overrideWithValue(testSoliplexConfig),
        ...overrides.cast(),
      ],
    ),
    child: MaterialApp.router(theme: testThemeData, routerConfig: router),
  );
}

Widget _createAppWithConsentNotice({required ConsentNotice notice}) {
  return UncontrolledProviderScope(
    container: ProviderContainer(
      overrides: [
        shellConfigProvider.overrideWithValue(
          testSoliplexConfig.copyWith(consentNotice: notice),
        ),
        oidcIssuersProvider.overrideWith((ref) async => [_createIssuer()]),
      ],
    ),
    child: MaterialApp(
      theme: testThemeData,
      home: const Scaffold(body: LoginScreen()),
    ),
  );
}

void main() {
  group('LoginScreen', () {
    group('UI', () {
      testWidgets('displays title and subtitle', (tester) async {
        await tester.pumpWidget(
          createTestApp(
            home: const LoginScreen(),
            overrides: [oidcIssuersProvider.overrideWith((ref) async => [])],
          ),
        );

        expect(find.text('Soliplex'), findsOneWidget);
        expect(find.text('Sign in to continue'), findsOneWidget);
      });
    });

    group('Loading state', () {
      testWidgets('shows loading indicator while fetching issuers', (
        tester,
      ) async {
        // Use a completer to keep the provider in loading state
        final completer = Completer<List<OidcIssuer>>();

        await tester.pumpWidget(
          createTestApp(
            home: const LoginScreen(),
            overrides: [
              oidcIssuersProvider.overrideWith((ref) => completer.future),
            ],
          ),
        );

        // Just pump one frame, don't settle
        await tester.pump();

        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        // Complete to clean up
        completer.complete([]);
        await tester.pumpAndSettle();
      });
    });

    group('Error state', () {
      testWidgets('shows error message when fetching fails', (tester) async {
        await tester.pumpWidget(
          createTestApp(
            home: const LoginScreen(),
            overrides: [
              oidcIssuersProvider.overrideWith(
                (ref) => throw Exception('Network error'),
              ),
            ],
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('Failed to load identity providers'), findsOneWidget);
        expect(find.text('Retry'), findsOneWidget);
      });
    });

    group('Issuer list', () {
      testWidgets('shows message when no issuers available', (tester) async {
        await tester.pumpWidget(
          createTestApp(
            home: const LoginScreen(),
            overrides: [oidcIssuersProvider.overrideWith((ref) async => [])],
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('No identity providers configured.'), findsOneWidget);
      });

      testWidgets('shows sign in button for each issuer', (tester) async {
        await tester.pumpWidget(
          createTestApp(
            home: const LoginScreen(),
            overrides: [
              oidcIssuersProvider.overrideWith(
                (ref) async => [
                  _createIssuer(),
                  _createIssuer(
                    id: 'microsoft',
                    name: 'Microsoft',
                    serverUrl: 'https://login.microsoft.com',
                    clientId: 'client-456',
                  ),
                ],
              ),
            ],
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('Sign in with Google'), findsOneWidget);
        expect(find.text('Sign in with Microsoft'), findsOneWidget);
      });
    });

    group('Sign in flow', () {
      testWidgets('calls signIn with correct issuer', (tester) async {
        late _MockAuthNotifier mockNotifier;
        final issuer = _createIssuer();

        await tester.pumpWidget(
          _createAppWithRouter(
            home: const LoginScreen(),
            overrides: [
              oidcIssuersProvider.overrideWith((ref) async => [issuer]),
              authProvider.overrideWith(() {
                return mockNotifier = _MockAuthNotifier();
              }),
            ],
          ),
        );

        await tester.pumpAndSettle();
        await tester.tap(find.text('Sign in with Google'));
        await tester.pumpAndSettle();

        expect(mockNotifier.signInCalled, isTrue);
        expect(mockNotifier.lastIssuer?.id, 'google');
        expect(find.text('Rooms Screen'), findsOneWidget);
      });

      testWidgets('shows error when AuthException is thrown', (tester) async {
        final issuer = _createIssuer();

        await tester.pumpWidget(
          createTestApp(
            home: const LoginScreen(),
            overrides: [
              oidcIssuersProvider.overrideWith((ref) async => [issuer]),
              authProvider.overrideWith(
                () => _MockAuthNotifier(shouldThrowAuthException: true),
              ),
            ],
          ),
        );

        await tester.pumpAndSettle();
        await tester.tap(find.text('Sign in with Google'));
        await tester.pumpAndSettle();

        expect(find.text('Authentication failed'), findsOneWidget);
      });

      testWidgets('handles AuthRedirectInitiated gracefully', (tester) async {
        final issuer = _createIssuer();

        await tester.pumpWidget(
          createTestApp(
            home: const LoginScreen(),
            overrides: [
              oidcIssuersProvider.overrideWith((ref) async => [issuer]),
              authProvider.overrideWith(
                () => _MockAuthNotifier(shouldThrowRedirect: true),
              ),
            ],
          ),
        );

        await tester.pumpAndSettle();
        await tester.tap(find.text('Sign in with Google'));
        await tester.pumpAndSettle();

        // Should not show error - redirect is expected on web
        expect(find.text('Authentication failed'), findsNothing);
      });
    });
  });

  group('Back navigation', () {
    testWidgets('shows change backend server button', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          home: const LoginScreen(),
          overrides: [
            oidcIssuersProvider.overrideWith((ref) async => [_createIssuer()]),
          ],
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Change server'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Change server'), findsOneWidget);
    });

    testWidgets('change backend server button navigates to home', (
      tester,
    ) async {
      final router = GoRouter(
        initialLocation: '/login',
        routes: [
          GoRoute(
            path: '/',
            builder: (_, __) => const Scaffold(body: Text('Home Screen')),
          ),
          GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: ProviderContainer(
            overrides: [
              shellConfigProvider.overrideWithValue(testSoliplexConfig),
              oidcIssuersProvider.overrideWith(
                (ref) async => [_createIssuer()],
              ),
            ],
          ),
          child: MaterialApp.router(theme: testThemeData, routerConfig: router),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.text('Change server'));
      await tester.pumpAndSettle();

      expect(find.text('Home Screen'), findsOneWidget);
    });
  });

  group('Consent notice', () {
    testWidgets('shows login options when no consentNotice configured', (
      tester,
    ) async {
      await tester.pumpWidget(
        createTestApp(
          home: const LoginScreen(),
          overrides: [
            oidcIssuersProvider.overrideWith(
              (ref) async => [_createIssuer()],
            ),
          ],
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Sign in with Google'), findsOneWidget);
    });

    testWidgets('shows interstitial when consentNotice configured', (
      tester,
    ) async {
      await tester.pumpWidget(
        _createAppWithConsentNotice(
          notice: const ConsentNotice(
            title: 'Notice',
            body: 'You are being monitored.',
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Notice'), findsOneWidget);
      expect(find.text('You are being monitored.'), findsOneWidget);
      expect(find.text('OK'), findsOneWidget);
      expect(find.text('Sign in with Google'), findsNothing);
    });

    testWidgets('dismisses interstitial after tapping acknowledgment button', (
      tester,
    ) async {
      await tester.pumpWidget(
        _createAppWithConsentNotice(
          notice: const ConsentNotice(
            title: 'Notice',
            body: 'You are being monitored.',
          ),
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(find.text('Notice'), findsNothing);
      expect(find.text('Sign in with Google'), findsOneWidget);
    });

    testWidgets('shows custom acknowledgmentLabel', (tester) async {
      await tester.pumpWidget(
        _createAppWithConsentNotice(
          notice: const ConsentNotice(
            title: 'Notice',
            body: 'Body',
            acknowledgmentLabel: 'I Agree',
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('I Agree'), findsOneWidget);
      expect(find.text('OK'), findsNothing);
    });
  });
}
