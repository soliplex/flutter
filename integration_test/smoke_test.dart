import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'patrol_helpers.dart';
import 'patrol_test_config.dart';
import 'test_log_harness.dart';

void main() {
  late TestLogHarness harness;

  patrolTest('smoke - backend reachable and app boots', ($) async {
    await verifyBackendOrFail(backendUrl);
    ignoreKeyboardAssertions();

    harness = TestLogHarness();
    await harness.initialize();

    try {
      await pumpTestApp($, harness);

      // Pump frames to let the app initialize and route.
      // Cannot use pumpAndSettle — SSE streams prevent settling.
      await waitForCondition(
        $.tester,
        condition: () => $.tester.any(find.byIcon(Icons.settings)),
        timeout: const Duration(seconds: 10),
        failureMessage: 'App did not boot to main UI within 10s',
      );

      // Verify the router ran (proves full boot sequence: binding → logging
      // → auth → router → screen). Log-based assertion from the harness.
      harness
        ..expectLog('Router', 'redirect called')

        // Phase D: verify app picked up the correct runtime configuration.
        ..expectLog('Config', backendUrl);

      // Pump extra frames so the rendered UI is visible in the macOS window.
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
