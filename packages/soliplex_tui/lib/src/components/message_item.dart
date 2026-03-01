import 'package:nocterm/nocterm.dart';
import 'package:soliplex_client/soliplex_client.dart';

/// Renders a single chat message based on its subtype.
class MessageItem extends StatelessComponent {
  const MessageItem({required this.message, super.key});

  final ChatMessage message;

  @override
  Component build(BuildContext context) {
    final theme = TuiTheme.of(context);

    return switch (message) {
      TextMessage(:final user, :final text) => _buildTextMessage(
          theme,
          user,
          text,
        ),
      ToolCallMessage(:final toolCalls) => _buildToolCallMessage(
          theme,
          toolCalls,
        ),
      ErrorMessage(:final errorText) => _buildErrorMessage(theme, errorText),
      GenUiMessage(:final widgetName) => Text(
          '[$widgetName]',
          style: TextStyle(color: theme.onSurface),
        ),
      LoadingMessage() => Text(
          '...',
          style: TextStyle(color: theme.onSurface),
        ),
    };
  }

  Component _buildTextMessage(
    TuiThemeData theme,
    ChatUser user,
    String text,
  ) {
    final (label, labelColor) = switch (user) {
      ChatUser.user => ('You', theme.primary),
      ChatUser.assistant => ('Assistant', theme.secondary),
      ChatUser.system => ('System', theme.error),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: labelColor)),
        MarkdownText(text),
      ],
    );
  }

  Component _buildToolCallMessage(
    TuiThemeData theme,
    List<ToolCallInfo> toolCalls,
  ) {
    final names = toolCalls.map((tc) => tc.name).join(', ');
    final statusIcon = toolCalls.every(
      (tc) => tc.status == ToolCallStatus.completed,
    )
        ? '+'
        : '!';

    return Text(
      '[$statusIcon] Tools: $names',
      style: TextStyle(color: theme.outline),
    );
  }

  Component _buildErrorMessage(TuiThemeData theme, String errorText) {
    return Text(
      'Error: $errorText',
      style: TextStyle(color: theme.error),
    );
  }
}

/// Renders the in-flight streaming text (not yet finalized in messages).
class StreamingMessageItem extends StatelessComponent {
  const StreamingMessageItem({required this.streaming, super.key});

  final StreamingState streaming;

  @override
  Component build(BuildContext context) {
    final theme = TuiTheme.of(context);

    return switch (streaming) {
      TextStreaming(:final text) when text.isNotEmpty => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Assistant', style: TextStyle(color: theme.secondary)),
            MarkdownText('$text▌'),
          ],
        ),
      AwaitingText(hasThinkingContent: true) => Text(
          'Thinking...',
          style: TextStyle(color: theme.onSurface.withOpacity(0.6)),
        ),
      _ => const SizedBox(),
    };
  }
}
