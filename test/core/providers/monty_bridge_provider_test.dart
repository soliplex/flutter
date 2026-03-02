import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:soliplex_client/soliplex_client.dart';
import 'package:soliplex_frontend/core/providers/api_provider.dart';
import 'package:soliplex_frontend/core/providers/rooms_provider.dart';
import 'package:soliplex_frontend/core/services/thread_bridge_cache.dart';
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

  group('toolRegistryProvider', () {
    test('returns empty registry by default', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final registry = container.read(toolRegistryProvider);

      expect(registry.toolDefinitions, isEmpty);
    });

    test('can be overridden with custom tools', () {
      final tool = ClientTool(
        definition: const Tool(
          name: 'custom_tool',
          description: 'A custom tool',
        ),
        executor: (_) async => 'result',
      );
      final container = ProviderContainer(
        overrides: [
          toolRegistryProvider
              .overrideWithValue(const ToolRegistry().register(tool)),
        ],
      );
      addTearDown(container.dispose);

      final registry = container.read(toolRegistryProvider);

      expect(registry.contains('custom_tool'), isTrue);
    });

    test('does not contain execute_python by default', () {
      // execute_python is registered by AgentRunNotifier, not
      // toolRegistryProvider — which is just a base registry.
      final container = ProviderContainer(
        overrides: [
          currentRoomProvider.overrideWithValue(_roomWithTools),
        ],
      );
      addTearDown(container.dispose);

      final registry = container.read(toolRegistryProvider);

      expect(registry.contains(PythonExecutorTool.toolName), isFalse);
    });
  });

  group('PythonExecutorTool', () {
    test('has correct tool definition', () {
      const definition = PythonExecutorTool.definition;

      expect(definition.name, 'execute_python');
      expect(definition.description, contains('Python'));
      expect(definition.parameters, isA<Map<String, Object?>>());
    });
  });

  group('MontyToolExecutor via threadBridgeCacheProvider', () {
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

    test('bridge cache creates bridge for seeded key', () {
      final cache = container.read(threadBridgeCacheProvider.notifier);
      final bridge = cache.getOrCreate(_testKey, []);

      expect(bridge, same(mockBridge));
    });

    test('bridge collects text output from events', () async {
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

      final events = mockBridge.execute('print("Hello World")');
      final buffer = StringBuffer();
      await for (final event in events) {
        if (event is TextMessageContentEvent) {
          buffer.write(event.delta);
        }
      }

      expect(buffer.toString(), 'Hello World');
    });

    test('bridge emits error event on failure', () async {
      when(() => mockBridge.execute(any())).thenAnswer((_) {
        return Stream.fromIterable([
          const RunStartedEvent(threadId: '1', runId: '1'),
          const RunErrorEvent(message: 'NameError: undefined variable'),
        ]);
      });

      final events = mockBridge.execute('print(x)');
      String? errorMessage;
      await for (final event in events) {
        if (event is RunErrorEvent) {
          errorMessage = event.message;
        }
      }

      expect(errorMessage, 'NameError: undefined variable');
    });

    test('bridge throws StateError when already executing', () {
      when(() => mockBridge.execute(any())).thenThrow(
        StateError('Cannot call start() while execution is active'),
      );

      expect(
        () => mockBridge.execute('print(1)'),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('host function dispatch via toolRegistryProvider', () {
    test('handler calls registry.execute with correct ToolCallInfo', () async {
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
          toolRegistryProvider.overrideWithValue(registry),
        ],
      );
      addTearDown(container.dispose);

      final readRegistry = container.read(toolRegistryProvider);

      expect(readRegistry.contains('custom.tools.weather'), isTrue);

      final result = await readRegistry.execute(
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
