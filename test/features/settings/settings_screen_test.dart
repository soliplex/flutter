import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soliplex_frontend/core/auth/auth_notifier.dart';
import 'package:soliplex_frontend/core/auth/auth_provider.dart';
import 'package:soliplex_frontend/core/auth/auth_state.dart';
import 'package:soliplex_frontend/core/auth/oidc_issuer.dart';
import 'package:soliplex_frontend/features/settings/settings_screen.dart';

import '../../helpers/test_helpers.dart';

class _MockAuthNotifier extends Notifier<AuthState> implements AuthNotifier {
  _MockAuthNotifier({this.initialState = const Unauthenticated()});

  final AuthState initialState;
  bool exitNoAuthModeCalled = false;

  @override
  AuthState build() => initialState;

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
  }) async {}

  @override
  Future<void> enterNoAuthMode() async {}

  @override
  void exitNoAuthMode() {
    exitNoAuthModeCalled = true;
    state = const Unauthenticated();
  }
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
      // Don't pump - the tap triggers sync call before navigation throws
      tester.takeException(); // Consume the go_router error

      expect(mockNotifier.exitNoAuthModeCalled, isTrue);
    });
  });
}
