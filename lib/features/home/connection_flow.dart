import 'package:flutter/foundation.dart';
import 'package:soliplex_frontend/core/auth/auth_state.dart';

/// Action to perform before fetching auth providers during backend connection.
enum PreConnectAction {
  /// Call signOut() to clear tokens from previous authenticated backend.
  signOut,

  /// Call exitNoAuthMode() to reset from previous no-auth backend.
  exitNoAuthMode,

  /// No cleanup needed (same backend or unauthenticated).
  none,
}

/// Result after fetching auth providers, determining navigation and actions.
@immutable
sealed class PostConnectResult {
  const PostConnectResult();
}

/// Backend has no auth providers - enter no-auth mode and go to rooms.
@immutable
class EnterNoAuthModeResult extends PostConnectResult {
  const EnterNoAuthModeResult();

  @override
  bool operator ==(Object other) => other is EnterNoAuthModeResult;

  @override
  int get hashCode => runtimeType.hashCode;
}

/// User is authenticated - go directly to rooms.
@immutable
class AlreadyAuthenticatedResult extends PostConnectResult {
  const AlreadyAuthenticatedResult();

  @override
  bool operator ==(Object other) => other is AlreadyAuthenticatedResult;

  @override
  int get hashCode => runtimeType.hashCode;
}

/// Auth required - exit no-auth mode if needed, invalidate issuers, then
/// navigate to login.
@immutable
class RequireLoginResult extends PostConnectResult {
  const RequireLoginResult({required this.shouldExitNoAuthMode});

  /// Whether to call exitNoAuthMode() before navigating.
  final bool shouldExitNoAuthMode;

  @override
  bool operator ==(Object other) =>
      other is RequireLoginResult &&
      other.shouldExitNoAuthMode == shouldExitNoAuthMode;

  @override
  int get hashCode => Object.hash(runtimeType, shouldExitNoAuthMode);
}

/// Determines what cleanup action to perform before fetching auth providers.
///
/// When switching backends, we must clear auth state to prevent tokens from
/// one backend being sent to another (security requirement).
PreConnectAction determinePreConnectAction({
  required bool isBackendChange,
  required AuthState currentAuthState,
}) {
  if (!isBackendChange) {
    return PreConnectAction.none;
  }

  return switch (currentAuthState) {
    Authenticated() => PreConnectAction.signOut,
    NoAuthRequired() => PreConnectAction.exitNoAuthMode,
    Unauthenticated() => PreConnectAction.none,
    AuthLoading() => PreConnectAction.none,
  };
}

/// Determines the result after fetching auth providers from the backend.
///
/// Decides whether to enter no-auth mode, navigate to rooms (if already
/// authenticated), or require login.
PostConnectResult determinePostConnectResult({
  required bool hasProviders,
  required AuthState currentAuthState,
}) {
  if (!hasProviders) {
    return const EnterNoAuthModeResult();
  }

  return switch (currentAuthState) {
    Authenticated() => const AlreadyAuthenticatedResult(),
    NoAuthRequired() => const RequireLoginResult(shouldExitNoAuthMode: true),
    Unauthenticated() => const RequireLoginResult(shouldExitNoAuthMode: false),
    AuthLoading() => const RequireLoginResult(shouldExitNoAuthMode: false),
  };
}

/// Normalizes a URL for comparison by removing trailing slash.
///
/// This ensures `http://example.com` and `http://example.com/` are treated
/// as the same backend, preventing unnecessary auth state resets.
String normalizeUrl(String url) {
  return url.endsWith('/') ? url.substring(0, url.length - 1) : url;
}
