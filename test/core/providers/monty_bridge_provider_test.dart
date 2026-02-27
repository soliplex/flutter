import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:soliplex_client/soliplex_client.dart';
import 'package:soliplex_frontend/core/providers/api_provider.dart';
import 'package:soliplex_frontend/core/providers/rooms_provider.dart';
import 'package:soliplex_frontend/core/services/thread_bridge_cache.dart';
import 'package:soliplex_frontend/core/services/tool_execution_zone.dart';
import 'package:soliplex_monty/soliplex_monty.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class MockMontyBridge extends Mock implements MontyBridge {}

class FakeToolCallInfo extends Fake implements ToolCallInfo {}

/// Testable notifier that returns seeded mock bridges without FFI.
class _TestBridgeCacheNotifier extends ThreadBridgeCacheNotifier {
  final Map<({String roomId, String threadId}), MontyBridge> _mockBridges = {};

  void seedBridge(
    ({String roomId, String threadId}) key,
    MontyBridge bridge,
  ) {
    _mockBridges[key] = bridge;
  }

  @override
  MontyBridge getOrCreate(
    ({String roomId, String threadId}) key,
    List<ToolNameMapping> mappings,
  ) {
    final existing = bridges[key];
    if (existing != null) return existing;

    final bridge = _mockBridges[key] ?? MockMontyBridge();
    bridges[key] = bridge;
    state = Map.of(bridges);
    return bridge;
  }
}

// ---------------------------------------------------------------------------
// Test data
// ---------------------------------------------------------------------------

const _roomWithTools = Room(
  id: 'room-1',
  name: 'Test Room',
  toolDefinitions: [
    {
      'tool_name': 'soliplex.tools.get_time',
      'tool_description': 'Get current time',
      'kind': 'get_time',
    },
  ],
);

const _testKey = (roomId: 'room-1', threadId: 'thread-1');

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUpAll(() {
    registerFallbackValue(FakeToolCallInfo());
  });

  group('execute_python in toolRegistryProvider', () {
    test('present when room has tool definitions', () {
      final container = ProviderContainer(
        overrides: [
          currentRoomProvider.overrideWithValue(_roomWithTools),
          threadBridgeCacheProvider.overrideWith(
            _TestBridgeCacheNotifier.new,
          ),
        ],
      );
      addTearDown(container.dispose);

      final registry = container.read(toolRegistryProvider);

      expect(registry.contains(PythonExecutorTool.toolName), isTrue);
    });

    test('absent when no room selected', () {
      final container = ProviderContainer(
        overrides: [currentRoomProvider.overrideWithValue(null)],
      );
      addTearDown(container.dispose);

      final registry = container.read(toolRegistryProvider);

      expect(registry.contains(PythonExecutorTool.toolName), isFalse);
    });

    test('absent when room has no tool definitions', () {
      const emptyRoom = Room(id: 'room-1', name: 'Empty');

      final container = ProviderContainer(
        overrides: [currentRoomProvider.overrideWithValue(emptyRoom)],
      );
      addTearDown(container.dispose);

      final registry = container.read(toolRegistryProvider);

      expect(registry.contains(PythonExecutorTool.toolName), isFalse);
    });
  });

  group('execute_python executor', () {
    late MockMontyBridge mockBridge;
    late _TestBridgeCacheNotifier cacheNotifier;
    late ProviderContainer container;

    setUp(() {
      mockBridge = MockMontyBridge();
      cacheNotifier = _TestBridgeCacheNotifier()
        ..seedBridge(_testKey, mockBridge);
      container = ProviderContainer(
        overrides: [
          currentRoomProvider.overrideWithValue(_roomWithTools),
          threadBridgeCacheProvider.overrideWith(() => cacheNotifier),
        ],
      );
    });

    tearDown(() => container.dispose());

    /// Executes code via the execute_python tool inside a Zone with [_testKey].
    Future<String> executeInZone(String code) {
      final registry = container.read(toolRegistryProvider);
      return runInToolExecutionZone(
        _testKey,
        () => registry.execute(
          ToolCallInfo(
            id: 'test',
            name: PythonExecutorTool.toolName,
            arguments: jsonEncode({'code': code}),
          ),
        ),
      );
    }

    test('returns error when no thread context', () async {
      final registry = container.read(toolRegistryProvider);

      // Execute WITHOUT zone wrapper — activeThreadKey will be null.
      final result = await registry.execute(
        ToolCallInfo(
          id: 'test',
          name: PythonExecutorTool.toolName,
          arguments: jsonEncode({'code': 'print(1)'}),
        ),
      );

      expect(result, 'Error: No thread context for execute_python');
    });

    test('returns error on empty code', () async {
      final result = await executeInZone('');

      expect(result, 'Error: No code provided');
      verifyNever(() => mockBridge.execute(any()));
    });

    test('returns error on missing code key', () async {
      final registry = container.read(toolRegistryProvider);
      final result = await runInToolExecutionZone(
        _testKey,
        () => registry.execute(
          ToolCallInfo(
            id: 'test',
            name: PythonExecutorTool.toolName,
            arguments: jsonEncode(<String, dynamic>{}),
          ),
        ),
      );

      expect(result, 'Error: No code provided');
    });

    test('collects text output from bridge events', () async {
      when(() => mockBridge.execute(any())).thenAnswer((_) {
        return Stream.fromIterable([
          const RunStartedEvent(threadId: '1', runId: '1'),
          const TextMessageStartEvent(messageId: 'm1'),
          const TextMessageContentEvent(messageId: 'm1', delta: 'Hello '),
          const TextMessageEndEvent(messageId: 'm1'),
          const TextMessageStartEvent(messageId: 'm2'),
          const TextMessageContentEvent(messageId: 'm2', delta: 'World'),
          const TextMessageEndEvent(messageId: 'm2'),
          const RunFinishedEvent(threadId: '1', runId: '1'),
        ]);
      });

      final result = await executeInZone('print("Hello World")');

      expect(result, 'Hello World');
    });

    test('returns informative message when bridge produces no text', () async {
      when(() => mockBridge.execute(any())).thenAnswer((_) {
        return Stream.fromIterable([
          const RunStartedEvent(threadId: '1', runId: '1'),
          const RunFinishedEvent(threadId: '1', runId: '1'),
        ]);
      });

      final result = await executeInZone('x = 1');

      expect(result, 'Code executed successfully with no output.');
    });

    test('returns error message from RunErrorEvent', () async {
      when(() => mockBridge.execute(any())).thenAnswer((_) {
        return Stream.fromIterable([
          const RunStartedEvent(threadId: '1', runId: '1'),
          const RunErrorEvent(message: 'NameError: undefined variable'),
        ]);
      });

      final result = await executeInZone('print(x)');

      expect(result, 'Error: NameError: undefined variable');
    });

    test('catches StateError from stuck platform', () async {
      when(() => mockBridge.execute(any())).thenThrow(
        StateError('Cannot call start() while execution is active'),
      );

      final result = await executeInZone('print(1)');

      expect(
        result,
        'Error: Cannot call start() while execution is active',
      );
    });

    test('has correct tool definition', () {
      final registry = container.read(toolRegistryProvider);
      final tools = registry.toolDefinitions;
      final executePython = tools.firstWhere(
        (t) => t.name == PythonExecutorTool.toolName,
      );

      expect(executePython.description, contains('Python'));
      expect(executePython.parameters, isA<Map<String, Object?>>());
    });
  });

  group('host function dispatch via toolRegistryProvider', () {
    test('handler calls registry.execute with correct ToolCallInfo', () async {
      // Use a tool name that doesn't conflict with room tools.
      // Room tools are registered after client tools and would overwrite
      // a client tool with the same name.
      final executedCalls = <ToolCallInfo>[];
      final spyTool = ClientTool(
        definition: const Tool(
          name: 'custom.tools.weather',
          description: 'Get weather',
          parameters: {'type': 'object', 'properties': <String, dynamic>{}},
        ),
        executor: (toolCall) async {
          executedCalls.add(toolCall);
          return '72°F and sunny';
        },
      );
      final registry = const ToolRegistry().register(spyTool);

      final container = ProviderContainer(
        overrides: [
          clientToolRegistryProvider.overrideWithValue(registry),
          currentRoomProvider.overrideWithValue(_roomWithTools),
          threadBridgeCacheProvider.overrideWith(
            _TestBridgeCacheNotifier.new,
          ),
        ],
      );
      addTearDown(container.dispose);

      final mergedRegistry = container.read(toolRegistryProvider);

      expect(mergedRegistry.contains('custom.tools.weather'), isTrue);
      expect(
        mergedRegistry.contains(PythonExecutorTool.toolName),
        isTrue,
      );

      final result = await mergedRegistry.execute(
        ToolCallInfo(
          id: 'dispatch-test',
          name: 'custom.tools.weather',
          arguments: jsonEncode(<String, dynamic>{}),
        ),
      );

      expect(result, '72°F and sunny');
      expect(executedCalls, hasLength(1));
      expect(executedCalls.first.name, 'custom.tools.weather');
    });
  });
}
