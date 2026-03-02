import 'dart:async';

import 'package:meta/meta.dart';
import 'package:soliplex_agent/src/models/agent_result.dart';
import 'package:soliplex_agent/src/runtime/agent_session_state.dart';
import 'package:soliplex_client/run.dart';
import 'package:soliplex_client/soliplex_client.dart';
import 'package:soliplex_logging/soliplex_logging.dart';

/// A single autonomous agent session.
///
/// Wraps a [RunOrchestrator] and automatically executes client-side tool
/// calls when the orchestrator yields. Callers receive a single
/// [AgentResult] when the session reaches a terminal state.
///
/// Created exclusively by `AgentRuntime.spawn()`.
class AgentSession {
  @internal
  AgentSession({
    required this.threadKey,
    required this.ephemeral,
    required RunOrchestrator orchestrator,
    required ToolRegistry toolRegistry,
    required Logger logger,
  })  : _orchestrator = orchestrator,
        _toolRegistry = toolRegistry,
        _logger = logger,
        id = '${threadKey.threadId}-'
            '${DateTime.now().microsecondsSinceEpoch}';

  /// Unique session identifier.
  final String id;

  /// The thread this session operates on.
  final ThreadKey threadKey;

  /// Whether the thread should be deleted on completion.
  final bool ephemeral;

  final RunOrchestrator _orchestrator;
  final ToolRegistry _toolRegistry;
  final Logger _logger;

  final Completer<AgentResult> _resultCompleter = Completer<AgentResult>();
  StreamSubscription<RunState>? _subscription;
  AgentSessionState _state = AgentSessionState.spawning;
  bool _disposed = false;

  /// Current session lifecycle state.
  AgentSessionState get state => _state;

  /// Completes when the session reaches a terminal state.
  Future<AgentResult> get result => _resultCompleter.future;

  /// Waits for the session result with an optional timeout.
  Future<AgentResult> awaitResult({Duration? timeout}) {
    if (timeout == null) return result;
    final start = DateTime.now();
    return result.timeout(
      timeout,
      onTimeout: () => AgentTimedOut(
        threadKey: threadKey,
        elapsed: DateTime.now().difference(start),
      ),
    );
  }

  /// Cancels the session. No-op if already terminal.
  void cancel() {
    if (_isTerminal) return;
    _orchestrator.cancelRun();
  }

  /// Starts the orchestrator run and subscribes to state changes.
  ///
  /// Called internally by `AgentRuntime`.
  Future<void> start({
    required String userMessage,
    String? existingRunId,
  }) async {
    _subscription = _orchestrator.stateChanges.listen(_onStateChange);
    await _orchestrator.startRun(
      key: threadKey,
      userMessage: userMessage,
      existingRunId: existingRunId,
    );
  }

  /// Releases all resources. Called by `AgentRuntime`.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    unawaited(_subscription?.cancel());
    _subscription = null;
    _orchestrator.dispose();
    _completeIfPending();
  }

  // ---------------------------------------------------------------------------
  // State listener
  // ---------------------------------------------------------------------------

  void _onStateChange(RunState runState) {
    if (_disposed) return;
    switch (runState) {
      case RunningState():
        _state = AgentSessionState.running;
      case ToolYieldingState():
        unawaited(_executeToolsAndResume(runState));
      case CompletedState():
        _completeWith(_mapCompleted(runState));
      case FailedState():
        _completeWith(_mapFailed(runState));
      case CancelledState():
        _completeWith(_mapCancelled(runState));
      case IdleState():
        break;
    }
  }

  // ---------------------------------------------------------------------------
  // Auto-execute loop
  // ---------------------------------------------------------------------------

  Future<void> _executeToolsAndResume(ToolYieldingState yielding) async {
    try {
      final executed = await _executeAll(yielding.pendingToolCalls);
      if (_disposed || _isTerminal) return;
      await _orchestrator.submitToolOutputs(executed);
    } on Object catch (error, stackTrace) {
      _logger.warning(
        'Tool execute/resume failed',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<List<ToolCallInfo>> _executeAll(
    List<ToolCallInfo> pendingTools,
  ) async {
    final results = <ToolCallInfo>[];
    for (final tc in pendingTools) {
      results.add(await _executeSingle(tc));
    }
    return results;
  }

  Future<ToolCallInfo> _executeSingle(ToolCallInfo toolCall) async {
    try {
      final result = await _toolRegistry.execute(toolCall);
      return toolCall.copyWith(
        status: ToolCallStatus.completed,
        result: result,
      );
    } on Object catch (error, stackTrace) {
      _logger.warning(
        'Tool "${toolCall.name}" failed',
        error: error,
        stackTrace: stackTrace,
      );
      return toolCall.copyWith(
        status: ToolCallStatus.failed,
        result: error.toString(),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Result mapping
  // ---------------------------------------------------------------------------

  AgentResult _mapCompleted(CompletedState state) {
    final output = _extractLastAssistantText(state.conversation);
    return AgentSuccess(
      threadKey: threadKey,
      output: output,
      runId: state.runId,
    );
  }

  AgentResult _mapFailed(FailedState state) {
    return AgentFailure(
      threadKey: threadKey,
      reason: state.reason,
      error: state.error,
    );
  }

  AgentResult _mapCancelled(CancelledState state) {
    return AgentFailure(
      threadKey: threadKey,
      reason: FailureReason.cancelled,
      error: 'Session cancelled',
    );
  }

  String _extractLastAssistantText(Conversation conversation) {
    final assistantMessages = conversation.messages
        .whereType<TextMessage>()
        .where((m) => m.user == ChatUser.assistant);
    return assistantMessages.lastOrNull?.text ?? '';
  }

  // ---------------------------------------------------------------------------
  // Completion helpers
  // ---------------------------------------------------------------------------

  void _completeWith(AgentResult agentResult) {
    switch (agentResult) {
      case AgentSuccess():
        _state = AgentSessionState.completed;
      case AgentFailure(:final reason):
        _state = reason == FailureReason.cancelled
            ? AgentSessionState.cancelled
            : AgentSessionState.failed;
      case AgentTimedOut():
        _state = AgentSessionState.failed;
    }
    if (!_resultCompleter.isCompleted) {
      _resultCompleter.complete(agentResult);
    }
  }

  void _completeIfPending() {
    if (_resultCompleter.isCompleted) return;
    _state = AgentSessionState.failed;
    _resultCompleter.complete(
      AgentFailure(
        threadKey: threadKey,
        reason: FailureReason.internalError,
        error: 'Session disposed before completion',
      ),
    );
  }

  bool get _isTerminal =>
      _state == AgentSessionState.completed ||
      _state == AgentSessionState.failed ||
      _state == AgentSessionState.cancelled;
}
