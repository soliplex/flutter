import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:soliplex_client/soliplex_client.dart';
import 'package:soliplex_frontend/core/models/active_run_state.dart';
import 'package:soliplex_frontend/core/providers/active_run_provider.dart';
import 'package:soliplex_frontend/core/providers/api_provider.dart';

import '../../helpers/test_helpers.dart';

void main() {
  late MockSoliplexApi mockApi;
  late MockAgUiClient mockAgUiClient;

  setUpAll(() {
    registerFallbackValue(const SimpleRunAgentInput(messages: []));
    registerFallbackValue(CancelToken());
  });

  setUp(() {
    mockApi = MockSoliplexApi();
    mockAgUiClient = MockAgUiClient();
  });

  group('ActiveRunNotifier Tool Calling Flow', () {
    late ProviderContainer container;
    late StreamController<BaseEvent> firstRunController;
    late StreamController<BaseEvent> continuationRunController;

    // Track the threadId used in startRun for mock consistency
    late String testThreadId;

    setUp(() {
      firstRunController = StreamController<BaseEvent>();
      continuationRunController = StreamController<BaseEvent>();

      // Generate threadId upfront so mock can return matching value
      testThreadId = 'thread_${DateTime.now().millisecondsSinceEpoch}';

      // Track which run we're on
      var runCounter = 0;

      // Mock createRun (positional args: roomId, threadId, cancelToken)
      // Return the SAME threadId that was passed in for consistency
      when(
        () => mockApi.createRun(
          any(),
          any(),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer((invocation) async {
        runCounter++;
        final passedThreadId = invocation.positionalArguments[1] as String;
        return RunInfo(
          id: 'run_$runCounter',
          threadId: passedThreadId, // Return the same threadId passed in
          createdAt: DateTime.now(),
        );
      });

      // Mock runAgent to return different streams for each run
      when(
        () => mockAgUiClient.runAgent(
          any(),
          any(),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer((invocation) {
        final endpoint = invocation.positionalArguments[0] as String;
        if (endpoint.contains('run_1')) {
          return firstRunController.stream;
        }
        return continuationRunController.stream;
      });

      container = ProviderContainer(
        overrides: [
          apiProvider.overrideWithValue(mockApi),
          agUiClientProvider.overrideWithValue(mockAgUiClient),
          // toolRegistryProvider is already set up with get_secret by default
        ],
      );
    });

    tearDown(() {
      firstRunController.close();
      continuationRunController.close();
      container.dispose();
    });

    test(
      'complete tool calling flow: tool call -> execution -> continuation',
      () async {
        final notifier = container.read(activeRunNotifierProvider.notifier);

        // Start a run using NAMED parameters (not positional)
        await notifier.startRun(
          roomId: 'room_1',
          threadId: testThreadId,
          userMessage: 'What is the secret?',
        );

        // Verify initial state is running
        expect(container.read(activeRunNotifierProvider), isA<RunningState>());

        // Emit tool call events from first run
        firstRunController
          ..add(RunStartedEvent(runId: 'run_1', threadId: testThreadId))
          ..add(
            const ToolCallStartEvent(
              toolCallId: 'tc_1',
              toolCallName: 'get_secret',
            ),
          );

        // Allow event processing
        await Future<void>.delayed(Duration.zero);

        // Verify tool is in streaming state
        var state = container.read(activeRunNotifierProvider) as RunningState;
        expect(state.conversation.toolCalls.length, 1);
        expect(
          state.conversation.toolCalls.first.status,
          ToolCallStatus.streaming,
        );

        // Emit args event
        firstRunController.add(
          const ToolCallArgsEvent(toolCallId: 'tc_1', delta: '{}'),
        );

        await Future<void>.delayed(Duration.zero);

        // Verify args accumulated, still streaming
        state = container.read(activeRunNotifierProvider) as RunningState;
        expect(state.conversation.toolCalls.first.arguments, '{}');
        expect(
          state.conversation.toolCalls.first.status,
          ToolCallStatus.streaming,
        );

        // Emit end event - this should trigger execution
        firstRunController.add(const ToolCallEndEvent(toolCallId: 'tc_1'));

        // Wait for tool execution and continuation run setup
        await Future<void>.delayed(const Duration(milliseconds: 100));

        // Verify continuation run was started
        verify(
          () => mockApi.createRun(
            any(),
            any(),
            cancelToken: any(named: 'cancelToken'),
          ),
        ).called(greaterThanOrEqualTo(2));

        // Verify runAgent was called for continuation (endpoint contains run_2)
        verify(
          () => mockAgUiClient.runAgent(
            any(that: contains('run_2')),
            any(),
            cancelToken: any(named: 'cancelToken'),
          ),
        ).called(1);

        // Emit response from continuation run
        final todayUtc = DateTime.now().toUtc();
        final dateString = '${todayUtc.year}-'
            '${todayUtc.month.toString().padLeft(2, '0')}-'
            '${todayUtc.day.toString().padLeft(2, '0')}';

        continuationRunController
          ..add(RunStartedEvent(runId: 'run_2', threadId: testThreadId))
          ..add(const TextMessageStartEvent(messageId: 'msg_1'))
          ..add(
            TextMessageContentEvent(
              messageId: 'msg_1',
              delta: 'The secret is $dateString',
            ),
          )
          ..add(const TextMessageEndEvent(messageId: 'msg_1'))
          ..add(RunFinishedEvent(runId: 'run_2', threadId: testThreadId));

        await Future<void>.delayed(const Duration(milliseconds: 50));

        // Verify final state contains the response with date
        final finalState = container.read(activeRunNotifierProvider);
        expect(finalState, isA<CompletedState>());

        final completedState = finalState as CompletedState;
        final messages = completedState.conversation.messages;

        // Find assistant message with date (TextMessage with user: assistant)
        final assistantMessages = messages.whereType<TextMessage>().where(
              (m) => m.user == ChatUser.assistant,
            );
        expect(
          assistantMessages.any((m) => m.text.contains(dateString)),
          isTrue,
          reason: "Response should contain today's UTC date: $dateString",
        );
      },
    );

    test('tool execution handles errors gracefully', () async {
      // Override with a registry that throws
      const errorTool = Tool(
        name: 'get_secret',
        description: 'A tool that fails',
        parameters: {'type': 'object', 'properties': <String, dynamic>{}},
      );
      final errorRegistry = const ToolRegistry().register(errorTool, (_) {
        throw Exception('Tool execution failed');
      });

      final errorContainer = ProviderContainer(
        overrides: [
          apiProvider.overrideWithValue(mockApi),
          agUiClientProvider.overrideWithValue(mockAgUiClient),
          toolRegistryProvider.overrideWithValue(errorRegistry),
        ],
      );

      addTearDown(errorContainer.dispose);

      final notifier = errorContainer.read(activeRunNotifierProvider.notifier);
      final errorTestThreadId =
          'thread_error_${DateTime.now().millisecondsSinceEpoch}';

      // Use named parameters for startRun
      await notifier.startRun(
        roomId: 'room_1',
        threadId: errorTestThreadId,
        userMessage: 'What is the secret?',
      );

      // Emit tool call events
      firstRunController
        ..add(RunStartedEvent(runId: 'run_1', threadId: errorTestThreadId))
        ..add(
          const ToolCallStartEvent(
            toolCallId: 'tc_1',
            toolCallName: 'get_secret',
          ),
        )
        ..add(const ToolCallEndEvent(toolCallId: 'tc_1'));

      // Wait for error handling
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Should still continue (with failed tool result)
      // Verify continuation run was attempted
      verify(
        () => mockApi.createRun(
          any(),
          any(),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).called(greaterThanOrEqualTo(1));

      // Verify tool call has failed status
      final state = errorContainer.read(activeRunNotifierProvider);
      final toolCallMessages = state.messages.whereType<ToolCallMessage>();
      expect(toolCallMessages, isNotEmpty);
      expect(
        toolCallMessages.first.toolCalls.first.status,
        ToolCallStatus.failed,
      );
    });

    test(
      'state transitions through streaming -> completed after execution',
      () async {
        final notifier = container.read(activeRunNotifierProvider.notifier);

        await notifier.startRun(
          roomId: 'room_1',
          threadId: testThreadId,
          userMessage: 'What is the secret?',
        );

        // Send tool call start - should be streaming
        firstRunController.add(
          const ToolCallStartEvent(
            toolCallId: 'tc_1',
            toolCallName: 'get_secret',
          ),
        );
        await Future<void>.delayed(Duration.zero);

        var state = container.read(activeRunNotifierProvider) as RunningState;
        expect(
          state.conversation.toolCalls.first.status,
          ToolCallStatus.streaming,
        );

        // Send args
        firstRunController.add(
          const ToolCallArgsEvent(toolCallId: 'tc_1', delta: '{}'),
        );
        await Future<void>.delayed(Duration.zero);

        state = container.read(activeRunNotifierProvider) as RunningState;
        expect(
          state.conversation.toolCalls.first.status,
          ToolCallStatus.streaming,
        );

        // Send end - triggers execution
        firstRunController.add(const ToolCallEndEvent(toolCallId: 'tc_1'));
        await Future<void>.delayed(const Duration(milliseconds: 100));

        // Tool should now be completed (execution finished)
        state = container.read(activeRunNotifierProvider) as RunningState;
        final toolCallMessages = state.messages.whereType<ToolCallMessage>();
        expect(toolCallMessages, isNotEmpty);
        expect(
          toolCallMessages.first.toolCalls.first.status,
          ToolCallStatus.completed,
        );
      },
    );

    test(
      'continuation run includes tool results in message history',
      () async {
        final capturedInputs = <SimpleRunAgentInput>[];
        var callCount = 0;

        // Override runAgent to capture inputs
        when(
          () => mockAgUiClient.runAgent(
            any(),
            any(),
            cancelToken: any(named: 'cancelToken'),
          ),
        ).thenAnswer((invocation) {
          final input =
              invocation.positionalArguments[1] as SimpleRunAgentInput;
          capturedInputs.add(input);
          callCount++;
          if (callCount == 1) {
            return firstRunController.stream;
          }
          return continuationRunController.stream;
        });

        final notifier = container.read(activeRunNotifierProvider.notifier);

        await notifier.startRun(
          roomId: 'room_1',
          threadId: testThreadId,
          userMessage: 'What is the secret?',
        );

        // Simulate tool call flow
        firstRunController
          ..add(
            const ToolCallStartEvent(
              toolCallId: 'tc_1',
              toolCallName: 'get_secret',
            ),
          )
          ..add(const ToolCallArgsEvent(toolCallId: 'tc_1', delta: '{}'))
          ..add(const ToolCallEndEvent(toolCallId: 'tc_1'));

        await Future<void>.delayed(const Duration(milliseconds: 100));

        // Verify we have at least 2 calls (initial + continuation)
        expect(capturedInputs.length, greaterThanOrEqualTo(2));

        // The continuation run (second call) should include tool results
        final continuationInput = capturedInputs[1];
        final messages = continuationInput.messages;
        expect(messages, isNotNull);

        // Should contain a ToolMessage with the result
        final toolMessages = messages!.whereType<ToolMessage>().toList();
        expect(toolMessages, isNotEmpty);
        // Result should contain the UTC date from get_secret
        final todayUtc = DateTime.now().toUtc();
        final dateString = '${todayUtc.year}-'
            '${todayUtc.month.toString().padLeft(2, '0')}-'
            '${todayUtc.day.toString().padLeft(2, '0')}';
        expect(toolMessages.first.content, contains(dateString));
      },
    );
  });
}
