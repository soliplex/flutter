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
      group('ToolCallStart status', () {
        test('creates ToolCallInfo with status streaming', () {
          const event = ToolCallStartEvent(
            toolCallId: 'tc-1',
            toolCallName: 'search',
          );

          final result = processEvent(conversation, streaming, event);

          expect(result.conversation.toolCalls, hasLength(1));
          final tc = result.conversation.toolCalls.first;
          expect(tc.id, equals('tc-1'));
          expect(tc.name, equals('search'));
          expect(tc.status, equals(ToolCallStatus.streaming));
        });

        test('accumulates tool names in activity across multiple starts', () {
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
      });

      group('ToolCallArgs accumulation', () {
        test('single delta fills arguments', () {
          const startEvent = ToolCallStartEvent(
            toolCallId: 'tc-1',
            toolCallName: 'search',
          );
          final afterStart = processEvent(conversation, streaming, startEvent);

          const argsEvent = ToolCallArgsEvent(
            toolCallId: 'tc-1',
            delta: '{"q":"test"}',
          );
          final result = processEvent(
            afterStart.conversation,
            afterStart.streaming,
            argsEvent,
          );

          expect(
            result.conversation.toolCalls.first.arguments,
            equals('{"q":"test"}'),
          );
        });

        test('multiple deltas concatenate', () {
          const startEvent = ToolCallStartEvent(
            toolCallId: 'tc-1',
            toolCallName: 'search',
          );
          final afterStart = processEvent(conversation, streaming, startEvent);

          const args1 = ToolCallArgsEvent(
            toolCallId: 'tc-1',
            delta: '{"q":',
          );
          final afterArgs1 = processEvent(
            afterStart.conversation,
            afterStart.streaming,
            args1,
          );

          const args2 = ToolCallArgsEvent(
            toolCallId: 'tc-1',
            delta: ' "test"}',
          );
          final result = processEvent(
            afterArgs1.conversation,
            afterArgs1.streaming,
            args2,
          );

          expect(
            result.conversation.toolCalls.first.arguments,
            equals('{"q": "test"}'),
          );
        });

        test('zero-arg tool has empty arguments', () {
          const startEvent = ToolCallStartEvent(
            toolCallId: 'tc-1',
            toolCallName: 'get_time',
          );
          final afterStart = processEvent(conversation, streaming, startEvent);

          // No ToolCallArgsEvent — go straight to end
          const endEvent = ToolCallEndEvent(toolCallId: 'tc-1');
          final result = processEvent(
            afterStart.conversation,
            afterStart.streaming,
            endEvent,
          );

          expect(
            result.conversation.toolCalls.first.arguments,
            isEmpty,
          );
        });

        test('args for non-existent toolCallId are ignored', () {
          const startEvent = ToolCallStartEvent(
            toolCallId: 'tc-1',
            toolCallName: 'search',
          );
          final afterStart = processEvent(conversation, streaming, startEvent);

          const argsEvent = ToolCallArgsEvent(
            toolCallId: 'tc-nonexistent',
            delta: '{"q":"test"}',
          );
          final result = processEvent(
            afterStart.conversation,
            afterStart.streaming,
            argsEvent,
          );

          // tc-1's arguments remain empty
          expect(
            result.conversation.toolCalls.first.arguments,
            isEmpty,
          );
        });

        test('args after ToolCallEnd are ignored (status guard)', () {
          const startEvent = ToolCallStartEvent(
            toolCallId: 'tc-1',
            toolCallName: 'search',
          );
          var result = processEvent(conversation, streaming, startEvent);

          const argsEvent = ToolCallArgsEvent(
            toolCallId: 'tc-1',
            delta: '{"q":"test"}',
          );
          result = processEvent(
            result.conversation,
            result.streaming,
            argsEvent,
          );

          const endEvent = ToolCallEndEvent(toolCallId: 'tc-1');
          result = processEvent(
            result.conversation,
            result.streaming,
            endEvent,
          );

          // Late args after end — should be ignored
          const lateArgs = ToolCallArgsEvent(
            toolCallId: 'tc-1',
            delta: ', "extra":"junk"}',
          );
          result = processEvent(
            result.conversation,
            result.streaming,
            lateArgs,
          );

          // Arguments unchanged from before end
          expect(
            result.conversation.toolCalls.first.arguments,
            equals('{"q":"test"}'),
          );
          expect(
            result.conversation.toolCalls.first.status,
            equals(ToolCallStatus.pending),
          );
        });
      });

      group('ToolCallEnd status transition', () {
        test('transitions from streaming to pending', () {
          const startEvent = ToolCallStartEvent(
            toolCallId: 'tc-1',
            toolCallName: 'search',
          );
          final afterStart = processEvent(conversation, streaming, startEvent);

          const argsEvent = ToolCallArgsEvent(
            toolCallId: 'tc-1',
            delta: '{"q":"test"}',
          );
          final afterArgs = processEvent(
            afterStart.conversation,
            afterStart.streaming,
            argsEvent,
          );

          const endEvent = ToolCallEndEvent(toolCallId: 'tc-1');
          final result = processEvent(
            afterArgs.conversation,
            afterArgs.streaming,
            endEvent,
          );

          expect(result.conversation.toolCalls, hasLength(1));
          final tc = result.conversation.toolCalls.first;
          expect(tc.status, equals(ToolCallStatus.pending));
          expect(tc.arguments, equals('{"q":"test"}'));
        });

        test('keeps tool in conversation.toolCalls', () {
          final conversationWithTool = conversation.withToolCall(
            const ToolCallInfo(
              id: 'tc-1',
              name: 'search',
              status: ToolCallStatus.streaming,
            ),
          );
          const event = ToolCallEndEvent(toolCallId: 'tc-1');

          final result = processEvent(conversationWithTool, streaming, event);

          expect(result.conversation.toolCalls, hasLength(1));
          expect(result.conversation.toolCalls.first.id, equals('tc-1'));
        });

        test('does not change activity', () {
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

        test('duplicate ToolCallEnd does not downgrade status', () {
          // Tool already in pending status (simulating after first end)
          final conversationWithPendingTool = conversation.withToolCall(
            const ToolCallInfo(
              id: 'tc-1',
              name: 'search',
              arguments: '{"q":"test"}',
            ),
          );
          const duplicateEnd = ToolCallEndEvent(toolCallId: 'tc-1');

          final result = processEvent(
            conversationWithPendingTool,
            streaming,
            duplicateEnd,
          );

          // Status should remain pending, not be re-set
          expect(
            result.conversation.toolCalls.first.status,
            equals(ToolCallStatus.pending),
          );
        });

        test('ToolCallEnd does not downgrade executing status', () {
          final conversationWithExecutingTool = conversation.withToolCall(
            const ToolCallInfo(
              id: 'tc-1',
              name: 'search',
              status: ToolCallStatus.executing,
            ),
          );
          const lateEnd = ToolCallEndEvent(toolCallId: 'tc-1');

          final result = processEvent(
            conversationWithExecutingTool,
            streaming,
            lateEnd,
          );

          // Status should remain executing
          expect(
            result.conversation.toolCalls.first.status,
            equals(ToolCallStatus.executing),
          );
        });
      });

      group('multiple tools accumulate independently', () {
        test('two sequential tool calls have correct args and status', () {
          // Start tool A
          const startA = ToolCallStartEvent(
            toolCallId: 'tc-a',
            toolCallName: 'search',
          );
          var result = processEvent(conversation, streaming, startA);

          // Args for tool A
          const argsA = ToolCallArgsEvent(
            toolCallId: 'tc-a',
            delta: '{"q":"alice"}',
          );
          result = processEvent(
            result.conversation,
            result.streaming,
            argsA,
          );

          // End tool A
          const endA = ToolCallEndEvent(toolCallId: 'tc-a');
          result = processEvent(
            result.conversation,
            result.streaming,
            endA,
          );

          // Start tool B
          const startB = ToolCallStartEvent(
            toolCallId: 'tc-b',
            toolCallName: 'summarize',
          );
          result = processEvent(
            result.conversation,
            result.streaming,
            startB,
          );

          // Args for tool B
          const argsB = ToolCallArgsEvent(
            toolCallId: 'tc-b',
            delta: '{"text":"hello"}',
          );
          result = processEvent(
            result.conversation,
            result.streaming,
            argsB,
          );

          // End tool B
          const endB = ToolCallEndEvent(toolCallId: 'tc-b');
          result = processEvent(
            result.conversation,
            result.streaming,
            endB,
          );

          // Both tools present, both pending, correct args
          expect(result.conversation.toolCalls, hasLength(2));

          final toolA =
              result.conversation.toolCalls.firstWhere((tc) => tc.id == 'tc-a');
          expect(toolA.status, equals(ToolCallStatus.pending));
          expect(toolA.arguments, equals('{"q":"alice"}'));

          final toolB =
              result.conversation.toolCalls.firstWhere((tc) => tc.id == 'tc-b');
          expect(toolB.status, equals(ToolCallStatus.pending));
          expect(toolB.arguments, equals('{"text":"hello"}'));
        });
      });

      group('regression — existing behavior preserved', () {
        test('ToolCallActivity still tracks tool names', () {
          const event = ToolCallStartEvent(
            toolCallId: 'tc-1',
            toolCallName: 'search',
          );

          final result = processEvent(conversation, streaming, event);

          final awaitingText = result.streaming as app_streaming.AwaitingText;
          final activity =
              awaitingText.currentActivity as app_streaming.ToolCallActivity;
          expect(activity.allToolNames, contains('search'));
        });

        test('text and tool calls coexist', () {
          // Start text
          const textStart = TextMessageStartEvent(messageId: 'msg-1');
          var result = processEvent(conversation, streaming, textStart);

          // Stream text content
          const textContent = TextMessageContentEvent(
            messageId: 'msg-1',
            delta: 'Here are the results: ',
          );
          result = processEvent(
            result.conversation,
            result.streaming,
            textContent,
          );

          // End text
          const textEnd = TextMessageEndEvent(messageId: 'msg-1');
          result = processEvent(
            result.conversation,
            result.streaming,
            textEnd,
          );

          // Then tool call
          const toolStart = ToolCallStartEvent(
            toolCallId: 'tc-1',
            toolCallName: 'search',
          );
          result = processEvent(
            result.conversation,
            result.streaming,
            toolStart,
          );

          const toolArgs = ToolCallArgsEvent(
            toolCallId: 'tc-1',
            delta: '{"q":"test"}',
          );
          result = processEvent(
            result.conversation,
            result.streaming,
            toolArgs,
          );

          const toolEnd = ToolCallEndEvent(toolCallId: 'tc-1');
          result = processEvent(
            result.conversation,
            result.streaming,
            toolEnd,
          );

          // Both text message and tool call present
          expect(result.conversation.messages, hasLength(1));
          expect(result.conversation.toolCalls, hasLength(1));
          expect(
            result.conversation.toolCalls.first.status,
            equals(ToolCallStatus.pending),
          );
        });
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
