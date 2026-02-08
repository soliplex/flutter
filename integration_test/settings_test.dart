import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:soliplex_frontend/features/inspector/widgets/http_event_tile.dart';
import 'package:soliplex_frontend/version.dart';

import 'patrol_helpers.dart';
import 'patrol_test_config.dart';
import 'test_log_harness.dart';

void main() {
  late TestLogHarness harness;

  patrolTest('settings - navigate and verify tiles (no-auth)', ($) async {
    await verifyBackendOrFail(backendUrl);
    ignoreKeyboardAssertions();

    harness = TestLogHarness();
    await harness.initialize();

    try {
      await pumpTestApp($, harness);

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

      // Frontend Version tile.
      expect(find.text('Frontend Version'), findsOneWidget);
      expect(find.text(soliplexVersion), findsOneWidget);

      // Backend URL tile shows the configured URL.
      expect(find.text('Backend URL'), findsOneWidget);
      expect(find.text(backendUrl), findsOneWidget);

      // Backend Version tile exists.
      expect(find.text('Backend Version'), findsOneWidget);

      // Network Requests tile exists with a count.
      expect(find.text('Network Requests'), findsOneWidget);
      expect(find.textContaining('requests captured'), findsOneWidget);

      // No-auth mode: shows "No Authentication" section.
      expect(find.text('No Authentication'), findsOneWidget);
      expect(
        find.text('Backend does not require login'),
        findsOneWidget,
      );
      expect(find.text('Disconnect'), findsOneWidget);

      // White-box: config provider loaded.
      harness.expectLog('Router', 'redirect called');

      // Pump extra frames for UI visibility.
      for (var i = 0; i < 5; i++) {
        await $.tester.pump(const Duration(milliseconds: 200));
      }
    } catch (e) {
      harness.dumpLogs(last: 50);
      rethrow;
    } finally {
      harness
        ..expectNoErrors()
        ..dispose();
    }
  });

  patrolTest('settings - network log viewer tabs (no-auth)', ($) async {
    await verifyBackendOrFail(backendUrl);
    ignoreKeyboardAssertions();

    harness = TestLogHarness();
    await harness.initialize();

    try {
      await pumpTestApp($, harness);

      // Wait for app to boot (generates HTTP traffic).
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

      // Tap "Network Requests" tile to open the log viewer.
      await $.tester.tap(find.text('Network Requests'));
      await $.tester.pump(const Duration(milliseconds: 500));

      // Header shows request count > 0.
      expect(find.textContaining('Requests ('), findsOneWidget);

      // At least one request tile is visible (app made HTTP calls on boot).
      expect(find.byType(HttpEventTile), findsWidgets);

      // Tap first request tile to open the detail view.
      await $.tester.tap(find.byType(HttpEventTile).first);
      await $.tester.pump(const Duration(milliseconds: 500));

      // Wait for detail view tabs to appear (handles both narrow page
      // navigation and wide master-detail auto-selection).
      final tabFinder = find.descendant(
        of: find.byType(TabBar),
        matching: find.text('Request'),
      );
      await waitForCondition(
        $.tester,
        condition: () => $.tester.any(tabFinder),
        timeout: const Duration(seconds: 5),
        failureMessage: 'Request tab did not appear in detail view',
      );

      // Verify all 3 tabs exist.
      expect(
        find.descendant(
          of: find.byType(TabBar),
          matching: find.text('Request'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(TabBar),
          matching: find.text('Response'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: find.byType(TabBar), matching: find.text('curl')),
        findsOneWidget,
      );

      // Tap "Response" tab.
      await $.tester.tap(
        find.descendant(
          of: find.byType(TabBar),
          matching: find.text('Response'),
        ),
      );
      await $.tester.pump(const Duration(milliseconds: 300));

      // Response tab shows some content (status metadata or stream info).
      // Verify we're on the Response tab by checking tab is still visible.
      expect(
        find.descendant(
          of: find.byType(TabBar),
          matching: find.text('Response'),
        ),
        findsOneWidget,
      );

      // Tap "curl" tab.
      await $.tester.tap(
        find.descendant(of: find.byType(TabBar), matching: find.text('curl')),
      );
      await $.tester.pump(const Duration(milliseconds: 300));

      // curl tab shows the command heading and copy button.
      expect(find.text('curl command'), findsOneWidget);
      expect(find.byTooltip('Copy to clipboard'), findsOneWidget);

      // Tap back to "Request" tab to confirm tab switching round-trips.
      await $.tester.tap(
        find.descendant(
          of: find.byType(TabBar),
          matching: find.text('Request'),
        ),
      );
      await $.tester.pump(const Duration(milliseconds: 300));

      // In wide layout the clear button is already visible. In narrow
      // layout we are on the detail page and must pop back to the list
      // first. Check for the clear button BEFORE touching "Back" — the
      // inspector's own back button would navigate to Settings, not the
      // list, which is the wrong direction.
      final clearButton = find.byTooltip('Clear all requests');
      if (!$.tester.any(clearButton)) {
        // Narrow layout: pop the detail page to reveal the list + clear btn.
        final backButton = find.byTooltip('Back');
        if ($.tester.any(backButton)) {
          await $.tester.tap(backButton);
          await $.tester.pump(const Duration(milliseconds: 500));
        }
        await waitForCondition(
          $.tester,
          condition: () => $.tester.any(clearButton),
          timeout: const Duration(seconds: 5),
          failureMessage: 'Clear button not found after back navigation',
        );
      }

      // Clear all requests.
      await $.tester.tap(clearButton);
      await $.tester.pump(const Duration(milliseconds: 500));

      // Verify empty state.
      expect(find.text('No HTTP requests yet'), findsOneWidget);

      // Pump extra frames for UI visibility.
      for (var i = 0; i < 5; i++) {
        await $.tester.pump(const Duration(milliseconds: 200));
      }
    } catch (e) {
      harness.dumpLogs(last: 50);
      rethrow;
    } finally {
      harness
        ..expectNoErrors()
        ..dispose();
    }
  });
}
