import 'dart:io';

import 'package:soliplex_agent/soliplex_agent.dart';
import 'package:soliplex_client/soliplex_client.dart';
import 'package:soliplex_logging/soliplex_logging.dart';
import 'package:test/test.dart';

/// Read env vars with optional default.
///
/// Throws [TestFailure] if the variable is missing and no fallback is given.
String env(String name, [String? fallback]) {
  final value = Platform.environment[name];
  if (value != null && value.isNotEmpty) return value;
  if (fallback != null) return fallback;
  throw TestFailure(
    'Missing env var $name — set it to run integration tests',
  );
}

/// Shared lifecycle for all integration tiers.
///
/// Manages HTTP clients, [SoliplexApi], and [AgUiClient] with the same
/// wiring as the Flutter app. Call [setUp] in `setUpAll` and [tearDown]
/// in `tearDownAll`.
class IntegrationHarness {
  late final String baseUrl;
  late final DartHttpClient restClient;
  late final DartHttpClient sseClient;
  late final SoliplexApi api;
  late final AgUiClient agUiClient;

  /// Initialise clients. Backend must be reachable.
  Future<void> setUp() async {
    baseUrl = env('SOLIPLEX_BASE_URL', 'http://localhost:8000');

    restClient = DartHttpClient();
    sseClient = DartHttpClient();

    api = SoliplexApi(
      transport: HttpTransport(client: restClient),
      urlBuilder: UrlBuilder('$baseUrl/api/v1'),
    );

    agUiClient = AgUiClient(
      config: AgUiClientConfig(baseUrl: '$baseUrl/api/v1'),
      httpClient: HttpClientAdapter(client: sseClient),
    );
  }

  /// Close HTTP clients.
  void tearDown() {
    api.close();
  }

  /// Create a thread in [roomId], returning `(ThreadKey, initialRunId?)`.
  Future<(ThreadKey, String?)> createThread(String roomId) async {
    final (info, _) = await api.createThread(roomId);
    final key = (
      serverId: 'default',
      roomId: roomId,
      threadId: info.id,
    );
    final initialRunId = info.hasInitialRun ? info.initialRunId : null;
    return (key, initialRunId);
  }

  /// Build a [RunOrchestrator] wired to this harness.
  RunOrchestrator createOrchestrator({
    required String loggerName,
    ToolRegistry toolRegistry = const ToolRegistry(),
    PlatformConstraints platformConstraints = const NativePlatformConstraints(),
  }) {
    return RunOrchestrator(
      api: api,
      agUiClient: agUiClient,
      toolRegistry: toolRegistry,
      platformConstraints: platformConstraints,
      logger: createTestLogger(loggerName),
    );
  }

  /// Build an [AgentRuntime] wired to this harness.
  AgentRuntime createRuntime({
    required String loggerName,
    ToolRegistryResolver? toolRegistryResolver,
    PlatformConstraints platform = const NativePlatformConstraints(),
  }) {
    return AgentRuntime(
      api: api,
      agUiClient: agUiClient,
      toolRegistryResolver:
          toolRegistryResolver ?? (_) async => const ToolRegistry(),
      platform: platform,
      logger: createTestLogger(loggerName),
    );
  }
}

/// Creates a real [Logger] backed by [StdoutSink] for integration output.
Logger createTestLogger(String name) {
  final manager = LogManager.instance
    ..minimumLevel = LogLevel.debug
    ..addSink(StdoutSink());
  return manager.getLogger(name);
}
