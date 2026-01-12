import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:soliplex_client/soliplex_client.dart';
import 'package:soliplex_frontend/core/providers/thread_message_cache.dart';

/// Standard error display widget with retry button.
///
/// Displays different error messages and icons based on exception type:
/// - [AuthException]: Shows authentication required message
/// - [NetworkException]: Differentiates timeout vs connection errors
/// - [NotFoundException]: Shows resource not found message
/// - [ApiException]: Shows server error with status code
/// - [CancelledException]: Shows operation cancelled message
/// - Unknown errors: Shows generic error message
///
/// In debug mode, shows the full error details below the message
/// for easier debugging.
class ErrorDisplay extends StatelessWidget {
  const ErrorDisplay({required this.error, this.onRetry, super.key});

  final Object error;
  final VoidCallback? onRetry;

  /// Unwraps wrapper exceptions to get the underlying cause.
  Object _unwrapError() {
    if (error is MessageFetchException) {
      return (error as MessageFetchException).cause;
    }
    return error;
  }

  String _getErrorMessage() {
    final unwrapped = _unwrapError();
    if (unwrapped is AuthException) {
      if (unwrapped.statusCode == 401) {
        return 'Session expired. Please log in again.';
      } else if (unwrapped.statusCode == 403) {
        return "You don't have permission to access this resource.";
      }
      return unwrapped.message;
    } else if (unwrapped is NetworkException) {
      if (unwrapped.isTimeout) {
        return 'Request timed out: ${unwrapped.message}';
      }
      return 'Network error: ${unwrapped.message}';
    } else if (unwrapped is NotFoundException) {
      return unwrapped.message;
    } else if (unwrapped is ApiException) {
      return 'Server error (${unwrapped.statusCode}): ${unwrapped.message}';
    } else if (unwrapped is CancelledException) {
      if (unwrapped.reason != null) {
        return 'Operation cancelled: ${unwrapped.reason}';
      }
      return 'Operation cancelled.';
    } else if (unwrapped is String && unwrapped.isNotEmpty) {
      return unwrapped;
    } else {
      return 'An unexpected error occurred.';
    }
  }

  IconData _getErrorIcon() {
    final unwrapped = _unwrapError();
    if (unwrapped is AuthException) return Icons.lock_outline;
    if (unwrapped is NetworkException) return Icons.wifi_off;
    if (unwrapped is NotFoundException) return Icons.search_off;
    if (unwrapped is CancelledException) return Icons.cancel_outlined;
    return Icons.error_outline;
  }

  bool _canRetry() {
    final unwrapped = _unwrapError();
    // AuthException should not show retry button (need login flow)
    // CancelledException should not show retry button (user cancelled)
    return unwrapped is! AuthException && unwrapped is! CancelledException;
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ExcludeSemantics(
              child: Icon(
                _getErrorIcon(),
                size: 64,
                color: Theme.of(context).colorScheme.error,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _getErrorMessage(),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            // Debug info in development builds
            if (kDebugMode) ...[
              const SizedBox(height: 8),
              SelectableText(
                error.toString(),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                      color: Colors.grey,
                    ),
              ),
            ],
            if (onRetry != null && _canRetry()) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
