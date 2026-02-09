import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soliplex_client/soliplex_client.dart';
import 'package:soliplex_frontend/core/models/active_run_state.dart';
import 'package:soliplex_frontend/core/providers/active_run_notifier.dart';
import 'package:soliplex_frontend/core/providers/active_run_provider.dart';
import 'package:soliplex_frontend/core/providers/api_provider.dart';
import 'package:soliplex_frontend/core/providers/rooms_provider.dart';
import 'package:soliplex_frontend/core/providers/selected_documents_provider.dart';
import 'package:soliplex_frontend/core/providers/shell_config_provider.dart';
import 'package:soliplex_frontend/core/providers/threads_provider.dart';
import 'package:soliplex_frontend/features/chat/chat_controller.dart';
import 'package:soliplex_frontend/features/chat/send_message.dart';
import 'package:soliplex_frontend/features/chat/send_message_provider.dart';

import '../../helpers/test_helpers.dart';

/// Fake SendMessage that records calls and returns configurable results.
class _FakeSendMessage implements SendMessage {
  SendMessageResult? resultToReturn;
  Object? exceptionToThrow;
  final List<
      ({
        String roomId,
        String text,
        Set<RagDocument> pendingDocuments,
        ThreadInfo? currentThread,
        bool isNewThreadIntent,
      })> calls = [];

  @override
  Future<SendMessageResult> call({
    required String roomId,
    required String text,
    required Set<RagDocument> pendingDocuments,
    ThreadInfo? currentThread,
    bool isNewThreadIntent = false,
  }) async {
    calls.add(
      (
        roomId: roomId,
        text: text,
        pendingDocuments: pendingDocuments,
        currentThread: currentThread,
        isNewThreadIntent: isNewThreadIntent,
      ),
    );
    final error = exceptionToThrow;
    if (error is Exception) throw error;
    if (error is Error) throw error;
    if (resultToReturn == null) {
      throw StateError(
        '_FakeSendMessage: set resultToReturn or '
        'exceptionToThrow before calling',
      );
    }
    return resultToReturn!;
  }
}

/// Tracking notifier for thread selection verification.
class _TrackingThreadSelectionNotifier extends Notifier<ThreadSelection>
    implements ThreadSelectionNotifier {
  _TrackingThreadSelectionNotifier({required this.initialSelection});

  final ThreadSelection initialSelection;

  @override
  ThreadSelection build() => initialSelection;

  @override
  void set(ThreadSelection value) => state = value;
}

/// Tracking notifier for active run verification.
class _TrackingActiveRunNotifier extends Notifier<ActiveRunState>
    implements ActiveRunNotifier {
  bool resetCalled = false;

  @override
  ActiveRunState build() => const IdleState();

  @override
  Future<void> startRun({
    required String roomId,
    required String threadId,
    required String userMessage,
    String? existingRunId,
    Map<String, dynamic>? initialState,
  }) async {}

  @override
  Future<void> cancelRun() async {}

  @override
  Future<void> reset() async {
    resetCalled = true;
  }
}

void main() {
  late _FakeSendMessage fakeSendMessage;
  late _TrackingThreadSelectionNotifier trackingThreadSelection;
  late _TrackingActiveRunNotifier trackingActiveRun;
  late MockSoliplexApi mockApi;

  setUp(() async {
    await initTestPrefs();
    fakeSendMessage = _FakeSendMessage();
    trackingThreadSelection = _TrackingThreadSelectionNotifier(
      initialSelection: const NoThreadSelected(),
    );
    trackingActiveRun = _TrackingActiveRunNotifier();
    mockApi = MockSoliplexApi();
  });

  /// Creates a [ProviderContainer] with standard test overrides.
  ///
  /// [room] controls currentRoomProvider. Null means no room selected.
  /// [thread] controls currentThreadProvider lookup.
  /// [threadSelection] overrides the initial thread selection state.
  ProviderContainer createContainer({
    Room? room,
    ThreadInfo? thread,
    ThreadSelection? threadSelection,
  }) {
    if (threadSelection != null) {
      trackingThreadSelection = _TrackingThreadSelectionNotifier(
        initialSelection: threadSelection,
      );
    }

    final container = ProviderContainer(
      overrides: [
        shellConfigProvider.overrideWithValue(testSoliplexConfig),
        sendMessageProvider.overrideWithValue(fakeSendMessage),
        apiProvider.overrideWithValue(mockApi),
        activeRunNotifierProvider.overrideWith(() => trackingActiveRun),
        threadSelectionProvider.overrideWith(
          () => trackingThreadSelection,
        ),
        currentRoomProvider.overrideWith((ref) => room),
        currentRoomIdProvider.overrideWith(
          () => MockCurrentRoomIdNotifier(initialRoomId: room?.id),
        ),
        currentThreadProvider.overrideWith((ref) => thread),
        currentThreadIdProvider.overrideWith((ref) => thread?.id),
        if (room != null)
          threadsProvider(room.id).overrideWith(
            (ref) async => thread != null ? [thread] : [],
          ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('ChatController', () {
    group('send()', () {
      test('calls SendMessage with existing thread', () async {
        final room = TestData.createRoom(id: 'room-1');
        final thread = TestData.createThread(id: 'thread-1', roomId: 'room-1');
        fakeSendMessage.resultToReturn = (
          threadId: 'thread-1',
          roomId: 'room-1',
          isNewThread: false,
        );

        final container = createContainer(
          room: room,
          thread: thread,
          threadSelection: const ThreadSelected('thread-1'),
        );

        final controller = container.read(chatControllerProvider.notifier);
        final result = await controller.send('Hello');

        expect(fakeSendMessage.calls, hasLength(1));
        expect(fakeSendMessage.calls.first.roomId, 'room-1');
        expect(fakeSendMessage.calls.first.text, 'Hello');
        expect(fakeSendMessage.calls.first.isNewThreadIntent, isFalse);
        expect(result, const MessageSent());
      });

      test('returns ThreadCreated for new thread', () async {
        final room = TestData.createRoom(id: 'room-1');
        fakeSendMessage.resultToReturn = (
          threadId: 'new-thread',
          roomId: 'room-1',
          isNewThread: true,
        );

        final container = createContainer(room: room);

        final controller = container.read(chatControllerProvider.notifier);
        final result = await controller.send('Hello');

        expect(
          result,
          const ThreadCreated(roomId: 'room-1', threadId: 'new-thread'),
        );
      });

      test('selects new thread after creation', () async {
        final room = TestData.createRoom(id: 'room-1');
        fakeSendMessage.resultToReturn = (
          threadId: 'new-thread',
          roomId: 'room-1',
          isNewThread: true,
        );

        final container = createContainer(room: room);

        final controller = container.read(chatControllerProvider.notifier);
        await controller.send('Hello');

        expect(
          container.read(threadSelectionProvider),
          const ThreadSelected('new-thread'),
        );
      });

      test('clears pending documents after new thread', () async {
        final room = TestData.createRoom(id: 'room-1');
        final doc = TestData.createDocument(id: 'doc-1');
        fakeSendMessage.resultToReturn = (
          threadId: 'new-thread',
          roomId: 'room-1',
          isNewThread: true,
        );

        final container = createContainer(room: room);

        final controller = container.read(chatControllerProvider.notifier)
          ..updateDocuments({doc});
        expect(container.read(chatControllerProvider), {doc});

        await controller.send('Hello');

        expect(container.read(chatControllerProvider), isEmpty);
      });

      test('passes NewThreadIntent to SendMessage', () async {
        final room = TestData.createRoom(id: 'room-1');
        final thread = TestData.createThread(id: 'thread-1', roomId: 'room-1');
        fakeSendMessage.resultToReturn = (
          threadId: 'new-thread',
          roomId: 'room-1',
          isNewThread: true,
        );

        final container = createContainer(
          room: room,
          thread: thread,
          threadSelection: const NewThreadIntent(),
        );

        final controller = container.read(chatControllerProvider.notifier);
        await controller.send('Hello');

        expect(fakeSendMessage.calls.first.isNewThreadIntent, isTrue);
      });

      test('returns SendFailed when no room selected', () async {
        final container = createContainer();

        final controller = container.read(chatControllerProvider.notifier);
        final result = await controller.send('Hello');

        expect(fakeSendMessage.calls, isEmpty);
        expect(result, const SendFailed('No room selected'));
      });

      test('returns SendFailed on NetworkException', () async {
        final room = TestData.createRoom(id: 'room-1');
        fakeSendMessage.exceptionToThrow = const NetworkException(
          message: 'timeout',
        );

        final container = createContainer(room: room);

        final controller = container.read(chatControllerProvider.notifier);
        final result = await controller.send('Hello');

        expect(result, const SendFailed('Network error: timeout'));
      });

      test('returns SendFailed on AuthException', () async {
        final room = TestData.createRoom(id: 'room-1');
        fakeSendMessage.exceptionToThrow = const AuthException(
          message: 'expired token',
        );

        final container = createContainer(room: room);

        final controller = container.read(chatControllerProvider.notifier);
        final result = await controller.send('Hello');

        expect(
          result,
          const SendFailed('Authentication error: expired token'),
        );
      });

      test('returns SendFailed on unexpected exception', () async {
        final room = TestData.createRoom(id: 'room-1');
        fakeSendMessage.exceptionToThrow = StateError('unexpected');

        final container = createContainer(room: room);

        final controller = container.read(chatControllerProvider.notifier);
        final result = await controller.send('Hello');

        expect(
          result,
          isA<SendFailed>().having(
            (f) => f.message,
            'message',
            contains('Failed to send message'),
          ),
        );
      });
    });

    group('retry()', () {
      test('resets the active run', () async {
        final container = createContainer(
          room: TestData.createRoom(id: 'room-1'),
        );

        final controller = container.read(chatControllerProvider.notifier);
        await controller.retry();

        expect(trackingActiveRun.resetCalled, isTrue);
      });
    });

    group('updateDocuments()', () {
      test('stores documents in state when no thread', () {
        final doc = TestData.createDocument(id: 'doc-1');
        final container = createContainer();

        container.read(chatControllerProvider.notifier).updateDocuments({doc});

        expect(container.read(chatControllerProvider), {doc});
      });

      test('delegates to selectedDocumentsNotifier when thread exists', () {
        final room = TestData.createRoom(id: 'room-1');
        final thread = TestData.createThread(id: 'thread-1', roomId: 'room-1');
        final doc = TestData.createDocument(id: 'doc-1');

        final container = createContainer(
          room: room,
          thread: thread,
          threadSelection: const ThreadSelected('thread-1'),
        );

        container.read(chatControllerProvider.notifier).updateDocuments({doc});

        // State should still be empty (pending docs unchanged)
        expect(container.read(chatControllerProvider), isEmpty);
        // The document should be in the selected documents notifier
        final stored = container
            .read(selectedDocumentsNotifierProvider.notifier)
            .getForThread('room-1', 'thread-1');
        expect(stored, {doc});
      });
    });

    group('room change listener', () {
      test('clears pending documents when room changes', () async {
        final doc = TestData.createDocument(id: 'doc-1');

        final container = createContainer(
          room: TestData.createRoom(id: 'room-1'),
        );

        container.read(chatControllerProvider.notifier).updateDocuments({doc});
        expect(container.read(chatControllerProvider), {doc});

        // Change room
        container.read(currentRoomIdProvider.notifier).set('room-2');

        // Allow listeners to fire
        await Future<void>.delayed(Duration.zero);

        expect(container.read(chatControllerProvider), isEmpty);
      });
    });
  });
}
