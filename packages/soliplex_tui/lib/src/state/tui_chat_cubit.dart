import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:soliplex_agent/soliplex_agent.dart';
import 'package:soliplex_client/soliplex_client.dart';

import 'package:soliplex_tui/src/loggers.dart';
import 'package:soliplex_tui/src/state/tui_chat_state.dart';

/// Cubit that maps [RunOrchestrator.stateChanges] to [TuiChatState].
///
/// Delegates all run lifecycle (SSE streaming, tool yielding, circuit breaker)
/// to [RunOrchestrator] and only handles UI-specific concerns:
/// reasoning text extraction, toggle state, and tool execution dispatch.
class TuiChatCubit extends Cubit<TuiChatState> {
  TuiChatCubit({
    required RunOrchestrator orchestrator,
    required ToolRegistry toolRegistry,
    required ThreadKey threadKey,
  })  : _orchestrator = orchestrator,
        _toolRegistry = toolRegistry,
        _threadKey = threadKey,
        super(const TuiIdleState()) {
    _subscription = _orchestrator.stateChanges.listen(_onRunState);
  }

  final RunOrchestrator _orchestrator;
  final ToolRegistry _toolRegistry;
  final ThreadKey _threadKey;

  bool _showReasoning = true;
  List<ChatMessage> _lastMessages = const [];
  StreamSubscription<RunState>? _subscription;

  /// Send a user message and start a new run.
  Future<void> sendMessage(String text) async {
    if (_orchestrator.currentState is RunningState ||
        _orchestrator.currentState is ToolYieldingState) {
      return;
    }
    Loggers.app.info('Sending message (${text.length} chars)');
    await _orchestrator.startRun(key: _threadKey, userMessage: text);
  }

  /// Cancel the active run.
  void cancelRun() {
    Loggers.app.info('Run cancelled by user');
    _orchestrator.cancelRun();
  }

  /// Toggle reasoning pane visibility.
  void toggleReasoning() {
    _showReasoning = !_showReasoning;
    final current = state;
    if (current is TuiStreamingState) {
      emit(current.copyWith(showReasoning: _showReasoning));
    }
  }

  void _onRunState(RunState runState) {
    switch (runState) {
      case IdleState():
        emit(TuiIdleState(messages: _lastMessages));

      case RunningState(:final conversation, :final streaming):
        _lastMessages = conversation.messages;
        final reasoningText = switch (streaming) {
          AwaitingText(:final bufferedThinkingText) => bufferedThinkingText,
          TextStreaming(:final thinkingText) => thinkingText,
        };
        emit(
          TuiStreamingState(
            messages: conversation.messages,
            conversation: conversation,
            streaming: streaming,
            reasoningText: reasoningText.isNotEmpty ? reasoningText : null,
            showReasoning: _showReasoning,
          ),
        );

      case CompletedState(:final conversation):
        _lastMessages = conversation.messages;
        emit(TuiIdleState(messages: conversation.messages));

      case ToolYieldingState(:final pendingToolCalls, :final conversation):
        _lastMessages = conversation.messages;
        emit(
          TuiExecutingToolsState(
            messages: conversation.messages,
            conversation: conversation,
            pendingTools: pendingToolCalls,
          ),
        );
        unawaited(_executeToolsAndSubmit(pendingToolCalls));

      case FailedState(:final error, :final conversation):
        _lastMessages = conversation?.messages ?? _lastMessages;
        emit(
          TuiErrorState(
            messages: _lastMessages,
            errorMessage: error,
          ),
        );

      case CancelledState(:final conversation):
        _lastMessages = conversation?.messages ?? _lastMessages;
        emit(TuiIdleState(messages: _lastMessages));
    }
  }

  Future<void> _executeToolsAndSubmit(
    List<ToolCallInfo> pendingTools,
  ) async {
    final executedTools = <ToolCallInfo>[];

    for (final tc in pendingTools) {
      Loggers.tool.info('Executing tool: ${tc.name}');
      try {
        final result = await _toolRegistry.execute(tc);
        Loggers.tool.debug('Tool ${tc.name} completed');
        executedTools.add(
          tc.copyWith(status: ToolCallStatus.completed, result: result),
        );
      } on Exception catch (e) {
        Loggers.tool.error('Tool ${tc.name} failed', error: e);
        executedTools.add(
          tc.copyWith(status: ToolCallStatus.failed, result: 'Error: $e'),
        );
      }
    }

    await _orchestrator.submitToolOutputs(executedTools);
  }

  @override
  Future<void> close() async {
    Loggers.app.debug('Cubit closing');
    await _subscription?.cancel();
    _orchestrator.dispose();
    return super.close();
  }
}
