import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soliplex_client/soliplex_client.dart' hide AuthException;
import 'package:soliplex_frontend/core/auth/auth_flow.dart'
    show AuthException, AuthFlow, AuthRedirectInitiated;
import 'package:soliplex_frontend/core/auth/auth_provider.dart';
import 'package:soliplex_frontend/core/auth/auth_state.dart';
import 'package:soliplex_frontend/core/auth/auth_storage.dart';
import 'package:soliplex_frontend/core/auth/oidc_issuer.dart';
import 'package:soliplex_frontend/core/logging/loggers.dart';
import 'package:soliplex_frontend/core/providers/api_provider.dart';

/// Notifier for managing authentication state.
///
/// Handles sign in, sign out, session restoration, and token refresh.
///
/// Implements [TokenRefresher] to provide refresh capabilities to
/// RefreshingHttpClient without tight coupling.
///
/// ## Dependency Injection
///
/// - [_storage] and [_refreshService]: `late final` fields initialized once
///   in [build] - these don't change based on config.
/// - [_authFlow]: Getter that reads fresh from provider each time - picks up
///   URL changes when user switches backends.
///
/// **Testing:** Override [authStorageProvider] and
/// [tokenRefreshServiceProvider] in tests to inject mocks.
class AuthNotifier extends Notifier<AuthState> implements TokenRefresher {
  late final AuthStorage _storage;
  late final TokenRefreshService _refreshService;

  /// Get the current auth flow (picks up latest config URL).
  AuthFlow get _authFlow => ref.read(authFlowProvider);

  @override
  AuthState build() {
    _storage = ref.read(authStorageProvider);
    _refreshService = ref.read(tokenRefreshServiceProvider);

    // Fire-and-forget: _restoreSession runs async while we return AuthLoading.
    // Any refresh calls during restore fail gracefully (state is not
    // Authenticated yet) and will succeed after restore completes.
    // Defense-in-depth: catch any unhandled errors and transition to
    // Unauthenticated to avoid being stuck in AuthLoading.
    _restoreSession().catchError((Object e) {
      Loggers.auth.error('Unhandled restore error', error: e);
      state = const Unauthenticated();
    });
    return const AuthLoading();
  }

  Future<void> _restoreSession() async {
    final Authenticated? tokens;
    try {
      tokens = await _storage.loadTokens();
    } on Exception catch (e) {
      // Storage unavailable (keychain locked, permissions, corruption)
      // Policy: treat as unauthenticated rather than stuck in loading
      Loggers.auth.warning('Failed to restore session', error: e);
      state = const Unauthenticated();
      return;
    }

    if (tokens == null) {
      state = const Unauthenticated();
      return;
    }

    // Check if tokens are expired - attempt refresh before clearing
    if (tokens.isExpired) {
      Loggers.auth.info('Stored tokens expired, attempting refresh');
      final refreshed = await _tryRefreshStoredTokens(tokens);
      if (refreshed) {
        return;
      }
      // Refresh failed - clear and require re-login
      try {
        await _storage.clearTokens();
      } on Exception catch (e) {
        Loggers.auth.warning('Failed to clear expired tokens', error: e);
      }
      state = const Unauthenticated();
      return;
    }

    // Tokens already persisted—assign directly to state.
    state = tokens;
  }

  /// Attempt to refresh expired stored tokens during session restore.
  ///
  /// Returns `true` if refresh succeeded and state was updated
  /// (even if storage persistence failed—session works but won't survive
  /// restart).
  /// Returns `false` if refresh failed (caller should clear and logout).
  ///
  /// ## Failure Handling Policy (Startup vs Runtime)
  ///
  /// This method treats ALL failures the same (return false → logout), unlike
  /// [tryRefresh] which distinguishes between failure types. This asymmetry
  /// is intentional:
  ///
  /// **At startup:** We're trying to *establish* trust from stored credentials.
  /// If we can't validate tokens (for any reason—network, revoked, etc.), we
  /// have nothing useful. Failing fast with "please log in" is clearer than
  /// pretending auth succeeded when we can't verify it.
  ///
  /// **At runtime:** We already established trust. A transient network error
  /// shouldn't destroy a valid session. The user stays "authenticated" in
  /// local state and can retry when network returns.
  Future<bool> _tryRefreshStoredTokens(Authenticated tokens) async {
    final TokenRefreshResult result;
    try {
      result = await _refreshService.refresh(
        discoveryUrl: tokens.issuerDiscoveryUrl,
        refreshToken: tokens.refreshToken,
        clientId: tokens.clientId,
      );
    } on Exception catch (e) {
      Loggers.auth.warning('Refresh during restore threw', error: e);
      return false;
    }

    if (result is! TokenRefreshSuccess) {
      final failure = result as TokenRefreshFailure;
      Loggers.auth.warning('Refresh during restore failed: ${failure.reason}');
      return false;
    }

    await _applyRefreshResult(
      result,
      issuerId: tokens.issuerId,
      issuerDiscoveryUrl: tokens.issuerDiscoveryUrl,
      clientId: tokens.clientId,
      fallbackIdToken: tokens.idToken,
      endSessionEndpoint: tokens.endSessionEndpoint,
    );

    Loggers.auth.info('Session restored via token refresh');
    return true;
  }

  /// Apply a successful token refresh result to storage and state.
  ///
  /// Preserves idToken if the IdP didn't return a new one (per OIDC Core 1.0
  /// Section 12.2). Attempts to persist to storage but continues on failure
  /// (session works for current app run).
  Future<void> _applyRefreshResult(
    TokenRefreshSuccess result, {
    required String issuerId,
    required String issuerDiscoveryUrl,
    required String clientId,
    required String fallbackIdToken,
    required String? endSessionEndpoint,
  }) async {
    final newState = Authenticated(
      accessToken: result.accessToken,
      refreshToken: result.refreshToken,
      expiresAt: result.expiresAt,
      issuerId: issuerId,
      issuerDiscoveryUrl: issuerDiscoveryUrl,
      clientId: clientId,
      idToken: result.idToken ?? fallbackIdToken,
      endSessionEndpoint: endSessionEndpoint,
    );

    try {
      await _storage.saveTokens(newState);
    } on Exception catch (e) {
      Loggers.auth.warning('Failed to persist refreshed tokens', error: e);
    }

    state = newState;
  }

  /// Sign in with the given OIDC issuer.
  ///
  /// Opens system browser for authentication, exchanges code for tokens,
  /// and persists tokens to secure storage.
  ///
  /// Throws [AuthException] if authentication fails or if the IdP doesn't
  /// return an id_token (required for proper OIDC logout).
  Future<void> signIn(OidcIssuer issuer) async {
    // On web, save issuer info before redirect - needed to complete auth
    // after callback since the BFF doesn't return issuer metadata
    if (_authFlow.isWeb) {
      try {
        await _storage.savePreAuthState(
          PreAuthState(
            issuerId: issuer.id,
            discoveryUrl: issuer.discoveryUrl,
            clientId: issuer.clientId,
            createdAt: DateTime.now(),
          ),
        );
      } on Exception catch (e) {
        Loggers.auth.info('Failed to save pre-auth state: ${e.runtimeType}');
        throw const AuthException(
          'Unable to prepare sign in. Please try again.',
        );
      }
    }

    try {
      final result = await _authFlow.authenticate(issuer);

      final accessToken = result.accessToken;
      final refreshToken = result.refreshToken ?? '';
      final idToken = result.idToken;

      // id_token is required for proper OIDC logout
      if (idToken == null) {
        throw const AuthException('IdP did not return id_token');
      }

      var expiresAt = result.expiresAt;
      if (expiresAt == null) {
        const fallback = TokenRefreshService.fallbackTokenLifetime;
        Loggers.auth.info(
          'Token response missing expires_in; '
          'using ${fallback.inMinutes}min fallback',
        );
        expiresAt = DateTime.now().add(fallback);
      }

      final newState = Authenticated(
        accessToken: accessToken,
        refreshToken: refreshToken,
        expiresAt: expiresAt,
        issuerId: issuer.id,
        issuerDiscoveryUrl: issuer.discoveryUrl,
        clientId: issuer.clientId,
        idToken: idToken,
      );

      // Save tokens to secure storage (may fail on unsigned macOS builds)
      try {
        await _storage.saveTokens(newState);
      } on Exception catch (e, st) {
        Loggers.auth.warning(
          'Failed to persist tokens',
          error: e,
          stackTrace: st,
        );
        // Continue - auth works, just won't persist across restarts
      }

      state = newState;
    } on AuthRedirectInitiated {
      // Web: browser redirecting to IdP. Auth completes via callback URL.
      // State remains unchanged; completeWebAuth() handles completion.
      rethrow;
    } on AuthException {
      // Auth failed or was cancelled - stay unauthenticated
      state = const Unauthenticated();
      rethrow;
    }
  }

  /// Complete web authentication with tokens from callback URL.
  ///
  /// Called by AuthCallbackScreen after extracting tokens from the
  /// BFF redirect URL. Creates an authenticated state and persists tokens.
  ///
  /// Reads pre-auth state (saved before redirect) to get issuer metadata
  /// needed for token refresh. Throws [AuthException] if pre-auth state is
  /// missing (storage already rejects expired state).
  Future<void> completeWebAuth({
    required String accessToken,
    String? refreshToken,
    int? expiresIn,
  }) async {
    // Load pre-auth state saved before redirect.
    // Storage returns null if missing OR expired (expiry check is in storage).
    final preAuthState = await _storage.loadPreAuthState();
    if (preAuthState == null) {
      Loggers.auth.info('Pre-auth state missing or expired - invalid callback');
      throw const AuthException(
        'Authentication session expired. Please try signing in again.',
      );
    }

    // Clear pre-auth state immediately to prevent reuse
    try {
      await _storage.clearPreAuthState();
    } on Exception catch (e) {
      Loggers.auth.info('Failed to clear pre-auth state: ${e.runtimeType}');
    }

    // Fetch OIDC discovery to get end_session_endpoint for logout
    final endSessionEndpoint = await _fetchEndSessionEndpoint(
      preAuthState.discoveryUrl,
    );

    final expiresAt = expiresIn != null
        ? DateTime.now().add(Duration(seconds: expiresIn))
        : DateTime.now().add(TokenRefreshService.fallbackTokenLifetime);

    final newState = Authenticated(
      accessToken: accessToken,
      refreshToken: refreshToken ?? '',
      expiresAt: expiresAt,
      issuerId: preAuthState.issuerId,
      issuerDiscoveryUrl: preAuthState.discoveryUrl,
      clientId: preAuthState.clientId,
      // Web BFF flow doesn't return id_token - use empty string.
      // Logout still redirects to IdP, just without id_token_hint parameter.
      idToken: '',
      endSessionEndpoint: endSessionEndpoint,
    );

    try {
      await _storage.saveTokens(newState);
    } on Exception catch (e) {
      // TODO(auth): Surface warning to user when persist fails - session works
      // but won't survive browser refresh.
      Loggers.auth.info('Failed to persist web auth tokens: ${e.runtimeType}');
    }

    state = newState;
  }

  /// Fetches the end_session_endpoint from OIDC discovery.
  ///
  /// Returns null if discovery fails or the IdP doesn't support logout.
  /// Failure is non-fatal since logout will still clear local state.
  Future<String?> _fetchEndSessionEndpoint(String discoveryUrl) async {
    try {
      final httpClient = ref.read(baseHttpClientProvider);
      final discovery = await fetchOidcDiscoveryDocument(
        Uri.parse(discoveryUrl),
        httpClient,
      );
      return discovery.endSessionEndpoint?.toString();
    } on Exception catch (e) {
      Loggers.auth.info(
        'Failed to fetch end_session_endpoint: ${e.runtimeType}',
      );
      return null;
    }
  }

  /// Sign out, end IdP session, and clear tokens.
  ///
  /// Clears local tokens FIRST, then calls the IdP's end_session_endpoint.
  /// This order is critical for web where endSession redirects the page -
  /// tokens must be cleared before the redirect or they'll persist.
  Future<void> signOut() async {
    final current = state;

    // Clear local state FIRST (critical for web where endSession redirects)
    try {
      await _storage.clearTokens();
    } on Exception catch (e) {
      Loggers.auth.info('Failed to clear tokens on logout: ${e.runtimeType}');
    }
    state = const Unauthenticated(
      reason: UnauthenticatedReason.explicitSignOut,
    );

    // Then end IdP session (may redirect on web)
    if (current is Authenticated) {
      try {
        await _authFlow.endSession(
          discoveryUrl: current.issuerDiscoveryUrl,
          endSessionEndpoint: current.endSessionEndpoint,
          idToken: current.idToken,
          clientId: current.clientId,
        );
      } on Exception catch (e) {
        Loggers.auth.info('IdP session termination failed: ${e.runtimeType}');
      }
    }
  }

  /// Exit no-auth mode, returning to unauthenticated state.
  ///
  /// Call this when switching from a no-auth backend to an auth-required
  /// backend. Safe to call from any state - simply transitions to
  /// [Unauthenticated].
  ///
  /// Note: Does not clear tokens. If transitioning from [Authenticated],
  /// prefer [signOut] to properly end the IdP session and clear tokens.
  /// However, calling this from [Authenticated] is harmless - it just
  /// transitions to a less privileged state without token cleanup.
  void exitNoAuthMode() {
    Loggers.auth.info('Exiting no-auth mode');
    state = const Unauthenticated(
      reason: UnauthenticatedReason.explicitSignOut,
    );
  }

  /// Enter no-auth mode when backend has no identity providers configured.
  ///
  /// Call this when the backend returns an empty list of auth providers,
  /// indicating authentication is not required.
  ///
  /// Clears any existing tokens since they're for a different backend.
  Future<void> enterNoAuthMode() async {
    if (state is Authenticated) {
      Loggers.auth.info('Clearing stale auth - switching to no-auth backend');
      try {
        await _storage.clearTokens();
      } on Exception catch (e) {
        // Proceed despite failure: no-auth mode doesn't use tokens, so stale
        // tokens are harmless here. If user later switches back to an auth
        // backend, _restoreSession() will re-validate and clear invalid tokens.
        // This matches signOut() behavior which also catches storage failures.
        Loggers.auth.warning(
          'Failed to clear tokens (${e.runtimeType}) from '
          'previous session. Proceeding to no-auth mode.',
        );
      }
    }
    Loggers.auth.info('Entering no-auth mode');
    state = const NoAuthRequired();
  }

  /// Get the current access token if authenticated.
  String? get accessToken {
    final current = state;
    return current is Authenticated ? current.accessToken : null;
  }

  /// Whether the current token needs refresh (expiring soon or expired).
  @override
  bool get needsRefresh {
    final current = state;
    return current is Authenticated && current.needsRefresh;
  }

  /// Refresh tokens if they are expiring soon.
  ///
  /// Call this proactively before making API requests to avoid 401s.
  /// Does nothing if not authenticated or tokens don't need refresh.
  /// On failure, logs and proceeds (request will use current token).
  @override
  Future<void> refreshIfExpiringSoon() async {
    if (needsRefresh) {
      final success = await tryRefresh();
      if (!success) {
        Loggers.auth.info('Proactive refresh failed');
      }
    }
  }

  /// Attempt to refresh the current tokens (runtime refresh).
  ///
  /// Returns `true` if refresh succeeded, `false` if it failed.
  ///
  /// Failure handling depends on the reason:
  /// - `invalidGrant`: Refresh token revoked/expired → clears auth state (logout)
  /// - `networkError`: Transient failure → preserves session, caller can retry
  /// - `noRefreshToken`: No token available → preserves session
  ///
  /// This is more lenient than [_tryRefreshStoredTokens] because at runtime we
  /// have an established session worth preserving through transient failures.
  @override
  Future<bool> tryRefresh() async {
    final current = state;
    if (current is! Authenticated) {
      return false;
    }

    final result = await _refreshService.refresh(
      discoveryUrl: current.issuerDiscoveryUrl,
      refreshToken: current.refreshToken,
      clientId: current.clientId,
    );

    switch (result) {
      case TokenRefreshSuccess():
        return _handleRefreshSuccess(result, current);

      case TokenRefreshFailure(
          reason: TokenRefreshFailureReason.noRefreshToken,
        ):
        Loggers.auth.info('No refresh token available');
        return false;

      case TokenRefreshFailure(reason: TokenRefreshFailureReason.invalidGrant):
        Loggers.auth.info('Refresh token expired, clearing auth state');
        await _clearAuthState();
        return false;

      case TokenRefreshFailure(reason: TokenRefreshFailureReason.networkError):
        Loggers.auth.info('Refresh failed due to network error');
        return false;

      case TokenRefreshFailure():
        Loggers.auth.info('Refresh failed');
        return false;
    }
  }

  Future<bool> _handleRefreshSuccess(
    TokenRefreshSuccess result,
    Authenticated current,
  ) async {
    await _applyRefreshResult(
      result,
      issuerId: current.issuerId,
      issuerDiscoveryUrl: current.issuerDiscoveryUrl,
      clientId: current.clientId,
      fallbackIdToken: current.idToken,
      endSessionEndpoint: current.endSessionEndpoint,
    );

    Loggers.auth.info('Token refresh successful');
    return true;
  }

  Future<void> _clearAuthState() async {
    try {
      await _storage.clearTokens();
    } on Exception catch (e) {
      Loggers.auth.info('Failed to clear tokens: ${e.runtimeType}');
    }
    state = const Unauthenticated();
  }
}
