import 'dart:async';

import 'package:mocktail/mocktail.dart';
import 'package:soliplex_agent/soliplex_agent.dart';

class MockSoliplexApi extends Mock implements SoliplexApi {}

class MockRunOrchestrator extends Mock implements RunOrchestrator {}

/// Test data factory with sensible defaults.
class TestData {
  TestData._();

  static const ThreadKey defaultThreadKey = (
    serverId: 'default',
    roomId: 'room_1',
    threadId: 'thread_1',
  );

  static RunInfo createRun({
    String id = 'run_1',
    String threadId = 'thread_1',
  }) {
    return RunInfo(
      id: id,
      threadId: threadId,
      createdAt: DateTime(2025),
    );
  }

  static TextMessage createUserMessage({
    String id = 'msg_user_1',
    String text = 'Hello',
  }) {
    return TextMessage.create(
      id: id,
      user: ChatUser.user,
      text: text,
    );
  }

  static TextMessage createAssistantMessage({
    String id = 'msg_assistant_1',
    String text = 'Hi there!',
  }) {
    return TextMessage.create(
      id: id,
      user: ChatUser.assistant,
      text: text,
    );
  }

  static Conversation createConversation({
    String threadId = 'thread_1',
    List<ChatMessage>? messages,
  }) {
    return Conversation(
      threadId: threadId,
      messages: messages ?? const [],
    );
  }
}

/// Helper to set up a [MockRunOrchestrator] with a controllable state stream.
({
  MockRunOrchestrator orchestrator,
  StreamController<RunState> controller,
}) buildMockOrchestrator({
  RunState initialState = const IdleState(),
}) {
  final orchestrator = MockRunOrchestrator();
  final controller = StreamController<RunState>.broadcast();

  when(() => orchestrator.currentState).thenReturn(initialState);
  when(() => orchestrator.stateChanges).thenAnswer((_) => controller.stream);
  when(orchestrator.cancelRun).thenReturn(null);
  when(orchestrator.dispose).thenReturn(null);

  return (orchestrator: orchestrator, controller: controller);
}
