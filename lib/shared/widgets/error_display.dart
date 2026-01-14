import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:soliplex_client/soliplex_client.dart' hide State;
import 'package:soliplex_frontend/core/providers/thread_message_cache.dart';
import 'package:soliplex_frontend/design/theme/theme_extensions.dart';

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
/// Includes a collapsible "Show details" section with full technical
/// information for debugging and bug reports.
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
        return 'Connection timed out: ${unwrapped.message}';
      }
      return 'Network error: ${unwrapped.message}';
    } else if (unwrapped is NotFoundException) {
      final resource = unwrapped.resource;
      if (resource != null) {
        return '$resource not found: ${unwrapped.message}';
      }
      return unwrapped.message;
    } else if (unwrapped is ApiException) {
      final statusText = _httpStatusText(unwrapped.statusCode);
      return 'Server error ($statusText): ${unwrapped.message}';
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
    return unwrapped is! AuthException && unwrapped is! CancelledException;
  }

  static String _httpStatusText(int statusCode) {
    return switch (statusCode) {
      400 => 'Bad Request',
      402 => 'Payment Required',
      405 => 'Method Not Allowed',
      408 => 'Request Timeout',
      409 => 'Conflict',
      410 => 'Gone',
      422 => 'Unprocessable Entity',
      429 => 'Too Many Requests',
      500 => 'Internal Server Error',
      501 => 'Not Implemented',
      502 => 'Bad Gateway',
      503 => 'Service Unavailable',
      504 => 'Gateway Timeout',
      _ => 'HTTP $statusCode',
    };
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
            const SizedBox(height: 8),
            _TechnicalDetails(error: error),
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

/// Collapsible technical details section.
class _TechnicalDetails extends StatefulWidget {
  const _TechnicalDetails({required this.error});

  final Object error;

  @override
  State<_TechnicalDetails> createState() => _TechnicalDetailsState();
}

class _TechnicalDetailsState extends State<_TechnicalDetails> {
  bool _expanded = false;

  Object _unwrapError() {
    if (widget.error is MessageFetchException) {
      return (widget.error as MessageFetchException).cause;
    }
    return widget.error;
  }

  Map<String, String> _buildDetails() {
    final unwrapped = _unwrapError();
    final details = <String, String>{};

    details['Type'] = unwrapped.runtimeType.toString();

    if (unwrapped is SoliplexException) {
      details['Message'] = unwrapped.message;

      if (unwrapped is AuthException && unwrapped.statusCode != null) {
        details['Status Code'] = unwrapped.statusCode.toString();
      }
      if (unwrapped is NetworkException) {
        details['Timeout'] = unwrapped.isTimeout ? 'Yes' : 'No';
      }
      if (unwrapped is ApiException) {
        details['Status Code'] = '${unwrapped.statusCode} '
            '(${ErrorDisplay._httpStatusText(unwrapped.statusCode)})';
        if (unwrapped.body != null && unwrapped.body!.isNotEmpty) {
          details['Response Body'] = unwrapped.body!;
        }
      }
      if (unwrapped is NotFoundException && unwrapped.resource != null) {
        details['Resource'] = unwrapped.resource!;
      }
      if (unwrapped.originalError != null) {
        details['Original Error'] = unwrapped.originalError.toString();
      }
    } else {
      details['Error'] = unwrapped.toString();
    }

    if (widget.error is MessageFetchException) {
      final wrapper = widget.error as MessageFetchException;
      details['Thread ID'] = wrapper.threadId;
    }

    return details;
  }

  String _getStackTrace() {
    final unwrapped = _unwrapError();
    if (unwrapped is SoliplexException && unwrapped.stackTrace != null) {
      final lines = unwrapped.stackTrace.toString().split('\n');
      final truncated = lines.take(10).join('\n');
      if (lines.length > 10) {
        return '$truncated\n... (${lines.length - 10} more lines)';
      }
      return truncated;
    }
    return '';
  }

  String _formatAllDetails() {
    final buffer = StringBuffer();
    for (final entry in _buildDetails().entries) {
      buffer.writeln('${entry.key}: ${entry.value}');
    }
    final stackTrace = _getStackTrace();
    if (stackTrace.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('Stack Trace:')
        ..writeln(stackTrace);
    }
    return buffer.toString().trim();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final soliplexTheme = SoliplexTheme.of(context);

    return Column(
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(soliplexTheme.radii.sm),
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 4),
                Text(
                  _expanded ? 'Hide details' : 'Show details',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_expanded)
          _DetailsPanel(
            details: _buildDetails(),
            stackTrace: _getStackTrace(),
            formattedDetails: _formatAllDetails(),
          ),
      ],
    );
  }
}

/// Expanded panel showing technical error details.
class _DetailsPanel extends StatelessWidget {
  const _DetailsPanel({
    required this.details,
    required this.stackTrace,
    required this.formattedDetails,
  });

  final Map<String, String> details;
  final String stackTrace;
  final String formattedDetails;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final soliplexTheme = SoliplexTheme.of(context);

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(
          soliplexTheme.radii.sm,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final entry in details.entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: _DetailRow(label: entry.key, value: entry.value),
            ),
          if (stackTrace.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Stack Trace:',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            SelectableText(
              stackTrace,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
                fontSize: 11,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Center(
            child: TextButton.icon(
              onPressed: () async {
                await Clipboard.setData(
                  ClipboardData(text: formattedDetails),
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Error details copied to clipboard'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.copy, size: 16),
              label: const Text('Copy details'),
            ),
          ),
        ],
      ),
    );
  }
}

/// A single row in the technical details panel.
class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            '$label:',
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Expanded(
          child: SelectableText(
            value,
            style: theme.textTheme.bodySmall?.copyWith(
              fontFamily: 'monospace',
            ),
          ),
        ),
      ],
    );
  }
}
