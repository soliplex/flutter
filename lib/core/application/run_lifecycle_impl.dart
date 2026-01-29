import 'package:soliplex_frontend/core/domain/interfaces/run_lifecycle.dart';
import 'package:soliplex_frontend/core/domain/interfaces/screen_wake_lock.dart';

/// Manages side effects of run lifecycle.
///
/// Uses reference counting to handle multiple concurrent runs.
/// Wake lock enabled when first run starts, disabled when last ends.
class RunLifecycleImpl implements RunLifecycle {
  RunLifecycleImpl({required ScreenWakeLock wakeLock}) : _wakeLock = wakeLock;

  final ScreenWakeLock _wakeLock;
  final Set<String> _activeRuns = {};

  @override
  void onRunStarted(String runId) {
    final wasEmpty = _activeRuns.isEmpty;
    _activeRuns.add(runId);
    if (wasEmpty) {
      _wakeLock.enable();
    }
  }

  @override
  void onRunEnded(String runId) {
    final wasRemoved = _activeRuns.remove(runId);
    if (wasRemoved && _activeRuns.isEmpty) {
      _wakeLock.disable();
    }
  }
}
