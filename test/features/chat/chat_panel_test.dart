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
import 'package:soliplex_frontend/core/providers/rooms_provider.dart';
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
            onNavigate?.call('/rooms/${state.pathParameters['roomId']}?thread='
                '$threadId');
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

        // Assert
        expect(find.text('Streaming response...'), findsOneWidget);
        expect(find.text('Cancel'), findsOneWidget);
      });

      testWidgets('does not show cancel button when idle', (tester) async {
        // Arrange
        await tester.pumpWidget(
          createTestApp(
            home: const Scaffold(body: ChatPanel()),
            overrides: [activeRunNotifierOverride(const IdleState())],
          ),
        );

        // Assert
        expect(find.text('Streaming response...'), findsNothing);
        expect(find.text('Cancel'), findsNothing);
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

        // Tap cancel button
        await tester.tap(find.text('Cancel'));
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
        when(() => mockApi.createThread('test-room'))
            .thenAnswer((_) async => newThread);

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

      testWidgets('creates thread when no current thread exists',
          (tester) async {
        // Arrange
        SharedPreferences.setMockInitialValues({});
        final mockRoom = TestData.createRoom();
        final newThread = TestData.createThread(id: 'created-thread');

        final mockApi = _TrackingSoliplexApi(threadToCreate: newThread);
        when(() => mockApi.createThread('test-room'))
            .thenAnswer((_) async => newThread);

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
              threadsProvider('test-room')
                  .overrideWith((ref) async => [existingThread]),
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
  });
}
