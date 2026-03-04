import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soliplex_agent/soliplex_agent.dart';
import 'package:soliplex_logging/soliplex_logging.dart';

import 'agent_providers.dart';
import 'room_providers.dart';
import 'signal_bridge.dart';

final _log = LogManager.instance.getLogger('runyaga.session');

/// Client-side tool: `secret_code` — always returns 42.
final _secretCodeTool = ClientTool.simple(
  name: 'secret_code',
  description: 'Returns the secret code.',
  executor: (toolCall, _) async {
    _log.info('secret_code tool called');
    return '42';
  },
);

/// Shared [AgentRuntime] — one per server connection lifetime.
final runtimeProvider = Provider<AgentRuntime>((ref) {
  final connection = ref.watch(connectionProvider);
  final runtime = AgentRuntime.fromConnection(
    connection: connection,
    toolRegistryResolver: (_) async =>
        const ToolRegistry().register(_secretCodeTool),
    platform: const NativePlatformConstraints(),
    logger: LogManager.instance.getLogger('runyaga.runtime'),
  );
  ref.onDispose(runtime.dispose);
  return runtime;
});

/// Per-room active sessions: `roomId → AgentSession?`.
///
/// Multiple rooms can stream concurrently. Each room tracks its own
/// active session independently.
final roomSessionsProvider =
    NotifierProvider<_RoomSessions, Map<String, AgentSession?>>(
  _RoomSessions.new,
);

class _RoomSessions extends Notifier<Map<String, AgentSession?>> {
  @override
  Map<String, AgentSession?> build() => {};

  void set(String roomId, AgentSession? session) {
    state = {...state, roomId: session};
  }

  void remove(String roomId) {
    final next = {...state}..remove(roomId);
    state = next;
  }
}

/// The active session for the **current** room (derived).
final activeSessionProvider = Provider<AgentSession?>((ref) {
  final roomId = ref.watch(currentRoomIdProvider);
  if (roomId == null) return null;
  final sessions = ref.watch(roomSessionsProvider);
  return sessions[roomId];
});

/// Run state stream bridged from the current room's active session signal.
final activeRunStateProvider = StreamProvider<RunState>((ref) {
  final session = ref.watch(activeSessionProvider);
  if (session == null) return Stream.value(const IdleState());
  return session.runState.toStream().map((state) {
    _log.info('runState: ${state.runtimeType}');
    return state;
  });
});

/// Session lifecycle state stream for the current room.
final activeSessionStateProvider = StreamProvider<AgentSessionState>((ref) {
  final session = ref.watch(activeSessionProvider);
  if (session == null) return Stream.value(AgentSessionState.spawning);
  return session.sessionState.toStream();
});

/// Whether the **current room** is streaming.
final isStreamingProvider = Provider<bool>((ref) {
  final runState = ref.watch(activeRunStateProvider).value;
  return runState is RunningState;
});

/// Whether the user can send a message in the current room.
final canSendMessageProvider = Provider<bool>((ref) {
  final roomId = ref.watch(currentRoomIdProvider);
  final isStreaming = ref.watch(isStreamingProvider);
  return roomId != null && !isStreaming;
});

/// All messages for the current thread.
final messagesProvider = FutureProvider<List<ChatMessage>>((ref) async {
  final roomId = ref.watch(currentRoomIdProvider);
  final threadId = ref.watch(currentThreadIdProvider);
  if (roomId == null || threadId == null) return [];

  final api = ref.watch(apiProvider);
  return (await api.getThreadHistory(roomId, threadId)).messages;
});

/// Sends a message via [AgentRuntime.spawn], setting the room's session.
///
/// Creates a new thread if [threadId] is null. Multiple rooms can have
/// concurrent sessions — each room tracks its own independently.
Future<void> sendMessage(
  WidgetRef ref, {
  required String roomId,
  required String message,
  String? threadId,
}) async {
  final runtime = ref.read(runtimeProvider);

  _log.info('sendMessage: roomId=$roomId threadId=$threadId');

  final AgentSession session;
  try {
    session = await runtime.spawn(
      roomId: roomId,
      prompt: message,
      threadId: threadId,
      ephemeral: false,
    );
  } on Object catch (e, st) {
    _log.warning('spawn failed', error: e, stackTrace: st);
    return;
  }

  _log.info(
    'spawned session ${session.id} '
    'thread=${session.threadKey.threadId}',
  );

  ref.read(roomSessionsProvider.notifier).set(roomId, session);

  // Auto-select the thread created by spawn.
  final newThreadId = session.threadKey.threadId;
  ref.read(threadSelectionProvider.notifier).select(roomId, newThreadId);

  // Wait for completion (success or failure), then refresh.
  session.result.then((result) {
    _log.info('session complete for room=$roomId result=$result');
    ref.invalidate(messagesProvider);
    ref.invalidate(threadsProvider(roomId));
    ref.read(roomSessionsProvider.notifier).remove(roomId);
  });
}

/// Cancels the active session in the current room, if any.
void cancelActiveSession(WidgetRef ref) {
  final roomId = ref.read(currentRoomIdProvider);
  if (roomId == null) return;
  final sessions = ref.read(roomSessionsProvider);
  sessions[roomId]?.cancel();
}
