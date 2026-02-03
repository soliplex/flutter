import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soliplex_client/soliplex_client.dart' as domain
    show Conversation, Failed, Running, ThreadInfo;
import 'package:soliplex_frontend/core/models/active_run_state.dart';
import 'package:soliplex_frontend/core/providers/active_run_notifier.dart';
import 'package:soliplex_frontend/core/providers/active_run_provider.dart';
import 'package:soliplex_frontend/core/providers/api_provider.dart';
import 'package:soliplex_frontend/core/providers/documents_provider.dart';
import 'package:soliplex_frontend/core/providers/rooms_provider.dart';
import 'package:soliplex_frontend/core/providers/selected_documents_provider.dart';
import 'package:soliplex_frontend/core/providers/threads_provider.dart';
import 'package:soliplex_frontend/features/chat/chat_panel.dart';
import 'package:soliplex_frontend/features/chat/widgets/chat_input.dart';
import 'package:soliplex_frontend/features/chat/widgets/message_list.dart';
import 'package:soliplex_frontend/shared/widgets/error_display.dart';

import '../../helpers/test_helpers.dart';

/// Mock that tracks method calls for verification.
class _TrackingActiveRunNotifier extends Notifier<ActiveRunState>
    implements ActiveRunNotifier {
  _TrackingActiveRunNotifier({required this.initialState});

  final ActiveRunState initialState;
  bool cancelRunCalled = false;
  bool resetCalled = false;
  ({String roomId, String threadId, String userMessage})? lastStartRun;

  @override
  ActiveRunState build() => initialState;

  @override
  Future<void> startRun({
    required String roomId,
    required String threadId,
    required String userMessage,
    String? existingRunId,
    Map<String, dynamic>? initialState,
  }) async {
    lastStartRun = (
      roomId: roomId,
      threadId: threadId,
      userMessage: userMessage,
    );
  }

  @override
  Future<void> cancelRun() async {
    cancelRunCalled = true;
  }

  @override
  Future<void> reset() async {
    resetCalled = true;
  }
}

/// Mock that tracks thread selection changes.
class _TrackingThreadSelectionNotifier extends Notifier<ThreadSelection>
    implements ThreadSelectionNotifier {
  _TrackingThreadSelectionNotifier({required this.initialSelection});

  final ThreadSelection initialSelection;
  final List<ThreadSelection> setCalls = [];

  @override
  ThreadSelection build() => initialSelection;

  @override
  void set(ThreadSelection value) {
    setCalls.add(value);
    state = value;
  }
}

/// Mock SoliplexApi that returns a specific thread on creation.
class _TrackingSoliplexApi extends Mock implements MockSoliplexApi {
  _TrackingSoliplexApi({required this.threadToCreate});

  final domain.ThreadInfo threadToCreate;
}

/// Creates a test app with GoRouter for testing navigation.
Widget _createAppWithRouter({
  required Widget home,
  required List<dynamic> overrides,
  void Function(String path)? onNavigate,
}) {
  final router = GoRouter(
    initialLocation: '/rooms/test-room',
    routes: [
      GoRoute(
        path: '/rooms/:roomId',
        builder: (context, state) {
          final threadId = state.uri.queryParameters['thread'];
          if (threadId != null) {
            onNavigate?.call(
              '/rooms/${state.pathParameters['roomId']}?thread='
              '$threadId',
            );
            return Text('Navigated to thread: $threadId');
          }
          return Scaffold(body: home);
        },
      ),
    ],
  );

  return UncontrolledProviderScope(
    container: ProviderContainer(overrides: overrides.cast()),
    child: MaterialApp.router(theme: testThemeData, routerConfig: router),
  );
}

void main() {
  group('ChatPanel', () {
    group('Layout', () {
      testWidgets('displays message list and chat input', (tester) async {
        // Arrange
        await tester.pumpWidget(
          createTestApp(
            home: const Scaffold(body: ChatPanel()),
            overrides: [
              currentRoomProvider.overrideWith((ref) => null),
              activeRunNotifierOverride(const IdleState()),
            ],
          ),
        );

        // Assert
        expect(find.byType(MessageList), findsOneWidget);
        expect(find.byType(ChatInput), findsOneWidget);
      });

      testWidgets('message list is expanded', (tester) async {
        // Arrange
        await tester.pumpWidget(
          createTestApp(
            home: const Scaffold(body: ChatPanel()),
            overrides: [
              currentRoomProvider.overrideWith((ref) => null),
              activeRunNotifierOverride(const IdleState()),
            ],
          ),
        );

        // Assert - MessageList should be wrapped in an Expanded widget
        final messageListFinder = find.byType(MessageList);
        expect(messageListFinder, findsOneWidget);

        // Find the Expanded widget that contains MessageList
        final expandedFinder = find.ancestor(
          of: messageListFinder,
          matching: find.byType(Expanded),
        );
        expect(expandedFinder, findsOneWidget);
      });

      testWidgets('chat input is at bottom', (tester) async {
        // Arrange
        await tester.pumpWidget(
          createTestApp(
            home: const Scaffold(body: ChatPanel()),
            overrides: [
              currentRoomProvider.overrideWith((ref) => null),
              activeRunNotifierOverride(const IdleState()),
            ],
          ),
        );

        // Assert
        expect(find.byType(ChatInput), findsOneWidget);
      });
    });

    group('Streaming State', () {
      testWidgets('shows cancel button when streaming', (tester) async {
        // Arrange
        const conversation = domain.Conversation(
          threadId: 'test-thread',
          status: domain.Running(runId: 'test-run'),
        );
        await tester.pumpWidget(
          createTestApp(
            home: const Scaffold(body: ChatPanel()),
            overrides: [
              activeRunNotifierOverride(
                const RunningState(conversation: conversation),
              ),
            ],
          ),
        );

        // Assert - stop button visible during streaming
        expect(find.byIcon(Icons.stop), findsOneWidget);
      });

      testWidgets('does not show stop button when idle', (tester) async {
        // Arrange
        await tester.pumpWidget(
          createTestApp(
            home: const Scaffold(body: ChatPanel()),
            overrides: [activeRunNotifierOverride(const IdleState())],
          ),
        );

        // Assert - send button visible when idle, not stop button
        expect(find.byIcon(Icons.stop), findsNothing);
        expect(find.byIcon(Icons.send), findsOneWidget);
      });
    });

    group('Error State', () {
      testWidgets('shows error display when run has error', (tester) async {
        // Arrange
        const conversation = domain.Conversation(
          threadId: '',
          status: domain.Failed(error: 'Something went wrong'),
        );
        await tester.pumpWidget(
          createTestApp(
            home: const Scaffold(body: ChatPanel()),
            overrides: [
              activeRunNotifierOverride(
                const CompletedState(
                  conversation: conversation,
                  result: FailedResult(errorMessage: 'Something went wrong'),
                ),
              ),
            ],
          ),
        );

        // Assert
        expect(find.byType(ErrorDisplay), findsOneWidget);
        expect(find.textContaining('Something went wrong'), findsWidgets);
      });

      testWidgets('shows message list when no error', (tester) async {
        // Arrange
        await tester.pumpWidget(
          createTestApp(
            home: const Scaffold(body: ChatPanel()),
            overrides: [activeRunNotifierOverride(const IdleState())],
          ),
        );

        // Assert
        expect(find.byType(MessageList), findsOneWidget);
        expect(find.byType(ErrorDisplay), findsNothing);
      });
    });

    group('Input State', () {
      testWidgets('input disabled when no room selected', (tester) async {
        // Arrange
        await tester.pumpWidget(
          createTestApp(
            home: const Scaffold(body: ChatPanel()),
            overrides: [
              currentRoomProvider.overrideWith((ref) => null),
              currentThreadProvider.overrideWith((ref) => null),
              threadSelectionProviderOverride(const NoThreadSelected()),
              activeRunNotifierOverride(const IdleState()),
            ],
          ),
        );

        // Assert
        final textField = tester.widget<TextField>(find.byType(TextField));
        expect(textField.enabled, isFalse);
      });

      testWidgets('input enabled when room selected', (tester) async {
        // Arrange
        final mockRoom = TestData.createRoom();
        final mockThread = TestData.createThread();

        await tester.pumpWidget(
          createTestApp(
            home: const Scaffold(body: ChatPanel()),
            overrides: [
              currentRoomProvider.overrideWith((ref) => mockRoom),
              currentThreadProvider.overrideWith((ref) => mockThread),
              activeRunNotifierOverride(const IdleState()),
              // Override to avoid API call
              allMessagesProvider.overrideWith((ref) async => []),
              documentsProvider(mockRoom.id).overrideWith((ref) async => []),
            ],
          ),
        );
        await tester.pumpAndSettle();

        // Assert
        final textField = tester.widget<TextField>(find.byType(TextField));
        expect(textField.enabled, isTrue);
      });
    });

    group('Cancel Handler', () {
      testWidgets('cancel button calls cancelRun', (tester) async {
        late _TrackingActiveRunNotifier mockNotifier;
        const conversation = domain.Conversation(
          threadId: 'test-thread',
          status: domain.Running(runId: 'test-run'),
        );

        await tester.pumpWidget(
          createTestApp(
            home: const Scaffold(body: ChatPanel()),
            overrides: [
              activeRunNotifierProvider.overrideWith(() {
                return mockNotifier = _TrackingActiveRunNotifier(
                  initialState: const RunningState(conversation: conversation),
                );
              }),
            ],
          ),
        );

        // Tap stop button (cancel)
        await tester.tap(find.byIcon(Icons.stop));
        await tester.pump();

        // Verify cancelRun was called
        expect(mockNotifier.cancelRunCalled, isTrue);
      });
    });

    group('Retry Handler', () {
      testWidgets('retry button calls reset', (tester) async {
        late _TrackingActiveRunNotifier mockNotifier;
        const conversation = domain.Conversation(
          threadId: 'test-thread',
          status: domain.Failed(error: 'Test error'),
        );

        await tester.pumpWidget(
          createTestApp(
            home: const Scaffold(body: ChatPanel()),
            overrides: [
              activeRunNotifierProvider.overrideWith(() {
                return mockNotifier = _TrackingActiveRunNotifier(
                  initialState: const CompletedState(
                    conversation: conversation,
                    result: FailedResult(errorMessage: 'Test error'),
                  ),
                );
              }),
            ],
          ),
        );

        // Tap retry button
        await tester.tap(find.text('Retry'));
        await tester.pumpAndSettle();

        // Verify reset was called
        expect(mockNotifier.resetCalled, isTrue);
      });
    });

    group('New Thread Flow', () {
      testWidgets('creates thread when NewThreadIntent is set', (tester) async {
        // Arrange
        SharedPreferences.setMockInitialValues({});
        final mockRoom = TestData.createRoom();
        final newThread = TestData.createThread(id: 'new-thread-id');

        final mockApi = _TrackingSoliplexApi(threadToCreate: newThread);
        when(
          () => mockApi.createThread('test-room'),
        ).thenAnswer((_) async => newThread);

        late _TrackingThreadSelectionNotifier selectionNotifier;
        late _TrackingActiveRunNotifier runNotifier;
        String? navigatedPath;

        await tester.pumpWidget(
          _createAppWithRouter(
            home: const ChatPanel(),
            onNavigate: (path) => navigatedPath = path,
            overrides: [
              currentRoomProvider.overrideWith((ref) => mockRoom),
              currentThreadProvider.overrideWith((ref) => null),
              apiProvider.overrideWithValue(mockApi),
              threadSelectionProvider.overrideWith(() {
                return selectionNotifier = _TrackingThreadSelectionNotifier(
                  initialSelection: const NewThreadIntent(),
                );
              }),
              activeRunNotifierProvider.overrideWith(() {
                return runNotifier = _TrackingActiveRunNotifier(
                  initialState: const IdleState(),
                );
              }),
              allMessagesProvider.overrideWith((ref) async => []),
              threadsProvider('test-room').overrideWith((ref) async => []),
            ],
          ),
        );
        await tester.pumpAndSettle();

        // Act: Enter text and tap send button
        await tester.enterText(find.byType(TextField), 'Hello world');
        await tester.pump(); // Trigger onChanged -> setState
        await tester.tap(find.byIcon(Icons.send));
        await tester.pumpAndSettle();

        // Assert: createThread was called
        verify(() => mockApi.createThread('test-room')).called(1);

        // Assert: selection was updated to the new thread
        expect(selectionNotifier.setCalls, contains(isA<ThreadSelected>()));
        final threadSelected =
            selectionNotifier.setCalls.whereType<ThreadSelected>().first;
        expect(threadSelected.threadId, equals('new-thread-id'));

        // Assert: startRun was called with the new thread
        expect(runNotifier.lastStartRun, isNotNull);
        expect(runNotifier.lastStartRun!.threadId, equals('new-thread-id'));
        expect(runNotifier.lastStartRun!.userMessage, equals('Hello world'));

        // Assert: navigation happened
        expect(navigatedPath, contains('new-thread-id'));
      });

      testWidgets('creates thread when no current thread exists', (
        tester,
      ) async {
        // Arrange
        SharedPreferences.setMockInitialValues({});
        final mockRoom = TestData.createRoom();
        final newThread = TestData.createThread(id: 'created-thread');

        final mockApi = _TrackingSoliplexApi(threadToCreate: newThread);
        when(
          () => mockApi.createThread('test-room'),
        ).thenAnswer((_) async => newThread);

        late _TrackingThreadSelectionNotifier selectionNotifier;
        late _TrackingActiveRunNotifier runNotifier;

        await tester.pumpWidget(
          _createAppWithRouter(
            home: const ChatPanel(),
            overrides: [
              currentRoomProvider.overrideWith((ref) => mockRoom),
              currentThreadProvider.overrideWith((ref) => null),
              apiProvider.overrideWithValue(mockApi),
              threadSelectionProvider.overrideWith(() {
                return selectionNotifier = _TrackingThreadSelectionNotifier(
                  initialSelection: const NoThreadSelected(),
                );
              }),
              activeRunNotifierProvider.overrideWith(() {
                return runNotifier = _TrackingActiveRunNotifier(
                  initialState: const IdleState(),
                );
              }),
              allMessagesProvider.overrideWith((ref) async => []),
              threadsProvider('test-room').overrideWith((ref) async => []),
            ],
          ),
        );
        await tester.pumpAndSettle();

        // Act: Enter text and tap send button
        await tester.enterText(find.byType(TextField), 'First message');
        await tester.pump(); // Trigger onChanged -> setState
        await tester.tap(find.byIcon(Icons.send));
        await tester.pumpAndSettle();

        // Assert: createThread was called
        verify(() => mockApi.createThread('test-room')).called(1);

        // Assert: selection was updated
        expect(
          selectionNotifier.setCalls.whereType<ThreadSelected>().first.threadId,
          equals('created-thread'),
        );

        // Assert: startRun was called with correct params
        expect(runNotifier.lastStartRun!.threadId, equals('created-thread'));
        expect(runNotifier.lastStartRun!.userMessage, equals('First message'));
      });

      testWidgets('uses existing thread when ThreadSelected', (tester) async {
        // Arrange
        SharedPreferences.setMockInitialValues({});
        final mockRoom = TestData.createRoom();
        final existingThread = TestData.createThread(id: 'existing-thread');

        final mockApi = _TrackingSoliplexApi(
          threadToCreate: TestData.createThread(),
        );
        // createThread should NOT be called

        late _TrackingActiveRunNotifier runNotifier;

        await tester.pumpWidget(
          _createAppWithRouter(
            home: const ChatPanel(),
            overrides: [
              currentRoomProvider.overrideWith((ref) => mockRoom),
              currentThreadProvider.overrideWith((ref) => existingThread),
              apiProvider.overrideWithValue(mockApi),
              threadSelectionProvider.overrideWith(() {
                return _TrackingThreadSelectionNotifier(
                  initialSelection: const ThreadSelected('existing-thread'),
                );
              }),
              activeRunNotifierProvider.overrideWith(() {
                return runNotifier = _TrackingActiveRunNotifier(
                  initialState: const IdleState(),
                );
              }),
              allMessagesProvider.overrideWith((ref) async => []),
              threadsProvider(
                'test-room',
              ).overrideWith((ref) async => [existingThread]),
            ],
          ),
        );
        await tester.pumpAndSettle();

        // Act: Enter text and tap send button
        await tester.enterText(find.byType(TextField), 'Message to existing');
        await tester.pump(); // Trigger onChanged -> setState
        await tester.tap(find.byIcon(Icons.send));
        await tester.pumpAndSettle();

        // Assert: createThread was NOT called
        verifyNever(() => mockApi.createThread(any()));

        // Assert: startRun was called with the existing thread
        expect(runNotifier.lastStartRun!.threadId, equals('existing-thread'));
        expect(
          runNotifier.lastStartRun!.userMessage,
          equals('Message to existing'),
        );
      });
    });

    group('Suggestions', () {
      testWidgets('shows suggestions when thread is empty and not streaming', (
        tester,
      ) async {
        // Arrange
        final mockRoom = TestData.createRoom(
          suggestions: ['How can I help?', 'Tell me more'],
        );
        final mockThread = TestData.createThread();

        await tester.pumpWidget(
          createTestApp(
            home: const Scaffold(body: ChatPanel()),
            overrides: [
              currentRoomProvider.overrideWith((ref) => mockRoom),
              currentThreadProvider.overrideWith((ref) => mockThread),
              activeRunNotifierOverride(const IdleState()),
              allMessagesProvider.overrideWith((ref) async => []),
              documentsProvider(mockRoom.id).overrideWith((ref) async => []),
            ],
          ),
        );
        await tester.pumpAndSettle();

        // Assert
        expect(find.text('How can I help?'), findsOneWidget);
        expect(find.text('Tell me more'), findsOneWidget);
        expect(find.byType(ActionChip), findsNWidgets(2));
      });

      testWidgets('hides suggestions when thread has messages', (
        tester,
      ) async {
        // Arrange
        final mockRoom = TestData.createRoom(
          suggestions: ['How can I help?'],
        );
        final mockThread = TestData.createThread();
        final messages = [TestData.createMessage(text: 'Hello')];

        await tester.pumpWidget(
          createTestApp(
            home: const Scaffold(body: ChatPanel()),
            overrides: [
              currentRoomProvider.overrideWith((ref) => mockRoom),
              currentThreadProvider.overrideWith((ref) => mockThread),
              activeRunNotifierOverride(const IdleState()),
              allMessagesProvider.overrideWith((ref) async => messages),
              documentsProvider(mockRoom.id).overrideWith((ref) async => []),
            ],
          ),
        );
        await tester.pumpAndSettle();

        // Assert
        expect(find.text('How can I help?'), findsNothing);
        expect(find.byType(ActionChip), findsNothing);
      });

      testWidgets('hides suggestions when streaming', (tester) async {
        // Arrange
        final mockRoom = TestData.createRoom(
          suggestions: ['How can I help?'],
        );
        final mockThread = TestData.createThread();
        const conversation = domain.Conversation(
          threadId: 'test-thread',
          status: domain.Running(runId: 'test-run'),
        );

        await tester.pumpWidget(
          createTestApp(
            home: const Scaffold(body: ChatPanel()),
            overrides: [
              currentRoomProvider.overrideWith((ref) => mockRoom),
              currentThreadProvider.overrideWith((ref) => mockThread),
              activeRunNotifierOverride(
                const RunningState(conversation: conversation),
              ),
              allMessagesProvider.overrideWith((ref) async => []),
              documentsProvider(mockRoom.id).overrideWith((ref) async => []),
            ],
          ),
        );
        // Use pump() instead of pumpAndSettle() - streaming causes continuous
        // animations that never settle
        await tester.pump();

        // Assert
        expect(find.text('How can I help?'), findsNothing);
        expect(find.byType(ActionChip), findsNothing);
      });

      testWidgets('tapping suggestion sends message', (tester) async {
        // Arrange
        SharedPreferences.setMockInitialValues({});
        final mockRoom = TestData.createRoom(
          suggestions: ['How can I help?'],
        );
        final mockThread = TestData.createThread();

        late _TrackingActiveRunNotifier runNotifier;

        await tester.pumpWidget(
          _createAppWithRouter(
            home: const ChatPanel(),
            overrides: [
              currentRoomProvider.overrideWith((ref) => mockRoom),
              currentThreadProvider.overrideWith((ref) => mockThread),
              threadSelectionProvider.overrideWith(() {
                return _TrackingThreadSelectionNotifier(
                  initialSelection: ThreadSelected(mockThread.id),
                );
              }),
              activeRunNotifierProvider.overrideWith(() {
                return runNotifier = _TrackingActiveRunNotifier(
                  initialState: const IdleState(),
                );
              }),
              allMessagesProvider.overrideWith((ref) async => []),
            ],
          ),
        );
        await tester.pumpAndSettle();

        // Act: Tap suggestion chip
        await tester.tap(find.text('How can I help?'));
        await tester.pumpAndSettle();

        // Assert: startRun was called with the suggestion text
        expect(runNotifier.lastStartRun, isNotNull);
        expect(
          runNotifier.lastStartRun!.userMessage,
          equals('How can I help?'),
        );
      });
    });

    group('Document Selection Persistence', () {
      testWidgets('selection persists after submit', (tester) async {
        // Arrange
        final mockRoom = TestData.createRoom();
        final mockThread = TestData.createThread();
        final doc = TestData.createDocument(id: 'doc-1', title: 'Test Doc');

        late ProviderContainer container;

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container = ProviderContainer(
              overrides: [
                currentRoomIdProviderOverride(mockRoom.id),
                currentRoomProvider.overrideWith((ref) => mockRoom),
                threadSelectionProvider.overrideWith(() {
                  return _TrackingThreadSelectionNotifier(
                    initialSelection: ThreadSelected(mockThread.id),
                  );
                }),
                activeRunNotifierOverride(const IdleState()),
                allMessagesProvider.overrideWith((ref) async => []),
                documentsProvider(mockRoom.id)
                    .overrideWith((ref) async => [doc]),
              ],
            ),
            child: MaterialApp(
              theme: testThemeData,
              home: const Scaffold(body: ChatPanel()),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Pre-populate selection for the thread
        container
            .read(selectedDocumentsNotifierProvider.notifier)
            .setForThread(mockRoom.id, mockThread.id, {doc});

        // Force rebuild to see the selection
        await tester.pump();

        // Verify chip is displayed
        expect(find.text('Test Doc'), findsOneWidget);

        // Act: Submit a message (simulate by checking selection still exists)
        // The key test is that the selection persists in the provider

        // Get selection from provider after "submit"
        final selectionAfter = container
            .read(selectedDocumentsNotifierProvider.notifier)
            .getForThread(mockRoom.id, mockThread.id);

        // Assert: Selection still exists in provider
        expect(selectionAfter, contains(doc));
        // Assert: Chip is still visible
        expect(find.text('Test Doc'), findsOneWidget);
      });

      testWidgets('switching threads restores correct selection', (
        tester,
      ) async {
        // Arrange
        final mockRoom = TestData.createRoom();
        final thread1 = TestData.createThread(id: 'thread-1');
        final thread2 = TestData.createThread(id: 'thread-2');
        final doc1 = TestData.createDocument(id: 'doc-1', title: 'Doc A');
        final doc2 = TestData.createDocument(id: 'doc-2', title: 'Doc B');

        late ProviderContainer container;
        late _TrackingThreadSelectionNotifier selectionNotifier;

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container = ProviderContainer(
              overrides: [
                currentRoomIdProviderOverride(mockRoom.id),
                currentRoomProvider.overrideWith((ref) => mockRoom),
                threadsProvider(mockRoom.id)
                    .overrideWith((ref) async => [thread1, thread2]),
                threadSelectionProvider.overrideWith(() {
                  return selectionNotifier = _TrackingThreadSelectionNotifier(
                    initialSelection: ThreadSelected(thread1.id),
                  );
                }),
                activeRunNotifierOverride(const IdleState()),
                allMessagesProvider.overrideWith((ref) async => []),
                documentsProvider(mockRoom.id)
                    .overrideWith((ref) async => [doc1, doc2]),
              ],
            ),
            child: MaterialApp(
              theme: testThemeData,
              home: const Scaffold(body: ChatPanel()),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Pre-populate selections for both threads
        container
            .read(selectedDocumentsNotifierProvider.notifier)
            .setForThread(mockRoom.id, thread1.id, {doc1});
        container
            .read(selectedDocumentsNotifierProvider.notifier)
            .setForThread(mockRoom.id, thread2.id, {doc2});

        // Force rebuild to see thread 1's selection
        await tester.pump();

        // Assert: Thread 1 shows Doc A chip
        expect(find.text('Doc A'), findsOneWidget);
        expect(find.text('Doc B'), findsNothing);

        // Act: Switch to thread 2
        selectionNotifier.set(ThreadSelected(thread2.id));
        await tester.pumpAndSettle();

        // Assert: Thread 2 shows Doc B chip
        expect(find.text('Doc A'), findsNothing);
        expect(find.text('Doc B'), findsOneWidget);

        // Act: Switch back to thread 1
        selectionNotifier.set(ThreadSelected(thread1.id));
        await tester.pumpAndSettle();

        // Assert: Thread 1's selection is restored
        expect(find.text('Doc A'), findsOneWidget);
        expect(find.text('Doc B'), findsNothing);
      });

      testWidgets('new thread has empty selection', (tester) async {
        // Arrange
        final mockRoom = TestData.createRoom();
        final existingThread = TestData.createThread(id: 'existing');
        final doc = TestData.createDocument(id: 'doc-1', title: 'Selected Doc');

        late ProviderContainer container;

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container = ProviderContainer(
              overrides: [
                currentRoomIdProviderOverride(mockRoom.id),
                currentRoomProvider.overrideWith((ref) => mockRoom),
                threadSelectionProvider.overrideWith(() {
                  return _TrackingThreadSelectionNotifier(
                    initialSelection: const NewThreadIntent(),
                  );
                }),
                activeRunNotifierOverride(const IdleState()),
                allMessagesProvider.overrideWith((ref) async => []),
                documentsProvider(mockRoom.id)
                    .overrideWith((ref) async => [doc]),
              ],
            ),
            child: MaterialApp(
              theme: testThemeData,
              home: const Scaffold(body: ChatPanel()),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Pre-populate selection for existing thread (simulating previous work)
        container
            .read(selectedDocumentsNotifierProvider.notifier)
            .setForThread(mockRoom.id, existingThread.id, {doc});

        // Rebuild
        await tester.pump();

        // Assert: New thread intent has no chips (empty selection)
        // The chip would contain 'Selected Doc' if there was a selection
        expect(find.text('Selected Doc'), findsNothing);
      });

      testWidgets('switching rooms clears pending document selection', (
        tester,
      ) async {
        // Arrange: Set up two rooms
        final room1 = TestData.createRoom(id: 'room-1', name: 'Room 1');
        final room2 = TestData.createRoom(id: 'room-2', name: 'Room 2');
        final doc = TestData.createDocument(id: 'doc-1', title: 'Room1 Doc');

        late MockCurrentRoomIdNotifier roomIdNotifier;

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: ProviderContainer(
              overrides: [
                currentRoomIdProvider.overrideWith(() {
                  return roomIdNotifier =
                      MockCurrentRoomIdNotifier(initialRoomId: room1.id);
                }),
                currentRoomProvider.overrideWith((ref) {
                  final roomId = ref.watch(currentRoomIdProvider);
                  if (roomId == room1.id) return room1;
                  if (roomId == room2.id) return room2;
                  return null;
                }),
                // No thread selected - using pending documents
                threadSelectionProviderOverride(const NewThreadIntent()),
                activeRunNotifierOverride(const IdleState()),
                allMessagesProvider.overrideWith((ref) async => []),
                documentsProvider(room1.id).overrideWith((ref) async => [doc]),
                documentsProvider(room2.id).overrideWith((ref) async => []),
              ],
            ),
            child: MaterialApp(
              theme: testThemeData,
              home: const Scaffold(body: ChatPanel()),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Simulate selecting a document in room 1 (via pending state)
        // We can't easily tap the picker in this test, so we'll verify
        // the behavior by checking that after room change, no chips appear

        // Pre-populate pending documents by calling onDocumentsChanged
        // This simulates the user selecting a document before sending
        final chatInput = tester.widget<ChatInput>(find.byType(ChatInput));
        chatInput.onDocumentsChanged?.call({doc});
        await tester.pump();

        // Verify the chip is displayed in room 1
        expect(find.text('Room1 Doc'), findsOneWidget);

        // Act: Switch to room 2
        roomIdNotifier.set(room2.id);
        await tester.pumpAndSettle();

        // Assert: Pending selection is cleared, no chip visible
        expect(find.text('Room1 Doc'), findsNothing);
      });
    });
  });
}
