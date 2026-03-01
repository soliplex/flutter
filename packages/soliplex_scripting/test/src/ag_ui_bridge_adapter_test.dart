import 'package:ag_ui/ag_ui.dart';
import 'package:soliplex_interpreter_monty/soliplex_interpreter_monty.dart';
import 'package:soliplex_scripting/soliplex_scripting.dart';
import 'package:test/test.dart';

void main() {
  const adapter = AgUiBridgeAdapter(
    threadId: 'thread-1',
    runId: 'run-1',
  );

  group('AgUiBridgeAdapter.mapEvent', () {
    test('maps BridgeRunStarted → RunStartedEvent', () {
      final result = adapter.mapEvent(
        const BridgeRunStarted(threadId: 't', runId: 'r'),
      );
      expect(result, isA<RunStartedEvent>());
      final event = result as RunStartedEvent;
      expect(event.threadId, 'thread-1');
      expect(event.runId, 'run-1');
    });

    test('maps BridgeRunFinished → RunFinishedEvent', () {
      final result = adapter.mapEvent(
        const BridgeRunFinished(threadId: 't', runId: 'r'),
      );
      expect(result, isA<RunFinishedEvent>());
      final event = result as RunFinishedEvent;
      expect(event.threadId, 'thread-1');
      expect(event.runId, 'run-1');
    });

    test('maps BridgeRunError → RunErrorEvent', () {
      final result = adapter.mapEvent(
        const BridgeRunError(message: 'NameError: x'),
      );
      expect(result, isA<RunErrorEvent>());
      expect((result as RunErrorEvent).message, 'NameError: x');
    });

    test('maps BridgeStepStarted → StepStartedEvent', () {
      final result = adapter.mapEvent(
        const BridgeStepStarted(stepId: 'step-1'),
      );
      expect(result, isA<StepStartedEvent>());
      expect((result as StepStartedEvent).stepName, 'step-1');
    });

    test('maps BridgeStepFinished → StepFinishedEvent', () {
      final result = adapter.mapEvent(
        const BridgeStepFinished(stepId: 'step-1'),
      );
      expect(result, isA<StepFinishedEvent>());
      expect((result as StepFinishedEvent).stepName, 'step-1');
    });

    test('maps BridgeToolCallStart → ToolCallStartEvent', () {
      final result = adapter.mapEvent(
        const BridgeToolCallStart(callId: 'c1', name: 'search'),
      );
      expect(result, isA<ToolCallStartEvent>());
      final event = result as ToolCallStartEvent;
      expect(event.toolCallId, 'c1');
      expect(event.toolCallName, 'search');
    });

    test('maps BridgeToolCallArgs → ToolCallArgsEvent', () {
      final result = adapter.mapEvent(
        const BridgeToolCallArgs(callId: 'c1', delta: '{"q":"test"}'),
      );
      expect(result, isA<ToolCallArgsEvent>());
      final event = result as ToolCallArgsEvent;
      expect(event.toolCallId, 'c1');
      expect(event.delta, '{"q":"test"}');
    });

    test('maps BridgeToolCallEnd → ToolCallEndEvent', () {
      final result = adapter.mapEvent(
        const BridgeToolCallEnd(callId: 'c1'),
      );
      expect(result, isA<ToolCallEndEvent>());
      expect((result as ToolCallEndEvent).toolCallId, 'c1');
    });

    test('maps BridgeToolCallResult → ToolCallResultEvent', () {
      final result = adapter.mapEvent(
        const BridgeToolCallResult(callId: 'c1', result: 'hello'),
      );
      expect(result, isA<ToolCallResultEvent>());
      final event = result as ToolCallResultEvent;
      expect(event.toolCallId, 'c1');
      expect(event.messageId, 'c1');
      expect(event.content, 'hello');
    });

    test('maps BridgeTextStart → TextMessageStartEvent', () {
      final result = adapter.mapEvent(
        const BridgeTextStart(messageId: 'msg-1'),
      );
      expect(result, isA<TextMessageStartEvent>());
      expect((result as TextMessageStartEvent).messageId, 'msg-1');
    });

    test('maps BridgeTextContent → TextMessageContentEvent', () {
      final result = adapter.mapEvent(
        const BridgeTextContent(messageId: 'msg-1', delta: 'hello world'),
      );
      expect(result, isA<TextMessageContentEvent>());
      final event = result as TextMessageContentEvent;
      expect(event.messageId, 'msg-1');
      expect(event.delta, 'hello world');
    });

    test('maps BridgeTextEnd → TextMessageEndEvent', () {
      final result = adapter.mapEvent(
        const BridgeTextEnd(messageId: 'msg-1'),
      );
      expect(result, isA<TextMessageEndEvent>());
      expect((result as TextMessageEndEvent).messageId, 'msg-1');
    });
  });

  group('AgUiBridgeAdapter.adapt', () {
    test('transforms stream of BridgeEvents to BaseEvents', () async {
      final source = Stream.fromIterable(const [
        BridgeRunStarted(threadId: 't', runId: 'r'),
        BridgeStepStarted(stepId: 's1'),
        BridgeToolCallStart(callId: 'c1', name: 'fn'),
        BridgeToolCallArgs(callId: 'c1', delta: '{}'),
        BridgeToolCallEnd(callId: 'c1'),
        BridgeToolCallResult(callId: 'c1', result: 'ok'),
        BridgeStepFinished(stepId: 's1'),
        BridgeRunFinished(threadId: 't', runId: 'r'),
      ]);

      final events = await adapter.adapt(source).toList();

      expect(events, hasLength(8));
      expect(events[0], isA<RunStartedEvent>());
      expect(events[1], isA<StepStartedEvent>());
      expect(events[2], isA<ToolCallStartEvent>());
      expect(events[3], isA<ToolCallArgsEvent>());
      expect(events[4], isA<ToolCallEndEvent>());
      expect(events[5], isA<ToolCallResultEvent>());
      expect(events[6], isA<StepFinishedEvent>());
      expect(events[7], isA<RunFinishedEvent>());
    });

    test('injects threadId and runId from adapter, not source', () async {
      final source = Stream.fromIterable(const [
        BridgeRunStarted(threadId: 'ignored', runId: 'ignored'),
        BridgeRunFinished(threadId: 'ignored', runId: 'ignored'),
      ]);

      final events = await adapter.adapt(source).toList();

      final started = events[0] as RunStartedEvent;
      expect(started.threadId, 'thread-1');
      expect(started.runId, 'run-1');

      final finished = events[1] as RunFinishedEvent;
      expect(finished.threadId, 'thread-1');
      expect(finished.runId, 'run-1');
    });
  });
}
