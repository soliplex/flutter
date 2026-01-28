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
    as sut show computeDisplayMessages;
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

      testWidgets('shows chat bubble icon in empty state', (tester) async {
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
        expect(find.byIcon(Icons.chat_bubble_outline), findsOneWidget);
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

      testWidgets('uses ListView.builder', (tester) async {
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
        expect(find.byType(ListView), findsOneWidget);
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

    group('Streaming Indicator', () {
      testWidgets('shows activity indicator when streaming', (tester) async {
        // Arrange
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
              allMessagesProvider.overrideWith(
                (ref) async => <domain.ChatMessage>[],
              ),
              activeRunNotifierOverride(
                const RunningState(conversation: conversation),
              ),
            ],
          ),
        );
        // Use pump() instead of pumpAndSettle() because
        // CircularProgressIndicator animation never settles.
        await tester.pump();
        await tester.pump();

        // Assert - One in loading state, one as streaming indicator
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.text('Assistant is thinking...'), findsOneWidget);
      });

      testWidgets('does not show indicator when not streaming', (tester) async {
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
        expect(find.text('Assistant is thinking...'), findsNothing);
      });

      testWidgets('shows indicator at bottom of list', (tester) async {
        // Arrange
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
        // Use pump() instead of pumpAndSettle() because
        // CircularProgressIndicator animation never settles.
        await tester.pump();
        await tester.pump();

        // Assert
        // Should have 2 messages + 1 indicator
        expect(find.byType(ChatMessageWidget), findsNWidgets(2));
        expect(find.text('Assistant is thinking...'), findsOneWidget);
      });
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
    });

    group('Scrolling', () {
      testWidgets('uses ScrollController', (tester) async {
        // Arrange
        final messages = [TestData.createMessage(text: 'Message 1')];

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
        final listView = tester.widget<ListView>(find.byType(ListView));
        expect(listView.controller, isNotNull);
      });

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

    group('Edge Cases', () {
      testWidgets('handles single message', (tester) async {
        // Arrange
        final messages = [TestData.createMessage(text: 'Only message')];

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
        expect(find.text('Only message'), findsOneWidget);
      });

      testWidgets('handles many messages', (tester) async {
        // Arrange
        final messages = List.generate(
          50,
          (index) =>
              TestData.createMessage(id: 'msg-$index', text: 'Message $index'),
        );

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

        // Assert - ListView should handle many items efficiently
        expect(find.byType(ListView), findsOneWidget);
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
      test('returns historical messages unchanged', () {
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
    });
  });
}
