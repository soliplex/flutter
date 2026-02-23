import 'dart:async';

import 'package:soliplex_client/soliplex_client.dart';

/// Builds a mock AG-UI event stream from a list of events.
///
/// Wraps [Stream.fromIterable] with optional per-event delay for timing tests.
/// Tests compose event lists inline — no scenario-builder classes needed.
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

/// Fake AG-UI client for deterministic testing.
///
/// Returns pre-configured event streams via [onRunAgent] callback.
/// Tracks call count for multi-run verification.
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
