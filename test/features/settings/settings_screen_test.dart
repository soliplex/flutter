import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:soliplex_client/soliplex_client.dart';
import 'package:soliplex_frontend/core/auth/auth_notifier.dart';
import 'package:soliplex_frontend/core/auth/auth_provider.dart';
import 'package:soliplex_frontend/core/auth/auth_state.dart';
import 'package:soliplex_frontend/core/auth/oidc_issuer.dart';
import 'package:soliplex_frontend/core/providers/backend_version_provider.dart';
import 'package:soliplex_frontend/core/providers/package_info_provider.dart';
import 'package:soliplex_frontend/features/settings/settings_screen.dart';

import '../../helpers/test_helpers.dart';

/// Creates a test app with GoRouter for testing navigation.
Widget _createAppWithRouter({
  required Widget home,
  required List<dynamic> overrides,
}) {
  final router = GoRouter(
    initialLocation: '/settings',
    routes: [
      GoRoute(
        path: '/settings',
        builder: (_, __) => Scaffold(body: home),
        routes: [
          GoRoute(
            path: 'backend-versions',
            builder: (_, __) => const Scaffold(
              body: Text('Backend Versions Screen'),
            ),
          ),
        ],
      ),
    ],
  );

  return UncontrolledProviderScope(
    container: ProviderContainer(
      overrides: [
        packageInfoProvider.overrideWithValue(testPackageInfo),
        backendVersionInfoProvider.overrideWithValue(
          const AsyncValue.data(testBackendVersionInfo),
        ),
        ...overrides.cast(),
      ],
    ),
    child: MaterialApp.router(theme: testThemeData, routerConfig: router),
  );
}

class _MockAuthNotifier extends Notifier<AuthState> implements AuthNotifier {
  _MockAuthNotifier({this.initialState = const Unauthenticated()});

  final AuthState initialState;
  bool exitNoAuthModeCalled = false;
  bool signOutCalled = false;

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
    state = const Unauthenticated(
      reason: UnauthenticatedReason.explicitSignOut,
    );
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
  Future<void> enterNoAuthMode() async {}

  @override
  void exitNoAuthMode() {
    exitNoAuthModeCalled = true;
    state = const Unauthenticated(
      reason: UnauthenticatedReason.explicitSignOut,
    );
  }
}

void main() {
  group('SettingsScreen', () {
    testWidgets('displays app version from packageInfoProvider',
        (tester) async {
      await tester.pumpWidget(createTestApp(home: const SettingsScreen()));

      expect(find.text('App Version'), findsOneWidget);
      expect(find.text('1.0.0+1'), findsOneWidget);
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

    testWidgets('Disconnect calls exitNoAuthMode', (tester) async {
      late _MockAuthNotifier mockNotifier;

      await tester.pumpWidget(
        createTestApp(
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

      testWidgets('calls signOut on confirm', (tester) async {
        late _MockAuthNotifier mockNotifier;

        await tester.pumpWidget(
          createTestApp(
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
        // Don't use pumpAndSettle - CircularProgressIndicator animates forever
        await tester.pump();

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        // Verify the auth section shows "Loading..." by checking it's in a
        // ListTile with a CircularProgressIndicator
        final loadingTile = find.ancestor(
          of: find.byType(CircularProgressIndicator),
          matching: find.byType(ListTile),
        );
        expect(
          find.descendant(of: loadingTile, matching: find.text('Loading...')),
          findsOneWidget,
        );
      });
    });

    group('Backend version', () {
      testWidgets('displays backend version when loaded', (tester) async {
        // Uses default testBackendVersionInfo from createTestApp
        await tester.pumpWidget(
          createTestApp(home: const SettingsScreen()),
        );
        // Just pump once - the value is immediately available via AsyncValue
        await tester.pump();

        expect(find.text('Backend Version'), findsOneWidget);
        expect(find.text('0.36.dev0'), findsOneWidget);
        expect(find.text('View All'), findsOneWidget);
      });

      testWidgets('shows Loading when fetching', (tester) async {
        await tester.pumpWidget(
          createTestApp(
            home: const SettingsScreen(),
            skipBackendVersionOverride: true,
            overrides: [
              // Use AsyncValue.loading() to avoid pending timers
              backendVersionInfoProvider.overrideWithValue(
                const AsyncValue<BackendVersionInfo>.loading(),
              ),
            ],
          ),
        );
        await tester.pump();

        expect(find.text('Backend Version'), findsOneWidget);
        // Find Loading text in the backend version subtitle
        expect(
          find.descendant(
            of: find.widgetWithText(ListTile, 'Backend Version'),
            matching: find.text('Loading...'),
          ),
          findsOneWidget,
        );
      });

      testWidgets('shows Unavailable on error', (tester) async {
        await tester.pumpWidget(
          createTestApp(
            home: const SettingsScreen(),
            skipBackendVersionOverride: true,
            overrides: [
              // Use AsyncValue.error() to avoid retry timers
              backendVersionInfoProvider.overrideWithValue(
                const AsyncValue<BackendVersionInfo>.error(
                  NetworkException(message: 'Connection failed'),
                  StackTrace.empty,
                ),
              ),
            ],
          ),
        );
        await tester.pump();

        expect(find.text('Backend Version'), findsOneWidget);
        expect(
          find.descendant(
            of: find.widgetWithText(ListTile, 'Backend Version'),
            matching: find.text('Unavailable'),
          ),
          findsOneWidget,
        );
      });

      testWidgets('View All navigates to backend-versions screen',
          (tester) async {
        await tester.pumpWidget(
          _createAppWithRouter(
            home: const SettingsScreen(),
            overrides: const [],
          ),
        );
        await tester.pump();

        await tester.tap(find.text('View All'));
        await tester.pumpAndSettle();

        expect(find.text('Backend Versions Screen'), findsOneWidget);
      });
    });
  });
}
