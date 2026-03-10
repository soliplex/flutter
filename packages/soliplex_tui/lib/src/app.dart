import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dart_monty_ffi/dart_monty_ffi.dart';
import 'package:dart_monty_platform_interface/dart_monty_platform_interface.dart';
import 'package:nocterm/nocterm.dart';
import 'package:signals_core/signals_core.dart';
import 'package:soliplex_agent/soliplex_agent.dart';
import 'package:soliplex_client/soliplex_client.dart'
    show DartHttpClient, SoliplexApi, ToolCallInfo;
import 'package:soliplex_completions/soliplex_completions.dart';
import 'package:soliplex_logging/soliplex_logging.dart';
import 'package:soliplex_mcp/soliplex_mcp.dart';
import 'package:soliplex_scripting/soliplex_scripting.dart';

import 'package:soliplex_tui/src/components/chat_page.dart';
import 'package:soliplex_tui/src/file_sink.dart';
import 'package:soliplex_tui/src/host/tui_host_api.dart';
import 'package:soliplex_tui/src/loggers.dart';
import 'package:soliplex_tui/src/services/tui_ui_delegate.dart';
import 'package:soliplex_tui/src/tool_definitions.dart';

/// Launches the Soliplex TUI application.
///
/// Builds the pure-Dart HTTP stack, resolves the target room and thread,
/// creates the [AgentRuntime], spawns an [AgentSession], and starts the
/// nocterm render loop.
Future<void> launchTui({
  required String serverUrl,
  required String logFile,
  String? roomId,
  bool montyEnabled = false,
  bool noTools = false,
  Set<String>? enabledTools,
  String? llmProvider,
  String? llmModel,
  String? llmUrl,
  String? llmApiKey,
  List<String> mcpServers = const [],
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

  AgentRuntime? runtime;
  McpConnectionManager? mcpManager;
  try {
    final resolvedRoomId = await _resolveRoom(connection.api, roomId);
    Loggers.app.info('Resolved room: $resolvedRoomId');

    final toolRegistry = noTools
        ? const ToolRegistry()
        : buildDemoToolRegistry(enabledTools: enabledTools);

    final wiring = _buildMontyWiring(
      montyEnabled: montyEnabled,
      llmProvider: llmProvider,
      llmModel: llmModel,
      llmUrl: llmUrl,
      llmApiKey: llmApiKey,
      mcpServers: mcpServers,
    );
    mcpManager = wiring.mcpManager;

    final uiDelegate = TuiUiDelegate();

    runtime = AgentRuntime(
      connection: connection,
      llmProvider: AgUiLlmProvider(
        api: connection.api,
        agUiStreamClient: connection.agUiStreamClient,
      ),
      toolRegistryResolver: (_) async => toolRegistry,
      platform: const NativePlatformConstraints(),
      logger: Loggers.agui,
      extensionFactory: wiring.extensionFactory,
      uiDelegate: uiDelegate,
    );

    wiring.bindAgentApi(runtime);

    await runApp(
      SoliplexTuiApp(
        runtime: runtime,
        roomId: resolvedRoomId,
        uiDelegate: uiDelegate,
      ),
    );
  } on Exception catch (e, s) {
    Loggers.app.error('Fatal error', error: e, stackTrace: s);
    rethrow;
  } finally {
    await mcpManager?.dispose();
    await runtime?.dispose();
    await LogManager.instance.flush();
    await LogManager.instance.close();
    await connection.close();
  }
}

/// Runs one or more headless interactions on the same thread.
///
/// Each message in [messages] spawns a session sequentially, printing the
/// response before sending the next. This enables multi-turn conversations
/// from the command line:
///
/// ```bash
/// soliplex_tui -p "hello" -p "tell me more" -p "thanks"
/// ```
///
/// Uses [AgentRuntime.spawn] which correctly handles thread creation,
/// initial run ID resolution, and the tool execution loop.
/// All events are logged to [logFile].
Future<void> runHeadless({
  required String serverUrl,
  required String logFile,
  required List<String> messages,
  String? roomId,
  String? threadId,
  bool verbose = false,
  bool json = false,
  bool autoApprove = false,
  bool montyEnabled = false,
  bool noTools = false,
  Set<String>? enabledTools,
  String? llmProvider,
  String? llmModel,
  String? llmUrl,
  String? llmApiKey,
  List<String> mcpServers = const [],
}) async {
  final fileSink = FileSink(filePath: logFile);
  LogManager.instance
    ..minimumLevel = LogLevel.trace
    ..addSink(fileSink);
  if (verbose) {
    LogManager.instance.addSink(_StderrSink());
  }

  Loggers.app.info(
    'Starting headless mode, server=$serverUrl, logFile=$logFile',
  );

  final connection = ServerConnection.create(
    serverId: 'default',
    serverUrl: serverUrl,
    httpClient: DartHttpClient(),
  );
  AgentRuntime? runtime;
  McpConnectionManager? mcpManager;

  try {
    final resolvedRoomId = roomId ?? (await _resolveRoom(connection.api, null));
    Loggers.app.info('Using room: $resolvedRoomId');

    // Resolve or create thread once — all prompts share it.
    final resolvedThreadId =
        threadId ?? (await connection.api.createThread(resolvedRoomId)).$1.id;

    final toolRegistry = noTools
        ? const ToolRegistry()
        : buildDemoToolRegistry(enabledTools: enabledTools);

    final wiring = _buildMontyWiring(
      montyEnabled: montyEnabled,
      llmProvider: llmProvider,
      llmModel: llmModel,
      llmUrl: llmUrl,
      llmApiKey: llmApiKey,
      mcpServers: mcpServers,
    );
    mcpManager = wiring.mcpManager;

    runtime = AgentRuntime(
      connection: connection,
      llmProvider: AgUiLlmProvider(
        api: connection.api,
        agUiStreamClient: connection.agUiStreamClient,
      ),
      toolRegistryResolver: (_) async => toolRegistry,
      platform: const NativePlatformConstraints(),
      logger: Loggers.agui,
      extensionFactory: wiring.extensionFactory,
      uiDelegate: autoApprove ? const AutoApproveUiDelegate() : null,
    );

    wiring.bindAgentApi(runtime);

    if (json) {
      await _runHeadlessJson(
        runtime: runtime,
        roomId: resolvedRoomId,
        threadId: resolvedThreadId,
        messages: messages,
        verbose: verbose,
      );
    } else {
      await _runHeadlessPlain(
        runtime: runtime,
        roomId: resolvedRoomId,
        threadId: resolvedThreadId,
        messages: messages,
        verbose: verbose,
      );
    }

    // Dispose in a guarded zone to absorb async SSE stream cleanup
    // errors.
    await runZonedGuarded(
      () => runtime!.dispose(),
      (e, s) => Loggers.agui.debug('Ignoring dispose error', error: e),
    );
    runtime = null;
  } on Exception catch (e, s) {
    Loggers.app.error('Headless fatal error', error: e, stackTrace: s);
    if (json) {
      final errorEnvelope = {
        'status': 'error',
        'errors': ['$e'],
      };
      stdout.writeln(jsonEncode(errorEnvelope));
    } else {
      stderr.writeln('Error: $e');
    }
    exit(1);
  } finally {
    await mcpManager?.dispose();
    await runtime?.dispose();
    await LogManager.instance.flush();
    await LogManager.instance.close();
    await connection.close();
  }
}

/// Plain-text headless output (original behavior).
Future<void> _runHeadlessPlain({
  required AgentRuntime runtime,
  required String roomId,
  required String threadId,
  required List<String> messages,
  required bool verbose,
}) async {
  for (final message in messages) {
    if (verbose) stderr.writeln('[prompt] $message');

    final session = await runtime.spawn(
      roomId: roomId,
      prompt: message,
      threadId: threadId,
    );

    if (verbose) {
      effect(() {
        final state = session.runState.value;
        stderr.writeln('[state] ${_describeRunState(state)}');
      });
    }

    final result = await session.result;

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
  }
}

/// JSON headless output — collects tool calls, wall time, and turns.
Future<void> _runHeadlessJson({
  required AgentRuntime runtime,
  required String roomId,
  required String threadId,
  required List<String> messages,
  required bool verbose,
}) async {
  final sw = Stopwatch()..start();
  final seenToolIds = <String>{};
  final allToolCalls = <Map<String, dynamic>>[];
  final errors = <String>[];
  var turns = 0;
  String? agentOutput;

  for (final message in messages) {
    if (verbose) stderr.writeln('[prompt] $message');
    turns++;

    final session = await runtime.spawn(
      roomId: roomId,
      prompt: message,
      threadId: threadId,
    );

    // Collect tool calls as they flow through ToolYieldingState.
    // Deduplicate by tool call ID since effect() may re-fire.
    final cleanup = effect(() {
      final state = session.runState.value;
      if (verbose) {
        stderr.writeln('[state] ${_describeRunState(state)}');
      }
      if (state is ToolYieldingState) {
        for (final tc in state.pendingToolCalls) {
          if (seenToolIds.add(tc.id)) {
            allToolCalls.add(_toolCallToJson(tc));
          }
        }
      }
    });

    final result = await session.result;
    cleanup();

    switch (result) {
      case AgentSuccess(:final output):
        agentOutput = output;
      case AgentFailure(:final error):
        errors.add(error);
      case AgentTimedOut(:final elapsed):
        errors.add('Timed out after $elapsed');
    }
  }

  sw.stop();

  final envelope = <String, dynamic>{
    'status': errors.isEmpty ? 'ok' : 'error',
    'turns': turns,
    'wall_time_ms': sw.elapsedMilliseconds,
    'agent_result': agentOutput,
    'tool_calls': allToolCalls,
    if (errors.isNotEmpty) 'errors': errors,
  };

  stdout.writeln(jsonEncode(envelope));
  if (errors.isNotEmpty) exit(1);
}

/// Lists available rooms from the server and prints them to [stdout].
Future<void> listRooms({required String serverUrl}) async {
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

/// Builds Monty wiring when enabled, returning the extension factory, a
/// callback to bind the [AgentApi] after runtime creation, and an optional
/// [McpConnectionManager] that the caller must dispose.
({
  SessionExtensionFactory? extensionFactory,
  void Function(AgentRuntime) bindAgentApi,
  McpConnectionManager? mcpManager,
})
_buildMontyWiring({
  required bool montyEnabled,
  String? llmProvider,
  String? llmModel,
  String? llmUrl,
  String? llmApiKey,
  List<String> mcpServers = const [],
}) {
  if (!montyEnabled) {
    return (extensionFactory: null, bindAgentApi: (_) {}, mcpManager: null);
  }

  MontyPlatform.instance = MontyFfi(bindings: NativeBindingsFfi());
  final blackboardApi = DirectBlackboardApi();
  AgentApi? agentApi;

  // Phase 2: direct LLM completions (bypasses backend).
  final provider = _createLlmProvider(
    provider: llmProvider,
    model: llmModel,
    url: llmUrl,
    apiKey: llmApiKey,
  );

  // Phase 2: MCP connection manager.
  final mcpConfigs = _parseMcpServers(mcpServers);
  final mcpManager = mcpConfigs.isNotEmpty
      ? McpConnectionManager(serverConfigs: mcpConfigs)
      : null;

  return (
    extensionFactory: () async {
      final hostApi = TuiHostApi(); // implements HostApi + SessionExtension
      final factory = createMontyScriptEnvironmentFactory(
        hostApi: hostApi,
        agentApi: agentApi,
        blackboardApi: blackboardApi,
        limits: MontyLimitsDefaults.tool,
        llmCompleter: provider?.complete,
        llmChatCompleter: provider != null
            ? (messages, {systemPrompt, maxTokens}) => provider.chat(
                [
                  for (final m in messages)
                    (role: m['role']!, content: m['content']!),
                ],
                systemPrompt: systemPrompt,
                maxTokens: maxTokens,
              )
            : null,
        mcpExecutor: mcpManager?.executeTool,
        mcpToolLister: mcpManager?.listTools,
        mcpServerLister: mcpManager?.listServers,
      );
      final env = await factory();
      return [
        hostApi, // onAttach gives it the AgentSession
        ScriptEnvironmentExtension(env),
      ];
    },
    bindAgentApi: (AgentRuntime runtime) {
      agentApi = RuntimeAgentApi(runtime: runtime);
    },
    mcpManager: mcpManager,
  );
}

/// Creates an [LlmProvider] from CLI flags, or returns `null` if no
/// provider was specified.
LlmProvider? _createLlmProvider({
  String? provider,
  String? model,
  String? url,
  String? apiKey,
}) {
  if (provider == null) return null;
  return switch (provider) {
    'anthropic' => AnthropicLlmProvider(
      apiKey:
          apiKey ??
          Platform.environment['ANTHROPIC_API_KEY'] ??
          (throw ArgumentError(
            'Anthropic requires --llm-api-key or ANTHROPIC_API_KEY',
          )),
      model: model ?? 'claude-sonnet-4-20250514',
    ),
    'openai' => OpenAiLlmProvider(
      apiKey:
          apiKey ??
          Platform.environment['OPENAI_API_KEY'] ??
          (throw ArgumentError(
            'OpenAI requires --llm-api-key or OPENAI_API_KEY',
          )),
      model: model ?? 'gpt-4o',
      baseUrl: url,
    ),
    'ollama' => OllamaLlmProvider(
      model: model ?? 'llama3.2',
      baseUrl: url ?? 'http://localhost:11434/api',
    ),
    _ => throw ArgumentError('Unknown LLM provider: $provider'),
  };
}

/// Parses `--mcp name=command args...` specs into a config map.
///
/// If the value starts with `http://` or `https://`, an HTTP transport is
/// used; otherwise it is treated as a stdio command.
Map<String, McpServerConfig> _parseMcpServers(List<String> specs) {
  final configs = <String, McpServerConfig>{};
  for (final spec in specs) {
    final eqIndex = spec.indexOf('=');
    if (eqIndex < 1) {
      throw FormatException(
        'Invalid --mcp format: $spec (expected name=command args...)',
      );
    }
    final name = spec.substring(0, eqIndex);
    final rest = spec.substring(eqIndex + 1).trim();
    if (rest.startsWith('http://') || rest.startsWith('https://')) {
      configs[name] = McpServerConfig.http(url: rest);
    } else {
      final parts = rest.split(' ');
      configs[name] = McpServerConfig.stdio(
        command: parts.first,
        args: parts.skip(1).toList(),
      );
    }
  }
  return configs;
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

/// Serializes a [ToolCallInfo] for the JSON envelope.
Map<String, dynamic> _toolCallToJson(ToolCallInfo tc) => {
  'id': tc.id,
  'name': tc.name,
  if (tc.hasArguments) 'arguments': tc.arguments,
};

/// Formats a [RunState] as a concise string for verbose logging.
String _describeRunState(RunState state) {
  return switch (state) {
    IdleState() => 'Idle',
    RunningState(:final streaming) => switch (streaming) {
      AwaitingText() => 'Running (awaiting text)',
      TextStreaming(:final text) => 'Running (${text.length} chars)',
    },
    ToolYieldingState(:final pendingToolCalls) =>
      'ToolYielding (${pendingToolCalls.map((t) => t.name).join(', ')})',
    CompletedState() => 'Completed',
    FailedState(:final error) => 'Failed: $error',
    CancelledState() => 'Cancelled',
  };
}

/// Log sink that writes to stderr for verbose mode.
class _StderrSink implements LogSink {
  @override
  void write(LogRecord record) {
    stderr.writeln(
      '[${record.level.name}] ${record.loggerName}: ${record.message}',
    );
  }

  @override
  Future<void> flush() async {}

  @override
  Future<void> close() async {}
}

/// Root nocterm application component.
class SoliplexTuiApp extends StatelessComponent {
  const SoliplexTuiApp({
    required this.runtime,
    required this.roomId,
    this.uiDelegate,
    super.key,
  });

  final AgentRuntime runtime;
  final String roomId;
  final TuiUiDelegate? uiDelegate;

  @override
  Component build(BuildContext context) {
    return NoctermApp(
      title: 'Soliplex TUI',
      theme: TuiThemeData.dark,
      home: ChatPage(runtime: runtime, roomId: roomId, uiDelegate: uiDelegate),
    );
  }
}
