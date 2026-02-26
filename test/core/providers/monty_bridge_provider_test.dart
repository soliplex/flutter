import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:soliplex_client/soliplex_client.dart';
import 'package:soliplex_frontend/core/providers/api_provider.dart';
import 'package:soliplex_frontend/core/providers/monty_bridge_provider.dart';
import 'package:soliplex_frontend/core/providers/rooms_provider.dart';
import 'package:soliplex_monty/soliplex_monty.dart';

import '../../helpers/test_helpers.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class MockMontyBridge extends Mock implements MontyBridge {}

class FakeToolCallInfo extends Fake implements ToolCallInfo {}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUpAll(() {
    registerFallbackValue(FakeToolCallInfo());
    registerFallbackValue(
      HostFunction(
        schema: const HostFunctionSchema(name: '_fb', description: '_fb'),
        handler: (_) async => null,
      ),
    );
  });

  group('montyBridgeProvider', () {
    late MockSoliplexApi mockApi;

    setUp(() {
      mockApi = MockSoliplexApi();
    });

    test('returns null when no room is selected', () {
      final container = ProviderContainer(
        overrides: [apiProvider.overrideWithValue(mockApi)],
      );
      addTearDown(container.dispose);

      final bridge = container.read(montyBridgeProvider);

      expect(bridge, isNull);
    });

    test('returns null when room has no tool definitions', () async {
      final room = TestData.createRoom();
      when(() => mockApi.getRooms()).thenAnswer((_) async => [room]);

      final container = ProviderContainer(
        overrides: [
          apiProvider.overrideWithValue(mockApi),
          currentRoomIdProvider.overrideWith(
            () => MockCurrentRoomIdNotifier(initialRoomId: room.id),
          ),
        ],
      );
      addTearDown(container.dispose);

      // Wait for rooms to load so currentRoomProvider resolves.
      await container.read(roomsProvider.future);

      final bridge = container.read(montyBridgeProvider);

      expect(bridge, isNull);
    });
  });

  group('toolRegistryProvider + montyBridgeProvider', () {
    test('execute_python tool present when bridge available', () {
      final mockBridge = MockMontyBridge();

      final container = ProviderContainer(
        overrides: [
          montyBridgeProvider.overrideWithValue(mockBridge),
        ],
      );
      addTearDown(container.dispose);

      final registry = container.read(toolRegistryProvider);

      expect(registry.contains(PythonExecutorTool.toolName), isTrue);
    });

    test('execute_python tool absent when bridge null', () {
      final container = ProviderContainer(
        overrides: [
          montyBridgeProvider.overrideWithValue(null),
        ],
      );
      addTearDown(container.dispose);

      final registry = container.read(toolRegistryProvider);

      expect(registry.contains(PythonExecutorTool.toolName), isFalse);
    });
  });

  group('createExecutePythonTool', () {
    test('collects text output from bridge events', () async {
      final mockBridge = MockMontyBridge();
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

      final tool = createExecutePythonTool(mockBridge);
      final result = await tool.executor(
        const ToolCallInfo(
          id: 'test-1',
          name: PythonExecutorTool.toolName,
          arguments: r'{"code":"print(\"Hello World\")"}',
        ),
      );

      expect(result, 'Hello World');
    });

    test('returns error on empty code', () async {
      final mockBridge = MockMontyBridge();

      final tool = createExecutePythonTool(mockBridge);
      final result = await tool.executor(
        ToolCallInfo(
          id: 'test-2',
          name: PythonExecutorTool.toolName,
          arguments: jsonEncode({'code': ''}),
        ),
      );

      expect(result, 'Error: No code provided');
      verifyNever(() => mockBridge.execute(any()));
    });

    test('returns error on missing code key', () async {
      final mockBridge = MockMontyBridge();

      final tool = createExecutePythonTool(mockBridge);
      final result = await tool.executor(
        ToolCallInfo(
          id: 'test-3',
          name: PythonExecutorTool.toolName,
          arguments: jsonEncode(<String, dynamic>{}),
        ),
      );

      expect(result, 'Error: No code provided');
    });

    test('returns (no output) when bridge produces no text', () async {
      final mockBridge = MockMontyBridge();
      when(() => mockBridge.execute(any())).thenAnswer((_) {
        return Stream.fromIterable([
          const RunStartedEvent(threadId: '1', runId: '1'),
          const RunFinishedEvent(threadId: '1', runId: '1'),
        ]);
      });

      final tool = createExecutePythonTool(mockBridge);
      final result = await tool.executor(
        ToolCallInfo(
          id: 'test-4',
          name: PythonExecutorTool.toolName,
          arguments: jsonEncode({'code': 'x = 1'}),
        ),
      );

      expect(result, '(no output)');
    });

    test('returns error message from RunErrorEvent', () async {
      final mockBridge = MockMontyBridge();
      when(() => mockBridge.execute(any())).thenAnswer((_) {
        return Stream.fromIterable([
          const RunStartedEvent(threadId: '1', runId: '1'),
          const RunErrorEvent(message: 'NameError: undefined variable'),
        ]);
      });

      final tool = createExecutePythonTool(mockBridge);
      final result = await tool.executor(
        ToolCallInfo(
          id: 'test-5',
          name: PythonExecutorTool.toolName,
          arguments: jsonEncode({'code': 'print(x)'}),
        ),
      );

      expect(result, 'Error: NameError: undefined variable');
    });

    test('has correct tool definition', () {
      final mockBridge = MockMontyBridge();
      final tool = createExecutePythonTool(mockBridge);

      expect(tool.definition.name, PythonExecutorTool.toolName);
      expect(tool.definition.description, contains('Python'));
      expect(tool.definition.parameters, isA<Map<String, Object?>>());
    });
  });

  group('host function handler dispatches to ToolRegistry', () {
    test('handler calls registry.execute with correct ToolCallInfo', () async {
      final mockBridge = MockMontyBridge();

      // Build a registry with a spy tool.
      final executedCalls = <ToolCallInfo>[];
      final spyTool = ClientTool(
        definition: const Tool(
          name: 'soliplex.tools.get_time',
          description: 'Get time',
          parameters: {'type': 'object', 'properties': <String, dynamic>{}},
        ),
        executor: (toolCall) async {
          executedCalls.add(toolCall);
          return '2026-02-26T12:00:00Z';
        },
      );
      final registry = const ToolRegistry().register(spyTool);

      // Create container with montyBridge and pre-seeded registry.
      final container = ProviderContainer(
        overrides: [
          montyBridgeProvider.overrideWithValue(mockBridge),
          clientToolRegistryProvider.overrideWithValue(registry),
        ],
      );
      addTearDown(container.dispose);

      // Read toolRegistryProvider to get the merged registry.
      final mergedRegistry = container.read(toolRegistryProvider);

      // Verify both tools are registered.
      expect(mergedRegistry.contains('soliplex.tools.get_time'), isTrue);
      expect(
        mergedRegistry.contains(PythonExecutorTool.toolName),
        isTrue,
      );

      // Execute the spy tool through the registry.
      final result = await mergedRegistry.execute(
        ToolCallInfo(
          id: 'dispatch-test',
          name: 'soliplex.tools.get_time',
          arguments: jsonEncode(<String, dynamic>{}),
        ),
      );

      expect(result, '2026-02-26T12:00:00Z');
      expect(executedCalls, hasLength(1));
      expect(executedCalls.first.name, 'soliplex.tools.get_time');
    });
  });
}
