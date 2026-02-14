import 'package:meta/meta.dart';
import 'package:soliplex_frontend/core/models/active_run_state.dart';
import 'package:soliplex_frontend/core/models/run_handle.dart';

/// Events broadcast when runs start or complete.
@immutable
sealed class RunLifecycleEvent {
  const RunLifecycleEvent({required this.key});

  /// Composite key identifying which room/thread this event is for.
  final RunKey key;

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
