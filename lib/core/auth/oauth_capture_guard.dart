import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:soliplex_frontend/core/auth/callback_params.dart';

/// Global guard to ensure OAuth params are captured before router init.
///
/// This singleton enforces the temporal constraint that OAuth callback params
/// must be captured in main() before GoRouter initializes.
final oAuthCaptureGuard = OAuthCaptureGuard();

/// Guards access to OAuth callback params to ensure they are captured early.
///
/// This class enforces the requirement that OAuth callback params must be
/// captured BEFORE GoRouter initializes. GoRouter may modify the URL, losing
/// any callback tokens present in query params.
///
/// ## Usage
///
/// ```dart
/// // In main() or runSoliplexApp():
/// final guard = OAuthCaptureGuard();
/// guard.capture(CallbackParamsCapture.captureNow());
///
/// // Later, when accessing params:
/// guard.assertCaptured(); // Throws if not captured
/// final params = guard.params;
/// ```
///
/// ## Why This Exists
///
/// The OAuth callback flow on web passes tokens via URL query params:
/// `https://app.com/?token=xxx&refresh_token=yyy`
///
/// GoRouter initialization can modify the URL (e.g., redirecting to a route),
/// which may clear these params before they're captured. This guard makes the
/// temporal dependency explicit and testable.
class OAuthCaptureGuard {
  late CallbackParams _params;
  bool _captured = false;

  /// Whether [capture] has been called.
  bool get isCaptured => _captured;

  /// Capture OAuth callback params from the current URL.
  ///
  /// Must be called exactly once, before GoRouter initializes.
  ///
  /// Throws [StateError] if called more than once.
  void capture(CallbackParams params) {
    if (_captured) {
      throw StateError(
        'OAuth params have already been captured. '
        'capture() must only be called once at app startup.',
      );
    }
    _params = params;
    _captured = true;
  }

  /// Get the captured OAuth callback params.
  ///
  /// Throws [StateError] if [capture] has not been called.
  CallbackParams get params {
    if (!_captured) {
      throw StateError(
        'OAuth params must be captured before accessing them. '
        'Call capture() in main() before GoRouter initializes.',
      );
    }
    return _params;
  }

  /// Assert that params have been captured.
  ///
  /// Call this at points where you need to verify the capture happened,
  /// such as before GoRouter setup or when accessing params.
  ///
  /// Throws [StateError] with a descriptive message if not captured.
  void assertCaptured() {
    if (!_captured) {
      throw StateError(
        'OAuth callback params were not captured at app startup. '
        'Ensure CallbackParamsCapture.captureNow() is called in main() '
        'before GoRouter initializes. GoRouter may modify the URL and '
        'lose callback tokens.',
      );
    }
  }

  /// Resets the guard state. Use ONLY in tests.
  ///
  /// Call this in `tearDown()` to ensure test isolation when multiple
  /// tests interact with the global [oAuthCaptureGuard] singleton.
  @visibleForTesting
  void reset() {
    _captured = false;
  }
}
