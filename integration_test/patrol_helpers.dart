import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
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
import 'package:soliplex_frontend/features/log_viewer/log_file_saver.dart';

import 'patrol_test_config.dart';
import 'test_log_harness.dart';

/// No-op file saver that prevents OS share sheet / browser download
/// from opening during Patrol tests.
class NoOpLogFileSaver implements LogFileSaver {
  @override
  Future<String?> save({
    required String filename,
    required Uint8List bytes,
    Rect? shareOrigin,
  }) async =>
      null;
}

/// Spy file saver that captures arguments for E2E verification.
///
/// Returns a fake path so the screen shows its success SnackBar,
/// allowing the test to assert the full UI flow without triggering
/// the OS share sheet.
class SpyLogFileSaver implements LogFileSaver {
  String? lastFilename;
  Uint8List? lastBytes;
  Rect? lastShareOrigin;

  @override
  Future<String?> save({
    required String filename,
    required Uint8List bytes,
    Rect? shareOrigin,
  }) async {
    lastFilename = filename;
    lastBytes = bytes;
    lastShareOrigin = shareOrigin;
    return '/mock/export/$filename';
  }
}

/// No-auth notifier that immediately resolves to [NoAuthRequired].
///
/// Skips the real [AuthNotifier.build] which fires _restoreSession and
/// needs storage/refresh providers. Safe because no-auth mode never
/// calls signIn/signOut/tryRefresh.
class NoAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => const NoAuthRequired();
}

/// Pre-authenticated notifier that returns ROPC-seeded tokens.
///
/// Skips [AuthNotifier.build] entirely (no _restoreSession, no storage/
/// refresh providers). Safe because fresh ROPC tokens (5min expiry) never
/// trigger refresh during ~30s test runs.
class PreAuthenticatedNotifier extends AuthNotifier {
  PreAuthenticatedNotifier(this._tokens);

  final Authenticated _tokens;

  @override
  AuthState build() => _tokens;
}

/// ROPC token exchange against an OIDC-enabled backend.
///
/// Steps:
/// 1. GET `/api/login` → discover issuer serverUrl + clientId
/// 2. GET `<serverUrl>/.well-known/openid-configuration` → token_endpoint
/// 3. POST token_endpoint with `grant_type=password`
///
/// Returns [Authenticated] with real tokens or fails the test.
Future<Authenticated> performRopcExchange({
  required String baseUrl,
  required String username,
  required String password,
  required String issuerId,
}) async {
  // 1. Discover issuer from backend.
  final loginRes = await http
      .get(Uri.parse('$baseUrl/api/login'))
      .timeout(const Duration(seconds: 8));
  if (loginRes.statusCode != 200) {
    fail('/api/login returned ${loginRes.statusCode}');
  }
  final loginJson = jsonDecode(loginRes.body) as Map<String, dynamic>;
  if (loginJson.isEmpty) {
    fail('/api/login returned no providers — backend may be in no-auth mode');
  }

  if (!loginJson.containsKey(issuerId)) {
    fail(
      'Issuer "$issuerId" not found in /api/login. '
      'Available: ${loginJson.keys.join(', ')}',
    );
  }
  final issuerData = loginJson[issuerId] as Map<String, dynamic>;
  final serverUrl = issuerData['server_url'] as String;
  final clientId = issuerData['client_id'] as String;

  // 2. OIDC discovery → token_endpoint.
  final discoveryUrl = '$serverUrl/.well-known/openid-configuration';
  final discoveryRes = await http
      .get(Uri.parse(discoveryUrl))
      .timeout(const Duration(seconds: 8));
  if (discoveryRes.statusCode != 200) {
    fail('OIDC discovery returned ${discoveryRes.statusCode}');
  }
  final discoveryJson = jsonDecode(discoveryRes.body) as Map<String, dynamic>;
  final tokenEndpoint = discoveryJson['token_endpoint'] as String?;
  if (tokenEndpoint == null) {
    fail('OIDC discovery missing token_endpoint');
  }

  // 3. ROPC exchange.
  final tokenRes = await http.post(
    Uri.parse(tokenEndpoint),
    headers: {'Content-Type': 'application/x-www-form-urlencoded'},
    body: {
      'grant_type': 'password',
      'client_id': clientId,
      'username': username,
      'password': password,
      'scope': 'openid',
    },
  ).timeout(const Duration(seconds: 10));

  if (tokenRes.statusCode != 200) {
    fail(
      'ROPC exchange failed (${tokenRes.statusCode}): ${tokenRes.body}\n'
      'Hint: Keycloak "Direct Access Grants" must be enabled on the client.',
    );
  }

  final tokenJson = jsonDecode(tokenRes.body) as Map<String, dynamic>;
  final expiresIn = (tokenJson['expires_in'] as num?)?.toInt() ?? 300;

  return Authenticated(
    accessToken: tokenJson['access_token'] as String,
    refreshToken: (tokenJson['refresh_token'] as String?) ?? '',
    expiresAt: DateTime.now().add(Duration(seconds: expiresIn)),
    issuerId: issuerId,
    issuerDiscoveryUrl: discoveryUrl,
    clientId: clientId,
    idToken: (tokenJson['id_token'] as String?) ?? '',
  );
}

/// Pump [SoliplexApp] with no-auth provider overrides.
///
/// Standard set of overrides for Patrol E2E tests running against a
/// `--no-auth-mode` backend. Pass a [logFileSaver] (e.g. [SpyLogFileSaver])
/// to inspect export calls; defaults to [NoOpLogFileSaver].
Future<void> pumpTestApp(
  PatrolIntegrationTester $,
  TestLogHarness harness, {
  LogFileSaver? logFileSaver,
}) async {
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
        logFileSaverProvider
            .overrideWithValue(logFileSaver ?? NoOpLogFileSaver()),
      ],
      child: const SoliplexApp(),
    ),
  );
}

/// Pump [SoliplexApp] with pre-authenticated provider overrides.
///
/// Same overrides as [pumpTestApp] but uses [PreAuthenticatedNotifier]
/// to seed real OIDC tokens from ROPC exchange.
Future<void> pumpAuthenticatedTestApp(
  PatrolIntegrationTester $,
  TestLogHarness harness, {
  required Authenticated tokens,
  LogFileSaver? logFileSaver,
}) async {
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
        authProvider.overrideWith(() => PreAuthenticatedNotifier(tokens)),
        logFileSaverProvider
            .overrideWithValue(logFileSaver ?? NoOpLogFileSaver()),
      ],
      child: const SoliplexApp(),
    ),
  );
}
