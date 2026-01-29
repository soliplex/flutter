import 'package:soliplex_frontend/core/domain/interfaces/screen_wake_lock.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Wraps wakelock_plus package.
///
/// Tracks desired state separately from actual state to support
/// future app lifecycle handling (re-enable on foreground).
class WakelockPlusAdapter implements ScreenWakeLock {
  bool _isEnabled = false;

  @override
  bool get isEnabled => _isEnabled;

  @override
  Future<void> enable() async {
    if (!_isEnabled) {
      await WakelockPlus.enable();
      _isEnabled = true;
    }
  }

  @override
  Future<void> disable() async {
    if (_isEnabled) {
      await WakelockPlus.disable();
      _isEnabled = false;
    }
  }
}
