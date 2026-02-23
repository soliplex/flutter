import 'package:flutter_test/flutter_test.dart';
import 'package:soliplex_client/soliplex_client.dart';

import '../../helpers/mock_agui_stream.dart';

void main() {
  group('Tool call integration', () {
    late ToolRegistry registry;

    setUp(() {
      registry = const ToolRegistry().register(
        ClientTool(
          definition: const Tool(
            name: 'get_secret_number',
            description: 'Returns the secret number for a person',
          ),
          executor: (toolCall) async {
            final args = toolCall.arguments;
            if (args.contains('alice')) return '42';
            if (args.contains('bob')) return '7';
            throw Exception('Unknown person');
          },
        ),
      );
    });

    test('secret-number happy path — process, execute, synthesize, map',
        () async {
      // Step 1-2: Process mock events through event processor
      final events = [
        const RunStartedEvent(threadId: 't1', runId: 'run-1'),
        const ToolCallStartEvent(
          toolCallId: 'tc-1',
          toolCallName: 'get_secret_number',
        ),
        const ToolCallArgsEvent(toolCallId: 'tc-1', delta: '{"name":"alice"}'),
        const ToolCallEndEvent(toolCallId: 'tc-1'),
        const ToolCallStartEvent(
          toolCallId: 'tc-2',
          toolCallName: 'get_secret_number',
        ),
        const ToolCallArgsEvent(toolCallId: 'tc-2', delta: '{"name":"bob"}'),
        const ToolCallEndEvent(toolCallId: 'tc-2'),
        const RunFinishedEvent(threadId: 't1', runId: 'run-1'),
      ];

      var conversation = Conversation.empty(threadId: 't1');
      StreamingState streaming = const AwaitingText();

      for (final event in events) {
        final result = processEvent(conversation, streaming, event);
        conversation = result.conversation;
        streaming = result.streaming;
      }

      // Verify: 2 tool calls, both pending
      expect(conversation.toolCalls, hasLength(2));
      expect(conversation.toolCalls[0].status, equals(ToolCallStatus.pending));
      expect(conversation.toolCalls[1].status, equals(ToolCallStatus.pending));
      expect(conversation.toolCalls[0].arguments, equals('{"name":"alice"}'));
      expect(conversation.toolCalls[1].arguments, equals('{"name":"bob"}'));

      // Step 3-4: Execute pending tool calls through registry
      final executed = await Future.wait(
        conversation.toolCalls.map((tc) async {
          try {
            final result = await registry.execute(tc);
            return tc.copyWith(
              status: ToolCallStatus.completed,
              result: result,
            );
          } catch (e) {
            return tc.copyWith(
              status: ToolCallStatus.failed,
              result: 'Error: $e',
            );
          }
        }),
      );

      expect(executed[0].status, equals(ToolCallStatus.completed));
      expect(executed[0].result, equals('42'));
      expect(executed[1].status, equals(ToolCallStatus.completed));
      expect(executed[1].result, equals('7'));

      // Step 5: Synthesize ToolCallMessage
      final toolMsg = ToolCallMessage.fromExecuted(
        id: 'tcm-1',
        toolCalls: executed,
      );
      expect(toolMsg.user, equals(ChatUser.assistant));
      expect(toolMsg.toolCalls, hasLength(2));

      // Step 6: Convert via convertToAgui
      final aguiMessages = convertToAgui([toolMsg]);

      // AssistantMessage with toolCalls + 2 ToolMessages
      expect(aguiMessages, hasLength(3));
      expect(aguiMessages[0], isA<AssistantMessage>());

      final assistantMsg = aguiMessages[0] as AssistantMessage;
      expect(assistantMsg.toolCalls, hasLength(2));
      expect(
        assistantMsg.toolCalls![0].function.name,
        equals('get_secret_number'),
      );

      expect(aguiMessages[1], isA<ToolMessage>());
      final tool1 = aguiMessages[1] as ToolMessage;
      expect(tool1.toolCallId, equals('tc-1'));
      expect(tool1.content, equals('42'));

      expect(aguiMessages[2], isA<ToolMessage>());
      final tool2 = aguiMessages[2] as ToolMessage;
      expect(tool2.toolCallId, equals('tc-2'));
      expect(tool2.content, equals('7'));

      // Step 7: Append ToolCallMessage, process Run 2 (text response)
      conversation = conversation.withAppendedMessage(toolMsg);
      conversation = conversation.copyWith(toolCalls: []);

      final run2Events = [
        const RunStartedEvent(threadId: 't1', runId: 'run-2'),
        const TextMessageStartEvent(messageId: 'msg-2'),
        const TextMessageContentEvent(
          messageId: 'msg-2',
          delta: "Alice's number is 42, Bob's is 7",
        ),
        const TextMessageEndEvent(messageId: 'msg-2'),
        const RunFinishedEvent(threadId: 't1', runId: 'run-2'),
      ];

      streaming = const AwaitingText();
      for (final event in run2Events) {
        final result = processEvent(conversation, streaming, event);
        conversation = result.conversation;
        streaming = result.streaming;
      }

      // Step 8: Final conversation has ToolCallMessage + TextMessage
      expect(conversation.messages, hasLength(2));
      expect(conversation.messages[0], isA<ToolCallMessage>());
      expect(conversation.messages[1], isA<TextMessage>());
      final finalText = conversation.messages[1] as TextMessage;
      expect(finalText.text, contains('42'));
      expect(finalText.text, contains('7'));
    });

    test('tool failure isolation — one fails, other succeeds', () async {
      final events = [
        const RunStartedEvent(threadId: 't1', runId: 'run-1'),
        const ToolCallStartEvent(
          toolCallId: 'tc-1',
          toolCallName: 'get_secret_number',
        ),
        const ToolCallArgsEvent(toolCallId: 'tc-1', delta: '{"name":"alice"}'),
        const ToolCallEndEvent(toolCallId: 'tc-1'),
        const ToolCallStartEvent(
          toolCallId: 'tc-2',
          toolCallName: 'get_secret_number',
        ),
        const ToolCallArgsEvent(
          toolCallId: 'tc-2',
          delta: '{"name":"charlie"}',
        ),
        const ToolCallEndEvent(toolCallId: 'tc-2'),
        const RunFinishedEvent(threadId: 't1', runId: 'run-1'),
      ];

      var conversation = Conversation.empty(threadId: 't1');
      StreamingState streaming = const AwaitingText();

      for (final event in events) {
        final result = processEvent(conversation, streaming, event);
        conversation = result.conversation;
        streaming = result.streaming;
      }

      // Execute — charlie throws
      final executed = await Future.wait(
        conversation.toolCalls.map((tc) async {
          try {
            final result = await registry.execute(tc);
            return tc.copyWith(
              status: ToolCallStatus.completed,
              result: result,
            );
          } catch (e) {
            return tc.copyWith(
              status: ToolCallStatus.failed,
              result: 'Error: $e',
            );
          }
        }),
      );

      expect(executed[0].status, equals(ToolCallStatus.completed));
      expect(executed[0].result, equals('42'));
      expect(executed[1].status, equals(ToolCallStatus.failed));
      expect(executed[1].result, contains('Unknown person'));

      // Both produce ToolMessages in AG-UI output
      final toolMsg = ToolCallMessage.fromExecuted(
        id: 'tcm-1',
        toolCalls: executed,
      );
      final aguiMessages = convertToAgui([toolMsg]);
      expect(aguiMessages, hasLength(3));

      final successTool = aguiMessages[1] as ToolMessage;
      expect(successTool.content, equals('42'));

      final failTool = aguiMessages[2] as ToolMessage;
      expect(failTool.content, contains('Unknown person'));
    });

    group('mapper round-trip edge cases', () {
      test('empty args normalizes to {}', () {
        final toolMsg = ToolCallMessage.fromExecuted(
          id: 'tcm-1',
          toolCalls: const [
            ToolCallInfo(
              id: 'tc-1',
              name: 'get_secret_number',
              status: ToolCallStatus.completed,
              result: '42',
            ),
          ],
        );

        final aguiMessages = convertToAgui([toolMsg]);
        final assistantMsg = aguiMessages[0] as AssistantMessage;
        expect(assistantMsg.toolCalls![0].function.arguments, equals('{}'));
      });

      test('failed tool produces ToolMessage with error content', () {
        final toolMsg = ToolCallMessage.fromExecuted(
          id: 'tcm-1',
          toolCalls: const [
            ToolCallInfo(
              id: 'tc-1',
              name: 'get_secret_number',
              arguments: '{"name":"alice"}',
              status: ToolCallStatus.failed,
              result: 'Error: timeout',
            ),
          ],
        );

        final aguiMessages = convertToAgui([toolMsg]);
        expect(aguiMessages, hasLength(2));
        final toolResult = aguiMessages[1] as ToolMessage;
        expect(toolResult.content, equals('Error: timeout'));
      });

      test('completed tool with empty result produces ToolMessage', () {
        final toolMsg = ToolCallMessage.fromExecuted(
          id: 'tcm-1',
          toolCalls: const [
            ToolCallInfo(
              id: 'tc-1',
              name: 'get_secret_number',
              arguments: '{"name":"alice"}',
              status: ToolCallStatus.completed,
            ),
          ],
        );

        final aguiMessages = convertToAgui([toolMsg]);
        expect(aguiMessages, hasLength(2));
        final toolResult = aguiMessages[1] as ToolMessage;
        expect(toolResult.content, isEmpty);
      });
    });

    group('FakeAgUiClient', () {
      test('onRunAgent returns different streams per call', () async {
        final client = FakeAgUiClient();

        final run1Events = [
          const RunStartedEvent(threadId: 't1', runId: 'run-1'),
          const ToolCallStartEvent(
            toolCallId: 'tc-1',
            toolCallName: 'get_secret_number',
          ),
          const ToolCallArgsEvent(
            toolCallId: 'tc-1',
            delta: '{"name":"alice"}',
          ),
          const ToolCallEndEvent(toolCallId: 'tc-1'),
          const RunFinishedEvent(threadId: 't1', runId: 'run-1'),
        ];

        final run2Events = [
          const RunStartedEvent(threadId: 't1', runId: 'run-2'),
          const TextMessageStartEvent(
            messageId: 'msg-1',
          ),
          const TextMessageContentEvent(
            messageId: 'msg-1',
            delta: "Alice's number is 42",
          ),
          const TextMessageEndEvent(messageId: 'msg-1'),
          const RunFinishedEvent(threadId: 't1', runId: 'run-2'),
        ];

        client.onRunAgent = (endpoint, input) {
          if (client.runAgentCallCount == 1) {
            return buildMockEventStream(run1Events);
          }
          return buildMockEventStream(run2Events);
        };

        // Run 1
        final events1 = await client
            .runAgent(
              'agentic_chat',
              const SimpleRunAgentInput(threadId: 't1'),
            )
            .toList();
        expect(events1, hasLength(5));
        expect(client.runAgentCallCount, equals(1));

        // Run 2 — process events through conversation state
        var conversation = Conversation.empty(threadId: 't1');
        StreamingState streaming = const AwaitingText();

        final stream2 = client.runAgent(
          'agentic_chat',
          const SimpleRunAgentInput(threadId: 't1'),
        );
        await for (final event in stream2) {
          final result = processEvent(conversation, streaming, event);
          conversation = result.conversation;
          streaming = result.streaming;
        }

        expect(client.runAgentCallCount, equals(2));
        expect(conversation.messages, hasLength(1));
        expect(conversation.messages[0], isA<TextMessage>());
        final textMsg = conversation.messages[0] as TextMessage;
        expect(textMsg.text, equals("Alice's number is 42"));
      });

      test('default stream is empty when onRunAgent is null', () async {
        final client = FakeAgUiClient();

        final events = await client
            .runAgent(
              'agentic_chat',
              const SimpleRunAgentInput(),
            )
            .toList();

        expect(events, isEmpty);
        expect(client.runAgentCallCount, equals(1));
      });
    });

    test('buildMockEventStream produces deterministic sequence', () async {
      final events = [
        const RunStartedEvent(threadId: 't1', runId: 'run-1'),
        const TextMessageStartEvent(
          messageId: 'msg-1',
        ),
        const TextMessageContentEvent(messageId: 'msg-1', delta: 'Hello'),
        const TextMessageEndEvent(messageId: 'msg-1'),
        const RunFinishedEvent(threadId: 't1', runId: 'run-1'),
      ];

      final collected = await buildMockEventStream(events).toList();

      expect(collected, hasLength(5));
      expect(collected[0], isA<RunStartedEvent>());
      expect(collected[4], isA<RunFinishedEvent>());
    });
  });
}
