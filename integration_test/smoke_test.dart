import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:soliplex_frontend/app.dart';
import 'package:soliplex_frontend/core/auth/auth_notifier.dart';
import 'package:soliplex_frontend/core/auth/auth_provider.dart';
import 'package:soliplex_frontend/core/auth/auth_state.dart';
import 'package:soliplex_frontend/core/logging/logging_provider.dart';
import 'package:soliplex_frontend/core/models/logo_config.dart';
import 'package:soliplex_frontend/core/models/soliplex_config.dart';
import 'package:soliplex_frontend/core/providers/config_provider.dart';
import 'package:soliplex_frontend/core/providers/shell_config_provider.dart';

import 'patrol_test_config.dart';
import 'test_log_harness.dart';

/// No-auth notifier that immediately resolves to [NoAuthRequired].
///
/// Skips the real [AuthNotifier.build] which fires _restoreSession and
/// needs storage/refresh providers. Safe because no-auth mode never
/// calls signIn/signOut/tryRefresh.
class _NoAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => const NoAuthRequired();
}

void main() {
  late TestLogHarness harness;

  patrolTest('smoke - backend reachable and app boots', ($) async {
    await verifyBackendOrFail(backendUrl);
    ignoreKeyboardAssertions();

    harness = TestLogHarness();
    await harness.initialize();

    try {
      await $.pumpWidget(
        ProviderScope(
          overrides: [
            preloadedPrefsProvider.overrideWithValue(harness.prefs),
            memorySinkProvider.overrideWithValue(harness.sink),
            shellConfigProvider.overrideWithValue(
              const SoliplexConfig(
                logo: LogoConfig.soliplex,
                oauthRedirectScheme: 'ai.soliplex.client',
              ),
            ),
            preloadedBaseUrlProvider.overrideWithValue(backendUrl),
            authProvider.overrideWith(_NoAuthNotifier.new),
          ],
          child: const SoliplexApp(),
        ),
      );

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
      harness.expectLog('Router', 'redirect called');

      // Pump a few extra frames so the rendered UI is
      // visible in the macOS window during the test run.
      await $.tester.pump(const Duration(seconds: 1));
    } catch (e) {
      harness.dumpLogs(last: 50);
      rethrow;
    } finally {
      harness.dispose();
    }
  });
}
