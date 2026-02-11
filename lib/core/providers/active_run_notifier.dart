import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soliplex_client/soliplex_client.dart';
import 'package:soliplex_client/soliplex_client.dart' as domain
    show Cancelled, Completed, Conversation, Failed, Idle, Running;
import 'package:soliplex_frontend/core/logging/loggers.dart';
import 'package:soliplex_frontend/core/models/active_run_state.dart';
import 'package:soliplex_frontend/core/providers/api_provider.dart';
import 'package:soliplex_frontend/core/providers/thread_history_cache.dart';

/// Internal state representing the notifier's resource management.
///
/// This sealed class ensures proper lifecycle management of the AgUiClient,
/// CancelToken, and StreamSubscription without nullable fields.
sealed class NotifierInternalState {
  const NotifierInternalState();
}

/// No active run - initial state or after reset.
@immutable
class IdleInternalState extends NotifierInternalState {
  const IdleInternalState();
}

/// A run is currently active with associated resources.
///
/// Not marked as @immutable because it holds mutable StreamSubscription.
class RunningInternalState extends NotifierInternalState {
  RunningInternalState({
    required this.roomId,
    required this.runId,
    required this.cancelToken,
    required this.subscription,
    required this.userMessageId,
    required this.previousAguiState,
  });

  /// The room this run belongs to. Needed for continuation runs
  /// (tool result submission).
  final String roomId;

  /// The ID of the active run.
  final String runId;

  /// Token for cancelling the run.
  final CancelToken cancelToken;

  /// Subscription to the event stream.
  final StreamSubscription<BaseEvent> subscription;

  /// The ID of the user message that triggered this run.
  /// Used to correlate citations at run completion.
  final String userMessageId;

  /// AG-UI state snapshot from before the run started.
  /// Used to detect new citations via length-based comparison.
  final Map<String, dynamic> previousAguiState;

  /// Completes when the SSE stream closes (onDone fires).
  /// Used by continuation runs to wait for the backend to finish
  /// processing Run 1 before creating Run 2.
  final Completer<void> streamDone = Completer<void>();

  /// Whether tool execution is in progress. When true, the onDone
  /// handler skips the CompletedState transition (the continuation
  /// run will handle it).
  bool toolExecutionPending = false;

  /// Disposes of all resources.
  Future<void> dispose() async {
    cancelToken.cancel();
    await subscription.cancel();
  }
}

/// Manages the lifecycle of an active AG-UI run.
///
/// This notifier:
/// - Uses [AgUiClient] for SSE streaming
/// - Processes AG-UI events from the backend
/// - Updates state as messages stream in
/// - Handles cancellation and errors
///
/// Usage:
/// ```dart
/// final notifier = ref.read(activeRunNotifierProvider.notifier);
/// await notifier.startRun(
///   roomId: 'room-123',
///   threadId: 'thread-456',
///   userMessage: 'Hello!',
/// );
/// ```
class ActiveRunNotifier extends Notifier<ActiveRunState> {
  late AgUiClient _agUiClient;
  late ToolRegistry _toolRegistry;
  NotifierInternalState _internalState = const IdleInternalState();
  bool _isStarting = false;

  @override
  ActiveRunState build() {
    _agUiClient = ref.watch(agUiClientProvider);
    _toolRegistry = ref.watch(toolRegistryProvider);

    ref.onDispose(() {
      if (_internalState is RunningInternalState) {
        (_internalState as RunningInternalState).dispose();
      }
    });

    return const IdleState();
  }

  /// Starts a new run with the given message.
  ///
  /// Two-step process:
  /// 1. Creates run via API to get backend-generated run_id (or uses provided)
  /// 2. Streams AG-UI events using that run_id
  ///
  /// If [existingRunId] is provided, uses that run instead of creating new.
  /// Useful when a thread was just created with an initial run.
  ///
  /// Throws [StateError] if a run is already active. Call [cancelRun] first.
  Future<void> startRun({
    required String roomId,
    required String threadId,
    required String userMessage,
    String? existingRunId,
    Map<String, dynamic>? initialState,
  }) async {
    if (_isStarting || state.isRunning) {
      throw StateError(
        'Cannot start run: a run is already active. '
        'Call cancelRun() first.',
      );
    }

    _isStarting = true;
    Loggers.activeRun.debug(
      'startRun called: room=$roomId, thread=$threadId',
    );
    StreamSubscription<BaseEvent>? subscription;
    String? runId;

    try {
      // Dispose any previous resources
      if (_internalState is RunningInternalState) {
        await (_internalState as RunningInternalState).dispose();
      }

      // Create new resources
      final cancelToken = CancelToken();

      // Step 1: Get run_id (use existing or create new)
      if (existingRunId != null && existingRunId.isNotEmpty) {
        runId = existingRunId;
      } else {
        final api = ref.read(apiProvider);
        final runInfo = await api.createRun(roomId, threadId);
        runId = runInfo.id;
      }

      // Create user message.
      // Note: Message ID uses milliseconds. Collision is mitigated by
      // _isStarting guard preventing concurrent startRun calls.
      final userMessageObj = TextMessage.create(
        id: 'user_${DateTime.now().millisecondsSinceEpoch}',
        user: ChatUser.user,
        text: userMessage,
      );

      // Read historical thread data from cache.
      // Cache is populated by allMessagesProvider when thread is selected.
      // If cache is empty (e.g., direct URL navigation + immediate send),
      // we proceed without history - backend still processes correctly.
      //
      // Deferred: Safety fetch from backend when cache is empty. Not needed
      // because normal UI flow ensures cache is populated before user can
      // send. Adding async fetch here would block UI for a rare edge case.
      // See issue #30 for details.
      final cachedHistory = ref.read(threadHistoryCacheProvider)[threadId];
      final cachedMessages = cachedHistory?.messages ?? [];
      final cachedAguiState = cachedHistory?.aguiState ?? const {};

      // Combine historical messages with new user message
      final allMessages = [...cachedMessages, userMessageObj];

      // Create conversation with full history, AG-UI state, and Running status
      final conversation = domain.Conversation(
        threadId: threadId,
        messages: allMessages,
        status: domain.Running(runId: runId),
        aguiState: cachedAguiState,
      );

      // Set running state
      state = RunningState(conversation: conversation);

      // Convert all messages to AG-UI format for backend
      final aguiMessages = convertToAgui(allMessages);

      // Merge accumulated AG-UI state with any client-provided initial state.
      // Order: cached state first (backend-generated), then initial state
      // (client-generated like filter_documents) so client can override.
      final mergedState = <String, dynamic>{
        ...cachedAguiState,
        ...?initialState,
      };

      // Create the input for the run.
      // Include client-side tool definitions so the model knows they exist.
      final toolDefs = _toolRegistry.toolDefinitions;
      final input = SimpleRunAgentInput(
        threadId: threadId,
        runId: runId,
        messages: aguiMessages,
        tools: toolDefs.isNotEmpty ? toolDefs : null,
        state: mergedState,
      );

      // Start streaming and store running state with correlation data.
      _internalState = _establishRunSubscription(
        roomId: roomId,
        runId: runId,
        cancelToken: cancelToken,
        input: input,
        userMessageId: userMessageObj.id,
        previousAguiState: cachedAguiState,
      );
      subscription = (_internalState as RunningInternalState).subscription;
    } on CancellationError catch (e, st) {
      // User cancelled - clean up resources
      Loggers.activeRun.info('Run cancelled', error: e, stackTrace: st);
      await subscription?.cancel();
      final completed = CompletedState(
        conversation: state.conversation.withStatus(
          domain.Cancelled(reason: e.message),
        ),
        result: CancelledResult(reason: e.message),
      );
      state = completed;
      _updateCacheOnCompletion(completed);
      _internalState = const IdleInternalState();
    } catch (e, stackTrace) {
      // Clean up subscription on any error
      Loggers.activeRun.error(
        'Run failed with exception',
        error: e,
        stackTrace: stackTrace,
      );
      await subscription?.cancel();
      final errorMsg = e.toString();
      final completed = CompletedState(
        conversation: state.conversation.withStatus(
          domain.Failed(error: errorMsg),
        ),
        result: FailedResult(errorMessage: errorMsg, stackTrace: stackTrace),
      );
      state = completed;
      _updateCacheOnCompletion(completed);
      _internalState = const IdleInternalState();
    } finally {
      _isStarting = false;
    }
  }

  /// Cancels the active run.
  ///
  /// Preserves all completed messages but clears streaming state.
  Future<void> cancelRun() async {
    Loggers.activeRun.debug('cancelRun called');
    final currentState = state;
    final previousInternalState = _internalState;

    if (previousInternalState is RunningInternalState) {
      await previousInternalState.dispose();
      _internalState = const IdleInternalState();
    }

    if (currentState is RunningState) {
      final completed = CompletedState(
        conversation: currentState.conversation.withStatus(
          const domain.Cancelled(reason: 'User cancelled'),
        ),
        result: const CancelledResult(reason: 'Cancelled by user'),
      );
      state = completed;
      _updateCacheOnCompletion(completed);
    }
  }

  /// Resets to idle state, clearing all messages and state.
  ///
  /// Clears UI state immediately so the UI updates instantly, then awaits
  /// disposal of any active resources. Disposal errors are caught and logged
  /// to ensure fire-and-forget callers (like Riverpod listeners) are safe.
  Future<void> reset() async {
    Loggers.activeRun.debug('reset called');
    final previousState = _internalState;
    _internalState = const IdleInternalState();
    state = const IdleState();

    if (previousState is RunningInternalState) {
      try {
        await previousState.dispose();
      } on Exception catch (e, st) {
        Loggers.activeRun.error(
          'Disposal error during reset',
          error: e,
          stackTrace: st,
        );
      }
    }
  }

  /// Handles run failures from both stream errors and processing exceptions.
  ///
  /// Logs the error, transitions to failed state, and cleans up resources.
  void _handleRunFailure(Object error, StackTrace stackTrace) {
    Loggers.activeRun.error(
      'Run failed',
      error: error,
      stackTrace: stackTrace,
    );

    final currentState = state;
    if (currentState is RunningState) {
      final errorMsg = error.toString();
      final completed = CompletedState(
        conversation: currentState.conversation.withStatus(
          domain.Failed(error: errorMsg),
        ),
        result: FailedResult(errorMessage: errorMsg, stackTrace: stackTrace),
      );
      state = completed;
      _updateCacheOnCompletion(completed);
    }

    // Clean up internal state
    final internalState = _internalState;
    if (internalState is RunningInternalState) {
      internalState.dispose();
      _internalState = const IdleInternalState();
    }
  }

  /// Processes a single AG-UI event and updates state accordingly.
  void _processEvent(BaseEvent event) {
    try {
      final currentState = state;
      if (currentState is! RunningState) return;

      // Log AG-UI events for debugging
      _logEvent(event);

      // Use application layer processor
      final result = processEvent(
        currentState.conversation,
        currentState.streaming,
        event,
      );

      // Map result to frontend state
      final newState = _mapResultToState(currentState, result);
      state = newState;

      // After a ToolCallEnd, check if all tool calls are pending (ready).
      // If so, execute them and continue with a new run.
      if (event is ToolCallEndEvent &&
          newState is RunningState &&
          !_toolRegistry.isEmpty) {
        final pendingCalls = newState.conversation.toolCalls
            .where((tc) => tc.status == ToolCallStatus.pending)
            .toList();
        final streamingCalls = newState.conversation.toolCalls
            .where((tc) => tc.status == ToolCallStatus.streaming)
            .toList();
        if (pendingCalls.isNotEmpty && streamingCalls.isEmpty) {
          _executeToolsAndContinue(pendingCalls);
        }
      }
    } catch (e, st) {
      _handleRunFailure(e, st);
    }
  }

  /// Executes all pending tool calls and continues with a new run.
  ///
  /// Safety: pauses the stream subscription first (no late events), checks
  /// `ref.mounted` after each await (user may navigate away), and never emits
  /// a non-Running public state during the transition.
  Future<void> _executeToolsAndContinue(List<ToolCallInfo> pendingCalls) async {
    final internal = _internalState;
    if (internal is! RunningInternalState) return;

    // Mark tool execution pending so onDone skips CompletedState.
    internal.toolExecutionPending = true;

    // Safety 3: Pause subscription before any async work.
    internal.subscription.pause();
    Loggers.activeRun.debug('Stream paused for tool execution');

    Loggers.activeRun.debug(
      'Executing ${pendingCalls.length} tool call(s): '
      '${pendingCalls.map((tc) => tc.name).join(", ")}',
    );

    // Mark all pending calls as executing
    final currentState = state;
    if (currentState is! RunningState) return;

    var conversation = currentState.conversation;
    conversation = conversation.copyWith(
      toolCalls: conversation.toolCalls
          .map(
            (tc) => pendingCalls.any((p) => p.id == tc.id)
                ? tc.copyWith(status: ToolCallStatus.executing)
                : tc,
          )
          .toList(),
    );
    state = currentState.copyWith(conversation: conversation);

    // Execute each tool with per-tool error isolation
    final results = <(String, String, ToolCallStatus)>[];
    await Future.wait(
      pendingCalls.map((tc) async {
        Loggers.activeRun.debug('Tool executing: ${tc.name} (${tc.id})');
        try {
          final result = await _toolRegistry.execute(tc);
          Loggers.activeRun.debug('Tool completed: ${tc.name} (${tc.id})');
          results.add((tc.id, result, ToolCallStatus.completed));
        } catch (e) {
          Loggers.activeRun.warning(
            'Tool failed: ${tc.name} (${tc.id})',
            error: e,
          );
          results.add((tc.id, 'Error: $e', ToolCallStatus.failed));
        }
      }),
    );

    // Safety 1: User may have navigated away during execution.
    if (!ref.mounted) return;

    // Mark each call completed/failed and update conversation
    final afterExec = state;
    if (afterExec is! RunningState) return;

    conversation = afterExec.conversation;
    final resultMap = {for (final r in results) r.$1: r};
    conversation = conversation.copyWith(
      toolCalls: conversation.toolCalls.map((tc) {
        final result = resultMap[tc.id];
        if (result != null) {
          return tc.copyWith(status: result.$3, result: result.$2);
        }
        return tc;
      }).toList(),
    );
    // Add ToolCallMessage to conversation so convertToAgui produces
    // AssistantMessage (tool calls) + ToolMessage (results) for the backend.
    final toolCallMessage = ToolCallMessage.create(
      id: 'tool_msg_${DateTime.now().millisecondsSinceEpoch}',
      toolCalls: conversation.toolCalls,
    );
    conversation = conversation
        .withAppendedMessage(toolCallMessage)
        .copyWith(toolCalls: []);
    state = afterExec.copyWith(conversation: conversation);

    // Resume subscription so remaining events (RUN_FINISHED) are delivered
    // and the stream closes naturally. The backend's on_done handler saves
    // events and marks the run as finished only when the connection closes.
    Loggers.activeRun.debug('Resuming stream to drain Run 1');
    internal.subscription.resume();

    // Wait for the stream to close (onDone fires). This ensures the backend
    // has processed the connection close and marked Run 1 as finished before
    // we create Run 2.
    await internal.streamDone.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        Loggers.activeRun.warning('Run 1 stream did not close within 10s');
      },
    );
    await internal.subscription.cancel();
    if (!ref.mounted) return;

    // Safety 4: If cancelRun() or reset() replaced _internalState during
    // the stream drain, another owner took over. Do not start Run 2.
    if (_internalState != internal) return;

    await _continueWithToolResults(internal, conversation);
  }

  /// Creates a continuation run (Run 2) with tool results in messages.
  ///
  /// The public state stays [RunningState] throughout — the UI sees
  /// uninterrupted "running".
  Future<void> _continueWithToolResults(
    RunningInternalState previousInternal,
    domain.Conversation conversation,
  ) async {
    final roomId = previousInternal.roomId;
    final threadId = conversation.threadId;

    try {
      // Create a new run via the API (like PR #83).
      final api = ref.read(apiProvider);
      final runInfo = await api.createRun(roomId, threadId);
      final newRunId = runInfo.id;

      // Convert all messages (including tool results) to AG-UI format
      final aguiMessages = convertToAgui(conversation.messages);

      final msgSummary = aguiMessages.map((m) {
        final suffix = m is ToolMessage ? '(${m.toolCallId})' : '';
        return '${m.role.value}$suffix';
      }).join(', ');
      Loggers.activeRun.debug(
        'Continuation messages (${aguiMessages.length}): $msgSummary',
      );

      final toolDefs = _toolRegistry.toolDefinitions;
      final input = SimpleRunAgentInput(
        threadId: threadId,
        runId: newRunId,
        messages: aguiMessages,
        tools: toolDefs.isNotEmpty ? toolDefs : null,
        state: conversation.aguiState,
      );

      // New cancel token for the continuation run (old run's token is stale).
      final cancelToken = CancelToken();

      // Update conversation status to Running with new run ID
      final runningConversation =
          conversation.withStatus(domain.Running(runId: newRunId));
      state = RunningState(conversation: runningConversation);

      // Swap internal state — public state stays RunningState (Safety 2).
      // Uses the shared subscription setup so continuation runs also support
      // multi-hop tool calling (Run 2 → Run 3).
      _internalState = _establishRunSubscription(
        roomId: roomId,
        runId: newRunId,
        cancelToken: cancelToken,
        input: input,
        userMessageId: previousInternal.userMessageId,
        previousAguiState: previousInternal.previousAguiState,
      );

      if (!ref.mounted) {
        await (_internalState as RunningInternalState).subscription.cancel();
        _internalState = const IdleInternalState();
        return;
      }
    } catch (e, st) {
      // Continuation run failed (network error, server down).
      Loggers.activeRun.error(
        'Continuation run failed: $e',
        error: e,
        stackTrace: st,
      );
      _handleRunFailure(e, st);
    }
  }

  /// Creates an event stream subscription and wraps it in a
  /// [RunningInternalState].
  ///
  /// Shared by [startRun] and [_continueWithToolResults] so both use
  /// the same onDone/onError semantics. In particular, the onDone handler
  /// supports the stream drain protocol (completes `streamDone`, respects
  /// `toolExecutionPending`), enabling multi-hop tool calling.
  RunningInternalState _establishRunSubscription({
    required String roomId,
    required String runId,
    required CancelToken cancelToken,
    required SimpleRunAgentInput input,
    required String userMessageId,
    required Map<String, dynamic> previousAguiState,
  }) {
    final endpoint = 'rooms/$roomId/agui/${input.threadId}/$runId';
    final eventStream = _agUiClient.runAgent(
      endpoint,
      input,
      cancelToken: cancelToken,
    );

    // ignore: cancel_subscriptions - stored in RunningInternalState
    final subscription = eventStream.listen(
      _processEvent,
      onError: (Object error, StackTrace stackTrace) {
        final effectiveStack =
            stackTrace.toString().isNotEmpty ? stackTrace : StackTrace.current;
        _handleRunFailure(error, effectiveStack);
      },
      onDone: () {
        final internal = _internalState;
        if (internal is RunningInternalState) {
          if (!internal.streamDone.isCompleted) {
            internal.streamDone.complete();
          }
          if (internal.toolExecutionPending) return;
        }
        final currentState = state;
        if (currentState is RunningState) {
          final completed = CompletedState(
            conversation: currentState.conversation.withStatus(
              const domain.Completed(),
            ),
            result: const Success(),
          );
          state = completed;
          _updateCacheOnCompletion(completed);
        }
      },
      cancelOnError: false,
    );

    Loggers.activeRun.debug(
      'Stream subscription established for run $runId',
    );

    return RunningInternalState(
      roomId: roomId,
      runId: runId,
      cancelToken: cancelToken,
      subscription: subscription,
      userMessageId: userMessageId,
      previousAguiState: previousAguiState,
    );
  }

  /// Logs AG-UI events at appropriate levels.
  void _logEvent(BaseEvent event) {
    switch (event) {
      case RunStartedEvent():
        Loggers.activeRun.debug('RUN_STARTED');
      case RunFinishedEvent():
        Loggers.activeRun.debug('RUN_FINISHED');
      case RunErrorEvent(:final message):
        Loggers.activeRun.error('RUN_ERROR: $message');
      case ThinkingTextMessageStartEvent():
        Loggers.activeRun.trace('THINKING_START');
      case ThinkingTextMessageContentEvent():
        Loggers.activeRun.trace('THINKING_CONTENT');
      case ThinkingTextMessageEndEvent():
        Loggers.activeRun.trace('THINKING_END');
      case TextMessageStartEvent(:final messageId):
        Loggers.activeRun.debug('TEXT_START: $messageId');
      case TextMessageContentEvent(:final messageId):
        Loggers.activeRun.trace('TEXT_CONTENT: $messageId');
      case TextMessageEndEvent(:final messageId):
        Loggers.activeRun.debug('TEXT_END: $messageId');
      case ToolCallStartEvent(:final toolCallId, :final toolCallName):
        Loggers.activeRun.debug('TOOL_START: $toolCallName ($toolCallId)');
      case ToolCallArgsEvent(:final toolCallId):
        Loggers.activeRun.trace('TOOL_ARGS: $toolCallId');
      case ToolCallEndEvent(:final toolCallId):
        Loggers.activeRun.debug('TOOL_END: $toolCallId');
      case StateSnapshotEvent():
        Loggers.activeRun.debug('STATE_SNAPSHOT');
      case StateDeltaEvent():
        Loggers.activeRun.debug('STATE_DELTA');
      default:
        Loggers.activeRun.trace('EVENT: ${event.runtimeType}');
    }
  }

  /// Maps an EventProcessingResult to the appropriate ActiveRunState.
  ///
  /// When the run completes (Completed/Failed/Cancelled), also updates
  /// the message cache so messages persist after thread switching.
  ActiveRunState _mapResultToState(
    RunningState previousState,
    EventProcessingResult result,
  ) {
    // On completion, correlate citations with the user message
    final conversation = _correlateMessageStateOnCompletion(result);

    final newState = switch (conversation.status) {
      domain.Completed() => CompletedState(
          conversation: conversation,
          streaming: result.streaming,
          result: const Success(),
        ),
      domain.Failed(:final error) => () {
          Loggers.activeRun.error('Run completed with failure: $error');
          return CompletedState(
            conversation: conversation,
            streaming: result.streaming,
            result: FailedResult(errorMessage: error),
          );
        }(),
      domain.Cancelled(:final reason) => CompletedState(
          conversation: conversation,
          streaming: result.streaming,
          result: CancelledResult(reason: reason),
        ),
      domain.Running() => previousState.copyWith(
          conversation: conversation,
          streaming: result.streaming,
        ),
      domain.Idle() => throw StateError(
          'Unexpected Idle status during event processing',
        ),
    };

    // Update cache when run completes via event
    if (newState is CompletedState) {
      _updateCacheOnCompletion(newState);
    }

    return newState;
  }

  /// Correlates AG-UI state changes with the user message on run completion.
  ///
  /// Uses [CitationExtractor] to find new citations by comparing the
  /// previous AG-UI state (captured at run start) with the current state.
  /// Creates a [MessageState] and adds it to the conversation.
  domain.Conversation _correlateMessageStateOnCompletion(
    EventProcessingResult result,
  ) {
    final conversation = result.conversation;

    // Only correlate on completion (Completed, Failed, Cancelled)
    if (conversation.status is domain.Running) {
      return conversation;
    }

    // Need internal state for correlation data
    if (_internalState is! RunningInternalState) {
      return conversation;
    }

    final runningState = _internalState as RunningInternalState;
    final userMessageId = runningState.userMessageId;
    final previousAguiState = runningState.previousAguiState;

    // Extract new citations using the schema firewall
    final extractor = CitationExtractor();
    final sourceReferences = extractor.extractNew(
      previousAguiState,
      conversation.aguiState,
    );

    // Create MessageState and add to conversation
    final messageState = MessageState(
      userMessageId: userMessageId,
      sourceReferences: sourceReferences,
    );

    return conversation.withMessageState(userMessageId, messageState);
  }

  /// Updates the history cache when a run completes.
  void _updateCacheOnCompletion(CompletedState completedState) {
    final threadId = completedState.threadId;
    if (threadId.isEmpty) return;

    // Merge existing messageStates from cache with new ones from this run
    final cachedHistory = ref.read(threadHistoryCacheProvider)[threadId];
    final existingMessageStates = cachedHistory?.messageStates ?? const {};
    final newMessageStates = completedState.conversation.messageStates;

    final history = ThreadHistory(
      messages: completedState.messages,
      aguiState: completedState.conversation.aguiState,
      messageStates: {...existingMessageStates, ...newMessageStates},
    );
    ref
        .read(threadHistoryCacheProvider.notifier)
        .updateHistory(threadId, history);
  }
}
