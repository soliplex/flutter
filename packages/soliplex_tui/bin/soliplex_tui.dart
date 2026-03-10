import 'dart:io';

import 'package:args/args.dart';
import 'package:soliplex_tui/soliplex_tui.dart';

Future<void> main(List<String> arguments) async {
  final parser = ArgParser()
    ..addOption(
      'server',
      abbr: 's',
      help: 'Soliplex backend URL',
      defaultsTo: 'http://localhost:8000',
    )
    ..addOption('room', abbr: 'r', help: 'Room ID to connect to')
    ..addOption('thread', abbr: 't', help: 'Thread ID (creates new if omitted)')
    ..addOption(
      'log-file',
      abbr: 'l',
      help: 'Log file path',
      defaultsTo: '/tmp/soliplex_tui.log',
    )
    ..addMultiOption(
      'prompt',
      abbr: 'p',
      help:
          'Send message(s) headless, print each response, and exit. '
          'Repeatable for multi-turn conversations.',
    )
    ..addFlag(
      'debug',
      abbr: 'd',
      negatable: false,
      help: 'Headless mode: read stdin, print response, exit',
    )
    ..addFlag(
      'list-rooms',
      negatable: false,
      help: 'List available rooms and exit',
    )
    ..addFlag(
      'verbose',
      abbr: 'v',
      negatable: false,
      help: 'Print run state events to stderr',
    )
    ..addFlag(
      'monty',
      negatable: false,
      help: 'Enable Monty Python execution (wires execute_python tool).',
    )
    ..addFlag(
      'json',
      negatable: false,
      help: 'Headless mode: output structured JSON instead of plain text.',
    )
    ..addFlag(
      'auto-approve',
      negatable: false,
      help:
          'Headless mode: auto-approve all tool requests '
          '(dangerous — only use with trusted prompts).',
    )
    ..addFlag(
      'no-tools',
      negatable: false,
      help: 'Do not advertise client tools.',
    )
    ..addOption(
      'tools',
      help: 'Comma-separated tool names to advertise (default: all).',
    )
    ..addOption(
      'llm-provider',
      help: 'LLM provider: ollama, anthropic, openai (requires --monty).',
    )
    ..addOption(
      'llm-model',
      help: 'LLM model name (provider-specific default if omitted).',
    )
    ..addOption(
      'llm-url',
      help: 'LLM API base URL (provider-specific default if omitted).',
    )
    ..addOption(
      'llm-api-key',
      help: 'LLM API key (or set ANTHROPIC_API_KEY / OPENAI_API_KEY).',
    )
    ..addMultiOption(
      'mcp',
      help: 'MCP server: name=command args... (repeatable, requires --monty).',
    )
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Show usage');

  final ArgResults results;
  try {
    results = parser.parse(arguments);
  } on FormatException catch (e) {
    stderr
      ..writeln('Error: ${e.message}')
      ..writeln('Usage: soliplex_tui [options]')
      ..writeln(parser.usage);
    exit(64);
  }

  if (results.flag('help')) {
    stdout
      ..writeln('soliplex_tui — Rich terminal UI for Soliplex')
      ..writeln()
      ..writeln('Usage: soliplex_tui [options]')
      ..writeln()
      ..writeln(parser.usage);
    exit(0);
  }

  if (results.flag('list-rooms')) {
    await listRooms(serverUrl: results.option('server')!);
    return;
  }

  final verbose = results.flag('verbose');
  final jsonOutput = results.flag('json');
  final autoApprove = results.flag('auto-approve');
  final montyEnabled = results.flag('monty');
  final noTools = results.flag('no-tools');
  final toolsFilter = results.option('tools');
  final enabledTools = toolsFilter?.split(',').map((s) => s.trim()).toSet();

  final llmProvider = results.option('llm-provider');
  final llmModel = results.option('llm-model');
  final llmUrl = results.option('llm-url');
  final llmApiKey = results.option('llm-api-key');
  final mcpServers = results.multiOption('mcp');

  final prompts = results.multiOption('prompt');
  if (prompts.isNotEmpty) {
    await runHeadless(
      serverUrl: results.option('server')!,
      logFile: results.option('log-file')!,
      messages: prompts,
      roomId: results.option('room'),
      threadId: results.option('thread'),
      verbose: verbose,
      json: jsonOutput,
      autoApprove: autoApprove,
      montyEnabled: montyEnabled,
      noTools: noTools,
      enabledTools: enabledTools,
      llmProvider: llmProvider,
      llmModel: llmModel,
      llmUrl: llmUrl,
      llmApiKey: llmApiKey,
      mcpServers: mcpServers,
    );
    return;
  }

  if (results.flag('debug')) {
    final message = stdin.readLineSync()?.trim();
    if (message == null || message.isEmpty) {
      stderr.writeln(
        'Error: --debug requires a message on stdin.\n'
        'Usage: echo "your message" | soliplex_tui --debug [options]',
      );
      exit(64);
    }

    await runHeadless(
      serverUrl: results.option('server')!,
      logFile: results.option('log-file')!,
      messages: [message],
      roomId: results.option('room'),
      threadId: results.option('thread'),
      verbose: verbose,
      json: jsonOutput,
      autoApprove: autoApprove,
      montyEnabled: montyEnabled,
      noTools: noTools,
      enabledTools: enabledTools,
      llmProvider: llmProvider,
      llmModel: llmModel,
      llmUrl: llmUrl,
      llmApiKey: llmApiKey,
      mcpServers: mcpServers,
    );
    return;
  }

  await launchTui(
    serverUrl: results.option('server')!,
    roomId: results.option('room'),
    logFile: results.option('log-file')!,
    montyEnabled: montyEnabled,
    noTools: noTools,
    enabledTools: enabledTools,
    llmProvider: llmProvider,
    llmModel: llmModel,
    llmUrl: llmUrl,
    llmApiKey: llmApiKey,
    mcpServers: mcpServers,
  );
}
