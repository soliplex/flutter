import 'package:meta/meta.dart';
import 'package:soliplex_frontend/core/models/active_run_state.dart';
import 'package:soliplex_frontend/core/models/thread_key.dart';

/// Events broadcast when runs start or complete.
@immutable
sealed class RunLifecycleEvent {
  const RunLifecycleEvent({required this.key});

  /// Composite key identifying which room/thread this event is for.
  final ThreadKey key;

  /// The room this event belongs to.
  String get roomId => key.roomId;

  /// The thread this event belongs to.
  String get threadId => key.threadId;
}

/// Emitted when a run is registered in the registry.
@immutable
class RunStarted extends RunLifecycleEvent {
  const RunStarted({required super.key});
}

/// Emitted when a run is replaced by a continuation (tool execution loop).
///
/// Unlike [RunCompleted], this does NOT trigger unread indicators — the
/// conversation is still in progress, just starting a new backend run.
@immutable
class RunContinued extends RunLifecycleEvent {
  const RunContinued({required super.key});
}

/// Emitted when a run reaches a terminal state (success, failure, or cancel).
@immutable
class RunCompleted extends RunLifecycleEvent {
  const RunCompleted({
    required super.key,
    required this.result,
  });

  /// The completion result — [Success], [FailedResult], or [CancelledResult].
  final CompletionResult result;
}
