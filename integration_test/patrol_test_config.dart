import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

/// Backend URL from --dart-define.
const backendUrl = String.fromEnvironment(
  'SOLIPLEX_BACKEND_URL',
  defaultValue: 'http://localhost:8000',
);

/// OIDC credentials from --dart-define (Phase C).
const oidcUsername = String.fromEnvironment('SOLIPLEX_OIDC_USERNAME');
const oidcPassword = String.fromEnvironment('SOLIPLEX_OIDC_PASSWORD');

/// OIDC issuer ID from --dart-define (must match a key in /api/login response).
const oidcIssuerId = String.fromEnvironment('SOLIPLEX_OIDC_ISSUER_ID');

/// Fail fast if backend is unreachable.
///
/// Uses /api/login which works in both no-auth and OIDC modes.
Future<void> verifyBackendOrFail(String url) async {
  try {
    final res = await http
        .get(Uri.parse('$url/api/login'))
        .timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) {
      fail('Backend returned ${res.statusCode} at $url/api/login');
    }
  } on TimeoutException {
    fail('Backend timed out at $url/api/login');
  } catch (e) {
    fail('Backend unreachable at $url: $e');
  }
}

/// Streaming-safe alternative to pumpAndSettle.
///
/// Phase B upgrades to harness.waitForLog() where possible.
Future<void> waitForCondition(
  WidgetTester tester, {
  required bool Function() condition,
  required Duration timeout,
  Duration step = const Duration(milliseconds: 200),
  String? failureMessage,
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(step);
    if (condition()) return;
  }
  fail(failureMessage ?? 'Timed out after $timeout');
}

/// Find a widget of [type] containing text that includes [substring].
///
/// Useful when room/tile names may change (e.g. "Gemini 2.5 Flash")
/// and an exact-match finder would be brittle.
Finder findByTextContaining(Type type, String substring) {
  return find.ancestor(
    of: find.textContaining(substring),
    matching: find.byType(type),
  );
}

/// Workaround for Flutter macOS keyboard assertion bug.
///
/// On web, this bug does not occur — skip to avoid unnecessary error
/// handler wrapping.
void ignoreKeyboardAssertions() {
  if (kIsWeb) return;

  final originalOnError = FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails details) {
    final msg = details.exception.toString();
    if (msg.contains('_pressedKeys.containsKey') ||
        msg.contains('KeyUpEvent is dispatched')) {
      return;
    }
    originalOnError?.call(details);
  };
}
