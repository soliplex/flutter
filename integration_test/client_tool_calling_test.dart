import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:soliplex_client/soliplex_client.dart';
import 'package:soliplex_frontend/core/providers/api_provider.dart';
import 'package:soliplex_frontend/features/chat/widgets/chat_message_widget.dart';
import 'package:soliplex_frontend/features/rooms/widgets/room_list_tile.dart';

import 'patrol_helpers.dart';
import 'patrol_test_config.dart';
import 'test_log_harness.dart';

void main() {
  late TestLogHarness harness;

  patrolTest('chat - client tool call returns secret code', ($) async {
    await verifyBackendOrFail(backendUrl);
    ignoreKeyboardAssertions();

    harness = TestLogHarness();
    await harness.initialize();

    try {
      // Register a get_secret_code tool that returns "42".
      final registry = const ToolRegistry().register(
        ClientTool(
          definition: const Tool(
            name: 'get_secret_code',
            description: 'Returns a secret code number.',
            parameters: {
              'type': 'object',
              'properties': <String, dynamic>{},
            },
          ),
          executor: (_) async => '42',
        ),
      );

      await pumpTestApp(
        $,
        harness,
        extraOverrides: [
          toolRegistryProvider.overrideWithValue(registry),
        ],
      );

      // Wait for rooms to load.
      await waitForCondition(
        $.tester,
        condition: () => $.tester.any(find.byType(RoomListTile)),
        timeout: const Duration(seconds: 10),
        failureMessage: 'RoomListTile did not appear within 10s',
      );

      // Find Gemini room (faster model).
      final geminiTile = findByTextContaining(RoomListTile, 'Gemini');
      await waitForCondition(
        $.tester,
        condition: () => $.tester.any(geminiTile),
        timeout: const Duration(seconds: 5),
        failureMessage: 'Gemini room not found',
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

      // Send prompt that triggers tool call.
      await $.tester.enterText(
        chatInputFinder,
        'What is the secret code? Use get_secret_code and only say '
        'the answer nothing else',
      );
      await $.tester.pump(const Duration(milliseconds: 200));

      await $.tester.tap(find.byTooltip('Send message'));
      await $.tester.pump(const Duration(milliseconds: 200));

      // Log-driven waits for full tool-call lifecycle (ordered).
      await harness.waitForLog(
        'ActiveRun',
        'TOOL_START: get_secret_code',
        timeout: const Duration(seconds: 60),
      );
      await harness.waitForLog(
        'ActiveRun',
        'Tool completed: get_secret_code',
        timeout: const Duration(seconds: 30),
      );
      await harness.waitForLog(
        'ActiveRun',
        'Continuation run',
        timeout: const Duration(seconds: 30),
      );
      await harness.waitForLog(
        'ActiveRun',
        'RUN_FINISHED',
        timeout: const Duration(seconds: 60),
      );

      // Pump to let UI update with response.
      await $.tester.pump(const Duration(milliseconds: 500));

      // --- Assertions ---

      // Tool lifecycle logs.
      harness
        ..expectLog('ActiveRun', 'TOOL_START: get_secret_code')
        ..expectLog('ActiveRun', 'TOOL_END')
        ..expectLog('ActiveRun', 'Tool completed: get_secret_code')
        ..expectLog('ActiveRun', 'Continuation run')
        ..expectLog('ActiveRun', 'RUN_FINISHED');

      // LLM response contains the secret code.
      expect(find.textContaining('42'), findsWidgets);

      // At least 2 messages rendered (user + assistant).
      expect(find.byType(ChatMessageWidget), findsAtLeast(2));

      // Performance: first RUN_STARTED → last RUN_FINISHED < 90s.
      final records = harness.sink.records;
      final startIndex = records.indexWhere(
        (r) => r.loggerName == 'ActiveRun' && r.message.contains('RUN_STARTED'),
      );
      final endIndex = records.lastIndexWhere(
        (r) =>
            r.loggerName == 'ActiveRun' && r.message.contains('RUN_FINISHED'),
      );
      expect(startIndex, greaterThanOrEqualTo(0), reason: 'RUN_STARTED found');
      expect(endIndex, greaterThan(startIndex), reason: 'RUN_FINISHED found');
      final runDuration =
          records[endIndex].timestamp.difference(records[startIndex].timestamp);
      expect(
        runDuration,
        lessThan(const Duration(seconds: 90)),
        reason: 'Two-run tool call took ${runDuration.inSeconds}s (limit: 90s)',
      );

      // Pump extra frames for macOS rendering.
      await $.tester.pump(const Duration(seconds: 1));
    } catch (e) {
      harness.dumpLogs(last: 80);
      rethrow;
    } finally {
      harness
        ..expectNoErrors()
        ..dispose();
    }
  });
}
