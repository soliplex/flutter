import 'dart:async';

import 'package:soliplex_agent/soliplex_agent.dart';

/// Waits until the orchestrator reaches [ToolYieldingState] or a terminal
/// state, whichever comes first.
Future<void> waitForYieldOrTerminal(
  RunOrchestrator orchestrator, {
  required int timeout,
}) async {
  final completer = Completer<void>();
  final sub = orchestrator.stateChanges.listen((state) {
    if (state is ToolYieldingState ||
        state is CompletedState ||
        state is FailedState ||
        state is CancelledState) {
      if (!completer.isCompleted) completer.complete();
    }
  });

  try {
    await completer.future.timeout(
      Duration(seconds: timeout),
      onTimeout: () {
        throw TimeoutException(
          'Orchestrator did not yield or terminate within ${timeout}s. '
          'Current state: ${orchestrator.currentState.runtimeType}',
        );
      },
    );
  } finally {
    await sub.cancel();
  }
}

/// Waits until the orchestrator reaches a terminal state (Completed, Failed,
/// or Cancelled), or throws on timeout.
Future<void> waitForTerminalState(
  RunOrchestrator orchestrator, {
  required int timeout,
}) async {
  final completer = Completer<void>();
  final sub = orchestrator.stateChanges.listen((state) {
    if (state is CompletedState ||
        state is FailedState ||
        state is CancelledState) {
      if (!completer.isCompleted) completer.complete();
    }
  });

  try {
    await completer.future.timeout(
      Duration(seconds: timeout),
      onTimeout: () {
        throw TimeoutException(
          'Orchestrator did not reach terminal state within ${timeout}s. '
          'Current state: ${orchestrator.currentState.runtimeType}',
        );
      },
    );
  } finally {
    await sub.cancel();
  }
}
