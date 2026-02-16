import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soliplex_client/soliplex_client.dart';
import 'package:soliplex_client/soliplex_client.dart' as domain
    show Cancelled, Completed, Conversation, Failed, Idle, Running;
import 'package:soliplex_frontend/core/logging/loggers.dart';
import 'package:soliplex_frontend/core/models/active_run_state.dart';
import 'package:soliplex_frontend/core/models/run_handle.dart';
import 'package:soliplex_frontend/core/providers/api_provider.dart';
import 'package:soliplex_frontend/core/providers/rooms_provider.dart';
import 'package:soliplex_frontend/core/providers/thread_history_cache.dart';
import 'package:soliplex_frontend/core/providers/threads_provider.dart';
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
///   roomId: 'room-123',
///   threadId: 'thread-456',
///   userMessage: 'Hello!',
/// );
/// ```
class ActiveRunNotifier extends Notifier<ActiveRunState> {
  late AgUiClient _agUiClient;
  bool _isStarting = false;

  /// Registry tracking active runs across rooms and threads.
  final RunRegistry _registry = RunRegistry();

  /// Current run handle — the run whose state the notifier exposes to UI.
  RunHandle? _currentHandle;

  /// The run registry for this notifier.
  ///
  /// Exposed for testing and external access to run tracking state.
  RunRegistry get registry => _registry;

  @override
  ActiveRunState build() {
    _agUiClient = ref.watch(agUiClientProvider);

    // Sync exposed state when the user navigates between rooms/threads.
    ref
      ..listen(currentRoomIdProvider, (_, __) => _syncCurrentHandle())
      ..listen(currentThreadIdProvider, (_, __) => _syncCurrentHandle())
      ..onDispose(() {
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
  /// notifier's [state] tracks the most recently started run.
  Future<void> startRun({
    required String roomId,
    required String threadId,
    required String userMessage,
    String? existingRunId,
    Map<String, dynamic>? initialState,
  }) async {
    if (_isStarting) {
      throw StateError(
        'Cannot start run: startRun already in progress.',
      );
    }

    _isStarting = true;
    Loggers.activeRun.debug(
      'startRun called: room=$roomId, thread=$threadId',
    );
    StreamSubscription<BaseEvent>? subscription;
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

      final runningState = RunningState(conversation: conversation);
      pendingState = runningState;

      // Step 2: Build the streaming endpoint URL with backend run_id
      final endpoint = 'rooms/$roomId/agui/$threadId/$runId';

      // Convert all messages to AG-UI format for backend
      final aguiMessages = convertToAgui(allMessages);

      // Merge accumulated AG-UI state with any client-provided initial state.
      // Order: cached state first (backend-generated), then initial state
      // (client-generated like filter_documents) so client can override.
      final mergedState = <String, dynamic>{
        ...cachedAguiState,
        ...?initialState,
      };

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

      // Create the handle. The subscription captures this handle via closure.
      // Safe because events are delivered asynchronously (next microtask),
      // and the handle is assigned synchronously after listen().
      late final RunHandle handle;

      // Process events — each run's callbacks are scoped to its own handle
      // ignore: cancel_subscriptions - stored in RunHandle and cancelled
      subscription = eventStream.listen(
        (event) => _processEventForRun(handle, event),
        onError: (Object error, StackTrace stackTrace) {
          final effectiveStack = stackTrace.toString().isNotEmpty
              ? stackTrace
              : StackTrace.current;
          _handleFailureForRun(handle, error, effectiveStack);
        },
        onDone: () => _handleDoneForRun(handle),
        cancelOnError: false,
      );

      handle = RunHandle(
        key: (roomId: roomId, threadId: threadId),
        runId: runId,
        cancelToken: cancelToken,
        subscription: subscription,
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
      await subscription?.cancel();
      final conv = pendingState?.conversation ?? state.conversation;
      final completed = CompletedState(
        conversation: conv.withStatus(
          domain.Cancelled(reason: e.message),
        ),
        result: CancelledResult(reason: e.message),
      );
      state = completed;
      _updateCacheOnCompletion(completed);
      _currentHandle = null;
    } catch (e, stackTrace) {
      // Clean up subscription on any error
      Loggers.activeRun.error(
        'Run failed with exception',
        error: e,
        stackTrace: stackTrace,
      );
      await subscription?.cancel();
      final conv = pendingState?.conversation ?? state.conversation;
      final errorMsg = e.toString();
      final completed = CompletedState(
        conversation: conv.withStatus(
          domain.Failed(error: errorMsg),
        ),
        result: FailedResult(errorMessage: errorMsg, stackTrace: stackTrace),
      );
      state = completed;
      _updateCacheOnCompletion(completed);
      _currentHandle = null;
    } finally {
      _isStarting = false;
    }
  }

  /// Cancels the current run.
  ///
  /// Preserves all completed messages but clears streaming state.
  /// Background runs in other threads are unaffected.
  Future<void> cancelRun() async {
    Loggers.activeRun.debug('cancelRun called');
    final handle = _currentHandle;
    if (handle == null) return;

    _currentHandle = null;
    await handle.dispose();

    final handleState = handle.state;
    if (handleState is RunningState) {
      final completed = CompletedState(
        conversation: handleState.conversation.withStatus(
          const domain.Cancelled(reason: 'User cancelled'),
        ),
        result: const CancelledResult(reason: 'Cancelled by user'),
      );
      _registry.completeRun(handle, completed);
      _updateCacheOnCompletion(completed);
      state = completed;
    }
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
      _updateCacheOnCompletion(completed);
      _syncUiState(handle, completed);
    }
  }

  /// Handles stream completion for a specific run.
  void _handleDoneForRun(RunHandle handle) {
    final handleState = handle.state;
    if (handleState is RunningState) {
      final completed = CompletedState(
        conversation: handleState.conversation.withStatus(
          const domain.Completed(),
        ),
        result: const Success(),
      );
      _registry.completeRun(handle, completed);
      _updateCacheOnCompletion(completed);
      _syncUiState(handle, completed);
    }
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
    );

    return conversation.withMessageState(handle.userMessageId, messageState);
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
