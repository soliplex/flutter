/// Contract for managing run lifecycle side effects.
///
/// Includes runId to support future reference counting
/// when multiple concurrent runs are supported.
abstract interface class RunLifecycle {
  /// Called when a run starts.
  void onRunStarted(String runId);

  /// Called when a run ends (success, failure, or cancellation).
  void onRunEnded(String runId);
}
