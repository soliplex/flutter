import 'package:flutter/foundation.dart'
    show ChangeNotifier, Listenable, debugPrint, kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soliplex_client/soliplex_client.dart';
import 'package:soliplex_frontend/core/auth/auth_flow.dart';
import 'package:soliplex_frontend/core/auth/auth_notifier.dart';
import 'package:soliplex_frontend/core/auth/auth_state.dart';
import 'package:soliplex_frontend/core/auth/auth_storage.dart';
import 'package:soliplex_frontend/core/auth/oidc_issuer.dart';
import 'package:soliplex_frontend/core/auth/web_auth_callback.dart';
import 'package:soliplex_frontend/core/providers/api_provider.dart';
import 'package:soliplex_frontend/core/providers/config_provider.dart';
import 'package:soliplex_frontend/core/providers/shell_config_provider.dart';

/// Provider for platform-specific authentication flow.
///
/// On web, uses backend baseUrl for BFF endpoints.
/// On native, requires oauthRedirectScheme from shell config.
final authFlowProvider = Provider<AuthFlow>((ref) {
  final config = ref.watch(configProvider);
  final shellConfig = ref.watch(shellConfigProvider);

  // Fail early on native if scheme not configured
  if (!kIsWeb && shellConfig.oauthRedirectScheme == null) {
    throw StateError(
      'oauthRedirectScheme must be set in SoliplexConfig for native platforms. '
      'This scheme must match CFBundleURLSchemes (iOS) and '
      'appAuthRedirectScheme (Android).',
    );
  }

  debugPrint('authFlowProvider: baseUrl=${config.baseUrl}');
  return createAuthFlow(
    backendBaseUrl: config.baseUrl,
    redirectScheme: shellConfig.oauthRedirectScheme,
  );
});

/// Provider for callback params captured at startup.
///
/// Override this in [ProviderScope.overrides] with the value from
/// [CallbackParamsCapture.captureNow] called in main().
///
/// Example:
/// ```dart
/// final params = CallbackParamsCapture.captureNow();
/// runApp(ProviderScope(
///   overrides: [capturedCallbackParamsProvider.overrideWithValue(params)],
///   child: App(),
/// ));
/// ```
final capturedCallbackParamsProvider = Provider<CallbackParams>(
  (ref) => const NoCallbackParams(),
);

/// Provider for OAuth callback URL operations (extract, clear).
final callbackParamsServiceProvider = Provider<CallbackParamsService>(
  (ref) => createCallbackParamsService(),
);

/// Provider for secure token storage.
final authStorageProvider = Provider<AuthStorage>((ref) => createAuthStorage());

/// Provider for token refresh service.
///
/// Uses the base HTTP client (without auth) to avoid circular dependencies
/// when refreshing tokens.
final tokenRefreshServiceProvider = Provider<TokenRefreshService>((ref) {
  final httpClient = ref.watch(baseHttpClientProvider);
  return TokenRefreshService(httpClient: httpClient, onDiagnostic: debugPrint);
});

/// Provider for auth state and actions.
///
/// Manages OIDC authentication state. Use this to:
/// - Sign in with an OIDC provider
/// - Sign out
/// - Watch authentication status
///
/// Example:
/// ```dart
/// // Sign in
/// await ref.read(authProvider.notifier).signIn(provider);
///
/// // Watch state
/// final authState = ref.watch(authProvider);
/// if (authState is Authenticated) {
///   // User is logged in
/// }
/// ```
final authProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);

/// Provider indicating whether the user has access to the app.
///
/// Returns true when the user is [Authenticated] or when the backend
/// is configured for [NoAuthRequired] mode.
///
/// Example:
/// ```dart
/// final canProceed = ref.watch(hasAppAccessProvider);
/// ```
final hasAppAccessProvider = Provider<bool>((ref) {
  final authState = ref.watch(authProvider);
  return authState is Authenticated || authState is NoAuthRequired;
});

/// Provider for the current access token.
///
/// Returns null if not authenticated.
final accessTokenProvider = Provider<String?>((ref) {
  final authState = ref.watch(authProvider);
  return authState is Authenticated ? authState.accessToken : null;
});

/// Listenable that fires only on auth status transitions (login/logout).
///
/// Use this with GoRouter's `refreshListenable` to trigger redirect
/// re-evaluation without recreating the router. Unlike watching
/// [authProvider] directly, this does NOT fire on token refresh.
///
/// This separation is critical: token refresh changes the auth state
/// (new tokens) but shouldn't cause navigation. Only actual login/logout
/// transitions should trigger route guards.
final authStatusListenableProvider = Provider<Listenable>((ref) {
  return _AuthStatusListenable(ref);
});

/// Notifies only when auth status transitions between having/not having app access.
///
/// Filters out token refresh noise - when `Authenticated(oldTokens)` becomes
/// `Authenticated(newTokens)`, no notification fires because access status
/// hasn't changed.
class _AuthStatusListenable extends ChangeNotifier {
  _AuthStatusListenable(this._ref) {
    _previouslyHadAccess = _hasAppAccess;
    _ref.listen<AuthState>(authProvider, (_, __) {
      final currentlyHasAccess = _hasAppAccess;
      if (currentlyHasAccess != _previouslyHadAccess) {
        _previouslyHadAccess = currentlyHasAccess;
        notifyListeners();
      }
    });
  }

  final Ref _ref;
  late bool _previouslyHadAccess;

  bool get _hasAppAccess {
    final state = _ref.read(authProvider);
    return state is Authenticated || state is NoAuthRequired;
  }
}

/// Provider for fetching available OIDC issuers from the backend.
///
/// Uses core's [fetchAuthProviders] to get configured identity providers,
/// then wraps them in [OidcIssuer] for OIDC-specific functionality.
final oidcIssuersProvider = FutureProvider<List<OidcIssuer>>((ref) async {
  final config = ref.watch(configProvider);
  final transport = ref.watch(httpTransportProvider);

  final configs = await fetchAuthProviders(
    transport: transport,
    baseUrl: Uri.parse(config.baseUrl),
  );

  return configs.map(OidcIssuer.fromConfig).toList();
});
