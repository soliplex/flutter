import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
// Hide ag_ui's CancelToken - HttpTransport uses soliplex_client's.
import 'package:soliplex_client/soliplex_client.dart' hide CancelToken;
import 'package:soliplex_client/src/utils/cancel_token.dart';
import 'package:soliplex_frontend/core/auth/auth_notifier.dart';
import 'package:soliplex_frontend/core/auth/auth_provider.dart';
import 'package:soliplex_frontend/core/auth/auth_state.dart';
import 'package:soliplex_frontend/core/auth/oidc_issuer.dart';
import 'package:soliplex_frontend/core/models/app_config.dart';
import 'package:soliplex_frontend/core/providers/api_provider.dart';
import 'package:soliplex_frontend/core/router/app_router.dart';
import 'package:soliplex_frontend/features/settings/settings_screen.dart';

import '../../helpers/test_helpers.dart';

class _MockAuthNotifier extends Notifier<AuthState> implements AuthNotifier {
  _MockAuthNotifier({this.initialState = const Unauthenticated()});

  final AuthState initialState;
  bool exitNoAuthModeCalled = false;
  bool signOutCalled = false;
  bool enterNoAuthModeCalled = false;

  @override
  AuthState build() => initialState;

  @override
  String? get accessToken => null;

  @override
  bool get needsRefresh => false;

  @override
  Future<void> signIn(OidcIssuer issuer) async {}

  @override
  Future<void> signOut() async {
    signOutCalled = true;
    state = const Unauthenticated();
  }

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
  Future<void> enterNoAuthMode() async {
    enterNoAuthModeCalled = true;
    state = const NoAuthRequired();
  }

  @override
  void exitNoAuthMode() {
    exitNoAuthModeCalled = true;
    state = const Unauthenticated();
  }
}

/// Fake HttpTransport for controlling fetchAuthProviders responses.
class _FakeHttpTransport implements HttpTransport {
  _FakeHttpTransport({this.authProviders = const {}});

  final Map<String, dynamic> authProviders;

  @override
  Duration get defaultTimeout => const Duration(seconds: 30);

  @override
  Future<T> request<T>(
    String method,
    Uri uri, {
    Object? body,
    Map<String, String>? headers,
    Duration? timeout,
    CancelToken? cancelToken,
    T Function(Map<String, dynamic>)? fromJson,
  }) async {
    return authProviders as T;
  }

  @override
  Stream<List<int>> requestStream(
    String method,
    Uri uri, {
    Object? body,
    Map<String, String>? headers,
    CancelToken? cancelToken,
  }) async* {
    yield [];
  }

  @override
  void close() {}
}

/// Creates a test app with GoRouter for testing navigation.
Widget _createAppWithRouter({
  required Widget home,
  required List<dynamic> overrides,
  String initialLocation = '/settings',
}) {
  late GoRouter router;
  router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/settings',
        builder: (_, __) => Scaffold(body: home),
      ),
      GoRoute(path: '/', builder: (_, __) => const Text('Home')),
      GoRoute(path: '/login', builder: (_, __) => const Text('Login')),
      GoRoute(path: '/rooms', builder: (_, __) => const Text('Rooms')),
    ],
  );

  final container = ProviderContainer(
    overrides: [
      ...overrides.cast(),
      routerProvider.overrideWithValue(router),
    ],
  );

  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  group('SettingsScreen', () {
    testWidgets('displays app version', (tester) async {
      await tester.pumpWidget(createTestApp(home: const SettingsScreen()));

      expect(find.text('App Version'), findsOneWidget);
      expect(find.textContaining('1.0.0'), findsOneWidget);
    });

    testWidgets('displays backend URL', (tester) async {
      await tester.pumpWidget(createTestApp(home: const SettingsScreen()));

      expect(find.text('Backend URL'), findsOneWidget);
      expect(find.text('http://localhost:8000'), findsOneWidget);
    });

    testWidgets('shows unauthenticated state', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          home: const SettingsScreen(),
          overrides: [authProvider.overrideWith(_MockAuthNotifier.new)],
        ),
      );

      expect(find.text('Authentication'), findsOneWidget);
      expect(find.text('Not signed in'), findsOneWidget);
    });

    testWidgets('shows Disconnect option in NoAuthRequired state',
        (tester) async {
      await tester.pumpWidget(
        createTestApp(
          home: const SettingsScreen(),
          overrides: [
            authProvider.overrideWith(
              () => _MockAuthNotifier(initialState: const NoAuthRequired()),
            ),
          ],
        ),
      );

      expect(find.text('No Authentication'), findsOneWidget);
      expect(find.text('Backend does not require login'), findsOneWidget);
      expect(find.text('Disconnect'), findsOneWidget);
    });

    testWidgets('Disconnect calls exitNoAuthMode and navigates to home',
        (tester) async {
      late _MockAuthNotifier mockNotifier;

      await tester.pumpWidget(
        _createAppWithRouter(
          home: const SettingsScreen(),
          overrides: [
            authProvider.overrideWith(() {
              return mockNotifier = _MockAuthNotifier(
                initialState: const NoAuthRequired(),
              );
            }),
          ],
        ),
      );

      await tester.tap(find.text('Disconnect'));
      await tester.pumpAndSettle();

      expect(mockNotifier.exitNoAuthModeCalled, isTrue);
      expect(find.text('Home'), findsOneWidget);
    });

    group('Authenticated state', () {
      testWidgets('shows signed in status with issuer ID', (tester) async {
        await tester.pumpWidget(
          createTestApp(
            home: const SettingsScreen(),
            overrides: [
              authProvider.overrideWith(
                () => _MockAuthNotifier(
                  initialState: TestData.createAuthenticated(
                    issuerId: 'google-oauth',
                  ),
                ),
              ),
            ],
          ),
        );

        expect(find.text('Signed In'), findsOneWidget);
        expect(find.text('via google-oauth'), findsOneWidget);
        expect(find.text('Sign Out'), findsOneWidget);
      });

      testWidgets('shows confirmation dialog on Sign Out tap', (tester) async {
        await tester.pumpWidget(
          createTestApp(
            home: const SettingsScreen(),
            overrides: [
              authProvider.overrideWith(
                () => _MockAuthNotifier(
                  initialState: TestData.createAuthenticated(),
                ),
              ),
            ],
          ),
        );

        await tester.tap(find.text('Sign Out'));
        await tester.pumpAndSettle();

        expect(find.text('Are you sure you want to sign out?'), findsOneWidget);
        expect(find.text('Cancel'), findsOneWidget);
      });

      testWidgets('dismisses dialog on Cancel', (tester) async {
        await tester.pumpWidget(
          createTestApp(
            home: const SettingsScreen(),
            overrides: [
              authProvider.overrideWith(
                () => _MockAuthNotifier(
                  initialState: TestData.createAuthenticated(),
                ),
              ),
            ],
          ),
        );

        await tester.tap(find.text('Sign Out'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();

        // Dialog should be dismissed
        expect(
          find.text('Are you sure you want to sign out?'),
          findsNothing,
        );
      });

      testWidgets('calls signOut and navigates on confirm', (tester) async {
        late _MockAuthNotifier mockNotifier;

        await tester.pumpWidget(
          _createAppWithRouter(
            home: const SettingsScreen(),
            overrides: [
              authProvider.overrideWith(() {
                return mockNotifier = _MockAuthNotifier(
                  initialState: TestData.createAuthenticated(),
                );
              }),
            ],
          ),
        );

        // Tap Sign Out
        await tester.tap(find.text('Sign Out'));
        await tester.pumpAndSettle();

        // Confirm in dialog
        await tester.tap(find.widgetWithText(TextButton, 'Sign Out'));
        await tester.pumpAndSettle();

        expect(mockNotifier.signOutCalled, isTrue);
        expect(find.text('Home'), findsOneWidget);
      });
    });

    group('Loading state', () {
      testWidgets('shows loading indicator', (tester) async {
        await tester.pumpWidget(
          createTestApp(
            home: const SettingsScreen(),
            overrides: [
              authProvider.overrideWith(
                () => _MockAuthNotifier(initialState: const AuthLoading()),
              ),
            ],
          ),
        );

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.text('Loading...'), findsOneWidget);
      });
    });

    group('URL edit dialog', () {
      testWidgets('does nothing when URL is unchanged (normalized)',
          (tester) async {
        late _MockAuthNotifier mockNotifier;
        final fakeTransport = _FakeHttpTransport();

        await tester.pumpWidget(
          _createAppWithRouter(
            home: const SettingsScreen(),
            overrides: [
              authProvider.overrideWith(() {
                return mockNotifier = _MockAuthNotifier(
                  initialState: TestData.createAuthenticated(),
                );
              }),
              httpTransportProvider.overrideWithValue(fakeTransport),
            ],
          ),
        );

        // Tap Backend URL to open dialog
        await tester.tap(find.text('Backend URL'));
        await tester.pumpAndSettle();

        // Enter same URL with trailing slash (should normalize to same)
        final textField = find.byType(TextFormField);
        await tester.enterText(textField, 'http://localhost:8000/');
        await tester.pumpAndSettle();

        // Tap Save
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();

        // Should not sign out (URLs normalize to same)
        expect(mockNotifier.signOutCalled, isFalse);
        // Should show snackbar
        expect(find.text('URL unchanged'), findsOneWidget);
      });

      testWidgets(
          'signs out and navigates to login when URL changes '
          'and backend requires auth', (tester) async {
        late _MockAuthNotifier mockNotifier;
        // Fake transport that returns auth providers
        final fakeTransport = _FakeHttpTransport(
          authProviders: {
            'google': {
              'title': 'Google',
              'server_url': 'https://accounts.google.com',
              'client_id': 'client-id',
              'scope': 'openid profile',
            },
          },
        );

        await tester.pumpWidget(
          _createAppWithRouter(
            home: const SettingsScreen(),
            overrides: [
              authProvider.overrideWith(() {
                return mockNotifier = _MockAuthNotifier(
                  initialState: TestData.createAuthenticated(),
                );
              }),
              httpTransportProvider.overrideWithValue(fakeTransport),
              configProviderOverride(AppConfig.defaults()),
            ],
          ),
        );

        // Tap Backend URL to open dialog
        await tester.tap(find.text('Backend URL'));
        await tester.pumpAndSettle();

        // Enter different URL
        final textField = find.byType(TextFormField);
        await tester.enterText(textField, 'http://newbackend.example.com');
        await tester.pumpAndSettle();

        // Tap Save - connection flow runs asynchronously
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();

        // Run async code and allow it to complete
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 100));
        });
        await tester.pumpAndSettle();

        // Should sign out and navigate to login
        expect(mockNotifier.signOutCalled, isTrue);
        expect(find.text('Login'), findsOneWidget);
      });

      testWidgets(
          'enters no-auth mode and navigates to rooms when URL changes '
          'and backend has no auth providers', (tester) async {
        late _MockAuthNotifier mockNotifier;
        // Fake transport that returns empty (no auth required)
        final fakeTransport = _FakeHttpTransport(authProviders: {});

        await tester.pumpWidget(
          _createAppWithRouter(
            home: const SettingsScreen(),
            overrides: [
              authProvider.overrideWith(() {
                return mockNotifier = _MockAuthNotifier(
                  initialState: TestData.createAuthenticated(),
                );
              }),
              httpTransportProvider.overrideWithValue(fakeTransport),
              configProviderOverride(AppConfig.defaults()),
            ],
          ),
        );

        // Tap Backend URL to open dialog
        await tester.tap(find.text('Backend URL'));
        await tester.pumpAndSettle();

        // Enter different URL
        final textField = find.byType(TextFormField);
        await tester.enterText(textField, 'http://newbackend.example.com');
        await tester.pumpAndSettle();

        // Tap Save - connection flow runs asynchronously
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();

        // Run async code and allow it to complete
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 100));
        });
        await tester.pumpAndSettle();

        // Should sign out, enter no-auth mode, and navigate to rooms
        expect(mockNotifier.signOutCalled, isTrue);
        expect(mockNotifier.enterNoAuthModeCalled, isTrue);
        expect(find.text('Rooms'), findsOneWidget);
      });

      testWidgets(
          'exits no-auth mode when URL changes from NoAuthRequired state',
          (tester) async {
        late _MockAuthNotifier mockNotifier;
        // Fake transport that returns auth providers
        final fakeTransport = _FakeHttpTransport(
          authProviders: {
            'google': {
              'title': 'Google',
              'server_url': 'https://accounts.google.com',
              'client_id': 'client-id',
              'scope': 'openid profile',
            },
          },
        );

        await tester.pumpWidget(
          _createAppWithRouter(
            home: const SettingsScreen(),
            overrides: [
              authProvider.overrideWith(() {
                return mockNotifier = _MockAuthNotifier(
                  initialState: const NoAuthRequired(),
                );
              }),
              httpTransportProvider.overrideWithValue(fakeTransport),
              configProviderOverride(AppConfig.defaults()),
            ],
          ),
        );

        // Tap Backend URL to open dialog
        await tester.tap(find.text('Backend URL'));
        await tester.pumpAndSettle();

        // Enter different URL
        final textField = find.byType(TextFormField);
        await tester.enterText(textField, 'http://newbackend.example.com');
        await tester.pumpAndSettle();

        // Tap Save - connection flow runs asynchronously
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();

        // Run async code and allow it to complete
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 100));
        });
        await tester.pumpAndSettle();

        // Should exit no-auth mode and navigate to login
        expect(mockNotifier.exitNoAuthModeCalled, isTrue);
        expect(find.text('Login'), findsOneWidget);
      });
    });
  });
}
