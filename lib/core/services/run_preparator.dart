import 'package:soliplex_client/soliplex_client.dart';
import 'package:soliplex_client/soliplex_client.dart' as domain
    show Conversation, Running;
import 'package:soliplex_frontend/core/models/active_run_state.dart';

/// Input data for [prepareRun].
class RunPreparationInput {
  const RunPreparationInput({
    required this.threadId,
    required this.runId,
    required this.userMessage,
    this.cachedHistory,
    this.initialState,
    this.tools,
  });

  final String threadId;
  final String runId;
  final String userMessage;
  final ThreadHistory? cachedHistory;
  final Map<String, dynamic>? initialState;
  final List<Tool>? tools;
}

/// Result of [prepareRun] containing everything needed to start streaming.
class PreparedRun {
  const PreparedRun({
    required this.runningState,
    required this.agentInput,
    required this.userMessageId,
    required this.previousAguiState,
  });

  final RunningState runningState;
  final SimpleRunAgentInput agentInput;
  final String userMessageId;
  final Map<String, dynamic> previousAguiState;
}

/// Builds the [RunningState] and [SimpleRunAgentInput] from raw inputs.
///
/// Pure function: no I/O, no provider reads, no side effects.
PreparedRun prepareRun(RunPreparationInput input) {
  // Create user message.
  // Note: Message ID uses milliseconds. Collision is mitigated by
  // _isStarting guard preventing concurrent startRun calls.
  final userMessageObj = TextMessage.create(
    id: 'user_${DateTime.now().millisecondsSinceEpoch}',
    user: ChatUser.user,
    text: input.userMessage,
  );

  // Read historical thread data from cache.
  final cachedMessages = input.cachedHistory?.messages ?? [];
  final cachedAguiState = input.cachedHistory?.aguiState ?? const {};

  // Combine historical messages with new user message
  final allMessages = [...cachedMessages, userMessageObj];

  // Create conversation with full history, AG-UI state, and Running status
  final conversation = domain.Conversation(
    threadId: input.threadId,
    messages: allMessages,
    status: domain.Running(runId: input.runId),
    aguiState: cachedAguiState,
  );

  final runningState = RunningState(conversation: conversation);

  // Convert all messages to AG-UI format for backend
  final aguiMessages = convertToAgui(allMessages);

  // Merge accumulated AG-UI state with any client-provided initial state.
  // Deep merge at the state-key level so client-provided keys (e.g.
  // document_filter) merge INTO the server's haiku.rag.chat dict
  // rather than replacing it.
  final mergedState = <String, dynamic>{...cachedAguiState};
  if (input.initialState != null) {
    for (final entry in input.initialState!.entries) {
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
  final agentInput = SimpleRunAgentInput(
    threadId: input.threadId,
    runId: input.runId,
    messages: aguiMessages,
    state: mergedState,
    tools: input.tools,
  );

  return PreparedRun(
    runningState: runningState,
    agentInput: agentInput,
    userMessageId: userMessageObj.id,
    previousAguiState: cachedAguiState,
  );
}
