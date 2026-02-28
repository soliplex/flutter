import 'package:ag_ui/ag_ui.dart';
import 'package:dart_monty_platform_interface/dart_monty_platform_interface.dart';
import 'package:dart_monty_platform_interface/dart_monty_testing.dart';
import 'package:soliplex_interpreter_monty/soliplex_interpreter_monty.dart';
import 'package:test/test.dart';

/// Shared resource-usage stub for integration tests.
const stubUsage = MontyResourceUsage(
  memoryBytesUsed: 1024,
  timeElapsedMs: 10,
  stackDepthUsed: 5,
);

/// Describes an integration test room.
class RoomFixture {
  const RoomFixture({
    required this.name,
    required this.layer,
    required this.functions,
    required this.progressQueue,
    required this.pythonCode,
    required this.expectedEventTypes,
  });

  /// Human-readable room name (e.g. "calculator").
  final String name;

  /// 0 = pure execution, 1 = client-side tool calls, 2 = agentic pipeline.
  final int layer;

  /// Host functions to register on the bridge.
  final List<HostFunction> functions;

  /// Mock platform progress sequence (simulates Monty runtime).
  final List<MontyProgress> progressQueue;

  /// Python code to execute.
  final String pythonCode;

  /// Expected event type sequence from `bridge.execute(code)`.
  final List<Type> expectedEventTypes;
}

/// Creates a [MockMontyPlatform] with the given progress sequence pre-queued.
MockMontyPlatform buildMockPlatform(List<MontyProgress> progressQueue) {
  final mock = MockMontyPlatform();
  progressQueue.forEach(mock.enqueueProgress);

  return mock;
}

/// Asserts that [events] match the expected [types] in order.
void assertEventSequence(List<BaseEvent> events, List<Type> types) {
  expect(
    events.map((e) => e.runtimeType).toList(),
    equals(types),
    reason: 'Event sequence mismatch.\n'
        'Expected: ${types.map((t) => t.toString()).join(', ')}\n'
        'Actual:   ${events.map((e) => e.runtimeType.toString()).join(', ')}',
  );
}

/// Finds the first [ToolCallResultEvent] whose preceding [ToolCallStartEvent]
/// has the given [toolName].
ToolCallResultEvent? findToolCallResult(
  List<BaseEvent> events,
  String toolName,
) {
  for (var i = 0; i < events.length; i++) {
    final e = events[i];
    if (e is ToolCallStartEvent && e.toolCallName == toolName) {
      // Walk forward to find the matching ToolCallResultEvent.
      for (var j = i + 1; j < events.length; j++) {
        if (events[j] is ToolCallResultEvent) {
          return events[j] as ToolCallResultEvent;
        }
        if (events[j] is ToolCallStartEvent) break; // next tool call
      }
    }
  }

  return null;
}

/// Runs a [RoomFixture] end-to-end: builds mock, registers functions,
/// executes code, and returns collected events.
Future<List<BaseEvent>> runRoom(RoomFixture room) async {
  final mock = buildMockPlatform(room.progressQueue);
  final bridge = DefaultMontyBridge(platform: mock);

  room.functions.forEach(bridge.register);

  try {
    return await bridge.execute(room.pythonCode).toList();
  } finally {
    bridge.dispose();
  }
}
