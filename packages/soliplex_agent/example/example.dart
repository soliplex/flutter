/// Minimal example showing how to create an `AgentRuntime`, spawn a session,
/// and await the result.
///
/// ```bash
/// dart run example/example.dart
/// ```
///
/// Requires a running Soliplex backend at http://localhost:8000.
library;

import 'package:soliplex_agent/soliplex_agent.dart';
import 'package:soliplex_logging/soliplex_logging.dart';

Future<void> main() async {
  // Set up logging.
  final logManager = LogManager.instance
    ..minimumLevel = LogLevel.info
    ..addSink(StdoutSink(useColors: true));
  final logger = logManager.getLogger('example');

  // Build clients from server URL — createClientBundle handles /api/v1.
  final bundle = createClientBundle('http://localhost:8000');

  // Create the agent runtime.
  final runtime = AgentRuntime(
    bundle: bundle,
    toolRegistryResolver: (_) async => const ToolRegistry(),
    platform: const NativePlatformConstraints(),
    logger: logger,
  );

  try {
    // Spawn a session.
    final session = await runtime.spawn(
      roomId: 'plain',
      prompt: 'Hello, what can you help me with?',
    );

    // Await the result.
    final result = await session.awaitResult(
      timeout: const Duration(seconds: 30),
    );

    switch (result) {
      case AgentSuccess(:final output):
        logger.info('Success: $output');
      case AgentFailure(:final reason):
        logger.error('Failed: $reason');
      case AgentTimedOut():
        logger.warning('Timed out');
    }
  } finally {
    await runtime.dispose();
    await bundle.close();
  }
}
