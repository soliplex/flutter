# HTTP Stack Extension Guide

How to extend the Soliplex HTTP networking stack with new protocols,
decorators, or platform clients.

## Adding a New Decorator

Decorators wrap `SoliplexHttpClient` to add cross-cutting behavior. The
existing chain is: Refreshing -> Authenticated -> Observable -> Platform.

### Steps

1. Create `packages/soliplex_client/lib/src/http/your_decorator.dart`
2. Implement `SoliplexHttpClient`
3. Delegate all methods to an inner `SoliplexHttpClient`
4. Add your behavior before or after delegation
5. Export from `http.dart` barrel
6. Compose into the chain in `lib/core/providers/api_provider.dart`

### Template

```dart
import 'package:soliplex_client/src/http/http_response.dart';
import 'package:soliplex_client/src/http/soliplex_http_client.dart';
import 'package:soliplex_client/src/utils/cancel_token.dart';

class YourDecorator implements SoliplexHttpClient {
  YourDecorator({required SoliplexHttpClient inner}) : _inner = inner;

  final SoliplexHttpClient _inner;

  @override
  Future<HttpResponse> request(
    String method,
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
    Duration? timeout,
  }) async {
    // Your logic before
    final response = await _inner.request(
      method, uri,
      headers: headers, body: body, timeout: timeout,
    );
    // Your logic after
    return response;
  }

  @override
  Future<StreamedHttpResponse> requestStream(
    String method,
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
    CancelToken? cancelToken,
  }) async {
    // Your logic before
    final response = await _inner.requestStream(
      method, uri,
      headers: headers, body: body, cancelToken: cancelToken,
    );
    // Your logic after (careful: body is a stream, not buffered)
    return response;
  }

  @override
  void close() => _inner.close();
}
```

### Key rules

- Always forward `cancelToken` on `requestStream`. Dropping it breaks
  cancellation for the entire chain.
- Always forward `timeout` on `request`. Dropping it removes timeout
  protection.
- Do not buffer the body stream in `requestStream`. Return it as-is or
  wrap it in a `StreamController` that forwards events.
- Throw only `SoliplexException` subtypes. Other exceptions bypass
  `ObservableHttpClient`'s error tracking.

## Adding a New Platform Client

Platform clients sit at the bottom of the decorator chain and translate
platform HTTP to `SoliplexHttpClient`.

### Platform client steps

1. Create in `packages/soliplex_client_native/` (if platform-specific) or
   `packages/soliplex_client/` (if pure Dart)
2. Implement `SoliplexHttpClient`
3. Wrap all platform exceptions in `NetworkException`
4. Implement `CancelToken` checks in `requestStream`
5. Normalize response headers to lowercase keys

### Exception wrapping contract

Every platform client must catch platform exceptions and wrap them:

```dart
try {
  // platform HTTP call
} on TimeoutException catch (e, st) {
  throw NetworkException(
    message: e.message ?? 'Request timed out',
    isTimeout: true, originalError: e, stackTrace: st,
  );
} on http.ClientException catch (e, st) {
  throw NetworkException(
    message: 'Client error: ${e.message}',
    originalError: e, stackTrace: st,
  );
} on Exception catch (e, st) {
  throw NetworkException(
    message: 'Network error: $e',
    originalError: e, stackTrace: st,
  );
}
```

### CancelToken integration

In `requestStream`, check the token at two points:

```dart
@override
Future<StreamedHttpResponse> requestStream(...) async {
  _checkNotClosed();
  cancelToken?.throwIfCancelled();  // Before send

  final response = await _platformSend(request);

  cancelToken?.throwIfCancelled();  // After headers arrive

  return StreamedHttpResponse(
    statusCode: response.statusCode,
    headers: _normalizeHeaders(response.headers),
    body: response.stream,
  );
}
```

### Import pattern for cross-package CancelToken

The barrel `soliplex_client.dart` hides ag_ui's `CancelToken` and exports
ours directly. For most code, a plain import is sufficient:

```dart
import 'package:soliplex_client/soliplex_client.dart';
// CancelToken is our type — ag_ui's is hidden at the barrel level.
```

Cross-package code (e.g., `soliplex_client_native`) can also use the
dedicated export `package:soliplex_client/cancel_token.dart`.

## Adding a New Protocol (WebSocket, A2A)

For protocols that don't fit the REST/SSE model, you have two options:

### Option A: Extend SoliplexHttpClient

If the protocol uses HTTP for connection setup (like WebSocket upgrade),
add a new method to the interface. This is a breaking change that requires
updating all decorators.

### Option B: Separate interface

If the protocol is fundamentally different, create a new interface in
`packages/soliplex_client/lib/src/` and compose it alongside the HTTP stack
rather than inside it. This avoids forcing HTTP decorators to handle
non-HTTP concerns.

**Recommended:** Option B for most cases. The HTTP decorator chain is
optimized for request/response and streaming patterns. WebSocket
bidirectional communication or A2A agent-to-agent protocols have different
lifecycle requirements.

## Adding an HttpObserver

Observers receive redacted event notifications from `ObservableHttpClient`.

### Observer steps

1. Implement `HttpObserver` from `http_observer.dart`
2. Register in `ObservableHttpClient(observers: [yourObserver])`
3. Handle all 5 event types (even if some are no-ops)

### Observer template

```dart
class YourObserver implements HttpObserver {
  @override
  void onRequest(HttpRequestEvent event) {
    // event.requestId, method, uri, headers, body, timestamp
  }

  @override
  void onResponse(HttpResponseEvent event) {
    // event.requestId, statusCode, duration, bodySize, headers, body
  }

  @override
  void onError(HttpErrorEvent event) {
    // event.requestId, method, uri, exception, duration
  }

  @override
  void onStreamStart(HttpStreamStartEvent event) {
    // event.requestId, method, uri, headers, body, timestamp
  }

  @override
  void onStreamEnd(HttpStreamEndEvent event) {
    // event.requestId, bytesReceived, duration, error, body
  }
}
```

### Observer rules

- Never throw from observer methods. `ObservableHttpClient` catches
  exceptions, but throwing wastes cycles and pollutes debug logs.
- All data is redacted. Do not attempt to reconstruct sensitive data
  from observer events.
- `onStreamEnd` may not fire if the connection fails during setup (before
  the body stream is established). Use `onStreamStart` to track in-flight
  streams and timeout detection for cleanup.
