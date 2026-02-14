import 'dart:async';

import 'package:soliplex_frontend/core/models/active_run_state.dart';
import 'package:soliplex_frontend/core/models/run_handle.dart';
import 'package:soliplex_frontend/core/models/run_lifecycle_event.dart';

/// Registry for tracking multiple concurrent AG-UI runs.
///
/// RunRegistry manages a collection of [RunHandle] instances, keyed by
/// their [RunKey]. It provides:
/// - Registration and lookup of runs
/// - Lifecycle event broadcasting via [completeRun]
/// - Removal and disposal of individual or all runs
/// - Query methods for UI state
///
/// Usage:
/// ```dart
/// final registry = RunRegistry();
///
/// // Register a new run
/// registry.registerRun(handle);
///
/// // Check if a run exists or is active
/// final key = (roomId: 'room-1', threadId: 'thread-1');
/// if (registry.hasRun(key)) {
///   final state = registry.getRunState(key);
/// }
///
/// // Remove when done
/// await registry.removeRun(key);
/// ```
class RunRegistry {
  final Map<RunKey, RunHandle> _runs = {};
  final _controller = StreamController<RunLifecycleEvent>.broadcast();

  /// Stream of lifecycle events for run start and completion.
  Stream<RunLifecycleEvent> get lifecycleEvents => _controller.stream;

  /// Registers a run handle in the registry.
  ///
  /// If a run already exists for the same room/thread, the existing run
  /// is cancelled and replaced with the new one.
  Future<void> registerRun(RunHandle handle) async {
    _checkNotDisposed();
    final existingHandle = _runs[handle.key];
    if (existingHandle != null) {
      await existingHandle.dispose();
    }
    _runs[handle.key] = handle;
    _controller.add(RunStarted(key: handle.key));
  }

  /// Transitions a run to completed state and emits a lifecycle event.
  ///
  /// Sets the handle's state and broadcasts [RunCompleted] for all results
  /// including cancellations. Consumers decide which events to act on.
  ///
  /// Silently returns if the registry is disposed or the handle is not
  /// the currently registered one for its key (e.g., it was replaced by
  /// a newer run).
  void completeRun(RunHandle handle, CompletedState completed) {
    if (_controller.isClosed || _runs[handle.key] != handle) return;
    handle.state = completed;
    _controller.add(RunCompleted(key: handle.key, result: completed.result));
  }

  /// Gets the current state for a thread's run.
  ///
  /// Returns null if no run exists for the given room/thread.
  ActiveRunState? getRunState(RunKey key) => _runs[key]?.state;

  /// Gets the run handle for a thread.
  ///
  /// Returns null if no run exists for the given room/thread.
  RunHandle? getHandle(RunKey key) => _runs[key];

  /// Checks if any run (active or completed) is registered for the given key.
  bool hasRun(RunKey key) => _runs.containsKey(key);

  /// Checks if an actively running (not yet completed) run exists for the key.
  bool hasActiveRun(RunKey key) => _runs[key]?.isActive ?? false;

  /// Removes a run and disposes its resources.
  ///
  /// Callers must call [completeRun] first if a lifecycle event is needed.
  /// Does nothing if no run exists for the given key.
  Future<void> removeRun(RunKey key) async {
    final handle = _runs.remove(key);
    await handle?.dispose();
  }

  /// Disposes all runs without emitting lifecycle events.
  ///
  /// For individual run lifecycle management, use [completeRun] followed
  /// by [removeRun].
  Future<void> removeAll() async {
    final handles = _runs.values.toList();
    _runs.clear();
    for (final handle in handles) {
      await handle.dispose();
    }
  }

  /// Number of registered runs (including completed ones).
  int get runCount => _runs.length;

  /// Number of actively running (not yet completed) runs.
  int get activeRunCount => _runs.values.where((h) => h.isActive).length;

  /// All currently registered run handles.
  Iterable<RunHandle> get handles => _runs.values;

  /// Disposes of the registry and all runs.
  ///
  /// After calling dispose, the registry should not be used.
  Future<void> dispose() async {
    await removeAll();
    await _controller.close();
  }

  void _checkNotDisposed() {
    if (_controller.isClosed) {
      throw StateError('RunRegistry has been disposed');
    }
  }
}
