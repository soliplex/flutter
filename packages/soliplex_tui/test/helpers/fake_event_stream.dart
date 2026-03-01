import 'dart:async';

import 'package:soliplex_client/soliplex_client.dart';

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

/// Fake AG-UI client for deterministic testing.
///
/// Only overrides [runAgent] and [close]. Tests set [onRunAgent] to return
/// different streams per call for multi-run sequencing.
class FakeAgUiClient extends AgUiClient {
  FakeAgUiClient() : super(config: AgUiClientConfig(baseUrl: 'http://fake'));

  /// Callback invoked for each [runAgent] call.
  Stream<BaseEvent> Function(String endpoint, SimpleRunAgentInput input)?
      onRunAgent;

  /// Number of times [runAgent] has been called.
  int runAgentCallCount = 0;

  @override
  Stream<BaseEvent> runAgent(
    String endpoint,
    SimpleRunAgentInput input, {
    CancelToken? cancelToken,
  }) {
    runAgentCallCount++;
    if (onRunAgent != null) return onRunAgent!(endpoint, input);
    return const Stream.empty();
  }

  @override
  Future<void> close() async {}
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
