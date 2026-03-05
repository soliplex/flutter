/// Demonstrates spawning parallel agent sessions and collecting results.
///
/// Run with:
/// ```bash
/// dart run example/parallel_agents.dart
/// ```
///
/// Requires a running Soliplex backend at http://localhost:8000.
library;

import 'dart:io';

import 'package:soliplex_agent/soliplex_agent.dart';
import 'package:soliplex_cli/soliplex_cli.dart';
import 'package:soliplex_logging/soliplex_logging.dart';

Future<void> main() async {
  final connection = ServerConnection.fromUrl(
    serverUrl: 'http://localhost:8000',
  );
  final logManager = LogManager.instance
    ..minimumLevel = LogLevel.info
    ..addSink(StdoutSink(useColors: true));
  final logger = logManager.getLogger('example');

  final toolRegistry = buildDemoToolRegistry();
  final runtime = AgentRuntime(
    connection: connection,
    toolRegistryResolver: (_) async => toolRegistry,
    platform: const NativePlatformConstraints(),
    logger: logger,
  );

  try {
    // Spawn three sessions in parallel.
    final s1 = await runtime.spawn(roomId: 'plain', prompt: 'Say "alpha".');
    final s2 = await runtime.spawn(roomId: 'plain', prompt: 'Say "beta".');
    final s3 = await runtime.spawn(roomId: 'plain', prompt: 'Say "gamma".');

    stdout.writeln('Spawned 3 sessions, waiting for all...\n');

    // Wait for all to complete.
    final results = await runtime.waitAll(
      [s1, s2, s3],
      timeout: const Duration(seconds: 60),
    );

    for (final result in results) {
      stdout.writeln(formatResult(result));
    }
  } finally {
    await runtime.dispose();
    await connection.close();
  }
}
