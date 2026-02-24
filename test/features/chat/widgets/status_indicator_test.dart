import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soliplex_client/soliplex_client.dart';
import 'package:soliplex_client/soliplex_client.dart' as domain show Running;
import 'package:soliplex_frontend/core/models/active_run_state.dart';
import 'package:soliplex_frontend/features/chat/widgets/status_indicator.dart';

void main() {
  group('StatusIndicator', () {
    Widget buildWidget(ActiveRunState runState) {
      return MaterialApp(
        home: Scaffold(
          body: StatusIndicator(runState: runState),
        ),
      );
    }

    testWidgets('shows "Executing: tool1, tool2" for ExecutingToolsState', (
      WidgetTester tester,
    ) async {
      const state = ExecutingToolsState(
        conversation: Conversation(
          threadId: 'thread-1',
          status: domain.Running(runId: 'run-1'),
        ),
        pendingTools: [
          ToolCallInfo(id: 'tc-1', name: 'search'),
          ToolCallInfo(id: 'tc-2', name: 'fetch'),
        ],
      );

      await tester.pumpWidget(buildWidget(state));

      expect(find.text('Executing: search, fetch'), findsOneWidget);
    });

    testWidgets('shows "Calling: tool1" for ToolCallActivity in streaming',
        (WidgetTester tester) async {
      const state = RunningState(
        conversation: Conversation(
          threadId: 'thread-1',
          status: domain.Running(runId: 'run-1'),
        ),
        streaming: AwaitingText(
          currentActivity: ToolCallActivity(toolName: 'search'),
        ),
      );

      await tester.pumpWidget(buildWidget(state));

      expect(find.text('Calling: search'), findsOneWidget);
    });

    testWidgets('shows "Thinking" for ThinkingActivity',
        (WidgetTester tester) async {
      const state = RunningState(
        conversation: Conversation(
          threadId: 'thread-1',
          status: domain.Running(runId: 'run-1'),
        ),
        streaming: AwaitingText(currentActivity: ThinkingActivity()),
      );

      await tester.pumpWidget(buildWidget(state));

      expect(find.text('Thinking'), findsOneWidget);
    });

    testWidgets('shows "Responding" for RespondingActivity',
        (WidgetTester tester) async {
      const state = RunningState(
        conversation: Conversation(
          threadId: 'thread-1',
          status: domain.Running(runId: 'run-1'),
        ),
        streaming: TextStreaming(
          messageId: 'msg-1',
          user: ChatUser.assistant,
          text: 'Hello',
        ),
      );

      await tester.pumpWidget(buildWidget(state));

      expect(find.text('Responding'), findsOneWidget);
    });

    testWidgets('shows "Executing: search" for single tool',
        (WidgetTester tester) async {
      const state = ExecutingToolsState(
        conversation: Conversation(
          threadId: 'thread-1',
          status: domain.Running(runId: 'run-1'),
        ),
        pendingTools: [ToolCallInfo(id: 'tc-1', name: 'search')],
      );

      await tester.pumpWidget(buildWidget(state));

      expect(find.text('Executing: search'), findsOneWidget);
    });

    testWidgets('has correct semantics label', (WidgetTester tester) async {
      const state = ExecutingToolsState(
        conversation: Conversation(
          threadId: 'thread-1',
          status: domain.Running(runId: 'run-1'),
        ),
        pendingTools: [ToolCallInfo(id: 'tc-1', name: 'search')],
      );

      await tester.pumpWidget(buildWidget(state));

      final semantics = tester.getSemantics(find.byType(StatusIndicator));
      expect(semantics.label, 'Executing: search');
    });

    testWidgets('shows progress indicator', (WidgetTester tester) async {
      const state = ExecutingToolsState(
        conversation: Conversation(
          threadId: 'thread-1',
          status: domain.Running(runId: 'run-1'),
        ),
        pendingTools: [ToolCallInfo(id: 'tc-1', name: 'search')],
      );

      await tester.pumpWidget(buildWidget(state));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });
}
