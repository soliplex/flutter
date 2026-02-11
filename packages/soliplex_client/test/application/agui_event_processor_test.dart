import 'package:ag_ui/ag_ui.dart';
import 'package:soliplex_client/src/application/agui_event_processor.dart';
import 'package:soliplex_client/src/application/streaming_state.dart'
    as app_streaming;
import 'package:soliplex_client/src/domain/chat_message.dart';
import 'package:soliplex_client/src/domain/conversation.dart';
import 'package:test/test.dart';

const _defaultUser = ChatUser.assistant;

void main() {
  group('processEvent', () {
    late Conversation conversation;
    late app_streaming.StreamingState streaming;

    setUp(() {
      conversation = Conversation.empty(threadId: 'thread-1');
      streaming = const app_streaming.AwaitingText();
    });

    group('run lifecycle events', () {
      test('RunStartedEvent sets status to Running', () {
        const event = RunStartedEvent(threadId: 'thread-1', runId: 'run-1');

        final result = processEvent(conversation, streaming, event);

        expect(result.conversation.status, isA<Running>());
        expect((result.conversation.status as Running).runId, equals('run-1'));
        expect(result.streaming, isA<app_streaming.AwaitingText>());
      });

      test('RunFinishedEvent sets status to Completed', () {
        final runningConversation = conversation.withStatus(
          const Running(runId: 'run-1'),
        );
        const event = RunFinishedEvent(threadId: 'thread-1', runId: 'run-1');

        final result = processEvent(runningConversation, streaming, event);

        expect(result.conversation.status, isA<Completed>());
        expect(result.streaming, isA<app_streaming.AwaitingText>());
      });

      test('RunErrorEvent sets status to Failed with message', () {
        final runningConversation = conversation.withStatus(
          const Running(runId: 'run-1'),
        );
        const event = RunErrorEvent(
          message: 'Something went wrong',
          code: 'ERROR_CODE',
        );

        final result = processEvent(runningConversation, streaming, event);

        expect(result.conversation.status, isA<Failed>());
        expect(
          (result.conversation.status as Failed).error,
          equals('Something went wrong'),
        );
        expect(result.streaming, isA<app_streaming.AwaitingText>());
      });
    });

    group('text message streaming', () {
      test('TextMessageStartEvent begins streaming', () {
        const event = TextMessageStartEvent(messageId: 'msg-1');

        final result = processEvent(conversation, streaming, event);

        expect(result.streaming, isA<app_streaming.TextStreaming>());
        final streamingState = result.streaming as app_streaming.TextStreaming;
        expect(streamingState.messageId, equals('msg-1'));
        expect(streamingState.text, isEmpty);
      });

      test('TextMessageContentEvent is ignored when AwaitingText', () {
        const event = TextMessageContentEvent(
          messageId: 'msg-1',
          delta: 'Hello',
        );

        final result = processEvent(conversation, streaming, event);

        expect(result.streaming, isA<app_streaming.AwaitingText>());
        expect(result.conversation.messages, isEmpty);
      });

      test('TextMessageContentEvent appends delta to streaming text', () {
        const streamingState = app_streaming.TextStreaming(
          messageId: 'msg-1',
          user: _defaultUser,
          text: 'Hello',
        );
        const event = TextMessageContentEvent(
          messageId: 'msg-1',
          delta: ' world',
        );

        final result = processEvent(conversation, streamingState, event);

        expect(result.streaming, isA<app_streaming.TextStreaming>());
        final newStreaming = result.streaming as app_streaming.TextStreaming;
        expect(newStreaming.messageId, equals('msg-1'));
        expect(newStreaming.text, equals('Hello world'));
      });

      test(
        'TextMessageContentEvent ignores delta if messageId does not match',
        () {
          const streamingState = app_streaming.TextStreaming(
            messageId: 'msg-1',
            user: _defaultUser,
            text: 'Hello',
          );
          const event = TextMessageContentEvent(
            messageId: 'msg-other',
            delta: ' world',
          );

          final result = processEvent(conversation, streamingState, event);

          expect(result.streaming, equals(streamingState));
        },
      );

      test('TextMessageEndEvent finalizes message and resets streaming', () {
        const streamingState = app_streaming.TextStreaming(
          messageId: 'msg-1',
          user: _defaultUser,
          text: 'Hello world',
        );
        const event = TextMessageEndEvent(messageId: 'msg-1');

        final result = processEvent(conversation, streamingState, event);

        expect(result.streaming, isA<app_streaming.AwaitingText>());
        expect(result.conversation.messages, hasLength(1));
        final message = result.conversation.messages.first;
        expect(message.id, equals('msg-1'));
      });

      test('TextMessageEndEvent preserves user role from streaming state', () {
        // Verify role propagation: user from streaming state goes into message
        const streamingState = app_streaming.TextStreaming(
          messageId: 'msg-1',
          user: ChatUser.user, // User role, not assistant
          text: 'User message',
        );
        const event = TextMessageEndEvent(messageId: 'msg-1');

        final result = processEvent(conversation, streamingState, event);

        final message = result.conversation.messages.first;
        expect(message.user, equals(ChatUser.user));
      });

      test(
        'TextMessageEndEvent ignores if messageId does not match streaming',
        () {
          const streamingState = app_streaming.TextStreaming(
            messageId: 'msg-1',
            user: _defaultUser,
            text: 'Hello',
          );
          const event = TextMessageEndEvent(messageId: 'msg-other');

          final result = processEvent(conversation, streamingState, event);

          expect(result.streaming, equals(streamingState));
          expect(result.conversation.messages, isEmpty);
        },
      );

      test('TextMessageStartEvent maps user role to ChatUser.user', () {
        const event = TextMessageStartEvent(
          messageId: 'msg-1',
          role: TextMessageRole.user,
        );

        final result = processEvent(conversation, streaming, event);

        final streamingState = result.streaming as app_streaming.TextStreaming;
        expect(streamingState.user, equals(ChatUser.user));
      });

      test('TextMessageStartEvent maps system role to ChatUser.system', () {
        const event = TextMessageStartEvent(
          messageId: 'msg-1',
          role: TextMessageRole.system,
        );

        final result = processEvent(conversation, streaming, event);

        final streamingState = result.streaming as app_streaming.TextStreaming;
        expect(streamingState.user, equals(ChatUser.system));
      });

      test('TextMessageStartEvent maps developer role to ChatUser.system', () {
        const event = TextMessageStartEvent(
          messageId: 'msg-1',
          role: TextMessageRole.developer,
        );

        final result = processEvent(conversation, streaming, event);

        final streamingState = result.streaming as app_streaming.TextStreaming;
        expect(streamingState.user, equals(ChatUser.system));
      });
    });

    group('tool call events', () {
      test('ToolCallStartEvent adds tool call with streaming status', () {
        const event = ToolCallStartEvent(
          toolCallId: 'tool-1',
          toolCallName: 'search',
        );

        final result = processEvent(conversation, streaming, event);

        expect(result.conversation.toolCalls, hasLength(1));
        expect(result.conversation.toolCalls.first.id, equals('tool-1'));
        expect(result.conversation.toolCalls.first.name, equals('search'));
        expect(
          result.conversation.toolCalls.first.status,
          equals(ToolCallStatus.streaming),
        );
      });

      test('ToolCallEndEvent marks tool call as pending', () {
        final conversationWithTool = conversation.withToolCall(
          const ToolCallInfo(
            id: 'tool-1',
            name: 'search',
            status: ToolCallStatus.streaming,
          ),
        );
        const event = ToolCallEndEvent(toolCallId: 'tool-1');

        final result = processEvent(conversationWithTool, streaming, event);

        expect(result.conversation.toolCalls, hasLength(1));
        expect(
          result.conversation.toolCalls.first.status,
          equals(ToolCallStatus.pending),
        );
      });

      test('ToolCallArgsEvent accumulates argument delta', () {
        final conversationWithTool = conversation.withToolCall(
          const ToolCallInfo(
            id: 'tool-1',
            name: 'search',
            arguments: '{"query":',
            status: ToolCallStatus.streaming,
          ),
        );
        const event = ToolCallArgsEvent(
          toolCallId: 'tool-1',
          delta: ' "hello"}',
        );

        final result = processEvent(conversationWithTool, streaming, event);

        expect(
          result.conversation.toolCalls.first.arguments,
          equals('{"query": "hello"}'),
        );
      });

      test('ToolCallArgsEvent for unknown id is ignored', () {
        const event = ToolCallArgsEvent(
          toolCallId: 'unknown-id',
          delta: 'data',
        );

        final result = processEvent(conversation, streaming, event);

        expect(result.conversation.toolCalls, isEmpty);
      });

      test('multiple ToolCallStartEvents accumulate tool names in activity',
          () {
        const event1 = ToolCallStartEvent(
          toolCallId: 'tc-1',
          toolCallName: 'search',
        );
        final result1 = processEvent(conversation, streaming, event1);

        const event2 = ToolCallStartEvent(
          toolCallId: 'tc-2',
          toolCallName: 'summarize',
        );
        final result2 = processEvent(
          result1.conversation,
          result1.streaming,
          event2,
        );

        final awaitingText = result2.streaming as app_streaming.AwaitingText;
        final activity =
            awaitingText.currentActivity as app_streaming.ToolCallActivity;
        expect(activity.allToolNames, equals({'search', 'summarize'}));
      });

      test('ToolCallEndEvent does not change activity', () {
        const awaitingWithTool = app_streaming.AwaitingText(
          currentActivity: app_streaming.ToolCallActivity(toolName: 'search'),
        );
        final conversationWithTool = conversation.withToolCall(
          const ToolCallInfo(
            id: 'tc-1',
            name: 'search',
            status: ToolCallStatus.streaming,
          ),
        );
        const event = ToolCallEndEvent(toolCallId: 'tc-1');

        final result = processEvent(
          conversationWithTool,
          awaitingWithTool,
          event,
        );

        expect(
          (result.streaming as app_streaming.AwaitingText).currentActivity,
          isA<app_streaming.ToolCallActivity>(),
        );
      });
    });

    group('thinking events', () {
      test(
        'ThinkingTextMessageStartEvent sets isThinkingStreaming and activity',
        () {
          const event = ThinkingTextMessageStartEvent();

          final result = processEvent(conversation, streaming, event);

          final awaitingText = result.streaming as app_streaming.AwaitingText;
          expect(awaitingText.isThinkingStreaming, isTrue);
          expect(
            awaitingText.currentActivity,
            isA<app_streaming.ThinkingActivity>(),
          );
        },
      );

      test('ThinkingTextMessageContentEvent buffers text in AwaitingText', () {
        const startedState = app_streaming.AwaitingText(
          isThinkingStreaming: true,
        );
        const event = ThinkingTextMessageContentEvent(delta: 'Thinking...');

        final result = processEvent(conversation, startedState, event);

        final awaitingText = result.streaming as app_streaming.AwaitingText;
        expect(awaitingText.bufferedThinkingText, equals('Thinking...'));
      });

      test('ThinkingTextMessageContentEvent appends to existing buffer', () {
        const startedState = app_streaming.AwaitingText(
          isThinkingStreaming: true,
          bufferedThinkingText: 'Part 1. ',
        );
        const event = ThinkingTextMessageContentEvent(delta: 'Part 2.');

        final result = processEvent(conversation, startedState, event);

        expect(
          (result.streaming as app_streaming.AwaitingText).bufferedThinkingText,
          equals('Part 1. Part 2.'),
        );
      });

      test('ThinkingTextMessageEndEvent sets isThinkingStreaming to false', () {
        const startedState = app_streaming.AwaitingText(
          isThinkingStreaming: true,
          bufferedThinkingText: 'Done thinking',
        );
        const event = ThinkingTextMessageEndEvent();

        final result = processEvent(conversation, startedState, event);

        final awaitingText = result.streaming as app_streaming.AwaitingText;
        expect(awaitingText.isThinkingStreaming, isFalse);
        expect(awaitingText.bufferedThinkingText, equals('Done thinking'));
      });

      test(
        'TextMessageStartEvent transfers buffered thinking to TextStreaming',
        () {
          const awaitingWithThinking = app_streaming.AwaitingText(
            bufferedThinkingText: 'Pre-text thinking',
          );
          const event = TextMessageStartEvent(messageId: 'msg-1');

          final result = processEvent(
            conversation,
            awaitingWithThinking,
            event,
          );

          final textStreaming = result.streaming as app_streaming.TextStreaming;
          expect(textStreaming.thinkingText, equals('Pre-text thinking'));
          expect(textStreaming.text, isEmpty);
        },
      );

      test(
        'ThinkingTextMessageContentEvent appends to TextStreaming.thinkingText',
        () {
          const textStreamingState = app_streaming.TextStreaming(
            messageId: 'msg-1',
            user: _defaultUser,
            text: 'Response text',
            thinkingText: 'Initial thinking',
            isThinkingStreaming: true,
          );
          const event = ThinkingTextMessageContentEvent(
            delta: ' more thinking',
          );

          final result = processEvent(conversation, textStreamingState, event);

          expect(
            (result.streaming as app_streaming.TextStreaming).thinkingText,
            equals('Initial thinking more thinking'),
          );
        },
      );

      test('TextMessageEndEvent preserves thinkingText in finalized message',
          () {
        const streamingState = app_streaming.TextStreaming(
          messageId: 'msg-1',
          user: _defaultUser,
          text: 'Response',
          thinkingText: 'My reasoning',
        );
        const event = TextMessageEndEvent(messageId: 'msg-1');

        final result = processEvent(conversation, streamingState, event);

        final message = result.conversation.messages.first as TextMessage;
        expect(message.thinkingText, equals('My reasoning'));
      });
    });

    group('state events', () {
      test('StateSnapshotEvent replaces aguiState', () {
        const event = StateSnapshotEvent(snapshot: {'key': 'value'});

        final result = processEvent(conversation, streaming, event);

        expect(result.conversation.aguiState, equals({'key': 'value'}));
        expect(result.streaming, equals(streaming));
      });

      test('StateDeltaEvent applies JSON Patch to aguiState', () {
        final conversationWithState = conversation.copyWith(
          aguiState: {'count': 0},
        );
        const event = StateDeltaEvent(
          delta: [
            {'op': 'replace', 'path': '/count', 'value': 1},
            {'op': 'add', 'path': '/name', 'value': 'test'},
          ],
        );

        final result = processEvent(conversationWithState, streaming, event);

        expect(result.conversation.aguiState['count'], 1);
        expect(result.conversation.aguiState['name'], 'test');
      });

      test('StateDeltaEvent applies JSON Patch to empty aguiState', () {
        // Default conversation has empty aguiState
        expect(conversation.aguiState, isEmpty);

        const event = StateDeltaEvent(
          delta: [
            {'op': 'add', 'path': '/count', 'value': 1},
            {
              'op': 'add',
              'path': '/nested',
              'value': {'key': 'value'},
            },
          ],
        );

        final result = processEvent(conversation, streaming, event);

        expect(result.conversation.aguiState['count'], 1);
        expect(result.conversation.aguiState['nested'], {'key': 'value'});
      });
    });

    group('passthrough events', () {
      test('CustomEvent passes through unchanged', () {
        const event = CustomEvent(name: 'custom', value: {'data': 123});

        final result = processEvent(conversation, streaming, event);

        expect(result.conversation, equals(conversation));
        expect(result.streaming, equals(streaming));
      });
    });
  });
}
