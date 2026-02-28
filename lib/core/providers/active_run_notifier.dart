import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soliplex_client/soliplex_client.dart';
import 'package:soliplex_client/soliplex_client.dart' as domain
    show Cancelled, Completed, Failed, Running;
import 'package:soliplex_frontend/core/logging/loggers.dart';
import 'package:soliplex_frontend/core/models/active_run_state.dart';
import 'package:soliplex_frontend/core/models/run_handle.dart';
import 'package:soliplex_frontend/core/models/run_lifecycle_event.dart';
import 'package:soliplex_frontend/core/models/thread_key.dart';
import 'package:soliplex_frontend/core/providers/api_provider.dart';
import 'package:soliplex_frontend/core/providers/deferred_message_queue_provider.dart';
import 'package:soliplex_frontend/core/providers/rooms_provider.dart';
import 'package:soliplex_frontend/core/providers/thread_history_cache.dart';
import 'package:soliplex_frontend/core/providers/threads_provider.dart';
import 'package:soliplex_frontend/core/providers/unread_runs_provider.dart';
import 'package:soliplex_frontend/core/router/app_router.dart';
import 'package:soliplex_frontend/core/services/agui_event_logger.dart';
import 'package:soliplex_frontend/core/services/run_completion_handler.dart';
import 'package:soliplex_frontend/core/services/run_preparator.dart';
import 'package:soliplex_frontend/core/services/run_registry.dart';
import 'package:soliplex_frontend/core/services/tool_execution_zone.dart';

/// Combined room + thread key for navigation sync.
///
/// Fires once per navigation instead of once per provider, avoiding
/// double `_syncCurrentHandle` calls.
final _currentThreadKeyProvider = Provider<(String?, String?)>((ref) {
  final roomId = ref.watch(currentRoomIdProvider);
  final threadId = ref.watch(currentThreadIdProvider);
  return (roomId, threadId);
});

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
  bool _processingDeferred = false;

  final RunCompletionHandler _completionHandler = RunCompletionHandler();

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
    _agUiClient = ref.read(agUiClientProvider);
    ref.listen(agUiClientProvider, (_, next) => _agUiClient = next);
    _toolRegistry = ref.read(toolRegistryProvider);
    ref.listen(toolRegistryProvider, (_, next) => _toolRegistry = next);

    // Mark thread as unread when a non-cancelled background run completes,
    // then process any deferred messages queued during the run.
    _lifecycleSub = _registry.lifecycleEvents.listen((event) {
      if (event is RunCompleted) {
        final isBackground = _currentHandle?.key != event.key;
        if (isBackground && event.result is! CancelledResult) {
          ref.read(unreadRunsProvider.notifier).markUnread(event.key);
        }
        if (event.result is! CancelledResult) {
          _processDeferredQueue();
        }
      }
    });

    // Sync exposed state when the user navigates between rooms/threads.
    // A single combined listener fires once per navigation instead of
    // twice (once per provider change).
    ref
      ..listen(_currentThreadKeyProvider, (_, __) => _syncCurrentHandle())
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

      // Prepare run: user message, history merge, AG-UI input.
      final cachedHistory = ref.read(threadHistoryCacheProvider)[key];
      final tools =
          _toolRegistry.isEmpty ? null : _toolRegistry.toolDefinitions;

      final prepared = prepareRun(
        RunPreparationInput(
          threadId: threadId,
          runId: runId,
          userMessage: userMessage,
          cachedHistory: cachedHistory,
          initialState: initialState,
          tools: tools,
        ),
      );

      final runningState = prepared.runningState;
      pendingState = runningState;

      Loggers.activeRun.debug(
        'RUN_INPUT: room=$roomId '
        'toolCount=${tools?.length ?? 0} '
        'toolNames=${tools?.map((t) => t.name).join(', ') ?? 'none'}',
      );

      // Step 2: Build the streaming endpoint URL with backend run_id
      final endpoint = 'rooms/$roomId/agui/$threadId/$runId';

      // Start streaming
      final eventStream = _agUiClient.runAgent(
        endpoint,
        prepared.agentInput,
        cancelToken: cancelToken,
      );

      // Create the handle with subscription wired up.
      final handle = _createHandleWithSubscription(
        key: key,
        runId: runId,
        cancelToken: cancelToken,
        eventStream: eventStream,
        userMessageId: prepared.userMessageId,
        previousAguiState: prepared.previousAguiState,
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

  /// Processes the next deferred message from the queue.
  ///
  /// Called after a non-cancelled [RunCompleted] event. Switches the UI to
  /// the target thread and starts a new run with the queued message.
  ///
  /// Re-entry is guarded by [_processingDeferred]. When the deferred run
  /// itself completes, the lifecycle listener fires again and picks up
  /// the next message naturally — no recursion needed.
  Future<void> _processDeferredQueue() async {
    if (_processingDeferred) return;
    _processingDeferred = true;
    try {
      final queue = ref.read(deferredMessageQueueProvider.notifier);
      final message = queue.pop();
      if (message == null) return;

      // Switch UI to target thread
      ref
          .read(threadSelectionProvider.notifier)
          .set(ThreadSelected(message.targetKey.threadId));
      ref.read(routerProvider).go(
            '/rooms/${message.targetKey.roomId}'
            '?thread=${message.targetKey.threadId}',
          );

      // Start run in target thread
      await startRun(
        key: message.targetKey,
        userMessage: message.message,
      );
    } catch (e, st) {
      Loggers.activeRun.error(
        'Failed to process deferred message',
        error: e,
        stackTrace: st,
      );
    } finally {
      _processingDeferred = false;
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
      if (handleState is! RunningState) {
        Loggers.activeRun.debug(
          'EVENT_SKIP: ${event.runtimeType} — '
          'handle state is ${handleState.runtimeType}, not RunningState',
        );
        return;
      }

      logAguiEvent(event);

      final result = processEvent(
        handleState.conversation,
        handleState.streaming,
        event,
      );

      Loggers.activeRun.debug(
        'EVENT_RESULT: ${event.runtimeType} → '
        'status=${result.conversation.status} '
        'toolCalls=${result.conversation.toolCalls.length} '
        'pendingTools=${result.conversation.toolCalls.where(
              (tc) => tc.status == ToolCallStatus.pending,
            ).length} '
        'msgs=${result.conversation.messages.length} '
        'streaming=${result.streaming.runtimeType}',
      );

      final newState = _mapResultForRun(handle, handleState, result);

      Loggers.activeRun.debug(
        'STATE_TRANSITION: ${handleState.runtimeType} → '
        '${newState.runtimeType}',
      );

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
    if (handleState is RunningState || handleState is ExecutingToolsState) {
      final errorMsg = error.toString();
      _abortToCompleted(
        handle,
        FailedResult(errorMessage: errorMsg, stackTrace: stackTrace),
      );
    }
  }

  /// Handles stream completion for a specific run.
  ///
  /// If the conversation has pending tool calls, transitions to
  /// [ExecutingToolsState] and starts client-side tool execution.
  /// Otherwise, completes normally.
  void _handleDoneForRun(RunHandle handle, {int depth = 0}) {
    final handleState = handle.state;
    Loggers.activeRun.debug(
      'HANDLE_DONE: state=${handleState.runtimeType} '
      'depth=$depth '
      'toolCalls=${handleState.conversation.toolCalls.length} '
      'allToolStatuses=${handleState.conversation.toolCalls.map(
            (tc) => '${tc.name}:${tc.status}',
          ).join(', ')} '
      'registryEmpty=${_toolRegistry.isEmpty}',
    );
    if (handleState is! RunningState) return;

    // Snapshot the tool registry so we only attempt client-executable tools.
    // Server-side tools (not in registry) are already handled by the backend.
    final toolRegistry = _toolRegistry;

    final allPendingTools = handleState.conversation.toolCalls
        .where((tc) => tc.status == ToolCallStatus.pending)
        .toList();

    // Only execute tools registered in the client-side ToolRegistry.
    // Server-side tools appear in the AG-UI stream as informational events
    // but are already executed by the backend.
    final clientTools =
        allPendingTools.where((tc) => toolRegistry.contains(tc.name)).toList();
    final serverTools =
        allPendingTools.where((tc) => !toolRegistry.contains(tc.name)).toList();

    if (serverTools.isNotEmpty) {
      Loggers.toolExecution.debug(
        'Skipping ${serverTools.length} server-side tools: '
        '${serverTools.map((t) => t.name).join(', ')}',
      );
    }

    if (clientTools.isNotEmpty) {
      Loggers.toolExecution.debug(
        'Stream done with ${clientTools.length} client-executable tools '
        '(depth=$depth): ${clientTools.map((t) => t.name).join(', ')}',
      );
      final executingState = ExecutingToolsState(
        conversation: handleState.conversation,
        pendingTools: clientTools,
      );
      handle.state = executingState;
      _syncUiState(handle, executingState);
      _executeToolsAndContinue(handle, depth: depth);
      return;
    }

    Loggers.activeRun.debug(
      'HANDLE_DONE: no pending tools, completing run normally',
    );
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
    // Snapshot the tool registry at entry so room switches mid-execution
    // don't change the tools used for this continuation chain.
    final toolRegistry = _toolRegistry;

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
      // Zone propagates handle.key so execute_python can look up the
      // per-thread bridge via activeThreadKey.
      final results = await runInToolExecutionZone(
        handle.key,
        () => Future.wait(
          pendingTools.map((toolCall) async {
            Loggers.toolExecution.debug(
              'Executing tool "${toolCall.name}" (${toolCall.id})',
            );
            try {
              final result = await toolRegistry.execute(toolCall);
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
        ),
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

      final tools =
          _toolRegistry.isEmpty ? null : _toolRegistry.toolDefinitions;
      final input = SimpleRunAgentInput(
        threadId: handle.key.threadId,
        runId: runInfo.id,
        messages: aguiMessages,
        state: conversation.aguiState,
        tools: tools,
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
    if (!identical(handle, _currentHandle)) {
      Loggers.activeRun.debug(
        'SYNC_UI_SKIP: handle is not current '
        '(background run or replaced)',
      );
      return;
    }
    Loggers.activeRun.debug(
      'SYNC_UI: ${newState.runtimeType} '
      'toolCalls=${newState.conversation.toolCalls.length} '
      'msgs=${newState.messages.length}',
    );
    state = newState;
    if (newState is CompletedState) {
      _currentHandle = null;
    }
  }

  /// Maps an [EventProcessingResult] to the appropriate [ActiveRunState].
  ///
  /// Delegates domain logic to [RunCompletionHandler.mapEventResult], then
  /// applies the notifier-level policy: only client-registered tools
  /// (per [_toolRegistry]) count as "pending". Server-side tools are
  /// already executed by the backend.
  ActiveRunState _mapResultForRun(
    RunHandle handle,
    RunningState previousState,
    EventProcessingResult result,
  ) {
    final mapped = _completionHandler.mapEventResult(
      handle: handle,
      previousState: previousState,
      result: result,
    );

    // The service converts Completed → RunningState when it finds pending
    // tools (domain truth). The notifier applies the policy filter: only
    // client-registered tools count. If none are client-executable, complete.
    if (mapped is RunningState && result.conversation.status is Completed) {
      final pendingToolCalls = mapped.conversation.toolCalls
          .where((tc) => tc.status == ToolCallStatus.pending);
      final hasClientPendingTools =
          pendingToolCalls.any((tc) => _toolRegistry.contains(tc.name));
      Loggers.activeRun.debug(
        'MAP_COMPLETED: '
        'pendingTools=${pendingToolCalls.length} '
        'hasClientPendingTools=$hasClientPendingTools '
        'statuses=${mapped.conversation.toolCalls.map(
              (tc) => '${tc.name}:${tc.status}',
            ).join(', ')}',
      );
      if (!hasClientPendingTools) {
        return CompletedState(
          conversation:
              mapped.conversation.withStatus(const domain.Completed()),
          streaming: result.streaming,
          result: const Success(),
        );
      }
    }

    return mapped;
  }

  /// Builds the cache-update callback injected into [RunRegistry].
  OnRunCompleted _buildCacheUpdater() {
    return (ThreadKey key, CompletedState completedState) {
      if (key.threadId.isEmpty) return;

      final cachedHistory = ref.read(threadHistoryCacheProvider)[key];
      final history = _completionHandler.buildUpdatedHistory(
        completedState: completedState,
        existingHistory: cachedHistory,
      );
      ref.read(threadHistoryCacheProvider.notifier).updateHistory(key, history);
    };
  }
}
