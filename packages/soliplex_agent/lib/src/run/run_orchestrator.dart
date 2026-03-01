import 'dart:async';

import 'package:soliplex_agent/src/host/platform_constraints.dart';
import 'package:soliplex_agent/src/models/failure_reason.dart';
import 'package:soliplex_agent/src/models/thread_key.dart';
import 'package:soliplex_agent/src/run/error_classifier.dart';
import 'package:soliplex_agent/src/run/run_state.dart';
import 'package:soliplex_client/soliplex_client.dart';
import 'package:soliplex_logging/soliplex_logging.dart';

/// Orchestrates a single AG-UI run lifecycle.
///
/// State machine: Idle -> Running -> Completed/ToolYielding/Failed/Cancelled.
/// Only one run at a time; concurrent `startRun()` throws [StateError].
///
/// ## Backend flow
///
/// The caller is responsible for creating the thread before calling
/// [startRun]. Typical sequence:
///
/// ```dart
/// // 1. Create thread (POST /rooms/{roomId}/agui)
/// final (threadInfo, aguiState) = await api.createThread(roomId);
///
/// // 2. Build ThreadKey from server-assigned thread ID
/// final key = (serverId: 'default', roomId: roomId, threadId: threadInfo.id);
///
/// // 3. Start orchestrator — creates a run (POST /rooms/{roomId}/agui/{threadId})
/// //    or reuses initialRunId from createThread.
/// await orchestrator.startRun(
///   key: key,
///   userMessage: 'Hello',
///   existingRunId: threadInfo.hasInitialRun ? threadInfo.initialRunId : null,
/// );
/// ```
///
/// If `existingRunId` is provided, the orchestrator skips `createRun` and
/// connects directly to the AG-UI SSE stream for that run.
///
/// ## Tool yielding
///
/// When a `RunFinishedEvent` arrives with pending client-side tool calls
/// (tools registered in the [ToolRegistry]), the orchestrator transitions
/// to [ToolYieldingState] instead of [CompletedState]. Server-side tool
/// calls (not in the registry) are ignored — they are executed by the
/// backend and appear in the event stream for display only.
///
/// The caller executes the pending tools, then calls [submitToolOutputs]
/// with results. This creates a **new backend run** (the backend rejects
/// re-posting to an existing run ID) and reconnects the AG-UI stream.
/// The cycle repeats until no pending client tools remain or the depth
/// limit (10) is hit.
///
/// ```dart
/// orchestrator.stateChanges.listen((state) {
///   switch (state) {
///     case ToolYieldingState(:final pendingToolCalls):
///       // Execute each tool via ToolRegistry.execute(), then:
///       final executed = pendingToolCalls.map((tc) => tc.copyWith(
///         status: ToolCallStatus.completed,
///         result: toolResult,
///       )).toList();
///       orchestrator.submitToolOutputs(executed);
///     case CompletedState(:final conversation):
///       // Done — display final response
///     case FailedState(:final reason, :final error):
///       // Handle error
///     case _:
///       break;
///   }
/// });
/// ```
///
/// **Important:** Each [Tool] definition must include a `parameters` field
/// (JSON Schema). The backend rejects tool definitions without it.
class RunOrchestrator {
  RunOrchestrator({
    required SoliplexApi api,
    required AgUiClient agUiClient,
    required ToolRegistry toolRegistry,
    required this.platformConstraints,
    required Logger logger,
  })  : _api = api,
        _agUiClient = agUiClient,
        _toolRegistry = toolRegistry,
        _logger = logger;

  final SoliplexApi _api;
  final AgUiClient _agUiClient;
  final ToolRegistry _toolRegistry;

  /// Platform capabilities for tool yielding decisions.
  final PlatformConstraints platformConstraints;
  final Logger _logger;

  static const _maxToolDepth = 10;

  final StreamController<RunState> _controller =
      StreamController<RunState>.broadcast();

  RunState _currentState = const IdleState();
  bool _disposed = false;
  CancelToken? _cancelToken;
  StreamSubscription<BaseEvent>? _subscription;
  bool _receivedTerminalEvent = false;
  int _toolDepth = 0;

  /// The current state of the orchestrator.
  RunState get currentState => _currentState;

  /// Broadcast stream of state transitions.
  Stream<RunState> get stateChanges => _controller.stream;

  /// Starts a new agent run.
  ///
  /// Throws [StateError] if already running or disposed.
  Future<void> startRun({
    required ThreadKey key,
    required String userMessage,
    String? existingRunId,
    ThreadHistory? cachedHistory,
  }) async {
    _guardNotRunning();
    _toolDepth = 0;
    try {
      final runId = await _createOrUseRun(key, existingRunId);
      if (_disposedDuringAwait()) return;
      final conversation = _buildConversation(
        key,
        userMessage,
        cachedHistory,
      );
      final input = _buildInput(key, runId, conversation);
      final endpoint = _buildEndpoint(key, runId);
      final initialState = RunningState(
        threadKey: key,
        runId: runId,
        conversation: conversation,
        streaming: const AwaitingText(),
      );
      _subscribeToStream(endpoint, input, initialState);
    } on Object catch (error, stackTrace) {
      _handleStartError(key, error, stackTrace);
    }
  }

  /// Cancels the current run. No-op if idle.
  void cancelRun() {
    _guardNotDisposed();
    switch (_currentState) {
      case RunningState(:final threadKey, :final conversation):
        _cancelToken?.cancel();
        _cleanup();
        _setState(
          CancelledState(threadKey: threadKey, conversation: conversation),
        );
      case ToolYieldingState(:final threadKey, :final conversation):
        _setState(
          CancelledState(threadKey: threadKey, conversation: conversation),
        );
      case _:
        return;
    }
  }

  /// Resets to [IdleState], cancelling any active run.
  void reset() {
    _guardNotDisposed();
    _cancelToken?.cancel();
    _cleanup();
    _setState(const IdleState());
  }

  /// Syncs to a thread without starting a run.
  ///
  /// Pass `null` to clear (reset to idle).
  void syncToThread(ThreadKey? key) {
    _guardNotDisposed();
    if (key == null) {
      reset();
      return;
    }
    if (_currentState is RunningState || _currentState is ToolYieldingState) {
      throw StateError('Cannot sync while a run is active');
    }
    _setState(const IdleState());
  }

  /// Submits executed tool results and resumes the agent.
  ///
  /// Creates a **new backend run** for the continuation — the backend
  /// rejects re-posting to an existing run ID. The full conversation
  /// (including a [ToolCallMessage] with results) is sent so the model
  /// sees the tool output and can respond.
  ///
  /// Throws [StateError] if not in [ToolYieldingState] or disposed.
  Future<void> submitToolOutputs(List<ToolCallInfo> executedTools) async {
    _guardSubmitToolOutputs();
    final yielding = _currentState as ToolYieldingState;
    _toolDepth++;
    if (_toolDepth > _maxToolDepth) {
      _setState(
        FailedState(
          threadKey: yielding.threadKey,
          reason: FailureReason.toolExecutionFailed,
          error: 'Tool depth limit exceeded ($_maxToolDepth)',
          conversation: yielding.conversation,
        ),
      );
      return;
    }
    final conversation = _buildResumeConversation(yielding, executedTools);
    try {
      final newRunId = await _createOrUseRun(yielding.threadKey, null);
      if (_interruptedDuringResume()) return;
      final input = _buildInput(yielding.threadKey, newRunId, conversation);
      final endpoint = _buildEndpoint(yielding.threadKey, newRunId);
      final initialState = RunningState(
        threadKey: yielding.threadKey,
        runId: newRunId,
        conversation: conversation,
        streaming: const AwaitingText(),
      );
      _subscribeToStream(endpoint, input, initialState);
    } on Object catch (error, stackTrace) {
      _handleStartError(yielding.threadKey, error, stackTrace);
    }
  }

  /// Releases all resources. Must be called when done.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _cancelToken?.cancel();
    unawaited(_subscription?.cancel());
    _subscription = null;
    _cancelToken = null;
    unawaited(_controller.close());
  }

  // ---------------------------------------------------------------------------
  // Private helpers — each <=40 LOC, <=4 params
  // ---------------------------------------------------------------------------

  void _guardNotRunning() {
    _guardNotDisposed();
    if (_currentState is RunningState || _currentState is ToolYieldingState) {
      throw StateError('A run is already active');
    }
  }

  void _guardNotDisposed() {
    if (_disposed) {
      throw StateError('RunOrchestrator has been disposed');
    }
  }

  void _guardSubmitToolOutputs() {
    _guardNotDisposed();
    if (_currentState is! ToolYieldingState) {
      throw StateError('Not in ToolYieldingState');
    }
  }

  /// Returns true if the orchestrator was disposed during an async gap.
  ///
  /// Use after `await` in [startRun] where the pre-await state is [IdleState].
  bool _disposedDuringAwait() => _disposed;

  /// Returns true if the state was changed during an async gap.
  ///
  /// Use after `await` in [submitToolOutputs] where the pre-await state is
  /// [ToolYieldingState]. Detects cancel, reset, or dispose.
  bool _interruptedDuringResume() {
    return _disposed || _currentState is! ToolYieldingState;
  }

  List<ToolCallInfo> _extractPendingTools(Conversation conversation) {
    return conversation.toolCalls
        .where(
          (tc) =>
              tc.status == ToolCallStatus.pending &&
              _toolRegistry.contains(tc.name),
        )
        .toList();
  }

  Conversation _buildResumeConversation(
    ToolYieldingState state,
    List<ToolCallInfo> executedTools,
  ) {
    final executedIds = {for (final tc in executedTools) tc.id};
    final updatedToolCalls = state.conversation.toolCalls.map((tc) {
      if (executedIds.contains(tc.id)) {
        return executedTools.firstWhere((e) => e.id == tc.id);
      }
      return tc;
    }).toList();
    final toolMsg = ToolCallMessage.fromExecuted(
      id: 'tool-result-${DateTime.now().microsecondsSinceEpoch}',
      toolCalls: executedTools,
    );
    return state.conversation.copyWith(
      messages: [...state.conversation.messages, toolMsg],
      toolCalls: updatedToolCalls,
    );
  }

  Future<String> _createOrUseRun(
    ThreadKey key,
    String? existingRunId,
  ) async {
    if (existingRunId != null) return existingRunId;
    final runInfo = await _api.createRun(key.roomId, key.threadId);
    return runInfo.id;
  }

  Conversation _buildConversation(
    ThreadKey key,
    String userMessage,
    ThreadHistory? cachedHistory,
  ) {
    final priorMessages = cachedHistory?.messages ?? <ChatMessage>[];
    final userMsg = TextMessage.create(
      id: 'user-${DateTime.now().microsecondsSinceEpoch}',
      user: ChatUser.user,
      text: userMessage,
    );
    return Conversation(
      threadId: key.threadId,
      messages: [...priorMessages, userMsg],
      aguiState: cachedHistory?.aguiState ?? const {},
      messageStates: cachedHistory?.messageStates ?? const {},
    );
  }

  SimpleRunAgentInput _buildInput(
    ThreadKey key,
    String runId,
    Conversation conversation,
  ) {
    final aguiMessages = convertToAgui(conversation.messages);
    return SimpleRunAgentInput(
      threadId: key.threadId,
      runId: runId,
      messages: aguiMessages,
      tools: _toolRegistry.toolDefinitions,
    );
  }

  String _buildEndpoint(ThreadKey key, String runId) {
    return 'rooms/${key.roomId}/agui/${key.threadId}/$runId';
  }

  void _subscribeToStream(
    String endpoint,
    SimpleRunAgentInput input,
    RunningState initialState,
  ) {
    _cancelToken = CancelToken();
    _receivedTerminalEvent = false;
    final stream = _agUiClient.runAgent(
      endpoint,
      input,
      cancelToken: _cancelToken,
    );
    _setState(initialState);
    _subscription = stream.listen(
      _onEvent,
      onError: _onStreamError,
      onDone: _onStreamDone,
    );
  }

  void _onEvent(BaseEvent event) {
    final running = _currentState;
    if (running is! RunningState) return;
    final result = processEvent(
      running.conversation,
      running.streaming,
      event,
    );
    _mapEventResult(running, result, event);
  }

  void _mapEventResult(
    RunningState previous,
    EventProcessingResult result,
    BaseEvent event,
  ) {
    if (event is RunFinishedEvent) {
      _handleRunFinished(previous, result.conversation);
      return;
    }
    if (event is RunErrorEvent) {
      _receivedTerminalEvent = true;
      _cleanup();
      _setState(
        FailedState(
          threadKey: previous.threadKey,
          reason: FailureReason.serverError,
          error: event.message,
          conversation: result.conversation,
        ),
      );
      return;
    }
    _setState(
      previous.copyWith(
        conversation: result.conversation,
        streaming: result.streaming,
      ),
    );
  }

  void _handleRunFinished(RunningState previous, Conversation conversation) {
    _receivedTerminalEvent = true;
    // Don't cancel the subscription — let the SSE stream drain naturally.
    // Cancelling it sends a client disconnect to the backend, which can
    // trigger CancelledError in the backend's async DB session cleanup.
    _cancelToken = null;
    final pendingTools = _extractPendingTools(conversation);
    if (pendingTools.isNotEmpty) {
      _setState(
        ToolYieldingState(
          threadKey: previous.threadKey,
          runId: previous.runId,
          conversation: conversation,
          pendingToolCalls: pendingTools,
          toolDepth: _toolDepth,
        ),
      );
    } else {
      _setState(
        CompletedState(
          threadKey: previous.threadKey,
          runId: previous.runId,
          conversation: conversation,
        ),
      );
    }
  }

  void _onStreamDone() {
    // Always clean up the subscription reference when the stream ends.
    _subscription = null;
    if (_receivedTerminalEvent) return;
    final running = _currentState;
    if (running is! RunningState) return;
    _cleanup();
    _logger.warning('Stream ended without terminal event');
    _setState(
      FailedState(
        threadKey: running.threadKey,
        reason: FailureReason.networkLost,
        error: 'Stream ended without terminal event',
        conversation: running.conversation,
      ),
    );
  }

  void _onStreamError(Object error, StackTrace stackTrace) {
    final running = _currentState;
    if (running is! RunningState) return;
    _cleanup();
    if (error is CancellationError) {
      _setState(
        CancelledState(
          threadKey: running.threadKey,
          conversation: running.conversation,
        ),
      );
      return;
    }
    final reason = classifyError(error);
    _logger.error(
      'Run failed',
      error: error,
      stackTrace: stackTrace,
    );
    _setState(
      FailedState(
        threadKey: running.threadKey,
        reason: reason,
        error: error.toString(),
        conversation: running.conversation,
      ),
    );
  }

  void _handleStartError(
    ThreadKey key,
    Object error,
    StackTrace stackTrace,
  ) {
    _cleanup();
    final reason = classifyError(error);
    _logger.error(
      'Failed to start run',
      error: error,
      stackTrace: stackTrace,
    );
    _setState(
      FailedState(
        threadKey: key,
        reason: reason,
        error: error.toString(),
      ),
    );
  }

  void _setState(RunState newState) {
    _currentState = newState;
    if (!_controller.isClosed) {
      _controller.add(newState);
    }
  }

  void _cleanup() {
    unawaited(_subscription?.cancel());
    _subscription = null;
    _cancelToken = null;
  }
}
