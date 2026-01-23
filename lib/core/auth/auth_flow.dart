import 'package:soliplex_frontend/core/auth/auth_flow_native.dart'
    if (dart.library.js_interop) 'package:soliplex_frontend/core/auth/auth_flow_web.dart'
    as impl;
import 'package:soliplex_frontend/core/auth/oidc_issuer.dart';

/// Result of a successful authentication.
class AuthResult {
  const AuthResult({
    required this.accessToken,
    this.refreshToken,
    this.idToken,
    this.expiresAt,
  });

  final String accessToken;
  final String? refreshToken;
  final String? idToken;
  final DateTime? expiresAt;
}

/// Authentication exception.
class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => 'AuthException: $message';
}

/// Thrown when web auth triggers a redirect to the IdP.
///
/// On web, [AuthFlow.authenticate] redirects the browser to the IdP login page
/// and throws this exception. The full flow is:
/// 1. AuthNotifier.signIn saves PreAuthState to storage
/// 2. AuthFlow.authenticate redirects to BFF, throws AuthRedirectInitiated
/// 3. User authenticates with IdP, BFF redirects back with tokens in URL
/// 4. AuthCallbackScreen extracts tokens from URL params
/// 5. AuthCallbackScreen calls AuthNotifier.completeWebAuth with tokens
///
/// This exception makes the web auth flow type-honest: instead of returning a
/// never-completing Future<AuthResult>, we throw to indicate "auth initiated,
/// completion via callback."
class AuthRedirectInitiated implements Exception {
  const AuthRedirectInitiated();

  @override
  String toString() => 'AuthRedirectInitiated: Browser redirecting to IdP';
}

/// Platform authentication service.
///
/// Handles OIDC authentication with platform-specific implementations:
/// - Native (iOS/macOS): Opens system browser via flutter_appauth
/// - Web: Redirects to backend BFF endpoint which handles OAuth flow
abstract class AuthFlow {
  /// Authenticate using OIDC.
  ///
  /// Returns [AuthResult] on success, throws [AuthException] on failure.
  Future<AuthResult> authenticate(OidcIssuer issuer);

  /// End the OIDC session.
  ///
  /// Platform behavior:
  /// - Native: Ends session via flutter_appauth (fetches endpoint from
  ///   discoveryUrl)
  /// - Web: Redirects to cached endSessionEndpoint (if available)
  ///
  /// Parameters:
  /// - [discoveryUrl]: OIDC discovery URL (native fetches end_session_endpoint)
  /// - [endSessionEndpoint]: Cached endpoint URL (web uses this directly)
  /// - [idToken]: ID token for id_token_hint parameter
  /// - [clientId]: Client ID for logout request
  Future<void> endSession({
    required String discoveryUrl,
    required String? endSessionEndpoint,
    required String idToken,
    required String clientId,
  });

  /// Whether this is a web platform implementation.
  ///
  /// Used to determine if web-specific callback handling is needed.
  bool get isWeb;
}

/// Creates a platform-appropriate [AuthFlow] implementation.
///
/// [backendBaseUrl] is the backend server URL for BFF endpoints (web only).
/// On native platforms, this parameter is ignored.
///
/// [redirectScheme] is the OAuth redirect URI scheme for native platforms.
/// Must match the scheme registered in platform configs (iOS Info.plist,
/// Android build.gradle.kts). Ignored on web.
AuthFlow createAuthFlow({String? backendBaseUrl, String? redirectScheme}) =>
    impl.createAuthFlow(
      backendBaseUrl: backendBaseUrl,
      redirectScheme: redirectScheme,
    );
