import 'package:soliplex_frontend/core/models/active_run_state.dart';
import 'package:soliplex_frontend/core/models/run_handle.dart';

/// Registry for tracking multiple concurrent AG-UI runs.
///
/// RunRegistry manages a collection of [RunHandle] instances, keyed by
/// their composite `roomId:threadId` identifier. It provides:
/// - Registration and lookup of active runs
/// - Cancellation of individual or all runs
/// - Query methods for UI state
///
/// Usage:
/// ```dart
/// final registry = RunRegistry();
///
/// // Register a new run
/// registry.registerRun(handle);
///
/// // Check if a run is active
/// if (registry.hasActiveRun('room-1', 'thread-1')) {
///   final state = registry.getRunState('room-1', 'thread-1');
/// }
///
/// // Cancel when done
/// await registry.cancelRun('room-1', 'thread-1');
/// ```
class RunRegistry {
  final Map<String, RunHandle> _runs = {};

  /// Registers a run handle in the registry.
  ///
  /// If a run already exists for the same room/thread, the existing run
  /// is cancelled and replaced with the new one.
  Future<void> registerRun(RunHandle handle) async {
    final existingHandle = _runs[handle.key];
    if (existingHandle != null) {
      await existingHandle.dispose();
    }
    _runs[handle.key] = handle;
  }

  /// Gets the current state for a thread's run.
  ///
  /// Returns null if no run exists for the given room/thread.
  ActiveRunState? getRunState(String roomId, String threadId) {
    final key = _makeKey(roomId, threadId);
    return _runs[key]?.state;
  }

  /// Gets the run handle for a thread.
  ///
  /// Returns null if no run exists for the given room/thread.
  RunHandle? getHandle(String roomId, String threadId) {
    final key = _makeKey(roomId, threadId);
    return _runs[key];
  }

  /// Checks if a run is registered for the given room/thread.
  ///
  /// Returns true if a handle exists, regardless of its state.
  bool hasActiveRun(String roomId, String threadId) {
    final key = _makeKey(roomId, threadId);
    return _runs.containsKey(key);
  }

  /// Cancels and removes a specific run.
  ///
  /// Does nothing if no run exists for the given room/thread.
  Future<void> cancelRun(String roomId, String threadId) async {
    final key = _makeKey(roomId, threadId);
    final handle = _runs.remove(key);
    await handle?.dispose();
  }

  /// Cancels and removes all runs.
  Future<void> cancelAll() async {
    final handles = _runs.values.toList();
    _runs.clear();
    for (final handle in handles) {
      await handle.dispose();
    }
  }

  /// Number of registered runs.
  int get activeRunCount => _runs.length;

  /// All currently registered run handles.
  Iterable<RunHandle> get handles => _runs.values;

  /// Disposes of the registry and all runs.
  ///
  /// After calling dispose, the registry should not be used.
  Future<void> dispose() async {
    await cancelAll();
  }

  /// Creates a composite key from room and thread IDs.
  String _makeKey(String roomId, String threadId) => '$roomId:$threadId';
}
