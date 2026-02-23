/// Lightweight AG-UI test harness for client-side tool calling.
///
/// This harness is **intentionally not a full AG-UI protocol mock**. It covers
/// only the behaviors needed for tool-call orchestration tests (Slices 2-3):
///
/// **What it provides:**
/// - Deterministic event stream replay from inline event lists
/// - Multi-run sequencing (Run 1 → tool calls → Run 2 → text response)
/// - Call counting for verifying continuation run count
///
/// **What it does NOT model:**
/// - `CancelToken` propagation or cancellation semantics
/// - Input validation (endpoint format, message content)
/// - SSE parsing, HTTP transport, or network errors
/// - Retry/backoff logic
/// - Resource cleanup beyond no-op `close()`
///
/// For tests that need cancellation or error injection, use `MockAgUiClient`
/// from `test_helpers.dart` (mocktail-based) instead.
library;

import 'dart:async';

import 'package:soliplex_client/soliplex_client.dart';

/// Builds a mock AG-UI event stream from a list of events.
///
/// Wraps [Stream.fromIterable] with optional per-event delay for timing tests.
/// Tests compose event lists inline — no scenario-builder classes needed.
///
/// Used by tool-call integration tests to simulate backend responses without
/// network calls.
Stream<BaseEvent> buildMockEventStream(
  List<BaseEvent> events, {
  Duration? interEventDelay,
}) {
  if (interEventDelay == null) {
    return Stream.fromIterable(events);
  }
  return Stream.fromIterable(events).asyncMap((event) async {
    await Future<void>.delayed(interEventDelay);
    return event;
  });
}

/// Fake AG-UI client for deterministic tool-call testing.
///
/// Extends [AgUiClient] with only [runAgent] and [close] overridden.
/// All other methods (convenience endpoints, retry logic) inherit from
/// [AgUiClient] but delegate to the overridden [runAgent].
///
/// **Use cases:**
/// - Verifying multi-hop tool execution (Run 1 → tools → Run 2 → text)
/// - Counting continuation runs via [runAgentCallCount]
/// - Returning different event streams per call via [onRunAgent]
///
/// **Not suitable for:** cancellation tests, error injection, timeout
/// simulation. Use `MockAgUiClient` (mocktail) for those scenarios.
class FakeAgUiClient extends AgUiClient {
  /// Creates a fake client with a dummy configuration.
  FakeAgUiClient() : super(config: AgUiClientConfig(baseUrl: 'http://fake'));

  /// Callback invoked for each [runAgent] call.
  ///
  /// Tests set this to return different streams for Run 1 vs Run 2.
  Stream<BaseEvent> Function(String endpoint, SimpleRunAgentInput input)?
      onRunAgent;

  /// Number of times [runAgent] has been called.
  int runAgentCallCount = 0;

  @override
  Stream<BaseEvent> runAgent(
    String endpoint,
    SimpleRunAgentInput input, {
    CancelToken? cancelToken,
  }) {
    runAgentCallCount++;
    if (onRunAgent != null) return onRunAgent!(endpoint, input);
    return const Stream.empty();
  }

  @override
  Future<void> close() async {}
}
