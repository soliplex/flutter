# Milestone 11: X-Request-ID Correlation

**Status:** completed
**Depends on:** 01-essential-logging-api

## Objective

Inject a unique `x-request-id` header into every outgoing HTTP request so
client-side and server-side logs can be correlated by the same identifier.

## Current State

`ObservableHttpClient` already generates a per-request `requestId`
(`timestamp-counter` format) for internal event correlation. However, this
ID is **never sent to the server** as an HTTP header. The server has no way
to correlate its logs with a specific client request.

## Proposed Change

1. Replace the default `timestamp-counter` ID generator with UUID v4
2. Inject the generated ID as an `x-request-id` header on outgoing requests
3. Respect caller-supplied `x-request-id` headers for trace propagation
4. Include the `x-request-id` in client-side HTTP log entries (already done
   via `HttpRequestEvent.requestId`)

## Files to Modify

| File | Change |
|------|--------|
| `packages/soliplex_client/pubspec.yaml` | Add `uuid` dependency |
| `packages/soliplex_client/lib/src/http/observable_http_client.dart` | Inject `x-request-id` header; switch default generator to UUID v4 |
| `packages/soliplex_client/test/observable_http_client_test.dart` | Test header injection and UUID format |

## Implementation Steps

### Step 1: Add uuid dependency

```yaml
# packages/soliplex_client/pubspec.yaml
dependencies:
  uuid: ^4.0.0
```

### Step 2: Update ObservableHttpClient

In `observable_http_client.dart`:

- Change `_defaultRequestIdGenerator` to use `Uuid().v4()`
- Remove unused `static int _requestCounter` field
- In `request()`: respect existing `x-request-id` header if present,
  otherwise generate one. Merge into headers before calling
  `_client.request()`
- In `requestStream()`: same header injection before calling
  `_client.requestStream()`
- Use the resolved ID (caller-supplied or generated) as the `requestId`
  in all observer events for that request

```dart
static final _uuid = Uuid();

static String _defaultRequestIdGenerator() => _uuid.v4();

// In request() and requestStream():
final requestId = headers?['x-request-id'] ?? _generateRequestId();
final enrichedHeaders = {
  ...?headers,
  'x-request-id': requestId,
};
// Pass enrichedHeaders to _client.request() instead of headers
```

### Step 3: Verify HttpRedactor passthrough

`x-request-id` is NOT redacted. The redactor only targets known sensitive
header names (`authorization`, `cookie`, `x-api-key`, and substrings like
`token`, `secret`, `auth`, `password`). `x-request-id` matches none of
these. Verify with a test.

### Step 4: Tests

- Verify `x-request-id` header is present on outgoing requests
- Verify the header value matches the `requestId` in observer events
- Verify caller-supplied `x-request-id` is preserved (not overwritten)
- Verify custom `generateRequestId` callback still works
- Verify `x-request-id` is visible (not redacted) in observer events
- Verify streaming requests also get the header

### Step 5: Quality gates

- `dart format`
- `dart analyze` (0 issues)
- `dart test packages/soliplex_client` (all pass)
- `flutter test` (all pass)

## Design Decisions

**UUID v4 over timestamp-counter:** UUIDs are globally unique across
devices and sessions, making them safe for multi-client correlation.
The timestamp-counter format could collide across app restarts or
devices.

**Header name `x-request-id`:** Industry standard. Supported by most
server frameworks (Express, FastAPI, Spring), API gateways (Kong, AWS
ALB), and observability tools (Datadog, Sentry) out of the box.

**Injection point:** `ObservableHttpClient` is the right layer because
it already owns request ID generation and sits below auth decorators,
ensuring every request (including retries) gets a unique ID.

**Respect caller-supplied IDs:** If the caller already set an
`x-request-id` header (e.g., propagating a server-side trace context),
use that value instead of generating a new one. This supports distributed
tracing scenarios where an upstream service passes a correlation ID.

**Retry semantics:** When `RefreshingHttpClient` retries a 401, the
retry passes through `ObservableHttpClient.request()` again and gets a
**new** `x-request-id`. This is correct for HTTP-level correlation (each
wire transmission gets its own ID). A higher-level "logical request" ID
spanning retries is out of scope for this milestone.

## Validation Gate

- [x] `dart format --set-exit-if-changed packages/soliplex_client`
- [x] `dart analyze --fatal-infos packages/soliplex_client`
- [x] `dart test packages/soliplex_client`
- [x] `flutter test`
- [ ] Manual: inspect outgoing request headers in Network Inspector,
      confirm `x-request-id` is a valid UUID v4
