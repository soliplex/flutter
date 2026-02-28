import 'package:soliplex_client/soliplex_client.dart';
import 'package:soliplex_client/soliplex_client.dart' as domain
    show Cancelled, Completed, Failed, Idle, Running;
import 'package:soliplex_frontend/core/logging/loggers.dart';
import 'package:soliplex_frontend/core/models/active_run_state.dart';
import 'package:soliplex_frontend/core/models/run_handle.dart';

/// Handles run completion: citation correlation, history building, and
/// event result mapping.
class RunCompletionHandler {
  /// Correlates AG-UI state changes with the user message on run completion.
  ///
  /// Uses [CitationExtractor] to find new citations by comparing the
  /// previous AG-UI state (captured at run start) with the current state.
  /// Creates a [MessageState] and adds it to the conversation.
  Conversation correlateMessages({
    required RunHandle handle,
    required EventProcessingResult result,
  }) {
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

  /// Builds an updated [ThreadHistory] by merging existing message states
  /// with the completed run's state.
  ThreadHistory buildUpdatedHistory({
    required CompletedState completedState,
    required ThreadHistory? existingHistory,
  }) {
    final existingMessageStates = existingHistory?.messageStates ?? const {};
    final newMessageStates = completedState.conversation.messageStates;

    return ThreadHistory(
      messages: completedState.messages,
      aguiState: completedState.conversation.aguiState,
      messageStates: {...existingMessageStates, ...newMessageStates},
    );
  }

  /// Maps an [EventProcessingResult] to the appropriate [ActiveRunState].
  ///
  /// Calls [correlateMessages] for citation extraction, then switches
  /// on conversation status to produce the correct state variant.
  ActiveRunState mapEventResult({
    required RunHandle handle,
    required RunningState previousState,
    required EventProcessingResult result,
  }) {
    final conversation = correlateMessages(handle: handle, result: result);

    return switch (conversation.status) {
      domain.Completed() => () {
          // Report pending tools to the caller. The notifier decides which
          // pending tools are client-executable based on ToolRegistry
          // membership. Server-side tools arrive as completed via
          // ToolCallResultEvent and won't appear here.
          final hasPendingTools = conversation.toolCalls
              .any((tc) => tc.status == ToolCallStatus.pending);
          if (hasPendingTools) {
            Loggers.toolExecution.debug(
              'RunFinished with pending tools \u2014 keeping RunningState',
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
  }
}
