import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:soliplex_client/soliplex_client.dart'
    show NetworkException, ThreadHistory;
import 'package:soliplex_frontend/core/models/thread_key.dart';
import 'package:soliplex_frontend/core/providers/api_provider.dart';
import 'package:soliplex_frontend/core/providers/thread_history_cache.dart';

import '../../helpers/test_helpers.dart';

void main() {
  group('ThreadHistoryCache', () {
    late MockSoliplexApi mockApi;

    setUp(() {
      mockApi = MockSoliplexApi();
    });

    group('getHistory', () {
      test('returns cached history on cache hit (no API call)', () async {
        // Arrange: Pre-populate cache
        final cachedHistory = ThreadHistory(
          messages: [
            TestData.createMessage(id: 'msg-1', text: 'Hello'),
            TestData.createMessage(id: 'msg-2', text: 'World'),
          ],
          aguiState: const {'haiku.rag.chat': <String, dynamic>{}},
        );

        final container = ProviderContainer(
          overrides: [apiProvider.overrideWithValue(mockApi)],
        );
        addTearDown(container.dispose);

        // Pre-populate cache
        container.read(threadHistoryCacheProvider.notifier).updateHistory(
          const (roomId: 'room-abc', threadId: 'thread-123'),
          cachedHistory,
        );

        // Act
        final history = await container
            .read(threadHistoryCacheProvider.notifier)
            .getHistory(const (roomId: 'room-abc', threadId: 'thread-123'));

        // Assert
        expect(history.messages, hasLength(2));
        expect(history.messages[0].id, 'msg-1');
        expect(history.messages[1].id, 'msg-2');
        expect(history.aguiState, containsPair('haiku.rag.chat', {}));
        verifyNever(() => mockApi.getThreadHistory(any(), any()));
      });

      test('fetches from API and caches on cache miss', () async {
        // Arrange
        final apiHistory = ThreadHistory(
          messages: [
            TestData.createMessage(id: 'msg-1', text: 'From API'),
          ],
          aguiState: const {'haiku.rag.chat': <String, dynamic>{}},
        );

        when(
          () => mockApi.getThreadHistory('room-abc', 'thread-123'),
        ).thenAnswer((_) async => apiHistory);

        final container = ProviderContainer(
          overrides: [apiProvider.overrideWithValue(mockApi)],
        );
        addTearDown(container.dispose);

        // Act
        final history = await container
            .read(threadHistoryCacheProvider.notifier)
            .getHistory(const (roomId: 'room-abc', threadId: 'thread-123'));

        // Assert
        expect(history.messages, hasLength(1));
        expect(history.messages[0].id, 'msg-1');
        expect(history.aguiState, containsPair('haiku.rag.chat', {}));
        verify(
          () => mockApi.getThreadHistory('room-abc', 'thread-123'),
        ).called(1);

        // Verify cached
        const key = (roomId: 'room-abc', threadId: 'thread-123');
        final cacheState = container.read(threadHistoryCacheProvider);
        expect(cacheState.containsKey(key), isTrue);
        expect(cacheState[key]!.messages, hasLength(1));
      });

      test('subsequent calls use cache after initial fetch', () async {
        // Arrange
        final apiHistory = ThreadHistory(
          messages: [
            TestData.createMessage(id: 'msg-1', text: 'From API'),
          ],
        );

        when(
          () => mockApi.getThreadHistory('room-abc', 'thread-123'),
        ).thenAnswer((_) async => apiHistory);

        final container = ProviderContainer(
          overrides: [apiProvider.overrideWithValue(mockApi)],
        );
        addTearDown(container.dispose);

        final cache = container.read(threadHistoryCacheProvider.notifier);

        // Act: First call - fetches from API
        await cache
            .getHistory(const (roomId: 'room-abc', threadId: 'thread-123'));

        // Act: Second call - should use cache
        await cache
            .getHistory(const (roomId: 'room-abc', threadId: 'thread-123'));

        // Assert: API only called once
        verify(
          () => mockApi.getThreadHistory('room-abc', 'thread-123'),
        ).called(1);
      });

      test('concurrent fetches share single API request', () async {
        // Arrange: Slow API response
        final apiHistory = ThreadHistory(
          messages: [
            TestData.createMessage(id: 'msg-1', text: 'From API'),
          ],
        );

        when(
          () => mockApi.getThreadHistory('room-abc', 'thread-123'),
        ).thenAnswer((_) async {
          // Simulate slow API
          await Future<void>.delayed(const Duration(milliseconds: 50));
          return apiHistory;
        });

        final container = ProviderContainer(
          overrides: [apiProvider.overrideWithValue(mockApi)],
        );
        addTearDown(container.dispose);

        final cache = container.read(threadHistoryCacheProvider.notifier);

        // Act: Start two concurrent fetches
        final future1 = cache
            .getHistory(const (roomId: 'room-abc', threadId: 'thread-123'));
        final future2 = cache
            .getHistory(const (roomId: 'room-abc', threadId: 'thread-123'));

        // Both should complete with same result
        final results = await Future.wait([future1, future2]);

        // Assert: API called only once despite two concurrent requests
        verify(
          () => mockApi.getThreadHistory('room-abc', 'thread-123'),
        ).called(1);

        // Both callers get the same history
        expect(results[0].messages, hasLength(1));
        expect(results[1].messages, hasLength(1));
        expect(results[0].messages[0].id, 'msg-1');
        expect(results[1].messages[0].id, 'msg-1');
      });

      test('propagates API errors wrapped with thread context', () async {
        // Arrange
        when(
          () => mockApi.getThreadHistory('room-abc', 'thread-123'),
        ).thenThrow(const NetworkException(message: 'Connection failed'));

        final container = ProviderContainer(
          overrides: [apiProvider.overrideWithValue(mockApi)],
        );
        addTearDown(container.dispose);

        // Act & Assert: Error is wrapped with HistoryFetchException
        await expectLater(
          container
              .read(threadHistoryCacheProvider.notifier)
              .getHistory(const (roomId: 'room-abc', threadId: 'thread-123')),
          throwsA(
            allOf([
              isA<HistoryFetchException>(),
              predicate<HistoryFetchException>(
                (e) =>
                    e.threadId == 'thread-123' && e.cause is NetworkException,
                'has correct threadId and cause',
              ),
            ]),
          ),
        );

        // Cache should remain empty (no partial caching on error)
        const key = (roomId: 'room-abc', threadId: 'thread-123');
        final cacheState = container.read(threadHistoryCacheProvider);
        expect(cacheState.containsKey(key), isFalse);
      });

      test('allows retry after API error', () async {
        // Arrange: First call fails, second succeeds
        var callCount = 0;
        when(
          () => mockApi.getThreadHistory('room-abc', 'thread-123'),
        ).thenAnswer((_) async {
          callCount++;
          if (callCount == 1) {
            throw const NetworkException(message: 'Connection failed');
          }
          return ThreadHistory(
            messages: [TestData.createMessage(id: 'msg-1', text: 'Success')],
          );
        });

        final container = ProviderContainer(
          overrides: [apiProvider.overrideWithValue(mockApi)],
        );
        addTearDown(container.dispose);

        final cache = container.read(threadHistoryCacheProvider.notifier);

        // First call fails (wrapped in HistoryFetchException)
        await expectLater(
          cache.getHistory(const (roomId: 'room-abc', threadId: 'thread-123')),
          throwsA(isA<HistoryFetchException>()),
        );

        // Second call retries and succeeds
        final history = await cache
            .getHistory(const (roomId: 'room-abc', threadId: 'thread-123'));
        expect(history.messages, hasLength(1));
        expect(history.messages[0].id, 'msg-1');

        // API was called twice (retry after failure)
        verify(
          () => mockApi.getThreadHistory('room-abc', 'thread-123'),
        ).called(2);
      });

      test('same threadId in different rooms produces separate cache entries',
          () async {
        // Arrange: Two rooms return different histories for the same threadId
        when(
          () => mockApi.getThreadHistory('room-a', 'shared-thread'),
        ).thenAnswer(
          (_) async => ThreadHistory(
            messages: [
              TestData.createMessage(id: 'msg-a', text: 'Room A history'),
            ],
          ),
        );
        when(
          () => mockApi.getThreadHistory('room-b', 'shared-thread'),
        ).thenAnswer(
          (_) async => ThreadHistory(
            messages: [
              TestData.createMessage(id: 'msg-b', text: 'Room B history'),
            ],
          ),
        );

        final container = ProviderContainer(
          overrides: [apiProvider.overrideWithValue(mockApi)],
        );
        addTearDown(container.dispose);

        final cache = container.read(threadHistoryCacheProvider.notifier);

        // Act: Fetch same threadId from two different rooms
        final historyA = await cache
            .getHistory(const (roomId: 'room-a', threadId: 'shared-thread'));
        final historyB = await cache
            .getHistory(const (roomId: 'room-b', threadId: 'shared-thread'));

        // Assert: They return different histories (not a cached collision)
        expect(historyA.messages[0].id, 'msg-a');
        expect(historyB.messages[0].id, 'msg-b');

        // Both API calls should have been made
        verify(() => mockApi.getThreadHistory('room-a', 'shared-thread'))
            .called(1);
        verify(() => mockApi.getThreadHistory('room-b', 'shared-thread'))
            .called(1);
      });

      test('different threads have separate cache entries', () async {
        // Arrange
        when(
          () => mockApi.getThreadHistory('room-abc', 'thread-1'),
        ).thenAnswer(
          (_) async => ThreadHistory(
            messages: [TestData.createMessage(id: 'msg-t1', text: 'Thread 1')],
          ),
        );
        when(
          () => mockApi.getThreadHistory('room-abc', 'thread-2'),
        ).thenAnswer(
          (_) async => ThreadHistory(
            messages: [TestData.createMessage(id: 'msg-t2', text: 'Thread 2')],
          ),
        );

        final container = ProviderContainer(
          overrides: [apiProvider.overrideWithValue(mockApi)],
        );
        addTearDown(container.dispose);

        final cache = container.read(threadHistoryCacheProvider.notifier);

        // Act
        final history1 = await cache
            .getHistory(const (roomId: 'room-abc', threadId: 'thread-1'));
        final history2 = await cache
            .getHistory(const (roomId: 'room-abc', threadId: 'thread-2'));

        // Assert
        expect(history1.messages[0].id, 'msg-t1');
        expect(history2.messages[0].id, 'msg-t2');

        final cacheState = container.read(threadHistoryCacheProvider);
        expect(
          cacheState.keys,
          containsAll(<ThreadKey>[
            (roomId: 'room-abc', threadId: 'thread-1'),
            (roomId: 'room-abc', threadId: 'thread-2'),
          ]),
        );
      });
    });

    group('updateHistory', () {
      test('updates cache for thread', () {
        // Arrange
        final container = ProviderContainer(
          overrides: [apiProvider.overrideWithValue(mockApi)],
        );
        addTearDown(container.dispose);

        final newHistory = ThreadHistory(
          messages: [
            TestData.createMessage(id: 'msg-new', text: 'New message'),
          ],
          aguiState: const {'key': 'value'},
        );

        // Act
        container.read(threadHistoryCacheProvider.notifier).updateHistory(
          const (roomId: 'room-abc', threadId: 'thread-123'),
          newHistory,
        );

        // Assert
        const key = (roomId: 'room-abc', threadId: 'thread-123');
        final cacheState = container.read(threadHistoryCacheProvider);
        expect(cacheState[key]!.messages, hasLength(1));
        expect(cacheState[key]!.messages[0].id, 'msg-new');
        expect(
          cacheState[key]!.aguiState,
          containsPair('key', 'value'),
        );
      });

      test('overwrites existing cache entry', () {
        // Arrange
        final container = ProviderContainer(
          overrides: [apiProvider.overrideWithValue(mockApi)],
        );
        addTearDown(container.dispose);

        container.read(threadHistoryCacheProvider.notifier)
          // Pre-populate
          ..updateHistory(
            const (roomId: 'room-abc', threadId: 'thread-123'),
            ThreadHistory(
              messages: [TestData.createMessage(id: 'old-msg', text: 'Old')],
            ),
          )
          // Act: Overwrite
          ..updateHistory(
            const (roomId: 'room-abc', threadId: 'thread-123'),
            ThreadHistory(
              messages: [TestData.createMessage(id: 'new-msg', text: 'New')],
            ),
          );

        // Assert
        const key = (roomId: 'room-abc', threadId: 'thread-123');
        final cacheState = container.read(threadHistoryCacheProvider);
        expect(cacheState[key]!.messages, hasLength(1));
        expect(cacheState[key]!.messages[0].id, 'new-msg');
      });

      test('does not affect other thread entries', () {
        // Arrange
        final container = ProviderContainer(
          overrides: [apiProvider.overrideWithValue(mockApi)],
        );
        addTearDown(container.dispose);

        container.read(threadHistoryCacheProvider.notifier)
          // Pre-populate thread-1
          ..updateHistory(
            const (roomId: 'room-abc', threadId: 'thread-1'),
            ThreadHistory(
              messages: [
                TestData.createMessage(id: 'msg-t1', text: 'Thread 1'),
              ],
            ),
          )
          // Act: Update thread-2
          ..updateHistory(
            const (roomId: 'room-abc', threadId: 'thread-2'),
            ThreadHistory(
              messages: [
                TestData.createMessage(id: 'msg-t2', text: 'Thread 2'),
              ],
            ),
          );

        // Assert: thread-1 unchanged
        const key1 = (roomId: 'room-abc', threadId: 'thread-1');
        const key2 = (roomId: 'room-abc', threadId: 'thread-2');
        final cacheState = container.read(threadHistoryCacheProvider);
        expect(cacheState[key1]!.messages[0].id, 'msg-t1');
        expect(cacheState[key2]!.messages[0].id, 'msg-t2');
      });
    });

    group('HistoryFetchException', () {
      test('asserts threadId is not empty', () {
        expect(
          () => HistoryFetchException(
            threadId: '',
            cause: const NetworkException(message: 'Failed'),
          ),
          throwsA(isA<AssertionError>()),
        );
      });

      test('allows non-empty threadId', () {
        final exception = HistoryFetchException(
          threadId: 'valid-thread-id',
          cause: const NetworkException(message: 'Failed'),
        );
        expect(exception.threadId, 'valid-thread-id');
        expect(exception.cause, isA<NetworkException>());
      });
    });

    group('refreshHistory', () {
      test('clears cache and refetches from API', () async {
        // Arrange: Pre-populate cache with stale data
        final staleHistory = ThreadHistory(
          messages: [TestData.createMessage(id: 'stale-msg', text: 'Stale')],
        );
        final freshHistory = ThreadHistory(
          messages: [TestData.createMessage(id: 'fresh-msg', text: 'Fresh')],
          aguiState: const {'fresh': true},
        );

        when(
          () => mockApi.getThreadHistory('room-abc', 'thread-123'),
        ).thenAnswer((_) async => freshHistory);

        final container = ProviderContainer(
          overrides: [apiProvider.overrideWithValue(mockApi)],
        );
        addTearDown(container.dispose);

        // Pre-populate cache
        container.read(threadHistoryCacheProvider.notifier).updateHistory(
          const (roomId: 'room-abc', threadId: 'thread-123'),
          staleHistory,
        );

        // Verify stale data is cached
        const key = (roomId: 'room-abc', threadId: 'thread-123');
        expect(
          container.read(threadHistoryCacheProvider)[key]!.messages[0].id,
          'stale-msg',
        );

        // Act
        final history = await container
            .read(threadHistoryCacheProvider.notifier)
            .refreshHistory(key);

        // Assert: Got fresh data
        expect(history.messages, hasLength(1));
        expect(history.messages[0].id, 'fresh-msg');
        expect(history.aguiState, containsPair('fresh', true));

        // Assert: Cache updated with fresh data
        final cacheState = container.read(threadHistoryCacheProvider);
        expect(cacheState[key]!.messages[0].id, 'fresh-msg');

        // Assert: API was called
        verify(
          () => mockApi.getThreadHistory('room-abc', 'thread-123'),
        ).called(1);
      });

      test('does not affect other thread entries', () async {
        // Arrange
        when(
          () => mockApi.getThreadHistory('room-abc', 'thread-1'),
        ).thenAnswer(
          (_) async => ThreadHistory(
            messages: [
              TestData.createMessage(id: 'refreshed-t1', text: 'Refreshed'),
            ],
          ),
        );

        final container = ProviderContainer(
          overrides: [apiProvider.overrideWithValue(mockApi)],
        );
        addTearDown(container.dispose);

        // Pre-populate both threads
        container.read(threadHistoryCacheProvider.notifier)
          ..updateHistory(
            const (roomId: 'room-abc', threadId: 'thread-1'),
            ThreadHistory(
              messages: [TestData.createMessage(id: 'old-t1', text: 'Old T1')],
            ),
          )
          ..updateHistory(
            const (roomId: 'room-abc', threadId: 'thread-2'),
            ThreadHistory(
              messages: [
                TestData.createMessage(id: 'msg-t2', text: 'Thread 2'),
              ],
            ),
          );

        // Act: Refresh thread-1
        await container
            .read(threadHistoryCacheProvider.notifier)
            .refreshHistory(
          const (roomId: 'room-abc', threadId: 'thread-1'),
        );

        // Assert: thread-2 unchanged
        const key1 = (roomId: 'room-abc', threadId: 'thread-1');
        const key2 = (roomId: 'room-abc', threadId: 'thread-2');
        final cacheState = container.read(threadHistoryCacheProvider);
        expect(cacheState[key1]!.messages[0].id, 'refreshed-t1');
        expect(cacheState[key2]!.messages[0].id, 'msg-t2');
      });
    });
  });
}
