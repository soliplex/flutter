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
      message: message,
      roomId: results.option('room'),
      threadId: results.option('thread'),
    );
    return;
  }

  await launchTui(
    serverUrl: results.option('server')!,
    roomId: results.option('room'),
    threadId: results.option('thread'),
    logFile: results.option('log-file')!,
  );
}
