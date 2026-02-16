import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soliplex_client/soliplex_client.dart';
import 'package:soliplex_frontend/core/models/run_handle.dart';
import 'package:soliplex_frontend/core/models/thread_key.dart';
import 'package:soliplex_frontend/core/providers/api_provider.dart';

/// Cache state: [ThreadKey] -> thread history (messages + AG-UI state).
typedef ThreadHistoryCacheState = Map<ThreadKey, ThreadHistory>;

/// Provides cached thread history with backend fetch on cache miss.
///
/// This is the single source of truth for historical thread data. It:
/// - Returns cached history instantly on cache hit (no API call)
/// - Fetches from backend and caches on cache miss
/// - Updates cache when runs complete (via [updateHistory])
///
/// Example:
/// ```dart
/// // Get history (fetches if not cached)
/// final history = await ref.read(threadHistoryCacheProvider.notifier)
///     .getHistory(roomId, threadId);
///
/// // Update cache after run completes
/// ref.read(threadHistoryCacheProvider.notifier)
///     .updateHistory(roomId, threadId, history);
/// ```
class ThreadHistoryCache extends Notifier<ThreadHistoryCacheState> {
  /// Tracks in-flight fetches to prevent duplicate concurrent requests.
  final _inFlightFetches = <ThreadKey, Future<ThreadHistory>>{};

  @override
  ThreadHistoryCacheState build() {
    // Clear in-flight fetches on rebuild to prevent race conditions
    // if the notifier is recreated while fetches are pending.
    _inFlightFetches.clear();
    return {};
  }

  /// Get history for a thread (from cache or backend).
  ///
  /// Returns cached history immediately if available. Otherwise, fetches
  /// from backend via [SoliplexApi.getThreadHistory], caches the result,
  /// and returns it.
  ///
  /// Concurrent calls for the same thread share a single fetch request.
  ///
  /// Throws on network/API errors from the backend fetch.
  Future<ThreadHistory> getHistory(String roomId, String threadId) async {
    final key = (roomId: roomId, threadId: threadId);

    // Cache hit
    final cached = state[key];
    if (cached != null) return cached;

    // Join existing fetch or start new one
    return _inFlightFetches[key] ??= _fetchAndCache(key);
  }

  /// Fetches history from backend and caches the result.
  ///
  /// On success, caches history and returns it. On error, the exception
  /// is wrapped with thread context and re-thrown. The in-flight tracking
  /// is always cleaned up, allowing subsequent calls to retry the fetch.
  Future<ThreadHistory> _fetchAndCache(ThreadKey key) async {
    try {
      final api = ref.read(apiProvider);
      final history = await api.getThreadHistory(key.roomId, key.threadId);
      state = {...state, key: history};
      return history;
    } on Exception catch (e, st) {
      Error.throwWithStackTrace(
        HistoryFetchException(threadId: key.threadId, cause: e),
        st,
      );
    } finally {
      final _ = _inFlightFetches.remove(key);
    }
  }

  /// Update cached history for a thread.
  ///
  /// Call this on run completion to persist the latest history. Overwrites
  /// any existing cache entry for the thread.
  void updateHistory(String roomId, String threadId, ThreadHistory history) {
    final key = (roomId: roomId, threadId: threadId);
    state = {...state, key: history};
  }

  /// Invalidate cache and refetch history for a thread.
  ///
  /// Clears the cached entry and fetches fresh data from the backend.
  /// Use this when cached data may be stale and a refresh is needed.
  ///
  /// Throws on network/API errors from the backend fetch.
  Future<ThreadHistory> refreshHistory(
    String roomId,
    String threadId,
  ) async {
    final key = (roomId: roomId, threadId: threadId);
    // Remove from cache to force refetch
    state = {...state}..remove(key);
    // Discard any in-flight fetch for this thread (we'll start a new one)
    final _ = _inFlightFetches.remove(key);
    // Fetch fresh data
    return getHistory(roomId, threadId);
  }
}

/// Provider for the thread history cache.
///
/// Manages cached history per thread with backend fetch on miss.
final threadHistoryCacheProvider =
    NotifierProvider<ThreadHistoryCache, ThreadHistoryCacheState>(
  ThreadHistoryCache.new,
);

/// Exception thrown when fetching history for a thread fails.
///
/// Wraps the underlying exception with thread context for better debugging.
class HistoryFetchException implements Exception {
  /// Creates an exception for a failed history fetch.
  HistoryFetchException({required this.threadId, required this.cause})
      : assert(threadId.isNotEmpty, 'threadId must not be empty');

  /// The thread that failed to load.
  final String threadId;

  /// The underlying exception that caused the failure.
  final Exception cause;

  @override
  String toString() => 'Failed to load history for thread $threadId: $cause';
}
