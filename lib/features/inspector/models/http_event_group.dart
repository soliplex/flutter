import 'dart:convert';

import 'package:soliplex_client/soliplex_client.dart';

/// Status of an HTTP event group.
enum HttpEventStatus {
  pending,
  success,
  clientError,
  serverError,
  networkError,
  streaming,
  streamComplete,
  streamError,
}

/// Groups related HTTP events by requestId.
///
/// Correlates request/response pairs and streaming events into a single
/// logical unit for display and analysis.
class HttpEventGroup {
  HttpEventGroup({
    required this.requestId,
    this.request,
    this.response,
    this.error,
    this.streamStart,
    this.streamEnd,
  });

  final String requestId;
  final HttpRequestEvent? request;
  final HttpResponseEvent? response;
  final HttpErrorEvent? error;
  final HttpStreamStartEvent? streamStart;
  final HttpStreamEndEvent? streamEnd;

  HttpEventGroup copyWith({
    HttpRequestEvent? request,
    HttpResponseEvent? response,
    HttpErrorEvent? error,
    HttpStreamStartEvent? streamStart,
    HttpStreamEndEvent? streamEnd,
  }) =>
      HttpEventGroup(
        requestId: requestId,
        request: request ?? this.request,
        response: response ?? this.response,
        error: error ?? this.error,
        streamStart: streamStart ?? this.streamStart,
        streamEnd: streamEnd ?? this.streamEnd,
      );

  bool get isStream => streamStart != null;

  /// UI label for the request method.
  ///
  /// Returns 'SSE' for streams, HTTP method otherwise.
  String get methodLabel => isStream ? 'SSE' : method;

  /// Returns the HTTP method from the first available event.
  ///
  /// Throws [StateError] if no event contains method information.
  /// Check [hasEvents] before accessing if the group may be incomplete.
  String get method {
    if (request case HttpRequestEvent(:final method)) return method;
    if (error case HttpErrorEvent(:final method)) return method;
    if (streamStart case HttpStreamStartEvent(:final method)) return method;
    throw StateError('HttpEventGroup $requestId has no event with method');
  }

  /// Returns the URI from the first available event.
  ///
  /// Throws [StateError] if no event contains URI information.
  /// Check [hasEvents] before accessing if the group may be incomplete.
  Uri get uri {
    if (request case HttpRequestEvent(:final uri)) return uri;
    if (error case HttpErrorEvent(:final uri)) return uri;
    if (streamStart case HttpStreamStartEvent(:final uri)) return uri;
    throw StateError('HttpEventGroup $requestId has no event with uri');
  }

  String get pathWithQuery {
    final u = uri;
    final path = u.path.isEmpty ? '/' : u.path;
    if (u.hasQuery) {
      return '$path?${u.query}';
    }
    return path;
  }

  /// Returns request headers from the first available event.
  ///
  /// Works for both regular requests and SSE streams.
  /// Returns empty map if no headers available.
  Map<String, String> get requestHeaders {
    if (request case HttpRequestEvent(:final headers)) return headers;
    if (streamStart case HttpStreamStartEvent(:final headers)) return headers;
    return const {};
  }

  /// Returns request body from the first available event.
  ///
  /// Works for both regular requests and SSE streams.
  /// Returns null if no body available.
  dynamic get requestBody {
    if (request case HttpRequestEvent(:final body)) return body;
    if (streamStart case HttpStreamStartEvent(:final body)) return body;
    return null;
  }

  /// Returns the timestamp from the first available event.
  ///
  /// Throws [StateError] if no event contains timestamp information.
  /// Check [hasEvents] before accessing if the group may be incomplete.
  DateTime get timestamp {
    if (request case HttpRequestEvent(:final timestamp)) return timestamp;
    if (streamStart case HttpStreamStartEvent(:final timestamp)) {
      return timestamp;
    }
    if (error case HttpErrorEvent(:final timestamp)) return timestamp;
    throw StateError('HttpEventGroup $requestId has no event with timestamp');
  }

  /// Whether this group contains at least one event.
  ///
  /// An incomplete group (no events) will throw [StateError] when accessing
  /// [method], [uri], or [timestamp]. Check this property first if the group
  /// may be incomplete.
  bool get hasEvents =>
      request != null ||
      response != null ||
      error != null ||
      streamStart != null ||
      streamEnd != null;

  /// Determines the aggregate status of this event group.
  ///
  /// Precedence: stream state > error > response status code.
  /// Streams check completion and error state first. For non-streams,
  /// network errors take precedence over missing responses (pending).
  HttpEventStatus get status {
    if (isStream) {
      return switch (streamEnd) {
        null => HttpEventStatus.streaming,
        HttpStreamEndEvent(error: _?) => HttpEventStatus.streamError,
        HttpStreamEndEvent() => HttpEventStatus.streamComplete,
      };
    }

    if (error != null) return HttpEventStatus.networkError;

    return switch (response) {
      null => HttpEventStatus.pending,
      HttpResponseEvent(statusCode: final code) when code >= 500 =>
        HttpEventStatus.serverError,
      HttpResponseEvent(statusCode: final code) when code >= 400 =>
        HttpEventStatus.clientError,
      HttpResponseEvent() => HttpEventStatus.success,
    };
  }

  /// Whether this status should display a spinner.
  bool get hasSpinner =>
      status == HttpEventStatus.pending || status == HttpEventStatus.streaming;

  /// Human-readable description of the current status for accessibility.
  String get statusDescription {
    return switch ((status, response, error)) {
      (HttpEventStatus.pending, _, _) => 'pending',
      (HttpEventStatus.success, HttpResponseEvent(:final statusCode), _) =>
        'success, status $statusCode',
      (HttpEventStatus.clientError, HttpResponseEvent(:final statusCode), _) =>
        'client error, status $statusCode',
      (HttpEventStatus.serverError, HttpResponseEvent(:final statusCode), _) =>
        'server error, status $statusCode',
      (HttpEventStatus.networkError, _, HttpErrorEvent(:final exception)) =>
        'network error, ${exception.runtimeType}',
      (HttpEventStatus.streaming, _, _) => 'streaming',
      (HttpEventStatus.streamComplete, _, _) => 'stream complete',
      (HttpEventStatus.streamError, _, _) => 'stream error',
      // Fallback for impossible states (status implies response/error exists)
      _ => status.name,
    };
  }

  /// Semantic label describing this request for accessibility.
  String get semanticLabel {
    final methodText = isStream ? 'SSE stream' : '$method request';
    return '$methodText to $pathWithQuery, $statusDescription';
  }

  /// Formats a body value as pretty-printed JSON if possible.
  ///
  /// Returns the original value as a string if JSON encoding fails.
  static String formatBody(dynamic body) {
    if (body == null) return '';
    if (body is String) {
      // Try to parse and re-format JSON strings
      try {
        final parsed = jsonDecode(body);
        return _jsonEncoder.convert(parsed);
      } on FormatException {
        return body;
      }
    }
    // Already parsed JSON (Map/List) - encode directly, fallback to toString
    // for non-JSON-encodable objects
    try {
      return _jsonEncoder.convert(body);
    } on Object {
      return body.toString();
    }
  }

  static const _jsonEncoder = JsonEncoder.withIndent('  ');

  /// Generates a curl command that reproduces this request.
  ///
  /// The command includes method, headers, body (if present), and URL.
  /// Values are properly escaped for shell execution.
  ///
  /// Works for both regular requests and SSE streams.
  /// Returns null if no request data is available.
  String? toCurl() {
    // Need at least method and URI to generate curl
    if (!hasEvents) return null;
    if (request == null && streamStart == null) return null;

    final parts = <String>['curl'];

    // Method (skip for GET since it's the default)
    if (method != 'GET') {
      parts.add('-X $method');
    }

    // Headers (using unified accessor)
    for (final entry in requestHeaders.entries) {
      final escapedValue = _shellEscape(entry.value);
      parts.add("-H '${entry.key}: $escapedValue'");
    }

    // Body (using unified accessor)
    final body = requestBody;
    if (body != null) {
      final bodyString = body is String ? body : jsonEncode(body);
      final escapedBody = _shellEscape(bodyString);
      parts.add("-d '$escapedBody'");
    }

    // URL (must be last)
    parts.add("'${_shellEscape(uri.toString())}'");

    return parts.join(' \\\n  ');
  }

  /// Escapes a string for safe use in single-quoted shell arguments.
  ///
  /// In single quotes, only single quotes need escaping.
  /// The pattern 'foo'\''bar' ends the quote, adds escaped quote, resumes.
  static String _shellEscape(String value) {
    return value.replaceAll("'", r"'\''");
  }
}
