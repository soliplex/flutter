import 'dart:async';
import 'dart:io';

import 'package:args/args.dart';
import 'package:dart_monty_ffi/dart_monty_ffi.dart';
import 'package:dart_monty_platform_interface/dart_monty_platform_interface.dart'
    show MontyPlatform;
import 'package:soliplex_agent/soliplex_agent.dart';
import 'package:soliplex_cli/src/client_factory.dart';
import 'package:soliplex_cli/src/result_printer.dart';
import 'package:soliplex_cli/src/tool_definitions.dart';
import 'package:soliplex_client/soliplex_client.dart'
    show DartHttpClient, SoliplexApi;
import 'package:soliplex_logging/soliplex_logging.dart';
import 'package:soliplex_scripting/soliplex_scripting.dart';

Future<void> runCli(List<String> args) async {
  final parser = ArgParser()
    ..addOption(
      'host',
      abbr: 'H',
      help: 'Backend base URL.',
      defaultsTo:
          Platform.environment['SOLIPLEX_BASE_URL'] ?? 'http://localhost:8000',
    )
    ..addOption(
      'room',
      abbr: 'r',
      help: 'Default room ID.',
      defaultsTo: Platform.environment['SOLIPLEX_ROOM_ID'] ?? 'plain',
    )
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Show usage.')
    ..addFlag(
      'verbose',
      abbr: 'v',
      negatable: false,
      help: 'Log all HTTP traffic to stderr.',
    )
    ..addFlag(
      'no-tools',
      negatable: false,
      help: 'Do not advertise client tools (for rooms with server-side tools).',
    )
    ..addOption(
      'tools',
      abbr: 't',
      help: 'Comma-separated tool names to advertise (default: all).',
    )
    ..addFlag(
      'monty',
      negatable: false,
      help: 'Enable Monty Python execution (wires execute_python tool).',
    )
    ..addFlag(
      'wasm-mode',
      negatable: false,
      help: 'Simulate WASM constraints (single bridge, no re-entrancy).',
    )
    ..addMultiOption(
      'prompt',
      abbr: 'p',
      splitCommas: false,
      help: 'Send prompt(s) non-interactively and exit. '
          'Multiple --prompt flags run sequentially in the same thread.',
    );

  final parsed = parser.parse(args);

  if (parsed.flag('help')) {
    stdout
      ..writeln('Usage: soliplex_cli [options]')
      ..writeln(parser.usage);
    return;
  }

  await runZonedGuarded(() => _runSession(parsed), (e, _) {
    stderr.writeln('[async error] $e');
  });
}

Future<void> _runSession(ArgResults parsed) async {
  final host = parsed.option('host')!;
  final room = parsed.option('room')!;
  final verbose = parsed.flag('verbose');

  final connection = verbose
      ? createVerboseConnection(host)
      : ServerConnection.create(
          serverId: 'default',
          serverUrl: host,
          httpClient: DartHttpClient(),
        );
  final logManager = LogManager.instance
    ..minimumLevel = LogLevel.debug
    ..addSink(StdoutSink(useColors: true));
  final logger = logManager.getLogger('cli');

  final noTools = parsed.flag('no-tools');
  final toolsOption = parsed.option('tools');
  final enabledTools = toolsOption?.split(',').map((s) => s.trim()).toSet();

  if (enabledTools != null) {
    final unknown = enabledTools.difference(availableDemoToolNames);
    if (unknown.isNotEmpty) {
      stderr.writeln(
        'Unknown tool(s): ${unknown.join(', ')}. '
        'Available: ${availableDemoToolNames.join(', ')}',
      );
      return;
    }
  }

  final toolRegistry = noTools
      ? const ToolRegistry()
      : buildDemoToolRegistry(enabledTools: enabledTools);

  final montyEnabled = parsed.flag('monty');
  final wasmMode = parsed.flag('wasm-mode');

  SessionExtensionFactory? extensionFactory;
  // Deferred: set after runtime creation so the closure captures the live
  // reference when sessions are spawned (not at construction time).
  AgentApi? agentApi;
  if (montyEnabled) {
    if (wasmMode) {
      // Retain global singleton for simulated WASM (single bridge).
      MontyPlatform.instance = MontyFfi(bindings: NativeBindingsFfi());
    }
    final hostApi = FakeHostApi(
      invokeHandler: (name, args) async {
        if (name == 'log') {
          final level = args['level'] ?? 'info';
          final message = args['message'] ?? '';
          stderr.writeln('[MONTY:$level] $message');
          return null;
        }
        throw UnimplementedError('FakeHostApi.invoke: no handler for "$name"');
      },
    );
    final blackboardApi = DirectBlackboardApi();
    final fetchClient = DartHttpClient();
    final MontyPlatformFactory? montyPlatformFactory =
        wasmMode ? null : () async => MontyFfi(bindings: NativeBindingsFfi());
    extensionFactory = () async {
      final factory = createMontyScriptEnvironmentFactory(
        hostApi: hostApi,
        agentApi: agentApi,
        blackboardApi: blackboardApi,
        httpClient: fetchClient,
        platformFactory: montyPlatformFactory,
        limits: MontyLimitsDefaults.tool,
      );
      final env = await factory();
      return [ScriptEnvironmentExtension(env)];
    };
  }

  final runtime = AgentRuntime(
    connection: connection,
    llmProvider: AgUiLlmProvider(
      api: connection.api,
      agUiStreamClient: connection.agUiStreamClient,
    ),
    toolRegistryResolver: (_) async => toolRegistry,
    platform: wasmMode
        ? const WebPlatformConstraints()
        : const NativePlatformConstraints(),
    logger: logger,
    extensionFactory: extensionFactory,
  );

  if (montyEnabled) {
    agentApi = RuntimeAgentApi(runtime: runtime);
  }

  final ctx = _CliContext(
    runtime: runtime,
    api: connection.api,
    defaultRoom: room,
    verbose: verbose,
  );

  if (verbose) stderr.writeln('[verbose mode]');
  final toolNames = toolRegistry.toolDefinitions.map((t) => t.name).toList();
  if (montyEnabled) toolNames.add('execute_python');

  final prompts = parsed.multiOption('prompt');
  if (prompts.isNotEmpty) {
    // Non-interactive mode: run prompts sequentially, then exit.
    if (verbose) {
      stderr.writeln(
        'soliplex-cli connected to $host (room: $room)  '
        'tools: [${toolNames.join(', ')}]',
      );
    }
    await _runPrompts(ctx, prompts);
    await runtime.dispose();
    await connection.close();
    return;
  }

  stdout
    ..writeln('soliplex-cli connected to $host (room: $room)')
    ..writeln(
      toolNames.isEmpty
          ? 'tools: (none)'
          : 'tools: [${toolNames.join(', ')}]'
              '${montyEnabled ? '  (monty: enabled)' : ''}'
              '${wasmMode ? '  (wasm-mode)' : ''}',
    )
    ..writeln();
  _printHelp();

  var forceQuit = false;

  ProcessSignal.sigint.watch().listen((_) async {
    if (forceQuit) exit(1);
    forceQuit = true;
    stdout.writeln('\nCancelling all sessions... (^C again to force)');
    await runtime.cancelAll();
  });

  await _readLoop(ctx);

  await runtime.dispose();
  await connection.close();
}

/// Runs prompts sequentially in the same thread, then exits.
Future<void> _runPrompts(_CliContext ctx, List<String> prompts) async {
  for (var i = 0; i < prompts.length; i++) {
    final prompt = prompts[i];
    if (ctx.verbose) {
      stderr.writeln('[${i + 1}/${prompts.length}] $prompt');
    }
    await _sendAndWait(ctx, ctx.defaultRoom, prompt);
    // Allow session cleanup (SSE teardown) to complete before next spawn.
    if (i < prompts.length - 1) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
  }
}

class _CliContext {
  _CliContext({
    required this.runtime,
    required this.api,
    required this.defaultRoom,
    required this.verbose,
  });

  final AgentRuntime runtime;
  final SoliplexApi api;
  final String defaultRoom;
  final bool verbose;
  final List<AgentSession> tracked = [];

  /// Active thread per room: roomId → threadId.
  final Map<String, String> threads = {};

  String? threadFor(String roomId) => threads[roomId];

  void setThread(String roomId, String threadId) {
    threads[roomId] = threadId;
  }

  void clearThread(String roomId) {
    threads.remove(roomId);
  }
}

Future<void> _readLoop(_CliContext ctx) async {
  stdout.write('> ');
  await for (final line in stdin.transform(const SystemEncoding().decoder)) {
    final input = line.trim();
    if (input.isEmpty) {
      stdout.write('> ');
      continue;
    }

    if (input == '/quit' || input == '/q') break;

    await _dispatch(ctx: ctx, input: input);

    stdout.write('> ');
  }
}

Future<void> _dispatch({
  required _CliContext ctx,
  required String input,
}) async {
  if (input == '/help' || input == '/?') {
    _printHelp();
    return;
  }

  if (input == '/examples') {
    _printExamples();
    return;
  }

  if (input == '/clear') {
    stdout.write('\x1B[2J\x1B[H');
    return;
  }

  if (input == '/rooms') {
    await _listRooms(ctx.api);
    return;
  }

  if (input == '/sessions') {
    _printSessions(ctx.runtime);
    return;
  }

  if (input == '/thread') {
    _printThread(ctx);
    return;
  }

  if (input == '/new') {
    ctx.clearThread(ctx.defaultRoom);
    stdout.writeln('Cleared thread for room "${ctx.defaultRoom}".');
    return;
  }

  if (input.startsWith('/new ')) {
    final rest = input.substring('/new '.length).trim();
    if (rest.isEmpty) {
      stdout.writeln('Usage: /new [roomId] [prompt]');
      return;
    }
    final spaceIdx = rest.indexOf(' ');
    if (spaceIdx == -1) {
      // /new <roomId> — just clear the thread.
      ctx.clearThread(rest);
      stdout.writeln('Cleared thread for room "$rest".');
      return;
    }
    // /new <roomId> <prompt> — clear thread and send prompt.
    final roomId = rest.substring(0, spaceIdx);
    final prompt = rest.substring(spaceIdx + 1).trim();
    if (prompt.isEmpty) {
      ctx.clearThread(roomId);
      stdout.writeln('Cleared thread for room "$roomId".');
      return;
    }
    ctx.clearThread(roomId);
    stdout.writeln('New thread in room "$roomId".');
    await _sendAndWait(ctx, roomId, prompt);
    return;
  }

  if (input == '/waitall') {
    await _waitAll(ctx.runtime, ctx.tracked);
    return;
  }

  if (input == '/waitany') {
    await _waitAny(ctx.runtime, ctx.tracked);
    return;
  }

  if (input == '/cancel') {
    await ctx.runtime.cancelAll();
    ctx.tracked.clear();
    stdout.writeln('All sessions cancelled.');
    return;
  }

  if (input.startsWith('/spawn ')) {
    final prompt = input.substring('/spawn '.length).trim();
    if (prompt.isEmpty) {
      stdout.writeln('Usage: /spawn <prompt>');
      return;
    }
    await _spawnBackground(ctx, prompt);
    return;
  }

  if (input.startsWith('/room ')) {
    final rest = input.substring('/room '.length).trim();
    await _sendToRoom(ctx, rest);
    return;
  }

  // Bare text → send to default room, reuse thread.
  await _sendAndWait(ctx, ctx.defaultRoom, input);
}

Future<void> _sendAndWait(_CliContext ctx, String room, String prompt) async {
  final existingThread = ctx.threadFor(room);
  final label = existingThread != null
      ? 'Continuing thread ${_short(existingThread)}...'
      : 'Starting new thread...';
  stdout.writeln(label);

  try {
    final session = await ctx.runtime.spawn(
      roomId: room,
      prompt: prompt,
      threadId: existingThread,
    );
    ctx.setThread(room, session.threadKey.threadId);

    StreamSubscription<RunState>? traceSub;
    void Function()? eventUnsub;
    if (ctx.verbose) {
      traceSub = session.stateChanges.listen(_traceState);
      eventUnsub = session.lastExecutionEvent.subscribe((event) {
        if (event == null) return;
        _traceExecutionEvent(event);
      });
    }

    final result = await session.awaitResult(
      timeout: const Duration(seconds: 120),
    );
    await traceSub?.cancel();
    eventUnsub?.call();
    stdout.writeln(formatResult(result));
  } on Object catch (e) {
    stdout.writeln('Error: $e');
  }
}

Future<void> _spawnBackground(_CliContext ctx, String prompt) async {
  try {
    final session = await ctx.runtime.spawn(
      roomId: ctx.defaultRoom,
      prompt: prompt,
    );
    ctx.tracked.add(session);
    stdout.writeln(
      'Spawned session ${_short(session.threadKey.threadId)} '
      '(${ctx.tracked.length} tracked)',
    );
  } on Object catch (e) {
    stdout.writeln('Error spawning: $e');
  }
}

Future<void> _sendToRoom(_CliContext ctx, String input) async {
  final spaceIdx = input.indexOf(' ');
  if (spaceIdx == -1) {
    stdout.writeln('Usage: /room <roomId> <prompt>');
    return;
  }
  final targetRoom = input.substring(0, spaceIdx);
  final prompt = input.substring(spaceIdx + 1).trim();
  if (prompt.isEmpty) {
    stdout.writeln('Usage: /room <roomId> <prompt>');
    return;
  }
  await _sendAndWait(ctx, targetRoom, prompt);
}

Future<void> _waitAll(AgentRuntime runtime, List<AgentSession> tracked) async {
  if (tracked.isEmpty) {
    stdout.writeln('No tracked sessions.');
    return;
  }
  stdout.writeln('Waiting for ${tracked.length} session(s)...');
  try {
    final results = await runtime.waitAll(
      tracked,
      timeout: const Duration(seconds: 120),
    );
    for (final result in results) {
      stdout.writeln(formatResult(result));
    }
  } on Object catch (e) {
    stdout.writeln('Error: $e');
  }
  tracked.clear();
}

Future<void> _waitAny(AgentRuntime runtime, List<AgentSession> tracked) async {
  if (tracked.isEmpty) {
    stdout.writeln('No tracked sessions.');
    return;
  }
  stdout.writeln('Waiting for first of ${tracked.length} session(s)...');
  try {
    final result = await runtime.waitAny(
      tracked,
      timeout: const Duration(seconds: 120),
    );
    stdout.writeln(formatResult(result));
    tracked.removeWhere((s) => s.threadKey == result.threadKey);
    stdout.writeln('${tracked.length} session(s) remaining.');
  } on Object catch (e) {
    stdout.writeln('Error: $e');
  }
}

Future<void> _listRooms(SoliplexApi api) async {
  try {
    final rooms = await api.getRooms();
    if (rooms.isEmpty) {
      stdout.writeln('No rooms found.');
      return;
    }
    for (final room in rooms) {
      stdout.writeln('  ${room.id}  ${room.name}');
    }
  } on Object catch (e) {
    stdout.writeln('Error listing rooms: $e');
  }
}

void _printSessions(AgentRuntime runtime) {
  final sessions = runtime.activeSessions;
  if (sessions.isEmpty) {
    stdout.writeln('No active sessions.');
    return;
  }
  for (final s in sessions) {
    stdout.writeln(
      '  ${_short(s.threadKey.threadId)}  '
      'state=${s.state}  room=${s.threadKey.roomId}',
    );
  }
}

void _printThread(_CliContext ctx) {
  if (ctx.threads.isEmpty) {
    stdout.writeln('No active threads.');
    return;
  }
  for (final entry in ctx.threads.entries) {
    stdout.writeln('  ${entry.key} → ${_short(entry.value)}');
  }
}

void _traceState(RunState state) {
  switch (state) {
    case RunningState(:final runId, :final conversation, :final streaming):
      final msgCount = conversation.messages.length;
      final toolCount = conversation.toolCalls.length;
      stderr.writeln(
        '[AGUI] Running  run=$runId  '
        'msgs=$msgCount  tools=$toolCount  streaming=$streaming',
      );
    case ToolYieldingState(
        :final pendingToolCalls,
        :final toolDepth,
        :final conversation,
      ):
      stderr.writeln(
        '[AGUI] ToolYielding  depth=$toolDepth  '
        'pending=${pendingToolCalls.length}',
      );
      for (final tc in pendingToolCalls) {
        stderr.writeln(
          '[AGUI]   tool=${tc.name}  id=${tc.id}  '
          'args=${tc.arguments}',
        );
      }
      // Also show all tool calls in conversation (including server-side).
      for (final tc in conversation.toolCalls) {
        if (!pendingToolCalls.any((p) => p.id == tc.id)) {
          stderr.writeln(
            '[AGUI]   (server) tool=${tc.name}  id=${tc.id}  '
            'status=${tc.status}',
          );
        }
      }
    case CompletedState(:final runId, :final conversation):
      final lastMsg = conversation.messages.lastOrNull;
      final preview = lastMsg != null
          ? lastMsg.toString().replaceAll('\n', ' ')
          : '(no messages)';
      stderr.writeln(
        '[AGUI] Completed  run=$runId  '
        'msgs=${conversation.messages.length}  '
        'tools=${conversation.toolCalls.length}',
      );
      stderr.writeln(
        '[AGUI]   last: '
        '${preview.substring(0, preview.length.clamp(0, 120))}',
      );
    case FailedState(:final reason, :final error):
      stderr
        ..writeln('[AGUI] FAILED  reason=$reason')
        ..writeln('[AGUI]   error: $error');
    case CancelledState():
      stderr.writeln('[AGUI] Cancelled');
    case IdleState():
      break;
  }
}

void _traceExecutionEvent(ExecutionEvent event) {
  switch (event) {
    case ClientToolExecuting(:final toolName, :final toolCallId):
      stderr.writeln('[TOOL] Executing $toolName  id=${_short(toolCallId)}');
    case ClientToolCompleted(:final toolCallId, :final result, :final status):
      final preview =
          result.length > 200 ? '${result.substring(0, 200)}...' : result;
      stderr.writeln(
        '[TOOL] Completed ${_short(toolCallId)}  '
        'status=$status  result=$preview',
      );
    default:
      break;
  }
}

String _short(String id) => id.length > 12 ? '${id.substring(0, 12)}...' : id;

void _printHelp() {
  stdout.writeln('''
Commands:
  <text>                   Send prompt (continues current thread)
  /spawn <text>            Spawn background session (new thread)
  /room <roomId> <text>    Send prompt to a specific room
  /new [roomId] [prompt]   Start a fresh thread (optionally send prompt)
  /thread                  Show active threads per room
  /sessions                List active background sessions
  /waitall                 Wait for all background sessions
  /waitany                 Wait for first to complete
  /cancel                  Cancel all sessions
  /rooms                   List available rooms
  /examples                Show usage examples
  /clear                   Clear terminal
  /help                    Show commands
  /quit                    Exit
''');
}

void _printExamples() {
  stdout.writeln('''
--- 1. Conversational thread (runs reuse the same thread) ---
  > Hello, how are you?
  > What did I just say?
  Second prompt continues on the same thread.

--- 2. Start a fresh thread ---
  > /new
  > Hello again!
  Clears the thread for the default room, next prompt creates a new one.

--- 2b. New thread with immediate prompt ---
  > /new plain What is the meaning of life?
  Clears the thread for "plain" and sends the prompt in one step.

--- 3. Tool call (secret_number) ---
  > Call the secret_number tool and tell me what it returns
  Agent calls secret_number, CLI auto-executes it (returns "42"),
  agent incorporates the result.

--- 4. Multi-tool (chained) ---
  > First echo "hello world", then call secret_number, summarize both
  Agent chains echo + secret_number, CLI auto-executes each.

--- 5. Target a different room ---
  > /room echo-room Just say hi
  > /room echo-room What did I just say?
  Both prompts share the same thread in echo-room.

--- 6. Parallel spawn + waitAll ---
  > /spawn Tell me a joke
  > /spawn What is 2+2?
  > /spawn Echo the word "alpha"
  > /sessions
  > /waitall
  Each /spawn gets its own ephemeral thread.

--- 7. Parallel spawn + waitAny (race) ---
  > /spawn Write a haiku about the ocean
  > /spawn Say hello
  > /waitany
  > /waitany

--- 8. Cancel ---
  > /spawn Write a very long essay about computing
  > /sessions
  > /cancel
  > /sessions

--- 9. Show active threads ---
  > Hello!
  > /room echo-room Hi there
  > /thread
  Shows: plain -> <threadId>, echo-room -> <threadId>

--- 10. SIGINT cancel ---
  > /spawn Some long running task
  Press Ctrl+C once to cancel gracefully.
  Press Ctrl+C again to force-exit.
''');
}
