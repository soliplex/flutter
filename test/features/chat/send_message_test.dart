import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:soliplex_client/soliplex_client.dart';
import 'package:soliplex_frontend/core/document_selection.dart';
import 'package:soliplex_frontend/features/chat/send_message.dart';

import '../../helpers/test_helpers.dart';

/// In-memory fake implementing [DocumentSelection].
class _FakeDocumentSelection implements DocumentSelection {
  final Map<ThreadKey, Set<RagDocument>> _store = {};

  @override
  Set<RagDocument> getForThread(String roomId, String threadId) {
    return _store[(roomId: roomId, threadId: threadId)] ?? {};
  }

  @override
  void setForThread(
    String roomId,
    String threadId,
    Set<RagDocument> documents,
  ) {
    _store[(roomId: roomId, threadId: threadId)] = documents;
  }
}

/// Tracks all calls to the startRun function.
class _StartRunTracker {
  final List<
      ({
        String roomId,
        String threadId,
        String userMessage,
        String? existingRunId,
        Map<String, dynamic>? initialState,
      })> calls = [];

  Future<void> call({
    required String roomId,
    required String threadId,
    required String userMessage,
    String? existingRunId,
    Map<String, dynamic>? initialState,
  }) async {
    calls.add(
      (
        roomId: roomId,
        threadId: threadId,
        userMessage: userMessage,
        existingRunId: existingRunId,
        initialState: initialState,
      ),
    );
  }
}

void main() {
  late MockSoliplexApi mockApi;
  late _StartRunTracker startRunTracker;
  late _FakeDocumentSelection fakeDocSelection;
  late SendMessage sendMessage;

  setUp(() {
    mockApi = MockSoliplexApi();
    startRunTracker = _StartRunTracker();
    fakeDocSelection = _FakeDocumentSelection();
    sendMessage = SendMessage(
      api: mockApi,
      startRun: startRunTracker.call,
      documentSelection: fakeDocSelection,
    );
  });

  group('SendMessage', () {
    group('new thread creation', () {
      test('creates thread when currentThread is null', () async {
        final newThread = TestData.createThread(
          id: 'new-thread',
          roomId: 'room-1',
        );
        when(
          () => mockApi.createThread('room-1'),
        ).thenAnswer((_) async => newThread);

        final result = await sendMessage.call(
          roomId: 'room-1',
          text: 'Hello',
          pendingDocuments: {},
        );

        verify(() => mockApi.createThread('room-1')).called(1);
        expect(result.threadId, 'new-thread');
        expect(result.roomId, 'room-1');
        expect(result.isNewThread, isTrue);
      });

      test('creates thread when isNewThreadIntent is true', () async {
        final existingThread = TestData.createThread(
          id: 'existing',
          roomId: 'room-1',
        );
        final newThread = TestData.createThread(
          id: 'new-thread',
          roomId: 'room-1',
        );
        when(
          () => mockApi.createThread('room-1'),
        ).thenAnswer((_) async => newThread);

        final result = await sendMessage.call(
          roomId: 'room-1',
          text: 'Hello',
          pendingDocuments: {},
          currentThread: existingThread,
          isNewThreadIntent: true,
        );

        verify(() => mockApi.createThread('room-1')).called(1);
        expect(result.threadId, 'new-thread');
        expect(result.isNewThread, isTrue);
      });

      test('transfers pending documents to new thread', () async {
        final newThread = TestData.createThread(
          id: 'new-thread',
          roomId: 'room-1',
        );
        when(
          () => mockApi.createThread('room-1'),
        ).thenAnswer((_) async => newThread);

        final doc = TestData.createDocument(id: 'doc-1');
        await sendMessage.call(
          roomId: 'room-1',
          text: 'Hello',
          pendingDocuments: {doc},
        );

        final stored = fakeDocSelection.getForThread(
          'room-1',
          'new-thread',
        );
        expect(stored, contains(doc));
      });
    });

    group('existing thread', () {
      test('uses existing thread directly', () async {
        final existingThread = TestData.createThread(
          id: 'existing',
          roomId: 'room-1',
        );

        final result = await sendMessage.call(
          roomId: 'room-1',
          text: 'Hello',
          pendingDocuments: {},
          currentThread: existingThread,
        );

        verifyNever(() => mockApi.createThread(any()));
        expect(result.threadId, 'existing');
        expect(result.roomId, 'room-1');
        expect(result.isNewThread, isFalse);
      });
    });

    group('startRun invocation', () {
      test('calls startRun with new thread id and initial run id', () async {
        final newThread = TestData.createThread(
          id: 'new-thread',
          roomId: 'room-1',
        );
        when(
          () => mockApi.createThread('room-1'),
        ).thenAnswer((_) async => newThread);

        await sendMessage.call(
          roomId: 'room-1',
          text: 'Hello world',
          pendingDocuments: {},
        );

        expect(startRunTracker.calls, hasLength(1));
        final call = startRunTracker.calls.first;
        expect(call.roomId, 'room-1');
        expect(call.threadId, 'new-thread');
        expect(call.userMessage, 'Hello world');
        expect(call.existingRunId, newThread.initialRunId);
      });

      test('calls startRun with existing thread', () async {
        final existingThread = TestData.createThread(
          id: 'existing',
          roomId: 'room-1',
        );

        await sendMessage.call(
          roomId: 'room-1',
          text: 'Hi there',
          pendingDocuments: {},
          currentThread: existingThread,
        );

        expect(startRunTracker.calls, hasLength(1));
        final call = startRunTracker.calls.first;
        expect(call.roomId, 'room-1');
        expect(call.threadId, 'existing');
        expect(call.userMessage, 'Hi there');
        expect(call.existingRunId, existingThread.initialRunId);
      });
    });

    group('error propagation', () {
      test('propagates exception from createThread', () async {
        when(
          () => mockApi.createThread('room-1'),
        ).thenThrow(const NetworkException(message: 'timeout'));

        expect(
          () => sendMessage.call(
            roomId: 'room-1',
            text: 'Hello',
            pendingDocuments: {},
          ),
          throwsA(isA<NetworkException>()),
        );
      });

      test('propagates exception from startRun', () async {
        final existingThread = TestData.createThread(
          id: 'existing',
          roomId: 'room-1',
        );

        final failingStartRun = SendMessage(
          api: mockApi,
          startRun: ({
            required String roomId,
            required String threadId,
            required String userMessage,
            String? existingRunId,
            Map<String, dynamic>? initialState,
          }) async {
            throw StateError('run already active');
          },
          documentSelection: fakeDocSelection,
        );

        expect(
          () => failingStartRun.call(
            roomId: 'room-1',
            text: 'Hello',
            pendingDocuments: {},
            currentThread: existingThread,
          ),
          throwsA(isA<StateError>()),
        );
      });
    });

    group('document filter', () {
      test('passes filter_documents initial state when docs selected',
          () async {
        final existingThread = TestData.createThread(
          id: 'existing',
          roomId: 'room-1',
        );
        final doc = TestData.createDocument(id: 'doc-1');
        fakeDocSelection.setForThread('room-1', 'existing', {doc});

        await sendMessage.call(
          roomId: 'room-1',
          text: 'Hello',
          pendingDocuments: {},
          currentThread: existingThread,
        );

        final call = startRunTracker.calls.first;
        expect(call.initialState, isNotNull);
        expect(call.initialState!['filter_documents'], isNotNull);
        final filterDocs =
            call.initialState!['filter_documents'] as Map<String, dynamic>;
        expect(filterDocs['document_ids'], contains('doc-1'));
      });

      test('passes null initial state when no docs selected', () async {
        final existingThread = TestData.createThread(
          id: 'existing',
          roomId: 'room-1',
        );

        await sendMessage.call(
          roomId: 'room-1',
          text: 'Hello',
          pendingDocuments: {},
          currentThread: existingThread,
        );

        final call = startRunTracker.calls.first;
        expect(call.initialState, isNull);
      });

      test('passes filter for pending docs transferred to new thread',
          () async {
        final newThread = TestData.createThread(
          id: 'new-thread',
          roomId: 'room-1',
        );
        when(
          () => mockApi.createThread('room-1'),
        ).thenAnswer((_) async => newThread);

        final doc = TestData.createDocument(id: 'doc-2');
        await sendMessage.call(
          roomId: 'room-1',
          text: 'Hello',
          pendingDocuments: {doc},
        );

        final call = startRunTracker.calls.first;
        expect(call.initialState, isNotNull);
        final filterDocs =
            call.initialState!['filter_documents'] as Map<String, dynamic>;
        expect(filterDocs['document_ids'], contains('doc-2'));
      });
    });
  });
}
