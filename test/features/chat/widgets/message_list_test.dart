import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soliplex_client/soliplex_client.dart';
import 'package:soliplex_client/soliplex_client.dart' as domain
    show ChatMessage, Conversation, Running;
import 'package:soliplex_frontend/core/models/active_run_state.dart';
import 'package:soliplex_frontend/core/providers/active_run_provider.dart';
import 'package:soliplex_frontend/core/providers/threads_provider.dart';
import 'package:soliplex_frontend/features/chat/widgets/chat_message_widget.dart';
import 'package:soliplex_frontend/features/chat/widgets/message_list.dart';
import 'package:soliplex_frontend/features/chat/widgets/message_list.dart'
    as sut show computeDisplayMessages, computeSpacerHeight;
import 'package:soliplex_frontend/shared/widgets/empty_state.dart';
import 'package:soliplex_frontend/shared/widgets/error_display.dart';

import '../../../helpers/test_helpers.dart';

void main() {
  group('MessageList', () {
    group('Loading State', () {
      testWidgets('shows loading indicator while fetching messages', (
        tester,
      ) async {
        // Arrange: Provider that never completes
        final completer = Completer<List<domain.ChatMessage>>();

        await tester.pumpWidget(
          createTestApp(
            home: const Scaffold(body: MessageList()),
            overrides: [
              currentThreadProvider.overrideWith(
                (ref) => TestData.createThread(),
              ),
              allMessagesProvider.overrideWith((ref) => completer.future),
              activeRunNotifierOverride(const IdleState()),
            ],
          ),
        );
        // Don't use pumpAndSettle - we want to see loading state
        await tester.pump();

        // Assert
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.byType(ChatMessageWidget), findsNothing);
      });
    });

    group('Error State', () {
      testWidgets('shows error display when message fetch fails', (
        tester,
      ) async {
        // Arrange: Provider that throws
        await tester.pumpWidget(
          createTestApp(
            home: const Scaffold(body: MessageList()),
            overrides: [
              currentThreadProvider.overrideWith(
                (ref) => TestData.createThread(),
              ),
              allMessagesProvider.overrideWith(
                (ref) => Future<List<domain.ChatMessage>>.error(
                  Exception('Network error'),
                ),
              ),
              activeRunNotifierOverride(const IdleState()),
            ],
          ),
        );
        await tester.pumpAndSettle();

        // Assert
        expect(find.byType(ErrorDisplay), findsOneWidget);
        expect(find.byType(ChatMessageWidget), findsNothing);
      });
    });

    group('Empty State', () {
      testWidgets('displays empty state when no messages', (tester) async {
        // Arrange
        await tester.pumpWidget(
          createTestApp(
            home: const Scaffold(body: MessageList()),
            overrides: [
              currentThreadProvider.overrideWith((ref) => null),
              allMessagesProvider.overrideWith(
                (ref) async => <domain.ChatMessage>[],
              ),
              activeRunNotifierOverride(const IdleState()),
            ],
          ),
        );
        await tester.pumpAndSettle();

        // Assert
        expect(find.byType(EmptyState), findsOneWidget);
        expect(find.text('No messages yet. Send one below!'), findsOneWidget);
      });
    });

    group('Message Display', () {
      testWidgets('displays list of messages', (tester) async {
        // Arrange
        final messages = [
          TestData.createMessage(id: 'msg-1', text: 'Hello'),
          TestData.createMessage(
            id: 'msg-2',
            user: ChatUser.assistant,
            text: 'Hi there!',
          ),
          TestData.createMessage(id: 'msg-3', text: 'How are you?'),
        ];

        final mockThread = TestData.createThread();

        // Act
        await tester.pumpWidget(
          createTestApp(
            home: const Scaffold(body: MessageList()),
            overrides: [
              currentThreadProvider.overrideWith((ref) => mockThread),
              allMessagesProvider.overrideWith((ref) async => messages),
              activeRunNotifierOverride(const IdleState()),
            ],
          ),
        );
        await tester.pumpAndSettle();

        // Assert
        expect(find.byType(ChatMessageWidget), findsNWidgets(3));
        expect(find.text('Hello'), findsOneWidget);
        expect(find.text('Hi there!'), findsOneWidget);
        expect(find.text('How are you?'), findsOneWidget);
      });

      testWidgets('assigns unique keys to message widgets', (tester) async {
        // Arrange
        final messages = [
          TestData.createMessage(id: 'msg-1', text: 'Message 1'),
          TestData.createMessage(id: 'msg-2', text: 'Message 2'),
        ];

        final mockThread = TestData.createThread();

        // Act
        await tester.pumpWidget(
          createTestApp(
            home: const Scaffold(body: MessageList()),
            overrides: [
              currentThreadProvider.overrideWith((ref) => mockThread),
              allMessagesProvider.overrideWith((ref) async => messages),
              activeRunNotifierOverride(const IdleState()),
            ],
          ),
        );
        await tester.pumpAndSettle();

        // Assert
        final messageWidgets = tester.widgetList<ChatMessageWidget>(
          find.byType(ChatMessageWidget),
        );
        expect(messageWidgets.first.key, isA<ValueKey<String>>());
        expect(messageWidgets.last.key, isA<ValueKey<String>>());
      });
    });

    group('Streaming Behavior', () {
      testWidgets('shows messages without extra widget when not streaming',
          (tester) async {
        // Arrange
        final messages = [TestData.createMessage(text: 'Hello')];

        final mockThread = TestData.createThread();

        // Act
        await tester.pumpWidget(
          createTestApp(
            home: const Scaffold(body: MessageList()),
            overrides: [
              currentThreadProvider.overrideWith((ref) => mockThread),
              allMessagesProvider.overrideWith((ref) async => messages),
              activeRunNotifierOverride(const IdleState()),
            ],
          ),
        );
        await tester.pumpAndSettle();

        // Assert
        expect(find.byType(ChatMessageWidget), findsOneWidget);
      });

      testWidgets(
        'shows only historical messages when running with AwaitingText',
        (tester) async {
          // Arrange: Running with AwaitingText (no thinking content)
          final messages = [
            TestData.createMessage(id: 'msg-1', text: 'Message 1'),
            TestData.createMessage(id: 'msg-2', text: 'Message 2'),
          ];

          final mockThread = TestData.createThread();
          const conversation = domain.Conversation(
            threadId: 'test-thread',
            status: domain.Running(runId: 'test-run'),
          );

          // Act
          await tester.pumpWidget(
            createTestApp(
              home: const Scaffold(body: MessageList()),
              overrides: [
                currentThreadProvider.overrideWith((ref) => mockThread),
                allMessagesProvider.overrideWith((ref) async => messages),
                activeRunNotifierOverride(
                  const RunningState(conversation: conversation),
                ),
              ],
            ),
          );
          await tester.pumpAndSettle();

          // Assert: Only 2 historical messages, no synthetic
          expect(find.byType(ChatMessageWidget), findsNWidgets(2));
        },
      );
    });

    group('Streaming Status', () {
      testWidgets('passes isStreaming to synthetic streaming message', (
        tester,
      ) async {
        // Arrange: User message in history, assistant streaming response
        final messages = [
          TestData.createMessage(id: 'msg-1', text: 'User question'),
        ];

        final mockThread = TestData.createThread();
        const conversation = domain.Conversation(
          threadId: 'test-thread',
          status: domain.Running(runId: 'test-run'),
        );

        // Act
        await tester.pumpWidget(
          createTestApp(
            home: const Scaffold(body: MessageList()),
            overrides: [
              currentThreadProvider.overrideWith((ref) => mockThread),
              allMessagesProvider.overrideWith((ref) async => messages),
              activeRunNotifierOverride(
                const RunningState(
                  conversation: conversation,
                  streaming: TextStreaming(
                    messageId: 'msg-2',
                    user: ChatUser.assistant,
                    text: 'Typing...',
                  ),
                ),
              ),
            ],
          ),
        );
        // Use pump() instead of pumpAndSettle() because the streaming
        // indicator's CircularProgressIndicator animation never settles.
        await tester.pump();
        await tester.pump();

        // Assert: 2 messages - user (not streaming) + synthetic (streaming)
        final messageWidgets = tester.widgetList<ChatMessageWidget>(
          find.byType(ChatMessageWidget),
        );
        expect(messageWidgets.length, equals(2));
        expect(messageWidgets.first.isStreaming, isFalse);
        expect(messageWidgets.last.isStreaming, isTrue);
      });

      testWidgets('does not pass isStreaming to historical messages', (
        tester,
      ) async {
        // Arrange: Two historical messages, new streaming response
        final messages = [
          TestData.createMessage(id: 'msg-1', text: 'First message'),
          TestData.createMessage(id: 'msg-2', text: 'Second message'),
        ];

        final mockThread = TestData.createThread();
        const conversation = domain.Conversation(
          threadId: 'test-thread',
          status: domain.Running(runId: 'test-run'),
        );

        // Act
        await tester.pumpWidget(
          createTestApp(
            home: const Scaffold(body: MessageList()),
            overrides: [
              currentThreadProvider.overrideWith((ref) => mockThread),
              allMessagesProvider.overrideWith((ref) async => messages),
              activeRunNotifierOverride(
                const RunningState(
                  conversation: conversation,
                  streaming: TextStreaming(
                    messageId: 'msg-3',
                    user: ChatUser.assistant,
                    text: 'Typing...',
                  ),
                ),
              ),
            ],
          ),
        );
        // Use pump() instead of pumpAndSettle() because the streaming
        // indicator's CircularProgressIndicator animation never settles.
        await tester.pump();
        await tester.pump();

        // Assert: 3 messages - 2 historical (not streaming) + 1 synthetic
        final messageWidgets = tester
            .widgetList<ChatMessageWidget>(find.byType(ChatMessageWidget))
            .toList();
        expect(messageWidgets.length, equals(3));
        expect(messageWidgets[0].isStreaming, isFalse);
        expect(messageWidgets[1].isStreaming, isFalse);
        expect(messageWidgets[2].isStreaming, isTrue);
      });

      testWidgets('passes isThinkingStreaming to synthetic message', (
        tester,
      ) async {
        // Arrange: Streaming with active thinking
        final messages = [
          TestData.createMessage(id: 'msg-1', text: 'User question'),
        ];

        final mockThread = TestData.createThread();
        const conversation = domain.Conversation(
          threadId: 'test-thread',
          status: domain.Running(runId: 'test-run'),
        );

        // Act
        await tester.pumpWidget(
          createTestApp(
            home: const Scaffold(body: MessageList()),
            overrides: [
              currentThreadProvider.overrideWith((ref) => mockThread),
              allMessagesProvider.overrideWith((ref) async => messages),
              activeRunNotifierOverride(
                const RunningState(
                  conversation: conversation,
                  streaming: TextStreaming(
                    messageId: 'msg-2',
                    user: ChatUser.assistant,
                    text: 'Typing...',
                    isThinkingStreaming: true,
                  ),
                ),
              ),
            ],
          ),
        );
        await tester.pump();
        await tester.pump();

        // Assert: Synthetic message has isThinkingStreaming true
        final messageWidgets = tester
            .widgetList<ChatMessageWidget>(find.byType(ChatMessageWidget))
            .toList();
        expect(messageWidgets.last.isThinkingStreaming, isTrue);
        expect(messageWidgets.first.isThinkingStreaming, isFalse);
      });
    });

    group('Scrolling', () {
      testWidgets('scrolls to bottom when new messages arrive', (tester) async {
        // Arrange
        final initialMessages = [
          TestData.createMessage(id: 'msg-1', text: 'Message 1'),
        ];

        final updatedMessages = [
          TestData.createMessage(id: 'msg-1', text: 'Message 1'),
          TestData.createMessage(id: 'msg-2', text: 'Message 2'),
          TestData.createMessage(id: 'msg-3', text: 'Message 3'),
        ];

        final mockThread = TestData.createThread();

        // Use a flag to track which messages to return
        // Riverpod 3.0 uses == for update filtering, so we need different
        // list instances (not a mutated list) to trigger rebuilds
        var useUpdatedMessages = false;

        final container = ProviderContainer(
          overrides: [
            currentThreadProvider.overrideWith((ref) => mockThread),
            allMessagesProvider.overrideWith((ref) async {
              return useUpdatedMessages ? updatedMessages : initialMessages;
            }),
            activeRunNotifierOverride(const IdleState()),
          ],
        );
        addTearDown(container.dispose);

        // Act - Initial render
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: testThemeData,
              home: const Scaffold(body: MessageList()),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Message 1'), findsOneWidget);
        expect(find.text('Message 3'), findsNothing);

        // Update to use new messages and invalidate the provider
        useUpdatedMessages = true;
        container.invalidate(allMessagesProvider);

        await tester.pumpAndSettle();

        // Assert - Should have scrolled (no assertion for exact position,
        // just verify no exceptions)
        expect(find.text('Message 3'), findsOneWidget);
      });
    });

    group('Trailing spacer', () {
      testWidgets(
        'height is zero when idle and last message is from assistant',
        (tester) async {
          final messages = [
            TestData.createMessage(id: 'msg-1', text: 'Hello'),
            TestData.createMessage(
              id: 'msg-2',
              text: 'Hi!',
              user: ChatUser.assistant,
            ),
          ];

          await tester.pumpWidget(
            createTestApp(
              home: const Scaffold(body: MessageList()),
              overrides: [
                currentThreadProvider.overrideWith(
                  (ref) => TestData.createThread(),
                ),
                allMessagesProvider.overrideWith((ref) async => messages),
                activeRunNotifierOverride(const IdleState()),
              ],
            ),
          );
          await tester.pumpAndSettle();

          final spacer = tester.widget<SizedBox>(
            find.byKey(MessageList.trailingSpacerKey),
          );
          expect(spacer.height, equals(0));
        },
      );

      testWidgets(
        'fills viewport when last message is from user',
        (tester) async {
          final messages = [
            TestData.createMessage(id: 'msg-1', text: 'Hello'),
          ];

          await tester.pumpWidget(
            createTestApp(
              home: const Scaffold(body: MessageList()),
              overrides: [
                currentThreadProvider.overrideWith(
                  (ref) => TestData.createThread(),
                ),
                allMessagesProvider.overrideWith((ref) async => messages),
                activeRunNotifierOverride(const IdleState()),
              ],
            ),
          );
          await tester.pumpAndSettle();

          final spacer = tester.widget<SizedBox>(
            find.byKey(MessageList.trailingSpacerKey),
          );
          expect(spacer.height, greaterThan(0));
        },
      );

      testWidgets(
        'fills viewport when streaming',
        (tester) async {
          final messages = [
            TestData.createMessage(id: 'msg-1', text: 'Hello'),
          ];

          const conversation = domain.Conversation(
            threadId: 'test-thread',
            status: domain.Running(runId: 'test-run'),
          );

          await tester.pumpWidget(
            createTestApp(
              home: const Scaffold(body: MessageList()),
              overrides: [
                currentThreadProvider.overrideWith(
                  (ref) => TestData.createThread(),
                ),
                allMessagesProvider.overrideWith((ref) async => messages),
                activeRunNotifierOverride(
                  const RunningState(
                    conversation: conversation,
                    streaming: TextStreaming(
                      messageId: 'msg-2',
                      user: ChatUser.assistant,
                      text: 'Responding...',
                    ),
                  ),
                ),
              ],
            ),
          );
          await tester.pump();
          await tester.pump();

          final spacer = tester.widget<SizedBox>(
            find.byKey(MessageList.trailingSpacerKey),
          );
          expect(spacer.height, greaterThan(0));
        },
      );
    });

    group('Scroll-to-bottom button', () {
      List<ChatMessage> manyMessages() => [
            ...List.generate(
              30,
              (i) => TestData.createMessage(id: 'msg-$i', text: 'Message $i'),
            ),
            TestData.createMessage(
              id: 'msg-final',
              user: ChatUser.assistant,
              text: 'Final reply',
            ),
          ];

      testWidgets('hidden after initial load', (tester) async {
        await tester.pumpWidget(
          createTestApp(
            home: const MessageList(),
            overrides: [
              currentThreadProvider.overrideWith(
                (ref) => TestData.createThread(),
              ),
              allMessagesProvider.overrideWith(
                (ref) async => manyMessages(),
              ),
              activeRunNotifierOverride(const IdleState()),
            ],
          ),
        );
        await tester.pumpAndSettle();

        // Advance well past the 500ms show timer.
        await tester.pump(const Duration(seconds: 2));
        await tester.pump();

        final opacity = tester.widget<AnimatedOpacity>(
          find.byType(AnimatedOpacity),
        );
        expect(opacity.opacity, equals(0.0));
      });

      testWidgets('appears after scrolling away from bottom', (
        tester,
      ) async {
        await tester.pumpWidget(
          createTestApp(
            home: const MessageList(),
            overrides: [
              currentThreadProvider.overrideWith(
                (ref) => TestData.createThread(),
              ),
              allMessagesProvider.overrideWith(
                (ref) async => manyMessages(),
              ),
              activeRunNotifierOverride(const IdleState()),
            ],
          ),
        );
        await tester.pumpAndSettle();

        // Scroll up far from bottom.
        await tester.drag(find.byType(ListView), const Offset(0, 2000));
        await tester.pumpAndSettle();

        // Advance past the 500ms show delay.
        await tester.pump(const Duration(milliseconds: 600));
        await tester.pump();

        final opacity = tester.widget<AnimatedOpacity>(
          find.byType(AnimatedOpacity),
        );
        expect(opacity.opacity, equals(1.0));
      });

      testWidgets('auto-hides after 3 seconds', (tester) async {
        await tester.pumpWidget(
          createTestApp(
            home: const MessageList(),
            overrides: [
              currentThreadProvider.overrideWith(
                (ref) => TestData.createThread(),
              ),
              allMessagesProvider.overrideWith(
                (ref) async => manyMessages(),
              ),
              activeRunNotifierOverride(const IdleState()),
            ],
          ),
        );
        await tester.pumpAndSettle();

        // Scroll up and wait for button to appear.
        await tester.drag(find.byType(ListView), const Offset(0, 2000));
        await tester.pumpAndSettle();
        await tester.pump(const Duration(milliseconds: 600));
        await tester.pump();

        // Verify visible.
        expect(
          tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
          equals(1.0),
        );

        // Advance past the 3-second auto-hide timer.
        await tester.pump(const Duration(seconds: 4));
        await tester.pump();

        expect(
          tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
          equals(0.0),
        );
      });

      testWidgets('hides immediately when scroll starts', (tester) async {
        await tester.pumpWidget(
          createTestApp(
            home: const MessageList(),
            overrides: [
              currentThreadProvider.overrideWith(
                (ref) => TestData.createThread(),
              ),
              allMessagesProvider.overrideWith(
                (ref) async => manyMessages(),
              ),
              activeRunNotifierOverride(const IdleState()),
            ],
          ),
        );
        await tester.pumpAndSettle();

        // Scroll up and wait for button to appear.
        await tester.drag(find.byType(ListView), const Offset(0, 2000));
        await tester.pumpAndSettle();
        await tester.pump(const Duration(milliseconds: 600));
        await tester.pump();

        expect(
          tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
          equals(1.0),
        );

        // Start a new scroll gesture.
        final gesture = await tester.startGesture(
          tester.getCenter(find.byType(ListView)),
        );
        await gesture.moveBy(const Offset(0, 50));
        await tester.pump();

        expect(
          tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
          equals(0.0),
        );

        // Clean up gesture.
        await gesture.up();
        await tester.pumpAndSettle();
      });

      testWidgets('tap scrolls to bottom and hides button', (tester) async {
        await tester.pumpWidget(
          createTestApp(
            home: const MessageList(),
            overrides: [
              currentThreadProvider.overrideWith(
                (ref) => TestData.createThread(),
              ),
              allMessagesProvider.overrideWith(
                (ref) async => manyMessages(),
              ),
              activeRunNotifierOverride(const IdleState()),
            ],
          ),
        );
        await tester.pumpAndSettle();

        // Scroll up and wait for button to appear.
        await tester.drag(find.byType(ListView), const Offset(0, 2000));
        await tester.pumpAndSettle();
        await tester.pump(const Duration(milliseconds: 600));
        await tester.pump();

        // Tap the button.
        await tester.tap(find.byIcon(Icons.arrow_downward));
        await tester.pumpAndSettle();

        // Button should be hidden.
        expect(
          tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
          equals(0.0),
        );
      });
    });
  });

  group('computeDisplayMessages', () {
    group('when not running', () {
      test('returns historical messages unchanged for IdleState', () {
        // Arrange
        final history = [
          TestData.createMessage(id: 'msg-1', text: 'Hello'),
          TestData.createMessage(id: 'msg-2', text: 'World'),
        ];
        const runState = IdleState();

        // Act
        final result = sut.computeDisplayMessages(history, runState);

        // Assert
        expect(result.messages, equals(history));
        expect(result.hasSyntheticMessage, isFalse);
      });

      test('returns historical messages unchanged for CompletedState', () {
        // Arrange
        final history = [
          TestData.createMessage(id: 'msg-1', text: 'Hello'),
        ];
        const runState = CompletedState(
          conversation: Conversation(threadId: 'thread-1'),
          result: Success(),
        );

        // Act
        final result = sut.computeDisplayMessages(history, runState);

        // Assert
        expect(result.messages, equals(history));
        expect(result.hasSyntheticMessage, isFalse);
      });
    });

    group('when running with AwaitingText', () {
      test('returns historical messages unchanged when no thinking content',
          () {
        // Arrange
        final history = [
          TestData.createMessage(id: 'msg-1', text: 'User message'),
        ];
        const runState = RunningState(
          conversation: Conversation(
            threadId: 'thread-1',
            status: Running(runId: 'run-1'),
          ),
        );

        // Act
        final result = sut.computeDisplayMessages(history, runState);

        // Assert
        expect(result.messages, equals(history));
        expect(result.hasSyntheticMessage, isFalse);
      });

      test('creates synthetic message for pre-text thinking', () {
        // Arrange
        final history = <ChatMessage>[];
        const runState = RunningState(
          conversation: Conversation(
            threadId: 'thread-1',
            status: Running(runId: 'run-1'),
          ),
          streaming: AwaitingText(
            bufferedThinkingText: 'Thinking before response...',
          ),
        );

        // Act
        final result = sut.computeDisplayMessages(history, runState);

        // Assert
        expect(result.hasSyntheticMessage, isTrue);
        expect(result.messages.length, equals(1));
        final message = result.messages.first as TextMessage;
        expect(message.text, isEmpty);
        expect(
          message.thinkingText,
          equals('Thinking before response...'),
        );
      });

      test('synthetic pre-text thinking message is from assistant', () {
        // Arrange
        final history = <ChatMessage>[];
        const runState = RunningState(
          conversation: Conversation(
            threadId: 'thread-1',
            status: Running(runId: 'run-1'),
          ),
          streaming: AwaitingText(
            bufferedThinkingText: 'Thinking...',
          ),
        );

        // Act
        final result = sut.computeDisplayMessages(history, runState);

        // Assert
        expect(result.messages.first.user, equals(ChatUser.assistant));
      });

      test('sets isThinkingStreaming when thinking is active', () {
        // Arrange
        final history = <ChatMessage>[];
        const runState = RunningState(
          conversation: Conversation(
            threadId: 'thread-1',
            status: Running(runId: 'run-1'),
          ),
          streaming: AwaitingText(isThinkingStreaming: true),
        );

        // Act
        final result = sut.computeDisplayMessages(history, runState);

        // Assert
        expect(result.hasSyntheticMessage, isTrue);
        expect(result.isThinkingStreaming, isTrue);
      });
    });

    group('when running with TextStreaming', () {
      test('appends synthetic message with streaming text', () {
        // Arrange
        final history = [
          TestData.createMessage(id: 'msg-1', text: 'User message'),
        ];
        const runState = RunningState(
          conversation: Conversation(
            threadId: 'thread-1',
            status: Running(runId: 'run-1'),
          ),
          streaming: TextStreaming(
            messageId: 'msg-2',
            user: ChatUser.assistant,
            text: 'Hello, I am streaming...',
          ),
        );

        // Act
        final result = sut.computeDisplayMessages(history, runState);

        // Assert
        expect(result.messages.length, equals(2));
        expect(result.hasSyntheticMessage, isTrue);

        final syntheticMessage = result.messages.last;
        expect(syntheticMessage, isA<TextMessage>());
        expect(syntheticMessage.id, equals('msg-2'));
        expect(
          (syntheticMessage as TextMessage).text,
          'Hello, I am streaming...',
        );
        expect(syntheticMessage.user, equals(ChatUser.assistant));
      });

      test('appends synthetic after all historical messages', () {
        // Arrange: Multiple historical messages
        final history = [
          TestData.createMessage(id: 'msg-1', text: 'First message'),
          TestData.createMessage(id: 'msg-2', text: 'Second message'),
        ];
        const runState = RunningState(
          conversation: Conversation(
            threadId: 'thread-1',
            status: Running(runId: 'run-1'),
          ),
          streaming: TextStreaming(
            messageId: 'msg-3',
            user: ChatUser.assistant,
            text: 'Streaming response...',
          ),
        );

        // Act
        final result = sut.computeDisplayMessages(history, runState);

        // Assert: All history preserved, synthetic appended at end
        expect(result.messages.length, equals(3));
        expect(result.hasSyntheticMessage, isTrue);

        expect(result.messages[0].id, equals('msg-1'));
        expect(result.messages[1].id, equals('msg-2'));

        final syntheticMessage = result.messages[2] as TextMessage;
        expect(syntheticMessage.id, equals('msg-3'));
        expect(syntheticMessage.text, equals('Streaming response...'));
      });

      test('handles empty streaming text', () {
        // Arrange: Streaming just started, no text yet
        final history = [
          TestData.createMessage(id: 'msg-1', text: 'User message'),
        ];
        const runState = RunningState(
          conversation: Conversation(
            threadId: 'thread-1',
            status: Running(runId: 'run-1'),
          ),
          streaming: TextStreaming(
            messageId: 'msg-2',
            user: ChatUser.assistant,
            text: '',
          ),
        );

        // Act
        final result = sut.computeDisplayMessages(history, runState);

        // Assert: Still creates synthetic message even with empty text
        expect(result.messages.length, equals(2));
        expect(result.hasSyntheticMessage, isTrue);
        expect((result.messages.last as TextMessage).text, isEmpty);
      });

      test('handles empty history with streaming', () {
        // Arrange: No history, just streaming
        final history = <ChatMessage>[];
        const runState = RunningState(
          conversation: Conversation(
            threadId: 'thread-1',
            status: Running(runId: 'run-1'),
          ),
          streaming: TextStreaming(
            messageId: 'msg-1',
            user: ChatUser.assistant,
            text: 'First response...',
          ),
        );

        // Act
        final result = sut.computeDisplayMessages(history, runState);

        // Assert
        expect(result.messages.length, equals(1));
        expect(result.hasSyntheticMessage, isTrue);
        expect(result.messages.first.id, equals('msg-1'));
      });

      test('synthetic message includes thinkingText from TextStreaming', () {
        // Arrange
        final history = <ChatMessage>[];
        const runState = RunningState(
          conversation: Conversation(
            threadId: 'thread-1',
            status: Running(runId: 'run-1'),
          ),
          streaming: TextStreaming(
            messageId: 'msg-1',
            user: ChatUser.assistant,
            text: 'Response text',
            thinkingText: 'Thinking while responding',
          ),
        );

        // Act
        final result = sut.computeDisplayMessages(history, runState);

        // Assert
        final message = result.messages.first as TextMessage;
        expect(message.text, equals('Response text'));
        expect(message.thinkingText, equals('Thinking while responding'));
      });

      test('isThinkingStreaming defaults to false for TextStreaming', () {
        // Arrange
        final history = <ChatMessage>[];
        const runState = RunningState(
          conversation: Conversation(
            threadId: 'thread-1',
            status: Running(runId: 'run-1'),
          ),
          streaming: TextStreaming(
            messageId: 'msg-1',
            user: ChatUser.assistant,
            text: 'Response text',
          ),
        );

        // Act
        final result = sut.computeDisplayMessages(history, runState);

        // Assert
        expect(result.isThinkingStreaming, isFalse);
      });

      test('passes through isThinkingStreaming from TextStreaming', () {
        // Arrange
        final history = <ChatMessage>[];
        const runState = RunningState(
          conversation: Conversation(
            threadId: 'thread-1',
            status: Running(runId: 'run-1'),
          ),
          streaming: TextStreaming(
            messageId: 'msg-1',
            user: ChatUser.assistant,
            text: '',
            isThinkingStreaming: true,
          ),
        );

        // Act
        final result = sut.computeDisplayMessages(history, runState);

        // Assert
        expect(result.isThinkingStreaming, isTrue);
      });
    });
  });

  group('computeSpacerHeight', () {
    test('returns 0 when not streaming and last message is from assistant', () {
      expect(
        sut.computeSpacerHeight(
          isStreaming: false,
          lastMessageUser: ChatUser.assistant,
          viewportHeight: 600,
          targetScrollOffset: null,
          maxScrollExtent: null,
          viewportDimension: null,
          currentSpacerHeight: 0,
        ),
        equals(0),
      );
    });

    test('returns viewportHeight when last message is from user', () {
      expect(
        sut.computeSpacerHeight(
          isStreaming: false,
          lastMessageUser: ChatUser.user,
          viewportHeight: 600,
          targetScrollOffset: null,
          maxScrollExtent: null,
          viewportDimension: null,
          currentSpacerHeight: 0,
        ),
        equals(600),
      );
    });

    test('returns viewportHeight when streaming without target offset', () {
      expect(
        sut.computeSpacerHeight(
          isStreaming: true,
          lastMessageUser: ChatUser.assistant,
          viewportHeight: 600,
          targetScrollOffset: null,
          maxScrollExtent: null,
          viewportDimension: null,
          currentSpacerHeight: 0,
        ),
        equals(600),
      );
    });

    test('shrinks as content grows below the target offset', () {
      // realContent = maxScrollExtent + viewportDimension - currentSpacer
      //             = 800 + 600 - 200 = 1200
      // spacer = targetOffset + viewportHeight - realContent
      //        = 100 + 600 - 1200 = -500 → clamped to 0
      final result = sut.computeSpacerHeight(
        isStreaming: true,
        lastMessageUser: ChatUser.user,
        viewportHeight: 600,
        targetScrollOffset: 100,
        maxScrollExtent: 800,
        viewportDimension: 600,
        currentSpacerHeight: 200,
      );
      expect(result, equals(0));
    });

    test('returns 0 when lastMessageUser is null and not streaming', () {
      expect(
        sut.computeSpacerHeight(
          isStreaming: false,
          lastMessageUser: null,
          viewportHeight: 600,
          targetScrollOffset: null,
          maxScrollExtent: null,
          viewportDimension: null,
          currentSpacerHeight: 0,
        ),
        equals(0),
      );
    });

    test(
        'returns viewportHeight when targetScrollOffset set but no scroll '
        'metrics', () {
      expect(
        sut.computeSpacerHeight(
          isStreaming: true,
          lastMessageUser: ChatUser.user,
          viewportHeight: 600,
          targetScrollOffset: 100,
          maxScrollExtent: null,
          viewportDimension: null,
          currentSpacerHeight: 0,
        ),
        equals(600),
      );
    });

    test('clamps to 0 when content fills the viewport', () {
      expect(
        sut.computeSpacerHeight(
          isStreaming: true,
          lastMessageUser: ChatUser.user,
          viewportHeight: 600,
          targetScrollOffset: 100,
          maxScrollExtent: 1000,
          viewportDimension: 600,
          currentSpacerHeight: 0,
        ),
        equals(0),
      );
    });

    test('clamps to viewportHeight maximum', () {
      // When content is very small, spacer should not exceed viewportHeight.
      expect(
        sut.computeSpacerHeight(
          isStreaming: true,
          lastMessageUser: ChatUser.user,
          viewportHeight: 600,
          targetScrollOffset: 100,
          maxScrollExtent: 100,
          viewportDimension: 600,
          currentSpacerHeight: 600,
        ),
        equals(600),
      );
    });

    test('computes partial spacer when content partially fills viewport', () {
      // realContent = maxScrollExtent + viewportDimension - currentSpacer
      //             = 200 + 600 - 200 = 600
      // spacer = targetOffset + viewportHeight - realContent
      //        = 100 + 600 - 600 = 100
      expect(
        sut.computeSpacerHeight(
          isStreaming: true,
          lastMessageUser: ChatUser.user,
          viewportHeight: 600,
          targetScrollOffset: 100,
          maxScrollExtent: 200,
          viewportDimension: 600,
          currentSpacerHeight: 200,
        ),
        equals(100),
      );
    });

    test(
      'returns viewportHeight when targetScrollOffset set but '
      'viewportDimension is null',
      () {
        expect(
          sut.computeSpacerHeight(
            isStreaming: true,
            lastMessageUser: ChatUser.user,
            viewportHeight: 600,
            targetScrollOffset: 100,
            maxScrollExtent: 500,
            viewportDimension: null,
            currentSpacerHeight: 0,
          ),
          equals(600),
        );
      },
    );
  });
}
