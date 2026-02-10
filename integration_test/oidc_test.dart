import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:soliplex_frontend/features/chat/widgets/chat_message_widget.dart';
import 'package:soliplex_frontend/features/rooms/widgets/room_list_tile.dart';

import 'patrol_helpers.dart';
import 'patrol_test_config.dart';
import 'test_log_harness.dart';

void main() {
  late TestLogHarness harness;

  /// Fail fast if OIDC credentials are not provided via --dart-define.
  void requireOidcCredentials() {
    if (oidcUsername.isEmpty || oidcPassword.isEmpty || oidcIssuerId.isEmpty) {
      fail(
        'OIDC credentials required. Pass:\n'
        '  --dart-define SOLIPLEX_OIDC_USERNAME=<user>\n'
        '  --dart-define SOLIPLEX_OIDC_PASSWORD=<pass>\n'
        '  --dart-define SOLIPLEX_OIDC_ISSUER_ID=<issuer>',
      );
    }
  }

  patrolTest('oidc - authenticated rooms load via ROPC', ($) async {
    requireOidcCredentials();
    await verifyBackendOrFail(backendUrl);
    ignoreKeyboardAssertions();

    harness = TestLogHarness();
    await harness.initialize();

    try {
      // ROPC exchange → real OIDC tokens.
      final tokens = await performRopcExchange(
        baseUrl: backendUrl,
        username: oidcUsername,
        password: oidcPassword,
        issuerId: oidcIssuerId,
      );

      // Boot app with pre-authenticated state.
      await pumpAuthenticatedTestApp($, harness, tokens: tokens);

      // Wait for rooms list (proves Bearer token works with backend).
      await waitForCondition(
        $.tester,
        condition: () => $.tester.any(find.byType(RoomListTile)),
        timeout: const Duration(seconds: 15),
        failureMessage: 'RoomListTile did not appear within 15s',
      );

      expect(find.byType(RoomListTile), findsWidgets);

      // White-box: verify authenticated HTTP calls.
      harness
        ..expectLog('HTTP', '/api/v1/rooms')
        ..expectLog('Room', 'Rooms loaded:');

      // Search for the "Gemini" room (faster model) via room search toolbar.
      final searchField = find.byWidgetPredicate(
        (w) =>
            w is TextField &&
            (w.decoration?.hintText?.contains('Search') ?? false),
      );
      await $.tester.enterText(searchField, 'Gemini');
      await $.tester.pump(const Duration(milliseconds: 500));

      // Tap the filtered room (substring — name is "Gemini 2.5 Flash").
      final geminiTile = findByTextContaining(RoomListTile, 'Gemini');
      await waitForCondition(
        $.tester,
        condition: () => $.tester.any(geminiTile),
        timeout: const Duration(seconds: 5),
        failureMessage: 'Gemini room not found after search filter',
      );
      await $.tester.tap(geminiTile.first);
      await $.tester.pump(const Duration(milliseconds: 500));

      // Wait for chat input.
      final chatInputFinder = find.byType(TextField);
      await waitForCondition(
        $.tester,
        condition: () => $.tester.any(chatInputFinder),
        timeout: const Duration(seconds: 10),
        failureMessage: 'Chat TextField did not appear within 10s',
      );

      // Send a test message.
      final testMessage =
          'patrol-oidc-${DateTime.now().millisecondsSinceEpoch}';
      await $.tester.enterText(chatInputFinder, testMessage);
      await $.tester.pump(const Duration(milliseconds: 200));

      await $.tester.tap(find.byTooltip('Send message'));
      await $.tester.pump(const Duration(milliseconds: 200));

      // Wait for AG-UI run to complete (proves streaming works with auth).
      await harness.waitForLog(
        'ActiveRun',
        'RUN_FINISHED',
        timeout: const Duration(seconds: 60),
      );

      await $.tester.pump(const Duration(milliseconds: 500));

      // At least 2 messages: user + assistant.
      expect(find.byType(ChatMessageWidget), findsAtLeast(2));

      // White-box: AG-UI lifecycle with authenticated backend.
      harness
        ..expectLog('ActiveRun', 'RUN_STARTED')
        ..expectLog('ActiveRun', 'TEXT_START:')
        ..expectLog('ActiveRun', 'RUN_FINISHED');

      // Pump extra frames so the rendered UI is visible in the macOS window.
      for (var i = 0; i < 5; i++) {
        await $.tester.pump(const Duration(milliseconds: 200));
      }
    } catch (e) {
      harness.dumpLogs(last: 50);
      rethrow;
    } finally {
      harness.dispose();
    }
  });

  patrolTest('oidc - settings shows auth state', ($) async {
    requireOidcCredentials();
    await verifyBackendOrFail(backendUrl);
    ignoreKeyboardAssertions();

    harness = TestLogHarness();
    await harness.initialize();

    try {
      final tokens = await performRopcExchange(
        baseUrl: backendUrl,
        username: oidcUsername,
        password: oidcPassword,
        issuerId: oidcIssuerId,
      );

      await pumpAuthenticatedTestApp($, harness, tokens: tokens);

      // Wait for app to boot.
      final settingsButton = find.byTooltip('Open settings');
      await waitForCondition(
        $.tester,
        condition: () => $.tester.any(settingsButton),
        timeout: const Duration(seconds: 10),
        failureMessage: 'Settings button did not appear within 10s',
      );

      // Navigate to settings.
      await $.tester.tap(settingsButton);
      await $.tester.pump(const Duration(milliseconds: 500));

      // Auth section shows signed-in state with issuer.
      expect(find.text('Signed In'), findsOneWidget);
      expect(find.textContaining('via'), findsOneWidget);
      expect(find.text('Sign Out'), findsOneWidget);

      // Pump extra frames for UI visibility.
      for (var i = 0; i < 5; i++) {
        await $.tester.pump(const Duration(milliseconds: 200));
      }
    } catch (e) {
      harness.dumpLogs(last: 50);
      rethrow;
    } finally {
      harness.dispose();
    }
  });
}
