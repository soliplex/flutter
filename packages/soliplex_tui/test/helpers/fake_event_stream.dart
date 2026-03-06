import 'package:soliplex_agent/soliplex_agent.dart';

/// Builds a mock AG-UI event stream from a list of events.
///
/// Mirrors the pattern from soliplex-flutter-charting test helpers.
Stream<BaseEvent> buildMockEventStream(
  List<BaseEvent> events, {
  Duration? interEventDelay,
}) {
  if (interEventDelay == null) {
    return Stream.fromIterable(events);
  }
  return Stream.fromIterable(events).asyncMap((event) async {
    await Future<void>.delayed(interEventDelay);
    return event;
  });
}

/// Builds a standard text response event sequence.
List<BaseEvent> textResponseEvents({
  String threadId = 'thread_1',
  String runId = 'run_1',
  String messageId = 'msg_1',
  String text = 'Hello from assistant!',
}) {
  return [
    RunStartedEvent(threadId: threadId, runId: runId),
    TextMessageStartEvent(messageId: messageId),
    TextMessageContentEvent(messageId: messageId, delta: text),
    TextMessageEndEvent(messageId: messageId),
    RunFinishedEvent(threadId: threadId, runId: runId),
  ];
}

/// Builds a text response with thinking events.
List<BaseEvent> thinkingThenTextEvents({
  String threadId = 'thread_1',
  String runId = 'run_1',
  String messageId = 'msg_1',
  String thinkingText = 'Let me think...',
  String text = 'Here is my answer.',
}) {
  return [
    RunStartedEvent(threadId: threadId, runId: runId),
    const ThinkingTextMessageStartEvent(),
    ThinkingTextMessageContentEvent(delta: thinkingText),
    const ThinkingTextMessageEndEvent(),
    TextMessageStartEvent(messageId: messageId),
    TextMessageContentEvent(messageId: messageId, delta: text),
    TextMessageEndEvent(messageId: messageId),
    RunFinishedEvent(threadId: threadId, runId: runId),
  ];
}

/// Builds a tool call event sequence (no text response — expects continuation).
List<BaseEvent> toolCallEvents({
  String threadId = 'thread_1',
  String runId = 'run_1',
  String toolCallId = 'tc_1',
  String toolName = 'get_time',
  String arguments = '{}',
}) {
  return [
    RunStartedEvent(threadId: threadId, runId: runId),
    ToolCallStartEvent(toolCallId: toolCallId, toolCallName: toolName),
    ToolCallArgsEvent(toolCallId: toolCallId, delta: arguments),
    ToolCallEndEvent(toolCallId: toolCallId),
    RunFinishedEvent(threadId: threadId, runId: runId),
  ];
}

/// Builds an error event sequence.
List<BaseEvent> errorEvents({
  String threadId = 'thread_1',
  String runId = 'run_1',
  String errorMessage = 'Something went wrong',
}) {
  return [
    RunStartedEvent(threadId: threadId, runId: runId),
    RunErrorEvent(message: errorMessage),
  ];
}
