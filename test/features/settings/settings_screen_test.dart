import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soliplex_frontend/core/auth/auth_notifier.dart';
import 'package:soliplex_frontend/core/auth/auth_provider.dart';
import 'package:soliplex_frontend/core/auth/auth_state.dart';
import 'package:soliplex_frontend/core/auth/oidc_issuer.dart';
import 'package:soliplex_frontend/core/models/app_config.dart';
import 'package:soliplex_frontend/features/settings/settings_screen.dart';

import '../../helpers/test_helpers.dart';

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
      await tester.pumpWidget(
        createTestApp(
          home: const SettingsScreen(),
          overrides: [
            configProviderOverride(
              const AppConfig(baseUrl: 'http://localhost:8000'),
            ),
          ],
        ),
      );

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

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.text('Loading...'), findsOneWidget);
      });
    });
  });
}
