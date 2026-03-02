import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:soliplex_agent/soliplex_agent.dart';
import 'package:soliplex_tui/src/state/tui_chat_cubit.dart';
import 'package:soliplex_tui/src/state/tui_chat_state.dart';
import 'package:test/test.dart';

import '../helpers/test_helpers.dart';

void main() {
  late MockRunOrchestrator mockOrchestrator;
  late StreamController<RunState> stateController;
  late ToolRegistry toolRegistry;

  const threadKey = TestData.defaultThreadKey;

  setUpAll(() {
    registerFallbackValue(threadKey);
    registerFallbackValue(<ToolCallInfo>[]);
  });

  setUp(() {
    final mock = buildMockOrchestrator();
    mockOrchestrator = mock.orchestrator;
    stateController = mock.controller;
    toolRegistry = const ToolRegistry();
  });

  tearDown(() async {
    await stateController.close();
  });

  TuiChatCubit buildCubit() => TuiChatCubit(
        orchestrator: mockOrchestrator,
        toolRegistry: toolRegistry,
        threadKey: threadKey,
      );

  group('TuiChatCubit', () {
    test('initial state is TuiIdleState', () {
      final cubit = buildCubit();
      expect(cubit.state, isA<TuiIdleState>());
      expect(cubit.state.messages, isEmpty);
      addTearDown(cubit.close);
    });

    blocTest<TuiChatCubit, TuiChatState>(
      'sendMessage calls orchestrator.startRun with correct args',
      setUp: () {
        when(
          () => mockOrchestrator.startRun(
            key: any(named: 'key'),
            userMessage: any(named: 'userMessage'),
          ),
        ).thenAnswer((_) async {});
      },
      build: buildCubit,
      act: (cubit) => cubit.sendMessage('Hello'),
      verify: (_) {
        verify(
          () => mockOrchestrator.startRun(
            key: threadKey,
            userMessage: 'Hello',
          ),
        ).called(1);
      },
    );

    blocTest<TuiChatCubit, TuiChatState>(
      'RunningState emissions produce TuiStreamingState',
      build: buildCubit,
      act: (cubit) {
        final conversation = TestData.createConversation(
          messages: [TestData.createUserMessage()],
        );
        stateController.add(
          RunningState(
            threadKey: threadKey,
            runId: 'run_1',
            conversation: conversation,
            streaming: const AwaitingText(),
          ),
        );
      },
      expect: () => [
        isA<TuiStreamingState>()
            .having((s) => s.messages, 'messages', hasLength(1)),
      ],
    );

    blocTest<TuiChatCubit, TuiChatState>(
      'CompletedState produces TuiIdleState with final messages',
      build: buildCubit,
      act: (cubit) {
        final conversation = TestData.createConversation(
          messages: [
            TestData.createUserMessage(),
            TestData.createAssistantMessage(),
          ],
        );
        stateController.add(
          CompletedState(
            threadKey: threadKey,
            runId: 'run_1',
            conversation: conversation,
          ),
        );
      },
      expect: () => [
        isA<TuiIdleState>().having((s) => s.messages, 'messages', hasLength(2)),
      ],
    );

    blocTest<TuiChatCubit, TuiChatState>(
      'ToolYieldingState emits TuiExecutingToolsState and calls '
      'submitToolOutputs',
      setUp: () {
        toolRegistry = const ToolRegistry().register(
          ClientTool(
            definition: const Tool(name: 'get_time', description: 'Gets time'),
            executor: (_) async => '2025-01-01T00:00:00Z',
          ),
        );
        when(
          () => mockOrchestrator.submitToolOutputs(any()),
        ).thenAnswer((_) async {});
      },
      build: () => TuiChatCubit(
        orchestrator: mockOrchestrator,
        toolRegistry: toolRegistry,
        threadKey: threadKey,
      ),
      act: (cubit) {
        final conversation = TestData.createConversation(
          messages: [TestData.createUserMessage()],
        );
        const toolCall = ToolCallInfo(
          id: 'tc_1',
          name: 'get_time',
          arguments: '{}',
        );
        stateController.add(
          ToolYieldingState(
            threadKey: threadKey,
            runId: 'run_1',
            conversation: conversation,
            pendingToolCalls: const [toolCall],
            toolDepth: 0,
          ),
        );
      },
      wait: const Duration(milliseconds: 100),
      expect: () => [
        isA<TuiExecutingToolsState>()
            .having((s) => s.pendingTools, 'pendingTools', hasLength(1)),
      ],
      verify: (_) {
        verify(() => mockOrchestrator.submitToolOutputs(any())).called(1);
      },
    );

    blocTest<TuiChatCubit, TuiChatState>(
      'FailedState produces TuiErrorState',
      build: buildCubit,
      act: (cubit) {
        stateController.add(
          FailedState(
            threadKey: threadKey,
            reason: FailureReason.serverError,
            error: 'Something went wrong',
            conversation: TestData.createConversation(
              messages: [TestData.createUserMessage()],
            ),
          ),
        );
      },
      expect: () => [
        isA<TuiErrorState>().having(
          (s) => s.errorMessage,
          'errorMessage',
          'Something went wrong',
        ),
      ],
    );

    blocTest<TuiChatCubit, TuiChatState>(
      'CancelledState produces TuiIdleState',
      build: buildCubit,
      act: (cubit) {
        stateController.add(
          CancelledState(
            threadKey: threadKey,
            conversation: TestData.createConversation(
              messages: [TestData.createUserMessage()],
            ),
          ),
        );
      },
      expect: () => [
        isA<TuiIdleState>().having((s) => s.messages, 'messages', hasLength(1)),
      ],
    );

    blocTest<TuiChatCubit, TuiChatState>(
      'cancelRun calls orchestrator.cancelRun',
      build: buildCubit,
      act: (cubit) => cubit.cancelRun(),
      verify: (_) {
        verify(() => mockOrchestrator.cancelRun()).called(1);
      },
    );

    blocTest<TuiChatCubit, TuiChatState>(
      'ignores sendMessage while orchestrator is running',
      setUp: () {
        when(() => mockOrchestrator.currentState).thenReturn(
          RunningState(
            threadKey: threadKey,
            runId: 'run_1',
            conversation: TestData.createConversation(),
            streaming: const AwaitingText(),
          ),
        );
      },
      build: buildCubit,
      act: (cubit) => cubit.sendMessage('Should be ignored'),
      verify: (_) {
        verifyNever(
          () => mockOrchestrator.startRun(
            key: any(named: 'key'),
            userMessage: any(named: 'userMessage'),
          ),
        );
      },
    );
  });
}
