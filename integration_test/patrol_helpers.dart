import 'package:flutter_riverpod/flutter_riverpod.dart';
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
class NoAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => const NoAuthRequired();
}

/// Pump [SoliplexApp] with no-auth provider overrides.
///
/// Standard set of 5 overrides for Patrol E2E tests running against a
/// `--no-auth-mode` backend.
Future<void> pumpTestApp(
  PatrolIntegrationTester $,
  TestLogHarness harness,
) async {
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
        authProvider.overrideWith(NoAuthNotifier.new),
      ],
      child: const SoliplexApp(),
    ),
  );
}
