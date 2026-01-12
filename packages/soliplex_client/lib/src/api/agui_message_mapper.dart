import 'dart:convert';

import 'package:ag_ui/ag_ui.dart';

import 'package:soliplex_client/src/domain/chat_message.dart';

/// Converts a list of [ChatMessage]s to AG-UI protocol [Message]s.
///
/// This mapper handles the conversion of internal chat message types to the
/// AG-UI protocol format required by the backend. The conversion rules are:
///
/// - [TextMessage] with [ChatUser.user] → [UserMessage]
/// - [TextMessage] with [ChatUser.assistant] → [AssistantMessage]
/// - [TextMessage] with [ChatUser.system] → [SystemMessage]
/// - [ToolCallMessage] → [AssistantMessage] with toolCalls, followed by
///   [ToolMessage]s for completed tool calls
/// - [GenUiMessage] → [AssistantMessage] with descriptive content
/// - [ErrorMessage] and [LoadingMessage] are skipped (transient messages)
List<Message> convertToAgui(List<ChatMessage> chatMessages) {
  final result = <Message>[];

  for (final message in chatMessages) {
    switch (message) {
      case TextMessage():
        result.add(_convertTextMessage(message));

      case ToolCallMessage():
        result.addAll(_convertToolCallMessage(message));

      case GenUiMessage():
        result.add(_convertGenUiMessage(message));

      case ErrorMessage():
      case LoadingMessage():
        // Skip transient messages
        continue;
    }
  }

  return result;
}

Message _convertTextMessage(TextMessage message) {
  switch (message.user) {
    case ChatUser.user:
      return UserMessage(id: message.id, content: message.text);
    case ChatUser.assistant:
      return AssistantMessage(id: message.id, content: message.text);
    case ChatUser.system:
      return SystemMessage(id: message.id, content: message.text);
  }
}

List<Message> _convertToolCallMessage(ToolCallMessage message) {
  final result = <Message>[];

  // Convert to AssistantMessage with toolCalls
  final toolCalls = message.toolCalls
      .map(
        (tc) => ToolCall(
          id: tc.id,
          function: FunctionCall(name: tc.name, arguments: tc.arguments),
        ),
      )
      .toList();

  result.add(AssistantMessage(id: message.id, toolCalls: toolCalls));

  // Add ToolMessage for each completed tool call
  for (final tc in message.toolCalls) {
    if (tc.status == ToolCallStatus.completed) {
      result.add(ToolMessage(toolCallId: tc.id, content: tc.result));
    }
  }

  return result;
}

Message _convertGenUiMessage(GenUiMessage message) {
  final dataJson = jsonEncode(message.data);
  final content =
      'Displayed ${message.widgetName} component with data: $dataJson';

  return AssistantMessage(id: message.id, content: content);
}
