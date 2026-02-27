import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:soliplex_frontend/core/auth/auth_flow.dart';
import 'package:soliplex_frontend/core/auth/oidc_issuer.dart';
import 'package:soliplex_frontend/core/logging/loggers.dart';
import 'package:url_launcher/url_launcher.dart';

/// Desktop implementation of OIDC authentication using RFC 8252
/// loopback interface redirect.
///
/// Used on Windows and Linux where `flutter_appauth` is unavailable.
/// Opens the system browser for authentication, runs a temporary
/// loopback HTTP server to capture the authorization code, then
/// exchanges the code for tokens via HTTP POST.
///
/// Security measures (per RFC 8252 and RFC 7636):
/// - **PKCE S256**: Prevents authorization code interception
/// - **State parameter**: CSRF protection (RFC 6749 Section 10.12)
/// - **Loopback only**: Binds to 127.0.0.1, not 0.0.0.0 (Section 8.3)
/// - **Ephemeral port**: Random OS-assigned port (Section 7.3)
/// - **Origin validation**: Discovery endpoints checked against issuer
class DesktopAuthFlow implements AuthFlow {
  @override
  bool get isWeb => false;

  @override
  Future<AuthResult> authenticate(OidcIssuer issuer) async {
    // 1. Fetch OIDC discovery document
    final discovery = await _fetchDiscovery(issuer.discoveryUrl);
    final authorizationEndpoint =
        discovery['authorization_endpoint'] as String?;
    final tokenEndpoint = discovery['token_endpoint'] as String?;

    if (authorizationEndpoint == null || tokenEndpoint == null) {
      throw const AuthException(
        'OIDC discovery missing required endpoints',
      );
    }

    // Validate endpoint origins match the issuer
    _validateEndpointOrigin(authorizationEndpoint, issuer.serverUrl);
    _validateEndpointOrigin(tokenEndpoint, issuer.serverUrl);

    // 2. Generate PKCE code verifier and challenge (RFC 7636)
    final codeVerifier = _generateCodeVerifier();
    final codeChallenge = _generateCodeChallenge(codeVerifier);

    // 3. Generate state parameter for CSRF protection (RFC 6749 §10.12)
    final state = _generateState();

    // 4. Start loopback server on random ephemeral port (RFC 8252 §7.3)
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final port = server.port;
    final redirectUri = 'http://127.0.0.1:$port/callback';

    try {
      // 5. Open system browser to authorization endpoint
      final authUri = Uri.parse(authorizationEndpoint).replace(
        queryParameters: {
          'response_type': 'code',
          'client_id': issuer.clientId,
          'redirect_uri': redirectUri,
          'scope': issuer.scope,
          'code_challenge': codeChallenge,
          'code_challenge_method': 'S256',
          'state': state,
        },
      );

      Loggers.auth.info('Desktop auth: opening browser for login');
      final launched = await launchUrl(
        authUri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        throw const AuthException(
          'Failed to open browser for authentication',
        );
      }

      // 6. Wait for the browser to redirect back with the auth code
      final code = await _waitForAuthCode(server, expectedState: state);

      // 7. Exchange code for tokens
      return _exchangeCodeForTokens(
        tokenEndpoint: tokenEndpoint,
        code: code,
        redirectUri: redirectUri,
        clientId: issuer.clientId,
        codeVerifier: codeVerifier,
      );
    } finally {
      await server.close();
    }
  }

  @override
  Future<void> endSession({
    required String discoveryUrl,
    required String? endSessionEndpoint,
    required String idToken,
    required String clientId,
  }) async {
    // Resolve end_session_endpoint from discovery if not cached
    var logoutUrl = endSessionEndpoint;
    if (logoutUrl == null) {
      try {
        final discovery = await _fetchDiscovery(discoveryUrl);
        logoutUrl = discovery['end_session_endpoint'] as String?;
      } on Exception catch (e) {
        Loggers.auth.debug(
          'Desktop auth: failed to fetch discovery for logout: '
          '${e.runtimeType}',
        );
      }
    }

    if (logoutUrl == null) {
      Loggers.auth.debug(
        'Desktop auth: no end_session_endpoint, '
        'local logout only',
      );
      return;
    }

    final logoutUri = Uri.parse(logoutUrl).replace(
      queryParameters: {
        'client_id': clientId,
        if (idToken.isNotEmpty) 'id_token_hint': idToken,
      },
    );

    Loggers.auth.info('Desktop auth: opening browser for logout');
    await launchUrl(
      logoutUri,
      mode: LaunchMode.externalApplication,
    );
  }

  /// Fetches and parses the OIDC discovery document as raw JSON.
  Future<Map<String, dynamic>> _fetchDiscovery(
    String discoveryUrl,
  ) async {
    final response = await http.get(Uri.parse(discoveryUrl));
    if (response.statusCode != 200) {
      throw AuthException(
        'OIDC discovery failed (HTTP ${response.statusCode})',
      );
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Validates that an endpoint URL originates from the expected
  /// issuer origin (scheme + host + port).
  void _validateEndpointOrigin(String endpoint, String issuerUrl) {
    final endpointUri = Uri.parse(endpoint);
    final issuerUri = Uri.parse(issuerUrl);
    if (endpointUri.scheme != issuerUri.scheme ||
        endpointUri.host != issuerUri.host ||
        endpointUri.port != issuerUri.port) {
      throw AuthException(
        'OIDC endpoint origin mismatch: '
        'expected ${issuerUri.origin}, got ${endpointUri.origin}',
      );
    }
  }

  /// Waits for the IdP to redirect the browser to the loopback server.
  ///
  /// Validates the `state` parameter matches the expected value
  /// (CSRF protection). Returns the authorization code.
  Future<String> _waitForAuthCode(
    HttpServer server, {
    required String expectedState,
  }) async {
    final request = await server.first.timeout(
      const Duration(minutes: 5),
      onTimeout: () {
        throw const AuthException(
          'Authentication timed out. Please try again.',
        );
      },
    );

    final uri = request.requestedUri;

    // Check for error response
    final error = uri.queryParameters['error'];
    if (error != null) {
      final description = uri.queryParameters['error_description'] ?? error;
      _sendHtmlResponse(
        request,
        'Authentication failed: $description. '
        'You can close this tab.',
      );
      throw const AuthException(
        'Authentication failed. Please try again.',
      );
    }

    // Validate state parameter (CSRF protection)
    final returnedState = uri.queryParameters['state'];
    if (returnedState != expectedState) {
      _sendHtmlResponse(
        request,
        'Authentication failed: invalid state parameter. '
        'You can close this tab.',
      );
      throw const AuthException(
        'Authentication failed: state mismatch (possible CSRF)',
      );
    }

    final code = uri.queryParameters['code'];
    if (code == null) {
      _sendHtmlResponse(
        request,
        'Authentication failed: no authorization code received. '
        'You can close this tab.',
      );
      throw const AuthException(
        'No authorization code received from IdP',
      );
    }

    _sendHtmlResponse(
      request,
      'Authentication successful! You can close this tab '
      'and return to the app.',
    );
    return code;
  }

  /// Sends a simple HTML page to the browser and closes the request.
  void _sendHtmlResponse(HttpRequest request, String message) {
    request.response
      ..statusCode = HttpStatus.ok
      ..headers.contentType = ContentType.html
      ..write(_buildHtmlPage(message))
      ..close();
  }

  static String _buildHtmlPage(String message) {
    final buffer = StringBuffer()
      ..write('<!DOCTYPE html>')
      ..write('<html><body style="font-family:system-ui; ')
      ..write('text-align:center; padding:40px">')
      ..write('<p>')
      ..write(message)
      ..write('</p></body></html>');
    return buffer.toString();
  }

  /// Exchanges the authorization code for tokens via HTTP POST.
  Future<AuthResult> _exchangeCodeForTokens({
    required String tokenEndpoint,
    required String code,
    required String redirectUri,
    required String clientId,
    required String codeVerifier,
  }) async {
    final response = await http.post(
      Uri.parse(tokenEndpoint),
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: {
        'grant_type': 'authorization_code',
        'code': code,
        'redirect_uri': redirectUri,
        'client_id': clientId,
        'code_verifier': codeVerifier,
      },
    );

    if (response.statusCode != 200) {
      Loggers.auth.error(
        'Token exchange failed (HTTP ${response.statusCode})',
      );
      throw const AuthException(
        'Token exchange failed. Please try again.',
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final accessToken = json['access_token'] as String?;
    if (accessToken == null) {
      throw const AuthException(
        'Token response missing access_token',
      );
    }

    final expiresIn = json['expires_in'] as int?;

    return AuthResult(
      accessToken: accessToken,
      refreshToken: json['refresh_token'] as String?,
      idToken: json['id_token'] as String?,
      expiresAt: expiresIn != null
          ? DateTime.now().add(Duration(seconds: expiresIn))
          : null,
    );
  }

  /// Generates a cryptographically random PKCE code verifier.
  ///
  /// Per RFC 7636, the verifier is 43-128 unreserved characters:
  /// [A-Z] / [a-z] / [0-9] / "-" / "." / "_" / "~".
  static String _generateCodeVerifier() {
    const length = 128;
    const charset = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopq'
        'rstuvwxyz0123456789-._~';
    final random = Random.secure();
    return List.generate(
      length,
      (_) => charset[random.nextInt(charset.length)],
    ).join();
  }

  /// Generates a PKCE S256 code challenge from the verifier.
  ///
  /// Per RFC 7636: BASE64URL(SHA256(code_verifier))
  static String _generateCodeChallenge(String verifier) {
    final bytes = utf8.encode(verifier);
    final digest = sha256.convert(bytes);
    return base64Url.encode(digest.bytes).replaceAll('=', '');
  }

  /// Generates a cryptographically random state parameter for CSRF
  /// protection (RFC 6749 Section 10.12).
  static String _generateState() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }
}
