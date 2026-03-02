import 'package:soliplex_frontend/core/auth/callback_params.dart';
import 'package:soliplex_frontend/core/auth/web_auth_callback_native.dart'
    if (dart.library.js_interop) 'package:soliplex_frontend/core/auth/web_auth_callback_web.dart'
    as impl;

export 'package:soliplex_frontend/core/auth/callback_params.dart';

/// Static utility for capturing OAuth callback params in main().
///
/// Use this BEFORE ProviderScope is created to capture URL params that
/// GoRouter might modify. Pass the result to ProviderScope overrides.
///
/// Example:
/// ```dart
/// void main() async {
///   final params = CallbackParamsCapture.captureNow();
///   runApp(ProviderScope(
///     overrides: [capturedCallbackParamsProvider.overrideWithValue(params)],
///     child: App(),
///   ));
/// }
/// ```
abstract final class CallbackParamsCapture {
  /// Capture callback params from current URL.
  ///
  /// On web, extracts tokens from URL query params.
  /// On native, returns [NoCallbackParams] (native uses flutter_appauth).
  static CallbackParams captureNow() => impl.captureCallbackParamsNow();

  /// Capture the initial URL hash path before GoRouter overwrites it.
  ///
  /// On web, returns the path from the hash (e.g., '/signedout').
  /// On native, returns null (not applicable).
  static String? captureInitialHashPath() => impl.captureInitialHashPath();
}

/// Service for handling OAuth callback URL operations.
///
/// Platform implementations:
/// - Web: Extracts params from URL and cleans up browser history.
/// - Native: All methods are no-ops since native uses flutter_appauth
///   which handles callbacks in-process.
abstract class CallbackParamsService {
  /// Check if the current URL has auth callback tokens.
  bool isAuthCallback();

  /// Extract callback parameters from current URL.
  CallbackParams extractParams();

  /// Clear the URL query parameters after processing callback.
  ///
  /// Security: Removes tokens from browser history on web.
  void clearUrlParams();
}

/// Creates a platform-appropriate [CallbackParamsService] implementation.
CallbackParamsService createCallbackParamsService() =>
    impl.createCallbackParamsService();
