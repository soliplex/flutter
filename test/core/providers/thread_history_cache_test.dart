import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:soliplex_client/soliplex_client.dart'
    show NetworkException, ThreadHistory;
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
        container
            .read(threadHistoryCacheProvider.notifier)
            .updateHistory('thread-123', cachedHistory);

        // Act
        final history = await container
            .read(threadHistoryCacheProvider.notifier)
            .getHistory('room-abc', 'thread-123');

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
          aguiState: const {'ask_history': <String, dynamic>{}},
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
            .getHistory('room-abc', 'thread-123');

        // Assert
        expect(history.messages, hasLength(1));
        expect(history.messages[0].id, 'msg-1');
        expect(history.aguiState, containsPair('ask_history', {}));
        verify(
          () => mockApi.getThreadHistory('room-abc', 'thread-123'),
        ).called(1);

        // Verify cached
        final cacheState = container.read(threadHistoryCacheProvider);
        expect(cacheState.containsKey('thread-123'), isTrue);
        expect(cacheState['thread-123']!.messages, hasLength(1));
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
        await cache.getHistory('room-abc', 'thread-123');

        // Act: Second call - should use cache
        await cache.getHistory('room-abc', 'thread-123');

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
        final future1 = cache.getHistory('room-abc', 'thread-123');
        final future2 = cache.getHistory('room-abc', 'thread-123');

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
              .getHistory('room-abc', 'thread-123'),
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
        final cacheState = container.read(threadHistoryCacheProvider);
        expect(cacheState.containsKey('thread-123'), isFalse);
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
          cache.getHistory('room-abc', 'thread-123'),
          throwsA(isA<HistoryFetchException>()),
        );

        // Second call retries and succeeds
        final history = await cache.getHistory('room-abc', 'thread-123');
        expect(history.messages, hasLength(1));
        expect(history.messages[0].id, 'msg-1');

        // API was called twice (retry after failure)
        verify(
          () => mockApi.getThreadHistory('room-abc', 'thread-123'),
        ).called(2);
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
        final history1 = await cache.getHistory('room-abc', 'thread-1');
        final history2 = await cache.getHistory('room-abc', 'thread-2');

        // Assert
        expect(history1.messages[0].id, 'msg-t1');
        expect(history2.messages[0].id, 'msg-t2');

        final cacheState = container.read(threadHistoryCacheProvider);
        expect(cacheState.keys, containsAll(['thread-1', 'thread-2']));
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
        container
            .read(threadHistoryCacheProvider.notifier)
            .updateHistory('thread-123', newHistory);

        // Assert
        final cacheState = container.read(threadHistoryCacheProvider);
        expect(cacheState['thread-123']!.messages, hasLength(1));
        expect(cacheState['thread-123']!.messages[0].id, 'msg-new');
        expect(
          cacheState['thread-123']!.aguiState,
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
            'thread-123',
            ThreadHistory(
              messages: [TestData.createMessage(id: 'old-msg', text: 'Old')],
            ),
          )
          // Act: Overwrite
          ..updateHistory(
            'thread-123',
            ThreadHistory(
              messages: [TestData.createMessage(id: 'new-msg', text: 'New')],
            ),
          );

        // Assert
        final cacheState = container.read(threadHistoryCacheProvider);
        expect(cacheState['thread-123']!.messages, hasLength(1));
        expect(cacheState['thread-123']!.messages[0].id, 'new-msg');
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
            'thread-1',
            ThreadHistory(
              messages: [
                TestData.createMessage(id: 'msg-t1', text: 'Thread 1'),
              ],
            ),
          )
          // Act: Update thread-2
          ..updateHistory(
            'thread-2',
            ThreadHistory(
              messages: [
                TestData.createMessage(id: 'msg-t2', text: 'Thread 2'),
              ],
            ),
          );

        // Assert: thread-1 unchanged
        final cacheState = container.read(threadHistoryCacheProvider);
        expect(cacheState['thread-1']!.messages[0].id, 'msg-t1');
        expect(cacheState['thread-2']!.messages[0].id, 'msg-t2');
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
        container
            .read(threadHistoryCacheProvider.notifier)
            .updateHistory('thread-123', staleHistory);

        // Verify stale data is cached
        expect(
          container
              .read(threadHistoryCacheProvider)['thread-123']!
              .messages[0]
              .id,
          'stale-msg',
        );

        // Act
        final history = await container
            .read(threadHistoryCacheProvider.notifier)
            .refreshHistory('room-abc', 'thread-123');

        // Assert: Got fresh data
        expect(history.messages, hasLength(1));
        expect(history.messages[0].id, 'fresh-msg');
        expect(history.aguiState, containsPair('fresh', true));

        // Assert: Cache updated with fresh data
        final cacheState = container.read(threadHistoryCacheProvider);
        expect(cacheState['thread-123']!.messages[0].id, 'fresh-msg');

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
            'thread-1',
            ThreadHistory(
              messages: [TestData.createMessage(id: 'old-t1', text: 'Old T1')],
            ),
          )
          ..updateHistory(
            'thread-2',
            ThreadHistory(
              messages: [
                TestData.createMessage(id: 'msg-t2', text: 'Thread 2'),
              ],
            ),
          );

        // Act: Refresh thread-1
        await container
            .read(threadHistoryCacheProvider.notifier)
            .refreshHistory('room-abc', 'thread-1');

        // Assert: thread-2 unchanged
        final cacheState = container.read(threadHistoryCacheProvider);
        expect(cacheState['thread-1']!.messages[0].id, 'refreshed-t1');
        expect(cacheState['thread-2']!.messages[0].id, 'msg-t2');
      });
    });
  });
}
