import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soliplex_client/soliplex_client.dart';
import 'package:soliplex_client/soliplex_client.dart' as domain
    show Cancelled, Completed, Conversation, Failed, Idle, Running;
import 'package:soliplex_frontend/core/logging/loggers.dart';
import 'package:soliplex_frontend/core/models/active_run_state.dart';
import 'package:soliplex_frontend/core/models/run_handle.dart';
import 'package:soliplex_frontend/core/models/run_lifecycle_event.dart';
import 'package:soliplex_frontend/core/models/thread_key.dart';
import 'package:soliplex_frontend/core/providers/api_provider.dart';
import 'package:soliplex_frontend/core/providers/rooms_provider.dart';
import 'package:soliplex_frontend/core/providers/thread_history_cache.dart';
import 'package:soliplex_frontend/core/providers/threads_provider.dart';
import 'package:soliplex_frontend/core/providers/unread_runs_provider.dart';
import 'package:soliplex_frontend/core/services/run_registry.dart';

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
///   key: (roomId: 'room-123', threadId: 'thread-456'),
///   userMessage: 'Hello!',
/// );
/// ```
class ActiveRunNotifier extends Notifier<ActiveRunState> {
  late AgUiClient _agUiClient;
  late ToolRegistry _toolRegistry;
  bool _isStarting = false;

  /// Registry tracking active runs across rooms and threads.
  late final RunRegistry _registry =
      RunRegistry(onRunCompleted: _buildCacheUpdater());

  /// Current run handle — the run whose state the notifier exposes to UI.
  RunHandle? _currentHandle;

  /// Subscription to registry lifecycle events.
  StreamSubscription<RunLifecycleEvent>? _lifecycleSub;

  /// The run registry for this notifier.
  ///
  /// Exposed for testing and external access to run tracking state.
  RunRegistry get registry => _registry;

  @override
  ActiveRunState build() {
    _agUiClient = ref.watch(agUiClientProvider);
    _toolRegistry = ref.watch(toolRegistryProvider);

    // Mark thread as unread when a non-cancelled background run completes.
    _lifecycleSub = _registry.lifecycleEvents.listen((event) {
      if (event is RunCompleted) {
        final isBackground = _currentHandle?.key != event.key;
        if (isBackground && event.result is! CancelledResult) {
          ref.read(unreadRunsProvider.notifier).markUnread(event.key);
        }
      }
    });

    // Sync exposed state when the user navigates between rooms/threads.
    ref
      ..listen(currentRoomIdProvider, (_, __) => _syncCurrentHandle())
      ..listen(currentThreadIdProvider, (_, __) => _syncCurrentHandle())
      ..onDispose(() {
        _lifecycleSub?.cancel();
        _registry.dispose().catchError((Object e, StackTrace st) {
          Loggers.activeRun.error(
            'Registry disposal error',
            error: e,
            stackTrace: st,
          );
        });
        _currentHandle?.dispose().catchError((Object e, StackTrace st) {
          Loggers.activeRun.error(
            'Handle disposal error',
            error: e,
            stackTrace: st,
          );
        });
        _currentHandle = null;
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
  /// Multiple runs can be active concurrently in different threads. The
  /// notifier's [state] tracks the run for the currently viewed thread.
  Future<void> startRun({
    required ThreadKey key,
    required String userMessage,
    String? existingRunId,
    Map<String, dynamic>? initialState,
  }) async {
    if (_isStarting) {
      throw StateError(
        'Cannot start run: startRun already in progress.',
      );
    }

    final roomId = key.roomId;
    final threadId = key.threadId;

    _isStarting = true;
    Loggers.activeRun.debug(
      'startRun called: room=$roomId, thread=$threadId',
    );
    String? runId;
    RunningState? pendingState;

    try {
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
      final cachedHistory = ref.read(threadHistoryCacheProvider)[key];
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

      final runningState = RunningState(conversation: conversation);
      pendingState = runningState;

      // Step 2: Build the streaming endpoint URL with backend run_id
      final endpoint = 'rooms/$roomId/agui/$threadId/$runId';

      // Convert all messages to AG-UI format for backend
      final aguiMessages = convertToAgui(allMessages);

      // Merge accumulated AG-UI state with any client-provided initial state.
      // Deep merge at the state-key level so client-provided keys (e.g.
      // document_filter) merge INTO the server's haiku.rag.chat dict
      // rather than replacing it.
      final mergedState = <String, dynamic>{...cachedAguiState};
      if (initialState != null) {
        for (final entry in initialState.entries) {
          final existing = mergedState[entry.key];
          if (existing is Map<String, dynamic> &&
              entry.value is Map<String, dynamic>) {
            mergedState[entry.key] = <String, dynamic>{
              ...existing,
              ...entry.value as Map<String, dynamic>,
            };
          } else {
            mergedState[entry.key] = entry.value;
          }
        }
      }

      // Create the input for the run
      final input = SimpleRunAgentInput(
        threadId: threadId,
        runId: runId,
        messages: aguiMessages,
        state: mergedState,
      );

      // Start streaming
      final eventStream = _agUiClient.runAgent(
        endpoint,
        input,
        cancelToken: cancelToken,
      );

      // Create the handle with subscription wired up.
      final handle = _createHandleWithSubscription(
        key: key,
        runId: runId,
        cancelToken: cancelToken,
        eventStream: eventStream,
        userMessageId: userMessageObj.id,
        previousAguiState: cachedAguiState,
        initialState: runningState,
      );

      Loggers.activeRun.debug(
        'Stream subscription established for run $runId',
      );

      // This run becomes the "current" run — notifier state follows it
      _currentHandle = handle;
      state = runningState;

      try {
        await _registry.registerRun(handle);
      } catch (e, st) {
        Loggers.activeRun.error(
          'Failed to register run with registry',
          error: e,
          stackTrace: st,
        );
      }
    } on CancellationError catch (e, st) {
      // User cancelled - clean up resources
      Loggers.activeRun.info('Run cancelled', error: e, stackTrace: st);
      final conv = pendingState?.conversation ?? state.conversation;
      final completed = CompletedState(
        conversation: conv.withStatus(
          domain.Cancelled(reason: e.message),
        ),
        result: CancelledResult(reason: e.message),
      );
      state = completed;
      registry.notifyCompletion(key, completed);
      _currentHandle = null;
    } catch (e, stackTrace) {
      Loggers.activeRun.error(
        'Run failed with exception',
        error: e,
        stackTrace: stackTrace,
      );
      final conv = pendingState?.conversation ?? state.conversation;
      final errorMsg = e.toString();
      final completed = CompletedState(
        conversation: conv.withStatus(
          domain.Failed(error: errorMsg),
        ),
        result: FailedResult(errorMessage: errorMsg, stackTrace: stackTrace),
      );
      state = completed;
      registry.notifyCompletion(key, completed);
      _currentHandle = null;
    } finally {
      _isStarting = false;
    }
  }

  /// Cancels the current run.
  ///
  /// Preserves the conversation so far and marks it as cancelled.
  /// Works for both streaming ([RunningState]) and tool execution
  /// ([ExecutingToolsState]). Background runs in other threads are unaffected.
  Future<void> cancelRun() async {
    Loggers.activeRun.debug('cancelRun called');
    final handle = _currentHandle;
    if (handle == null) return;

    // Abort synchronously before disposing to prevent race with onDone.
    // If dispose() yields, onDone could fire and complete the run as Success
    // before we get a chance to mark it Cancelled.
    final handleState = handle.state;
    if (handleState is RunningState || handleState is ExecutingToolsState) {
      _abortToCompleted(
        handle,
        const CancelledResult(reason: 'Cancelled by user'),
      );
    }

    await handle.dispose();
  }

  /// Resets to idle state, clearing all messages and state.
  ///
  /// Clears UI state immediately so the UI updates instantly, then awaits
  /// disposal of any active resources. Disposal errors are caught and logged
  /// to ensure fire-and-forget callers (like Riverpod listeners) are safe.
  Future<void> reset() async {
    Loggers.activeRun.debug('reset called');
    state = const IdleState();
    final handle = _currentHandle;
    _currentHandle = null;

    if (handle != null) {
      try {
        await handle.dispose();
      } on Exception catch (e, st) {
        Loggers.activeRun.error(
          'Disposal error during reset',
          error: e,
          stackTrace: st,
        );
      }
    }
  }

  /// Syncs the exposed state with the currently viewed thread.
  ///
  /// Called when the user navigates between rooms/threads. Looks up the
  /// registry for an active run matching the viewed thread and exposes
  /// its state. If no run exists, resets to idle.
  void _syncCurrentHandle() {
    final roomId = ref.read(currentRoomIdProvider);
    final threadId = ref.read(currentThreadIdProvider);

    if (roomId == null || threadId == null) {
      _currentHandle = null;
      state = const IdleState();
      return;
    }

    final handle = _registry.getHandle((roomId: roomId, threadId: threadId));
    if (handle != null) {
      _currentHandle = handle;
      state = handle.state;
    } else {
      _currentHandle = null;
      state = const IdleState();
    }
  }

  /// Processes a single AG-UI event for a specific run.
  void _processEventForRun(RunHandle handle, BaseEvent event) {
    try {
      final handleState = handle.state;
      if (handleState is! RunningState) return;

      _logEvent(event);

      final result = processEvent(
        handleState.conversation,
        handleState.streaming,
        event,
      );

      final newState = _mapResultForRun(handle, handleState, result);
      if (newState is CompletedState) {
        _registry.completeRun(handle, newState);
      } else {
        handle.state = newState;
      }

      _syncUiState(handle, newState);
    } catch (e, st) {
      _handleFailureForRun(handle, e, st);
    }
  }

  /// Handles run failures for a specific run.
  void _handleFailureForRun(
    RunHandle handle,
    Object error,
    StackTrace stackTrace,
  ) {
    Loggers.activeRun.error(
      'Run failed',
      error: error,
      stackTrace: stackTrace,
    );

    final handleState = handle.state;
    if (handleState is RunningState) {
      final errorMsg = error.toString();
      final completed = CompletedState(
        conversation: handleState.conversation.withStatus(
          domain.Failed(error: errorMsg),
        ),
        result: FailedResult(errorMessage: errorMsg, stackTrace: stackTrace),
      );
      _registry.completeRun(handle, completed);
      _syncUiState(handle, completed);
    }
  }

  /// Handles stream completion for a specific run.
  ///
  /// If the conversation has pending tool calls, transitions to
  /// [ExecutingToolsState] and starts client-side tool execution.
  /// Otherwise, completes normally.
  void _handleDoneForRun(RunHandle handle, {int depth = 0}) {
    final handleState = handle.state;
    if (handleState is! RunningState) return;

    final pendingTools = handleState.conversation.toolCalls
        .where((tc) => tc.status == ToolCallStatus.pending)
        .toList();

    if (pendingTools.isNotEmpty) {
      Loggers.toolExecution.debug(
        'Stream done with ${pendingTools.length} pending tools '
        '(depth=$depth): ${pendingTools.map((t) => t.name).join(', ')}',
      );
      final executingState = ExecutingToolsState(
        conversation: handleState.conversation,
        pendingTools: pendingTools,
      );
      handle.state = executingState;
      _syncUiState(handle, executingState);
      _executeToolsAndContinue(handle, depth: depth);
      return;
    }

    final completed = CompletedState(
      conversation: handleState.conversation.withStatus(
        const domain.Completed(),
      ),
      result: const Success(),
    );
    _registry.completeRun(handle, completed);
    _syncUiState(handle, completed);
  }

  /// Maximum number of tool-execution → continuation hops before aborting.
  static const _maxToolDepth = 10;

  /// Executes pending tools and starts a continuation run with results.
  ///
  /// This is the core orchestration method for client-side tool calling.
  /// After tool execution, it creates a new backend run, streams events,
  /// and replaces the old handle in the registry.
  Future<void> _executeToolsAndContinue(
    RunHandle handle, {
    required int depth,
  }) async {
    // Circuit breaker: prevent infinite tool loops.
    if (depth >= _maxToolDepth) {
      Loggers.toolExecution.error(
        'Tool execution depth limit reached ($depth)',
      );
      _abortToCompleted(
        handle,
        const FailedResult(
          errorMessage: 'Tool execution depth limit exceeded',
        ),
      );
      return;
    }

    try {
      final handleState = handle.state;
      if (handleState is! ExecutingToolsState) return;

      final pendingTools = handleState.pendingTools;
      Loggers.toolExecution.debug(
        'Executing ${pendingTools.length} tools (depth=$depth): '
        '${pendingTools.map((t) => t.name).join(', ')}',
      );

      // Execute all tools in parallel, catching per-tool failures.
      final results = await Future.wait(
        pendingTools.map((toolCall) async {
          Loggers.toolExecution.debug(
            'Executing tool "${toolCall.name}" (${toolCall.id})',
          );
          try {
            final result = await _toolRegistry.execute(toolCall);
            Loggers.toolExecution.debug(
              'Tool "${toolCall.name}" completed '
              '(${result.length} chars result)',
            );
            return toolCall.copyWith(
              status: ToolCallStatus.completed,
              result: result,
            );
          } catch (e, st) {
            Loggers.toolExecution.error(
              'Tool "${toolCall.name}" failed',
              error: e,
              stackTrace: st,
            );
            return toolCall.copyWith(
              status: ToolCallStatus.failed,
              result: e.toString(),
            );
          }
        }),
      );

      // Safety checks: bail if state changed during async execution.
      if (handle.cancelToken.isCancelled) {
        Loggers.toolExecution.debug(
          'Cancelled during tool execution, aborting continuation',
        );
        return;
      }
      if (_registry.getHandle(handle.key) != handle) {
        Loggers.toolExecution.debug(
          'Handle replaced during tool execution, aborting continuation',
        );
        return;
      }

      final completedCount =
          results.where((r) => r.status == ToolCallStatus.completed).length;
      final failedCount =
          results.where((r) => r.status == ToolCallStatus.failed).length;
      Loggers.toolExecution.debug(
        'All tools finished: $completedCount completed, $failedCount failed',
      );

      // Build ToolCallMessage with executed results.
      final toolCallMessage = ToolCallMessage.fromExecuted(
        id: 'tc_${DateTime.now().millisecondsSinceEpoch}',
        toolCalls: results,
      );

      // Update conversation: append tool call message, clear pending tools.
      final conversation = handleState.conversation
          .withAppendedMessage(toolCallMessage)
          .copyWith(toolCalls: const []);

      // Create a new backend run for the continuation.
      Loggers.toolExecution.debug('Creating continuation run (depth=$depth)');
      final api = ref.read(apiProvider);
      final runInfo = await api.createRun(
        handle.key.roomId,
        handle.key.threadId,
      );

      // Post-API safety checks.
      if (handle.cancelToken.isCancelled) return;
      if (_registry.getHandle(handle.key) != handle) return;

      // Build AG-UI messages for the continuation run.
      final aguiMessages = convertToAgui(conversation.messages);

      final continuationConversation = conversation.withStatus(
        domain.Running(runId: runInfo.id),
      );

      final endpoint =
          'rooms/${handle.key.roomId}/agui/${handle.key.threadId}/${runInfo.id}';

      final input = SimpleRunAgentInput(
        threadId: handle.key.threadId,
        runId: runInfo.id,
        messages: aguiMessages,
        state: conversation.aguiState,
      );

      // Start streaming the continuation.
      final cancelToken = CancelToken();
      final eventStream = _agUiClient.runAgent(
        endpoint,
        input,
        cancelToken: cancelToken,
      );

      final runningState = RunningState(conversation: continuationConversation);

      final newHandle = _createHandleWithSubscription(
        key: handle.key,
        runId: runInfo.id,
        cancelToken: cancelToken,
        eventStream: eventStream,
        userMessageId: handle.userMessageId,
        previousAguiState: handle.previousAguiState,
        initialState: runningState,
        depth: depth + 1,
      );

      Loggers.toolExecution.debug(
        'Continuation run ${runInfo.id} streaming started',
      );

      // Atomically swap the old handle for the new one.
      final swapped = await _registry.replaceRun(handle, newHandle);
      if (!swapped) {
        Loggers.toolExecution.debug(
          'replaceRun returned false — handle was replaced externally',
        );
        await newHandle.dispose();
        return;
      }

      // Update _currentHandle only if it still points to the old handle.
      if (identical(_currentHandle, handle)) {
        _currentHandle = newHandle;
        state = runningState;
      }

      Loggers.toolExecution.debug(
        'Continuation run ${runInfo.id} handoff complete (depth=$depth)',
      );
    } catch (e, st) {
      Loggers.toolExecution.error(
        'Tool execution loop failed',
        error: e,
        stackTrace: st,
      );
      _abortToCompleted(
        handle,
        FailedResult(errorMessage: e.toString(), stackTrace: st),
      );
    }
  }

  /// Aborts a run to completed state, clearing pending tool calls.
  ///
  /// Used when tool execution encounters an unrecoverable error or when
  /// the circuit breaker triggers.
  void _abortToCompleted(RunHandle handle, CompletionResult result) {
    final handleState = handle.state;
    final conversation = switch (handleState) {
      RunningState(:final conversation) => conversation,
      ExecutingToolsState(:final conversation) => conversation,
      _ => handle.state.conversation,
    };

    final domainStatus = switch (result) {
      FailedResult(:final errorMessage) => domain.Failed(error: errorMessage),
      CancelledResult(:final reason) => domain.Cancelled(reason: reason),
      Success() => const domain.Completed(),
    };

    final completed = CompletedState(
      conversation:
          conversation.copyWith(toolCalls: const []).withStatus(domainStatus),
      result: result,
    );
    _registry.completeRun(handle, completed);
    _syncUiState(handle, completed);
  }

  /// Creates a [RunHandle] for a continuation run and wires up streaming.
  ///
  /// Bundles the late-final handle pattern with subscription setup. The
  /// subscription is stored inside the returned handle (not leaked).
  RunHandle _createHandleWithSubscription({
    required ThreadKey key,
    required String runId,
    required CancelToken cancelToken,
    required Stream<BaseEvent> eventStream,
    required String userMessageId,
    required Map<String, dynamic> previousAguiState,
    required RunningState initialState,
    int depth = 0,
  }) {
    late final RunHandle handle;
    return handle = RunHandle(
      key: key,
      runId: runId,
      cancelToken: cancelToken,
      subscription: eventStream.listen(
        (event) => _processEventForRun(handle, event),
        onError: (Object error, StackTrace stackTrace) {
          final effectiveStack = stackTrace.toString().isNotEmpty
              ? stackTrace
              : StackTrace.current;
          _handleFailureForRun(handle, error, effectiveStack);
        },
        onDone: () => _handleDoneForRun(handle, depth: depth),
        cancelOnError: false,
      ),
      userMessageId: userMessageId,
      previousAguiState: previousAguiState,
      initialState: initialState,
    );
  }

  /// Syncs the notifier's exposed state if this handle is the one the UI
  /// is watching. Detaches the handle on terminal (completed) states.
  void _syncUiState(RunHandle handle, ActiveRunState newState) {
    if (!identical(handle, _currentHandle)) return;
    state = newState;
    if (newState is CompletedState) {
      _currentHandle = null;
    }
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
  ActiveRunState _mapResultForRun(
    RunHandle handle,
    RunningState previousState,
    EventProcessingResult result,
  ) {
    final conversation = _correlateMessagesForRun(handle, result);

    final newState = switch (conversation.status) {
      domain.Completed() => () {
          // If tools are pending, keep as RunningState so _handleDoneForRun
          // can detect them and start client-side tool execution.
          final hasPendingTools = conversation.toolCalls
              .any((tc) => tc.status == ToolCallStatus.pending);
          if (hasPendingTools) {
            Loggers.toolExecution.debug(
              'RunFinished with pending tools — keeping RunningState',
            );
            return previousState.copyWith(
              conversation: conversation.withStatus(
                domain.Running(runId: previousState.runId),
              ),
              streaming: result.streaming,
            );
          }
          return CompletedState(
            conversation: conversation,
            streaming: result.streaming,
            result: const Success(),
          );
        }(),
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

    return newState;
  }

  /// Correlates AG-UI state changes with the user message on run completion.
  ///
  /// Uses [CitationExtractor] to find new citations by comparing the
  /// previous AG-UI state (captured at run start) with the current state.
  /// Creates a [MessageState] and adds it to the conversation.
  domain.Conversation _correlateMessagesForRun(
    RunHandle handle,
    EventProcessingResult result,
  ) {
    final conversation = result.conversation;

    // Only correlate on completion (Completed, Failed, Cancelled)
    if (conversation.status is domain.Running) {
      return conversation;
    }

    // Extract new citations using the schema firewall
    final extractor = CitationExtractor();
    final sourceReferences = extractor.extractNew(
      handle.previousAguiState,
      conversation.aguiState,
    );

    // Create MessageState and add to conversation
    final messageState = MessageState(
      userMessageId: handle.userMessageId,
      sourceReferences: sourceReferences,
      runId: handle.runId,
    );

    return conversation.withMessageState(handle.userMessageId, messageState);
  }

  /// Builds the cache-update callback injected into [RunRegistry].
  OnRunCompleted _buildCacheUpdater() {
    return (ThreadKey key, CompletedState completedState) {
      if (key.threadId.isEmpty) return;

      // Merge existing messageStates from cache with new ones from this run
      final cachedHistory = ref.read(threadHistoryCacheProvider)[key];
      final existingMessageStates = cachedHistory?.messageStates ?? const {};
      final newMessageStates = completedState.conversation.messageStates;

      final history = ThreadHistory(
        messages: completedState.messages,
        aguiState: completedState.conversation.aguiState,
        messageStates: {...existingMessageStates, ...newMessageStates},
      );
      ref.read(threadHistoryCacheProvider.notifier).updateHistory(key, history);
    };
  }
}
