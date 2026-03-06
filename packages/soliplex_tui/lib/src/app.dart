import 'dart:async';
import 'dart:io';

import 'package:nocterm/nocterm.dart';
import 'package:nocterm_bloc/nocterm_bloc.dart';
import 'package:soliplex_agent/soliplex_agent.dart';
import 'package:soliplex_client/soliplex_client.dart'
    show DartHttpClient, SoliplexApi;
import 'package:soliplex_logging/soliplex_logging.dart';

import 'package:soliplex_tui/src/components/chat_page.dart';
import 'package:soliplex_tui/src/file_sink.dart';
import 'package:soliplex_tui/src/loggers.dart';
import 'package:soliplex_tui/src/state/tui_chat_cubit.dart';

/// Launches the Soliplex TUI application.
///
/// Builds the pure-Dart HTTP stack, resolves the target room and thread,
/// creates the [RunOrchestrator] and [TuiChatCubit], and starts the nocterm
/// render loop.
Future<void> launchTui({
  required String serverUrl,
  required String logFile,
  String? roomId,
  String? threadId,
}) async {
  final fileSink = FileSink(filePath: logFile);
  LogManager.instance
    ..minimumLevel = LogLevel.trace
    ..addSink(fileSink);

  Loggers.app.info('Starting TUI, server=$serverUrl, logFile=$logFile');

  final connection = ServerConnection.create(
    serverId: 'default',
    serverUrl: serverUrl,
    httpClient: DartHttpClient(),
  );

  try {
    // Resolve room.
    final resolvedRoomId = await _resolveRoom(connection.api, roomId);
    Loggers.app.info('Resolved room: $resolvedRoomId');

    // Resolve thread (use provided or create new).
    final resolvedThreadId = await _resolveThread(
      connection.api,
      resolvedRoomId,
      threadId,
    );
    Loggers.app.info('Resolved thread: $resolvedThreadId');

    final orchestrator = RunOrchestrator(
      api: connection.api,
      agUiStreamClient: connection.agUiStreamClient,
      toolRegistry: const ToolRegistry(),
      logger: Loggers.agui,
    );

    final threadKey = (
      serverId: 'default',
      roomId: resolvedRoomId,
      threadId: resolvedThreadId,
    );

    final cubit = TuiChatCubit(
      orchestrator: orchestrator,
      toolRegistry: const ToolRegistry(),
      threadKey: threadKey,
    );

    await runApp(
      SoliplexTuiApp(
        cubit: cubit,
        roomId: resolvedRoomId,
        threadId: resolvedThreadId,
      ),
    );
  } on Exception catch (e, s) {
    Loggers.app.error('Fatal error', error: e, stackTrace: s);
    rethrow;
  } finally {
    await LogManager.instance.flush();
    await LogManager.instance.close();
    await connection.close();
  }
}

/// Runs a single headless interaction: sends [message], prints the final
/// response to [stdout], and exits.
///
/// Uses [AgentRuntime.spawn] which correctly handles thread creation,
/// initial run ID resolution, and the tool execution loop.
/// All events are logged to [logFile].
Future<void> runHeadless({
  required String serverUrl,
  required String logFile,
  required String message,
  String? roomId,
  String? threadId,
}) async {
  final fileSink = FileSink(filePath: logFile);
  LogManager.instance
    ..minimumLevel = LogLevel.trace
    ..addSink(fileSink);

  Loggers.app.info(
    'Starting headless mode, server=$serverUrl, logFile=$logFile',
  );

  final connection = ServerConnection.create(
    serverId: 'default',
    serverUrl: serverUrl,
    httpClient: DartHttpClient(),
  );
  AgentRuntime? runtime;

  try {
    final resolvedRoomId = roomId ?? (await _resolveRoom(connection.api, null));
    Loggers.app.info('Using room: $resolvedRoomId');

    runtime = AgentRuntime(
      connection: connection,
      toolRegistryResolver: (_) async => const ToolRegistry(),
      platform: const NativePlatformConstraints(),
      logger: Loggers.agui,
    );

    final session = await runtime.spawn(
      roomId: resolvedRoomId,
      prompt: message,
      threadId: threadId,
    );

    final result = await session.result;
    // Dispose in a guarded zone to absorb async SSE stream cleanup errors.
    await runZonedGuarded(
      () => runtime!.dispose(),
      (e, s) => Loggers.agui.debug('Ignoring dispose error', error: e),
    );
    runtime = null;

    switch (result) {
      case AgentSuccess(:final output):
        stdout.writeln(output);
      case AgentFailure(:final error):
        stderr.writeln('Error: $error');
        exit(1);
      case AgentTimedOut(:final elapsed):
        stderr.writeln('Timed out after $elapsed');
        exit(1);
    }
  } on Exception catch (e, s) {
    Loggers.app.error('Headless fatal error', error: e, stackTrace: s);
    stderr.writeln('Error: $e');
    exit(1);
  } finally {
    await runtime?.dispose();
    await LogManager.instance.flush();
    await LogManager.instance.close();
    await connection.close();
  }
}

/// Lists available rooms from the server and prints them to [stdout].
Future<void> listRooms({
  required String serverUrl,
}) async {
  final connection = ServerConnection.create(
    serverId: 'default',
    serverUrl: serverUrl,
    httpClient: DartHttpClient(),
  );
  try {
    final rooms = await connection.api.getRooms();
    for (final room in rooms) {
      stdout.writeln('${room.id}\t${room.name}');
    }
  } finally {
    await connection.close();
  }
}

/// Resolves the room ID — uses the provided ID or picks the first available.
Future<String> _resolveRoom(SoliplexApi api, String? roomId) async {
  if (roomId != null) return roomId;

  final rooms = await api.getRooms();
  if (rooms.isEmpty) {
    stderr.writeln('Error: No rooms available on the server.');
    exit(1);
  }
  return rooms.first.id;
}

/// Resolves the thread ID — uses the provided ID or creates a new thread.
Future<String> _resolveThread(
  SoliplexApi api,
  String roomId,
  String? threadId,
) async {
  if (threadId != null) return threadId;

  final (thread, _) = await api.createThread(roomId);
  return thread.id;
}

/// Root nocterm application component.
class SoliplexTuiApp extends StatelessComponent {
  const SoliplexTuiApp({
    required this.cubit,
    required this.roomId,
    required this.threadId,
    super.key,
  });

  final TuiChatCubit cubit;
  final String roomId;
  final String threadId;

  @override
  Component build(BuildContext context) {
    return NoctermApp(
      title: 'Soliplex TUI',
      theme: TuiThemeData.dark,
      home: BlocProvider<TuiChatCubit>.value(
        value: cubit,
        child: ChatPage(roomId: roomId, threadId: threadId),
      ),
    );
  }
}
