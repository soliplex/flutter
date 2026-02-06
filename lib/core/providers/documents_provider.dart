import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soliplex_client/soliplex_client.dart';
import 'package:soliplex_frontend/core/logging/loggers.dart';
import 'package:soliplex_frontend/core/providers/api_provider.dart';

/// Determines if an error should trigger a retry.
///
/// Retries on:
/// - [NetworkException]: Connection failures, timeouts
/// - [ApiException] with status 5xx, 408, or 429
///
/// Does NOT retry on:
/// - [AuthException]: 401/403 require re-authentication
/// - [NotFoundException]: Resource doesn't exist
/// - [CancelledException]: User-initiated cancel
/// - Other status codes (4xx client errors)
@visibleForTesting
bool shouldRetryDocumentsFetch(Object error) {
  if (error is NetworkException) return true;
  if (error is ApiException) {
    final status = error.statusCode;
    // 5xx server errors, 408 timeout, 429 rate limit
    return status >= 500 || status == 408 || status == 429;
  }
  return false;
}

/// Backoff delays between retry attempts.
/// Can be overridden in tests via [documentsRetryDelaysProvider].
const _defaultBackoffDelays = [
  Duration(seconds: 1),
  Duration(seconds: 2),
  Duration(seconds: 4),
];

/// Provider for retry delays. Override in tests for faster execution.
@visibleForTesting
final documentsRetryDelaysProvider = Provider<List<Duration>>(
  (ref) => _defaultBackoffDelays,
);

/// Maximum number of retry attempts for document fetching.
@visibleForTesting
const maxRetryAttempts = 3;

/// Provider for documents in a specific room.
///
/// Fetches documents from the backend API using [SoliplexApi.getDocuments].
/// Each room's documents are cached separately by Riverpod's family provider.
///
/// Uses a Notifier with manual AsyncValue state management to avoid
/// Riverpod's error-handling race conditions that occur when throwing
/// from async providers.
///
/// **Retry Logic**:
/// Automatically retries up to 3 times with exponential backoff (1s, 2s, 4s)
/// on transient failures:
/// - Network errors (connection failures, timeouts)
/// - Server errors (5xx status codes)
/// - Rate limiting (429) and request timeout (408)
///
/// Does NOT retry on:
/// - Authentication errors (401/403)
/// - Not found (404)
/// - Other client errors (4xx)
///
/// **Usage**:
/// ```dart
/// // Read documents for a room
/// final docsAsync = ref.watch(documentsProvider('room-id'));
///
/// // Refresh documents for a room (bypasses cache, triggers new fetch)
/// ref.invalidate(documentsProvider('room-id'));
///
/// // Manual retry after error
/// ref.read(documentsProvider('room-id').notifier).retry();
/// ```
///
/// **Error Handling**:
/// Returns [AsyncValue.error] with [SoliplexException] subtypes:
/// - [NetworkException]: Connection failures, timeouts (after retries)
/// - [NotFoundException]: Room not found (404)
/// - [AuthException]: 401/403 authentication errors
/// - [ApiException]: Other server errors (after retries for 5xx)
final documentsProvider = NotifierProvider.family<DocumentsNotifier,
    AsyncValue<List<RagDocument>>, String>(DocumentsNotifier.new);

/// Notifier that manages document fetching with retry logic.
///
/// Uses manual [AsyncValue] state management instead of [AsyncNotifier]
/// to have direct control over state transitions. This avoids the race
/// condition where throwing errors causes dispose/recreate cycles.
class DocumentsNotifier extends Notifier<AsyncValue<List<RagDocument>>> {
  /// Creates a notifier for the given room ID.
  DocumentsNotifier(this._roomId);

  final String _roomId;

  @override
  AsyncValue<List<RagDocument>> build() {
    // Start fetching asynchronously
    _fetchDocuments();

    // Return loading state immediately
    return const AsyncValue.loading();
  }

  /// Fetches documents with retry logic and updates state directly.
  Future<void> _fetchDocuments() async {
    final api = ref.read(apiProvider);
    final delays = ref.read(documentsRetryDelaysProvider);

    Object? lastError;
    StackTrace? lastStackTrace;

    for (var attempt = 0; attempt < maxRetryAttempts; attempt++) {
      try {
        final documents = await api.getDocuments(_roomId);
        state = AsyncValue.data(documents);
        return;
      } catch (e, st) {
        lastError = e;
        lastStackTrace = st;

        // Don't retry non-retryable errors
        if (!shouldRetryDocumentsFetch(e)) {
          state = AsyncValue.error(e, st);
          return;
        }

        // Don't delay after the last attempt
        if (attempt < maxRetryAttempts - 1) {
          Loggers.room.trace(
            'Document fetch retry ${attempt + 1}/$maxRetryAttempts'
            ' for $_roomId',
          );
          await Future<void>.delayed(delays[attempt]);
        }
      }
    }

    // All retries exhausted - set error state directly
    Loggers.room.warning(
      'Document fetch retries exhausted for $_roomId',
      error: lastError,
      stackTrace: lastStackTrace,
    );
    state = AsyncValue.error(lastError!, lastStackTrace!);
  }

  /// Retries fetching documents after an error.
  void retry() {
    state = const AsyncValue.loading();
    _fetchDocuments();
  }
}
