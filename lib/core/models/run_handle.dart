import 'dart:async';

import 'package:soliplex_client/soliplex_client.dart';
import 'package:soliplex_frontend/core/models/active_run_state.dart';

/// Composite identifier for a run: (roomId, threadId).
typedef RunKey = ({String roomId, String threadId});

/// Encapsulates all resources for a single AG-UI run.
///
/// RunHandle bundles together the cancellation token, stream subscription,
/// and current state for a run. It provides a unified interface for:
/// - Tracking run state
/// - Cancelling the run
/// - Cleaning up resources on completion
///
/// The [key] property provides a composite identifier for use in registries:
/// ```dart
/// final handle = RunHandle(...);
/// registry[handle.key] = handle;
/// ```
class RunHandle {
  /// Creates a run handle with the given resources.
  RunHandle({
    required this.key,
    required this.runId,
    required this.cancelToken,
    required this.subscription,
    required this.userMessageId,
    required this.previousAguiState,
    ActiveRunState? initialState,
  }) : state = initialState ?? const IdleState();

  bool _disposed = false;

  /// Composite key identifying which room/thread this run belongs to.
  final RunKey key;

  /// The room this run belongs to.
  String get roomId => key.roomId;

  /// The thread this run belongs to.
  String get threadId => key.threadId;

  /// The backend-generated run ID.
  final String runId;

  /// Token for cancelling the run.
  final CancelToken cancelToken;

  /// Subscription to the AG-UI event stream.
  final StreamSubscription<BaseEvent> subscription;

  /// The ID of the user message that triggered this run.
  final String userMessageId;

  /// AG-UI state snapshot from before the run started.
  final Map<String, dynamic> previousAguiState;

  /// Current state of the run.
  ActiveRunState state;

  /// Whether the run is currently active (not idle or completed).
  bool get isActive => state.isRunning;

  /// Disposes of all resources held by this handle.
  ///
  /// Cancels the token and subscription. Safe to call multiple times —
  /// subsequent calls are a no-op.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    cancelToken.cancel();
    await subscription.cancel();
  }

  @override
  String toString() => 'RunHandle(key: $key, state: $state)';
}
