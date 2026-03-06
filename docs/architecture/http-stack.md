# HTTP Networking Stack Architecture

The Soliplex HTTP stack lives in `packages/soliplex_client/lib/src/http/` and
provides a decorator-based transport layer for REST and SSE communication.

## Decorator Chain

Requests flow through a chain of decorators, each with a single
responsibility. The chain is composed at app startup in
`lib/core/providers/api_provider.dart`.

```text
HttpTransport          JSON encode/decode, status-to-exception mapping
  |
  v
RefreshingHttpClient   Proactive token refresh + reactive 401 retry (REST only)
  |
  v
AuthenticatedHttpClient   Injects Bearer token header
  |
  v
ObservableHttpClient   Emits events to HttpObserver list
  |
  v
Platform Client        DartHttpClient (all platforms) or
                       CupertinoHttpClient (iOS/macOS, in soliplex_client_native)
```

Every layer implements `SoliplexHttpClient`, the common interface defined in
`soliplex_http_client.dart`. This makes the chain composable: any subset of
decorators can be used, and new decorators slot in without changing existing
code.

### What each layer does

**HttpTransport** (`http_transport.dart`)
Top of the stack. Converts `Map` bodies to JSON, decodes JSON responses,
and maps HTTP status codes to typed exceptions (`AuthException`,
`NotFoundException`, `ApiException`). Also handles `CancelToken` for both
REST and SSE paths.

**RefreshingHttpClient** (`refreshing_http_client.dart`)
Calls `refresher.refreshIfExpiringSoon()` before every request. For REST
requests, if the response is 401 it attempts a single refresh-and-retry.
For SSE streams, only proactive refresh runs (mid-stream retry is not
possible). Concurrent refresh attempts are deduplicated via a `Completer`.

**AuthenticatedHttpClient** (`authenticated_http_client.dart`)
Injects `Authorization: Bearer <token>` on every request. The token is
obtained via a callback `String? Function()` provided at construction.

**ObservableHttpClient** (`observable_http_client.dart`)
Wraps requests and streams with observer notifications. All sensitive data
(headers, URIs, bodies) is redacted via `HttpRedactor` before reaching
observers. Observer exceptions are caught and swallowed so they never break
the request flow.

**Platform clients** (`dart_http_client.dart`, `cupertino_http_client.dart`)
Convert platform HTTP exceptions to `NetworkException`. Both implement
identical error handling: `TimeoutException`, `http.ClientException`, and
generic `Exception` are all caught and wrapped.

## Interface: SoliplexHttpClient

```dart
abstract class SoliplexHttpClient {
  Future<HttpResponse> request(
    String method, Uri uri, {
    Map<String, String>? headers,
    Object? body,
    Duration? timeout,
  });

  Future<StreamedHttpResponse> requestStream(
    String method, Uri uri, {
    Map<String, String>? headers,
    Object? body,
    CancelToken? cancelToken,
  });

  void close();
}
```

Two paths: `request()` for REST (buffered body), `requestStream()` for SSE
(streaming body). The `CancelToken` parameter only appears on
`requestStream()` because REST requests are short-lived and use timeout
instead.

## Response Types

**HttpResponse** (`http_response.dart`)
Immutable. Contains `statusCode`, `bodyBytes` (`Uint8List`), `headers`,
`reasonPhrase`. Convenience getters: `body` (UTF-8 decoded string),
`isSuccess`, `contentType`, `contentLength`.

**StreamedHttpResponse** (`http_response.dart`)
Immutable metadata + streaming body. Contains `statusCode`, `headers`,
`reasonPhrase`, and `body` (`Stream<List<int>>`). The body stream must be
listened to exactly once.

## CancelToken Flow

`CancelToken` (`src/utils/cancel_token.dart`) enables cooperative
cancellation. It has `cancel()`, `isCancelled`, `throwIfCancelled()`, and
`whenCancelled` (a Future for async listeners).

### REST path

```text
HttpTransport.request()
  token.throwIfCancelled()       // pre-flight check
  _client.request(...)           // no token passed down
  token.throwIfCancelled()       // post-flight check
```

REST requests rely on pre/post checks. The token is not passed to the
underlying client.

### SSE path

```text
HttpTransport.requestStream()
  token.throwIfCancelled()       // pre-flight check
  _client.requestStream(..., cancelToken: token)   // threaded through
  token.throwIfCancelled()       // post-connection check
  _wrapStreamWithCancellation()  // body stream wrapper
```

The token is threaded through every decorator so platform clients can bail
out early. After connection, the body stream is wrapped: when the token
fires, a `CancelledException` is injected into the stream and the
underlying subscription is cancelled.

### AgUiStreamClient

`AgUiStreamClient` (`agui_stream_client.dart`) routes AG-UI SSE streams
directly through `SoliplexHttpClient`. It calls `requestStream()` with
the `CancelToken` as a method argument — no shared mutable state.

```dart
final client = AgUiStreamClient(
  httpClient: soliplexHttpClient,
  urlBuilder: UrlBuilder(baseUrl),
);

await for (final event in client.runAgent(endpoint, input, cancelToken: token)) {
  // typed BaseEvent instances
}
```

The response body is parsed via ag_ui's `SseParser` (WHATWG SSE byte
parser) and `EventDecoder` (JSON → typed `BaseEvent`). Status codes are
checked before parsing — non-2xx responses drain the body and throw
`ApiException`.

## Stream Lifecycle

SSE streams go through 5 phases:

```text
1. Connection    POST/GET to SSE endpoint, await response headers
2. Status check  HttpTransport maps 401/404/5xx to exceptions (drains body)
3. Body stream   Consumer listens to Stream<List<int>>
4. Completion    Stream closes normally (onDone) or with error (onError)
5. Cleanup       Subscription cancelled, observer notified
```

**Error handling rules:**

- Connection errors (phase 1) throw `NetworkException` before the body
  stream is set up. `ObservableHttpClient` emits `onStreamStart` but not
  `onStreamEnd`.
- Status errors (phase 2) throw typed exceptions. `HttpTransport` drains
  the body stream to release the socket.
- Body errors (phase 3-4) are forwarded through the stream. If cancel
  token is active, `CancelledException` is injected.
- Subscription cancellation (phase 5) triggers `ObservableHttpClient`'s
  `onStreamEnd` with final byte count.

## Observer Events

`ObservableHttpClient` emits events through the `HttpObserver` interface:

| Path | Events |
|------|--------|
| REST | `onRequest` -> `onResponse` or `onError` |
| SSE  | `onStreamStart` -> `onStreamEnd` (includes byte count, error if any) |

All data is redacted via `HttpRedactor` before reaching observers. Observer
exceptions are caught and swallowed (debug-only `assert` prints a warning).

Each request gets a unique `requestId` for correlation across events.

## Platform Parity

Both `DartHttpClient` and `CupertinoHttpClient` implement identical
contracts:

- Same exception wrapping: `TimeoutException`, `ClientException`, generic
  `Exception` all become `NetworkException`
- Same `CancelToken` checks: `throwIfCancelled()` before send, after
  response headers arrive
- Same body encoding: `String`, `List<int>`, `Map<String, dynamic>`
- Same header normalization: keys lowercased in response
- Same close guard: `StateError` if used after `close()`

`CupertinoHttpClient` lives in `packages/soliplex_client_native/` because
it depends on `cupertino_http` (Apple-only FFI). It imports `CancelToken`
from the public export `package:soliplex_client/cancel_token.dart`.

## Exception Hierarchy

```text
SoliplexException (abstract)
  AuthException          401/403 responses
  NotFoundException      404 responses
  ApiException           other 4xx/5xx responses
  NetworkException       connection failures, timeouts
  CancelledException     user-initiated cancellation
```

`HttpTransport` maps status codes to exceptions. Platform clients map
low-level errors to `NetworkException`. All exceptions preserve
`originalError` and `stackTrace`.

## Troubleshooting

**SSE connection drops silently**
Check `ObservableHttpClient` stream end events. If `onStreamEnd.isSuccess`
is false, the error field contains the cause. Common causes: server timeout
(no keepalive), network change, or `CancelToken` fired.

**401 on SSE but not on REST**
`RefreshingHttpClient` does proactive refresh before both REST and SSE.
However, only REST gets reactive retry on 401. If the token expires
mid-stream setup, the SSE path throws `AuthException` immediately. See
Slice G in the roadmap for planned improvements.

**CancelToken not stopping the stream**
Verify the token reaches the platform client. `AgUiStreamClient` passes
`cancelToken` directly to `requestStream()`, which threads it through
every decorator to the platform client. Check the decorator chain
composition in `api_provider.dart`.

**Observer not seeing events**
`ObservableHttpClient` must be explicitly composed into the chain. It is
not automatic. Verify the decorator order in `api_provider.dart`.

## File Index

| File | Role |
|------|------|
| `soliplex_http_client.dart` | Interface: `SoliplexHttpClient` |
| `http_response.dart` | `HttpResponse`, `StreamedHttpResponse` |
| `http_transport.dart` | JSON layer, exception mapping, cancel wrapping |
| `refreshing_http_client.dart` | Token refresh decorator |
| `authenticated_http_client.dart` | Bearer token injection decorator |
| `observable_http_client.dart` | Observer notification decorator |
| `dart_http_client.dart` | Pure Dart platform client |
| `agui_stream_client.dart` | AG-UI SSE streaming via SoliplexHttpClient |
| `http_observer.dart` | Observer interface and event types |
| `http_redactor.dart` | Sensitive data redaction |
| `token_refresher.dart` | Token refresh interface |
| `http.dart` | Barrel file exporting all HTTP types |
