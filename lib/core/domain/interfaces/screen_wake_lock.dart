/// Contract for controlling screen wake lock state.
///
/// Implementations live in infrastructure layer.
abstract interface class ScreenWakeLock {
  /// Enables the screen wake lock, preventing the device from sleeping.
  Future<void> enable();

  /// Disables the screen wake lock, allowing normal sleep behavior.
  Future<void> disable();

  /// Whether the wake lock is currently enabled.
  bool get isEnabled;
}
