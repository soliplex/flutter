import 'package:flutter/foundation.dart';
import 'package:soliplex_client/soliplex_client.dart';
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

/// Result of probing a backend URL for connectivity.
@immutable
sealed class ConnectionProbeResult {
  const ConnectionProbeResult();
}

/// Backend was reached successfully.
@immutable
class ConnectionSuccess extends ConnectionProbeResult {
  const ConnectionSuccess({
    required this.url,
    required this.providers,
  });

  /// The resolved URL (with scheme) that successfully connected.
  final Uri url;

  /// Auth providers returned by the backend.
  final List<AuthProviderConfig> providers;

  /// Whether the connection uses HTTP (not HTTPS).
  bool get isInsecure => url.scheme == 'http';
}

/// Backend could not be reached over any scheme.
@immutable
class ConnectionFailure extends ConnectionProbeResult {
  const ConnectionFailure(this.error, {required this.url});

  /// The error that caused the connection to fail.
  final Object error;

  /// The URL that was being probed when the failure occurred.
  final String url;
}

/// Probes the backend by trying HTTPS first, falling back to HTTP on network
/// errors.
///
/// If the input already has an explicit scheme, only that scheme is tried.
/// For schemeless input, tries `https://` first. If that fails with a
/// [NetworkException], tries `http://`. Non-network errors (4xx, 5xx) are
/// not retried since they indicate the server was reachable.
Future<ConnectionProbeResult> probeConnection({
  required String input,
  required HttpTransport transport,
}) async {
  final trimmed = input.trim();
  final scheme = _parseScheme(trimmed);

  final urls = switch (scheme) {
    'https' => [trimmed],
    'http' => [trimmed],
    null => ['https://$trimmed', 'http://$trimmed'],
    _ => [trimmed],
  };

  NetworkException? lastNetworkError;
  String? lastNetworkUrl;
  for (final url in urls) {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      return ConnectionFailure(ArgumentError('Failed to parse URI'), url: url);
    }
    try {
      final providers = await fetchAuthProviders(
        transport: transport,
        baseUrl: uri,
      );
      return ConnectionSuccess(url: uri, providers: providers);
    } on NetworkException catch (e) {
      lastNetworkError = e;
      lastNetworkUrl = url;
    } on Exception catch (e) {
      return ConnectionFailure(e, url: url);
    }
  }
  return ConnectionFailure(lastNetworkError!, url: lastNetworkUrl!);
}

String? _parseScheme(String input) {
  final separatorIndex = input.indexOf('://');
  if (separatorIndex == -1) return null;
  return input.substring(0, separatorIndex);
}

/// Normalizes a URI for comparison by removing trailing slash.
///
/// This ensures `http://example.com` and `http://example.com/` are treated
/// as the same backend, preventing unnecessary auth state resets.
Uri normalizeUri(Uri uri) {
  final path = uri.path;
  if (path.endsWith('/')) {
    return uri.replace(path: path.substring(0, path.length - 1));
  }
  return uri;
}
