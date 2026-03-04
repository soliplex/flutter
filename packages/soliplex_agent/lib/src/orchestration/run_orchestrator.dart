import 'dart:async';

import 'package:soliplex_agent/src/models/failure_reason.dart';
import 'package:soliplex_agent/src/models/thread_key.dart';
import 'package:soliplex_agent/src/orchestration/error_classifier.dart';
import 'package:soliplex_agent/src/orchestration/run_state.dart';
import 'package:soliplex_agent/src/tools/tool_registry.dart';
import 'package:soliplex_client/soliplex_client.dart';
import 'package:soliplex_logging/soliplex_logging.dart';

/// Callback invoked when the model yields client-side tool calls.
///
/// Returns executed tools with status and result populated.
typedef ToolExecutorCallback = Future<List<ToolCallInfo>> Function(
  List<ToolCallInfo> pendingToolCalls,
);

/// Orchestrates a single AG-UI run lifecycle.
///
/// State machine: Idle -> Running -> Completed/ToolYielding/Failed/Cancelled.
/// Only one run at a time; concurrent calls throw [StateError].
///
/// ## Recommended: `runToCompletion()`
///
/// The recommended entry point is [runToCompletion], which drives the full
/// tool-yield/resume cycle internally and returns the terminal [RunState].
///
/// ```dart
/// final result = await orchestrator.runToCompletion(
///   key: key,
///   userMessage: 'Hello',
///   toolExecutor: (pending) async {
///     return pending.map((tc) => tc.copyWith(
///       status: ToolCallStatus.completed,
///       result: await executeMyTool(tc),
///     )).toList();
///   },
/// );
/// ```
///
/// ## Backend flow
///
/// The caller is responsible for creating the thread before calling
/// [runToCompletion] or [startRun]. Typical sequence:
///
/// ```dart
/// // 1. Create thread (POST /rooms/{roomId}/agui)
/// final (threadInfo, aguiState) = await api.createThread(roomId);
///
/// // 2. Build ThreadKey from server-assigned thread ID
/// final key = (serverId: 'default', roomId: roomId, threadId: threadInfo.id);
///
/// // 3. Run to completion
/// final result = await orchestrator.runToCompletion(
///   key: key,
///   userMessage: 'Hello',
///   toolExecutor: myToolExecutor,
///   existingRunId: threadInfo.hasInitialRun ? threadInfo.initialRunId : null,
/// );
/// ```
///
/// **Important:** Each [Tool] definition must include a `parameters` field
/// (JSON Schema). The backend rejects tool definitions without it.
class RunOrchestrator {
  /// Creates a [RunOrchestrator] with the given dependencies.
  RunOrchestrator({
    required SoliplexApi api,
    required AgUiClient agUiClient,
    required ToolRegistry toolRegistry,
    required Logger logger,
  })  : _api = api,
        _agUiClient = agUiClient,
        _toolRegistry = toolRegistry,
        _logger = logger;

  final SoliplexApi _api;
  final AgUiClient _agUiClient;
  final ToolRegistry _toolRegistry;
  final Logger _logger;

  static const _maxToolDepth = 10;

  final StreamController<RunState> _controller =
      StreamController<RunState>.broadcast();

  RunState _currentState = const IdleState();
  bool _disposed = false;
  bool _disposing = false;
  CancelToken? _cancelToken;
  StreamSubscription<BaseEvent>? _subscription;
  bool _receivedTerminalEvent = false;
  int _toolDepth = 0;

  // runToCompletion infrastructure
  Completer<RunState>? _terminalCompleter;
  int _subscriptionEpoch = 0;
  bool _runToCompletionActive = false;

  /// The current state of the orchestrator.
  RunState get currentState => _currentState;

  /// Broadcast stream of state transitions.
  Stream<RunState> get stateChanges => _controller.stream;

  /// The current cancellation token for the active run.
  ///
  /// Returns a fresh (uncancelled) token if no run is active.
  CancelToken get cancelToken {
    _guardNotDisposed();
    return _cancelToken ?? CancelToken();
  }

  /// Runs a complete agent interaction including all tool yield/resume cycles.
  ///
  /// State emissions continue on [stateChanges] for UI observers.
  /// Returns the terminal [RunState] (Completed, Failed, or Cancelled).
  ///
  /// While active, [startRun] and [submitToolOutputs] throw [StateError].
  Future<RunState> runToCompletion({
    required ThreadKey key,
    required String userMessage,
    required ToolExecutorCallback toolExecutor,
    String? existingRunId,
    ThreadHistory? cachedHistory,
  }) async {
    _guardRunToCompletion();
    _runToCompletionActive = true;
    _toolDepth = 0;
    try {
      try {
        await _initializeStream(
          key,
          userMessage,
          existingRunId,
          cachedHistory,
        );
      } on Object catch (error, stackTrace) {
        _handleStartError(key, error, stackTrace);
        return _currentState;
      }
      if (_disposed) return CancelledState(threadKey: key);
      return await _driveToolLoop(key, toolExecutor);
    } finally {
      _runToCompletionActive = false;
    }
  }

  /// **Deprecated.** Use [runToCompletion] instead.
  ///
  /// Starts a new agent run. The caller must observe [stateChanges] and
  /// handle [ToolYieldingState] by calling [submitToolOutputs] manually.
  ///
  /// Throws [StateError] if already running, disposed, or
  /// [runToCompletion] is active.
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
      final conversation = _buildConversation(key, userMessage, cachedHistory);
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

  /// **Deprecated.** Use [runToCompletion] instead.
  ///
  /// Submits executed tool results and resumes the agent. Creates a **new
  /// backend run** for the continuation.
  ///
  /// Throws [StateError] if not in [ToolYieldingState], disposed, or
  /// [runToCompletion] is active.
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
  ///
  /// Safe to call during an active run — stream errors triggered by
  /// cancellation are silently absorbed to prevent unhandled exceptions.
  void dispose() {
    if (_disposed) return;
    _disposing = true;
    _disposed = true;
    _cancelToken?.cancel();
    _cancelToken = null;
    _completeTerminalOnDispose();
    unawaited(_subscription?.cancel());
    _subscription = null;
    if (!_controller.isClosed) {
      unawaited(_controller.close());
    }
    _disposing = false;
  }

  // ---------------------------------------------------------------------------
  // Private helpers — each <=40 LOC, <=4 params
  // ---------------------------------------------------------------------------

  /// Sets up the initial SSE subscription for [runToCompletion].
  Future<void> _initializeStream(
    ThreadKey key,
    String userMessage,
    String? existingRunId,
    ThreadHistory? cachedHistory,
  ) async {
    final runId = await _createOrUseRun(key, existingRunId);
    if (_disposed) return;
    final conversation = _buildConversation(key, userMessage, cachedHistory);
    final input = _buildInput(key, runId, conversation);
    final endpoint = _buildEndpoint(key, runId);
    _subscribeToStream(
      endpoint,
      input,
      RunningState(
        threadKey: key,
        runId: runId,
        conversation: conversation,
        streaming: const AwaitingText(),
      ),
    );
  }

  /// Drives the tool yield/resume loop for [runToCompletion].
  ///
  /// **R4:** Every operation inside the loop is wrapped in try/catch
  /// that returns a terminal [RunState].
  Future<RunState> _driveToolLoop(
    ThreadKey key,
    ToolExecutorCallback toolExecutor,
  ) async {
    while (true) {
      final state = await _terminalCompleter!.future;
      if (state is! ToolYieldingState) return state;
      if (_disposed) return _cancelledFromYielding(key, state);
      List<ToolCallInfo> results;
      try {
        results = await toolExecutor(state.pendingToolCalls);
      } on Object catch (e) {
        return _failFromYielding(key, state, e);
      }
      if (_disposed) return _cancelledFromYielding(key, state);
      if (_currentState is CancelledState) return _currentState;
      try {
        _toolDepth++;
        if (_toolDepth > _maxToolDepth) {
          return _failDepthExceeded(key, state);
        }
        await _resumeStream(state, results);
      } on Object catch (e) {
        return _failFromYielding(key, state, e);
      }
    }
  }

  /// Resumes the SSE stream after tool execution.
  ///
  /// Creates a new backend run and subscribes to the continuation stream.
  Future<void> _resumeStream(
    ToolYieldingState yielding,
    List<ToolCallInfo> executedTools,
  ) async {
    final conversation = _buildResumeConversation(yielding, executedTools);
    final newRunId = await _createOrUseRun(yielding.threadKey, null);
    if (_disposed) return;
    final input = _buildInput(yielding.threadKey, newRunId, conversation);
    final endpoint = _buildEndpoint(yielding.threadKey, newRunId);
    _subscribeToStream(
      endpoint,
      input,
      RunningState(
        threadKey: yielding.threadKey,
        runId: newRunId,
        conversation: conversation,
        streaming: const AwaitingText(),
      ),
    );
  }

  /// Returns a [CancelledState] from a tool-yielding context.
  CancelledState _cancelledFromYielding(
    ThreadKey key,
    ToolYieldingState state,
  ) {
    return CancelledState(threadKey: key, conversation: state.conversation);
  }

  /// Returns a [FailedState] for a tool execution error during the loop.
  RunState _failFromYielding(
    ThreadKey key,
    ToolYieldingState state,
    Object error,
  ) {
    final failed = FailedState(
      threadKey: key,
      reason: FailureReason.toolExecutionFailed,
      error: error.toString(),
      conversation: state.conversation,
    );
    _setState(failed);
    return failed;
  }

  /// Returns a [FailedState] when the tool depth limit is exceeded.
  RunState _failDepthExceeded(ThreadKey key, ToolYieldingState state) {
    final failed = FailedState(
      threadKey: key,
      reason: FailureReason.toolExecutionFailed,
      error: 'Tool depth limit exceeded ($_maxToolDepth)',
      conversation: state.conversation,
    );
    _setState(failed);
    return failed;
  }

  /// Whether [state] is terminal for the SSE subscription completer.
  ///
  /// **R1:** Exhaustive switch expression — adding a new [RunState]
  /// variant without updating this method causes a compile error.
  bool _isTerminal(RunState state) => switch (state) {
        CompletedState() => true,
        FailedState() => true,
        CancelledState() => true,
        ToolYieldingState() => true,
        RunningState() => false,
        IdleState() => false,
      };

  /// Defensively completes [_terminalCompleter] during [dispose] (R4).
  void _completeTerminalOnDispose() {
    if (_terminalCompleter?.isCompleted ?? true) return;
    final key = switch (_currentState) {
      RunningState(:final threadKey) => threadKey,
      ToolYieldingState(:final threadKey) => threadKey,
      _ => const (serverId: '', roomId: '', threadId: ''),
    };
    _terminalCompleter!.complete(CancelledState(threadKey: key));
  }

  void _guardRunToCompletion() {
    _guardNotDisposed();
    if (_runToCompletionActive) {
      throw StateError('runToCompletion is already active');
    }
    if (_currentState is RunningState || _currentState is ToolYieldingState) {
      throw StateError('A run is already active');
    }
  }

  void _guardNotRunning() {
    _guardNotDisposed();
    if (_runToCompletionActive) {
      throw StateError(
        'Cannot call startRun while runToCompletion is active',
      );
    }
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
    if (_runToCompletionActive) {
      throw StateError(
        'Cannot call submitToolOutputs while runToCompletion is active',
      );
    }
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

  Future<String> _createOrUseRun(ThreadKey key, String? existingRunId) async {
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
    // Cancel stale subscription from the previous run.
    unawaited(_subscription?.cancel());
    _subscription = null;
    _cancelToken = CancelToken();
    _receivedTerminalEvent = false;
    _terminalCompleter = Completer<RunState>();
    _subscriptionEpoch++;
    final epoch = _subscriptionEpoch;
    final stream = _agUiClient.runAgent(
      endpoint,
      input,
      cancelToken: _cancelToken,
    );
    _setState(initialState);
    _subscription = stream.listen(
      _onEvent,
      onError: _onStreamError,
      onDone: () {
        if (epoch != _subscriptionEpoch) return;
        _onStreamDone();
      },
    );
  }

  void _onEvent(BaseEvent event) {
    final running = _currentState;
    if (running is! RunningState) return;
    final result = processEvent(running.conversation, running.streaming, event);
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
    _subscription = null;
    if (_disposing || _disposed) return;
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
    if (_disposing || _disposed) return;
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
    _logger.error('Run failed', error: error, stackTrace: stackTrace);
    _setState(
      FailedState(
        threadKey: running.threadKey,
        reason: reason,
        error: error.toString(),
        conversation: running.conversation,
      ),
    );
  }

  void _handleStartError(ThreadKey key, Object error, StackTrace stackTrace) {
    _cleanup();
    final reason = classifyError(error);
    _logger.error('Failed to start run', error: error, stackTrace: stackTrace);
    _setState(
      FailedState(threadKey: key, reason: reason, error: error.toString()),
    );
  }

  void _setState(RunState newState) {
    _currentState = newState;
    if (!_controller.isClosed) {
      _controller.add(newState);
    }
    if (_isTerminal(newState) && !(_terminalCompleter?.isCompleted ?? true)) {
      _terminalCompleter!.complete(newState);
    }
  }

  void _cleanup() {
    unawaited(_subscription?.cancel());
    _subscription = null;
    _cancelToken = null;
  }
}
