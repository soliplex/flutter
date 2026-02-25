import 'dart:async';

import 'package:soliplex_frontend/core/logging/loggers.dart';
import 'package:soliplex_frontend/core/models/active_run_state.dart';
import 'package:soliplex_frontend/core/models/run_handle.dart';
import 'package:soliplex_frontend/core/models/run_lifecycle_event.dart';
import 'package:soliplex_frontend/core/models/thread_key.dart';

/// Callback invoked when a run completes (success, failure, or cancellation).
typedef OnRunCompleted = void Function(ThreadKey key, CompletedState completed);

/// Registry for tracking multiple concurrent AG-UI runs.
///
/// RunRegistry manages a collection of [RunHandle] instances, keyed by
/// their [ThreadKey]. It provides:
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
  RunRegistry({this.onRunCompleted});

  /// Optional callback invoked when a run completes via [completeRun] or
  /// [notifyCompletion].
  final OnRunCompleted? onRunCompleted;

  final Map<ThreadKey, RunHandle> _runs = {};
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
    onRunCompleted?.call(handle.key, completed);
  }

  /// Atomically replaces an old run handle with a new one (CAS).
  ///
  /// Used by tool execution continuations to swap the old run's handle with
  /// the newly created continuation run. Returns `true` if the swap succeeded.
  /// Returns `false` if [oldHandle] is no longer the registered handle for its
  /// key (i.e., it was replaced by another call).
  ///
  /// On success: registers [newHandle], emits [RunContinued], disposes old.
  /// On failure: the registry is unchanged and the caller should dispose
  /// [newHandle].
  Future<bool> replaceRun(RunHandle oldHandle, RunHandle newHandle) async {
    _checkNotDisposed();
    if (_runs[oldHandle.key] != oldHandle) return false;

    _runs[newHandle.key] = newHandle;
    _controller.add(RunContinued(key: newHandle.key));

    try {
      await oldHandle.dispose();
    } catch (e, st) {
      Loggers.toolExecution.error(
        'Failed to dispose old handle during replaceRun',
        error: e,
        stackTrace: st,
      );
    }
    return true;
  }

  /// Notifies the completion callback for runs that failed before
  /// registration (e.g., errors during run setup).
  void notifyCompletion(ThreadKey key, CompletedState completed) {
    onRunCompleted?.call(key, completed);
  }

  /// Gets the current state for a thread's run.
  ///
  /// Returns null if no run exists for the given room/thread.
  ActiveRunState? getRunState(ThreadKey key) => _runs[key]?.state;

  /// Gets the run handle for a thread.
  ///
  /// Returns null if no run exists for the given room/thread.
  RunHandle? getHandle(ThreadKey key) => _runs[key];

  /// Checks if any run (active or completed) is registered for the given key.
  bool hasRun(ThreadKey key) => _runs.containsKey(key);

  /// Checks if an actively running (not yet completed) run exists for the key.
  bool hasActiveRun(ThreadKey key) => _runs[key]?.isActive ?? false;

  /// Removes a run and disposes its resources.
  ///
  /// Callers must call [completeRun] first if a lifecycle event is needed.
  /// Does nothing if no run exists for the given key.
  Future<void> removeRun(ThreadKey key) async {
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
