import 'package:soliplex_client/soliplex_client.dart';

/// Chat state for the TUI.
///
/// Prefixed with `Tui` to avoid collision with soliplex_client's
/// [StreamingState] hierarchy.
sealed class TuiChatState {
  const TuiChatState({required this.messages});

  final List<ChatMessage> messages;
}

/// Awaiting user input — no active run.
final class TuiIdleState extends TuiChatState {
  const TuiIdleState({super.messages = const []});
}

/// AG-UI events arriving — holds live streaming state.
final class TuiStreamingState extends TuiChatState {
  const TuiStreamingState({
    required super.messages,
    required this.conversation,
    required this.streaming,
    this.reasoningText,
  });

  final Conversation conversation;
  final StreamingState streaming;
  final String? reasoningText;
}

/// Client-side tool execution in progress.
final class TuiExecutingToolsState extends TuiChatState {
  const TuiExecutingToolsState({
    required super.messages,
    required this.conversation,
    required this.pendingTools,
  });

  final Conversation conversation;
  final List<ToolCallInfo> pendingTools;
}

/// Error display state.
final class TuiErrorState extends TuiChatState {
  const TuiErrorState({
    required super.messages,
    required this.errorMessage,
  });

  final String errorMessage;
}
