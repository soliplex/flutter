import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soliplex_client/soliplex_client.dart';
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

/// Fetches documents with automatic retry on transient failures.
///
/// Implements exponential backoff: 1s, 2s, 4s between attempts.
/// Maximum 3 attempts before giving up.
Future<List<RagDocument>> _fetchWithRetry(
  SoliplexApi api,
  String roomId,
  List<Duration> backoffDelays,
) async {
  const maxAttempts = 3;

  Object? lastError;
  StackTrace? lastStackTrace;

  for (var attempt = 0; attempt < maxAttempts; attempt++) {
    try {
      debugPrint('[_fetchWithRetry] Attempt ${attempt + 1}/$maxAttempts');
      return await api.getDocuments(roomId);
    } catch (e, st) {
      debugPrint('[_fetchWithRetry] Attempt ${attempt + 1} failed: $e');
      lastError = e;
      lastStackTrace = st;

      // Don't retry non-retryable errors
      if (!shouldRetryDocumentsFetch(e)) {
        debugPrint('[_fetchWithRetry] Not retryable, rethrowing');
        rethrow;
      }

      // Don't delay after the last attempt
      if (attempt < maxAttempts - 1) {
        debugPrint(
          '[_fetchWithRetry] Waiting ${backoffDelays[attempt]} before retry',
        );
        await Future<void>.delayed(backoffDelays[attempt]);
      }
    }
  }

  // All retries exhausted - rethrow last error
  debugPrint('[_fetchWithRetry] All $maxAttempts attempts exhausted');
  Error.throwWithStackTrace(lastError!, lastStackTrace!);
}

/// Provider for documents in a specific room.
///
/// Fetches documents from the backend API using [SoliplexApi.getDocuments].
/// Each room's documents are cached separately by Riverpod's family provider.
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
/// ```
///
/// **Error Handling**:
/// Throws [SoliplexException] subtypes which should be handled in the UI:
/// - [NetworkException]: Connection failures, timeouts
///   (after retries exhausted)
/// - [NotFoundException]: Room not found (404)
/// - [AuthException]: 401/403 authentication errors
/// - [ApiException]: Other server errors (after retries exhausted for 5xx)
var _providerInvocationCount = 0; // TODO: Remove after debugging

final documentsProvider = FutureProvider.family<List<RagDocument>, String>((
  ref,
  roomId,
) async {
  _providerInvocationCount++;
  debugPrint(
    '[documentsProvider] Invocation #$_providerInvocationCount for room=$roomId',
  );

  // Use ref.read instead of ref.watch to prevent provider re-execution
  // during retry delays. If apiProvider rebuilds mid-retry (e.g., due to
  // httpLogProvider updates), we don't want to restart the entire fetch.
  final api = ref.read(apiProvider);
  final delays = ref.read(documentsRetryDelaysProvider);
  return _fetchWithRetry(api, roomId, delays);
});
