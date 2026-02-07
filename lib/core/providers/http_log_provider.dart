import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';
import 'package:soliplex_client/soliplex_client.dart';
import 'package:soliplex_frontend/core/logging/loggers.dart';

/// Notifier that stores HTTP events and implements [HttpObserver].
///
/// Provides app-wide HTTP traffic logging for debugging and inspection.
/// Events are stored in chronological order as they occur. Oldest events
/// are dropped when [maxEvents] is exceeded to prevent unbounded memory growth.
///
/// **Security**: All sensitive data (headers, URIs, bodies) is redacted by
/// [ObservableHttpClient] before events reach this provider. Events stored
/// here are already safe for display.
///
/// **Timing**: Events are processed asynchronously via [scheduleMicrotask].
/// State updates may be delayed by one microtask tick after the HTTP event
/// occurs. This avoids Riverpod build-time mutation errors when HTTP requests
/// happen during provider initialization.
///
/// **Storage**: This provider's state MUST NOT be persisted to disk. HTTP logs
/// may contain sensitive debugging information that should only exist in memory
/// during the current session.
///
/// Example:
/// ```dart
/// // Access events
/// final events = ref.watch(httpLogProvider);
///
/// // Clear log
/// ref.read(httpLogProvider.notifier).clear();
/// ```
@doNotStore
class HttpLogNotifier extends Notifier<List<HttpEvent>>
    implements HttpObserver {
  /// Maximum number of events to retain.
  static const maxEvents = 500;

  @override
  List<HttpEvent> build() => [];

  void _addEvent(HttpEvent event) {
    // Defer state update to avoid Riverpod errors when called during
    // another provider's initialization (e.g., FutureProvider making HTTP
    // requests during build).
    scheduleMicrotask(() {
      final newState = [...state, event];
      state = newState.length > maxEvents
          ? newState.sublist(newState.length - maxEvents)
          : newState;
    });
  }

  final _suppressedRequestIds = <String>{};
  final _requestInfoById = <String, String>{};

  @override
  void onRequest(HttpRequestEvent event) {
    if (event.uri.path.endsWith('/v1/logs')) {
      _suppressedRequestIds.add(event.requestId);
    } else {
      _requestInfoById[event.requestId] = '${event.method} ${event.uri}';
      Loggers.http.debug(
        '${event.method} ${event.uri}',
        attributes: {
          'http.request_id': event.requestId,
          'http.type': 'request',
        },
      );
    }
    _addEvent(event);
  }

  @override
  void onResponse(HttpResponseEvent event) {
    if (_suppressedRequestIds.remove(event.requestId)) {
      _requestInfoById.remove(event.requestId);
    } else {
      final info = _requestInfoById.remove(event.requestId);
      Loggers.http.debug(
        '${event.statusCode} $info',
        attributes: {
          'http.request_id': event.requestId,
          'http.type': 'response',
          'http.status_code': event.statusCode,
        },
      );
    }
    _addEvent(event);
  }

  @override
  void onError(HttpErrorEvent event) {
    _suppressedRequestIds.remove(event.requestId);
    _requestInfoById.remove(event.requestId);
    // Note: HttpErrorEvent does not carry a StackTrace from the call site.
    // The stack trace is lost at the ObservableHttpClient boundary.
    Loggers.http.error(
      '${event.method} ${event.uri}',
      error: event.exception,
      attributes: {
        'http.request_id': event.requestId,
        'http.type': 'error',
      },
    );
    _addEvent(event);
  }

  @override
  void onStreamStart(HttpStreamStartEvent event) => _addEvent(event);

  @override
  void onStreamEnd(HttpStreamEndEvent event) => _addEvent(event);

  /// Clears all stored HTTP events.
  void clear() {
    state = [];
  }
}

/// Provider for HTTP event logging.
///
/// The notifier implements [HttpObserver] and can be passed to
/// [ObservableHttpClient] to capture all HTTP traffic.
///
/// **Do not persist**: This provider's state should never be saved to disk.
final httpLogProvider = NotifierProvider<HttpLogNotifier, List<HttpEvent>>(
  HttpLogNotifier.new,
);
