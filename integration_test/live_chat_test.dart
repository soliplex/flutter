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

  patrolTest('rooms - load from backend', ($) async {
    await verifyBackendOrFail(backendUrl);
    ignoreKeyboardAssertions();

    harness = TestLogHarness();
    await harness.initialize();

    try {
      await pumpTestApp($, harness);

      // Wait for room list to render (router redirects / → /rooms).
      await waitForCondition(
        $.tester,
        condition: () => $.tester.any(find.byType(RoomListTile)),
        timeout: const Duration(seconds: 10),
        failureMessage: 'RoomListTile did not appear within 10s',
      );

      expect(find.byType(RoomListTile), findsWidgets);

      // White-box: verify HTTP call and room loading via logs.
      harness
        ..expectLog('HTTP', '/api/v1/rooms')
        ..expectLog('Room', 'Rooms loaded:');

      // Pump extra frames for macOS rendering.
      await $.tester.pump(const Duration(seconds: 1));
    } catch (e) {
      harness.dumpLogs(last: 50);
      rethrow;
    } finally {
      harness.dispose();
    }
  });

  patrolTest('chat - send message and receive response', ($) async {
    await verifyBackendOrFail(backendUrl);
    ignoreKeyboardAssertions();

    harness = TestLogHarness();
    await harness.initialize();

    try {
      await pumpTestApp($, harness);

      // Wait for rooms to load.
      await waitForCondition(
        $.tester,
        condition: () => $.tester.any(find.byType(RoomListTile)),
        timeout: const Duration(seconds: 10),
        failureMessage: 'RoomListTile did not appear within 10s',
      );

      // Tap the first room to navigate to /rooms/:roomId.
      await $.tester.tap(find.byType(RoomListTile).first);
      await $.tester.pump(const Duration(milliseconds: 500));

      // Wait for room screen to load — thread auto-selects, enabling
      // the chat input. On macOS the test window is below the 840px
      // desktop breakpoint so HistoryPanel is in the drawer; the chat
      // input is in the body and accessible without opening the drawer.
      final chatInputFinder = find.byType(TextField);
      await waitForCondition(
        $.tester,
        condition: () => $.tester.any(chatInputFinder),
        timeout: const Duration(seconds: 10),
        failureMessage: 'Chat TextField did not appear within 10s',
      );

      // Enter a unique test message.
      final testMessage =
          'patrol-test-${DateTime.now().millisecondsSinceEpoch}';

      await $.tester.enterText(chatInputFinder, testMessage);
      await $.tester.pump(const Duration(milliseconds: 200));

      // Tap send button.
      await $.tester.tap(find.byTooltip('Send message'));
      await $.tester.pump(const Duration(milliseconds: 200));

      // Log-driven wait for the AG-UI run to complete.
      await harness.waitForLog(
        'ActiveRun',
        'RUN_FINISHED',
        timeout: const Duration(seconds: 60),
      );

      // Pump to let UI update with response.
      await $.tester.pump(const Duration(milliseconds: 500));

      // At least 2 messages: user message + assistant response.
      expect(
        find.byType(ChatMessageWidget),
        findsAtLeast(2),
      );

      // White-box: verify AG-UI lifecycle events in logs.
      harness
        ..expectLog('ActiveRun', 'RUN_STARTED')
        ..expectLog('ActiveRun', 'TEXT_START:')
        ..expectLog('ActiveRun', 'RUN_FINISHED');

      // Pump extra frames for macOS rendering.
      await $.tester.pump(const Duration(seconds: 1));
    } catch (e) {
      harness.dumpLogs(last: 50);
      rethrow;
    } finally {
      harness.dispose();
    }
  });
}
