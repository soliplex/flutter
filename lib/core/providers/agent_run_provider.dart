import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soliplex_agent/soliplex_agent.dart';
import 'package:soliplex_client/soliplex_client.dart';
import 'package:soliplex_frontend/core/providers/api_provider.dart';
import 'package:soliplex_frontend/core/providers/flutter_host_api.dart';
import 'package:soliplex_frontend/features/debug/debug_chart_config.dart';
import 'package:soliplex_logging/soliplex_logging.dart';
import 'package:soliplex_scripting/soliplex_scripting.dart';

/// Converts the app's 2-tuple thread identifier to the agent package's
/// 3-tuple [ThreadKey]. Uses `'default'` for serverId since the app
/// currently targets a single backend.
ThreadKey toAgentThreadKey(String roomId, String threadId) =>
    (serverId: 'default', roomId: roomId, threadId: threadId);

/// Manages charts produced by LLM → Monty → `chart_create()`.
///
/// Cleared on reset. Watched by the Debug Agent Screen to render charts
/// alongside conversation messages.
class AgentChartNotifier extends Notifier<List<DebugChartConfig>> {
  @override
  List<DebugChartConfig> build() => const [];

  /// Appends a chart produced by a Monty `chart_create()` call.
  void add(DebugChartConfig config) {
    state = [...state, config];
  }

  /// Clears all charts (e.g. on reset).
  void clear() {
    state = const [];
  }
}

/// Charts produced by LLM → Monty → `chart_create()` in the Debug Agent.
final agentChartProvider =
    NotifierProvider<AgentChartNotifier, List<DebugChartConfig>>(
  AgentChartNotifier.new,
);

/// Riverpod notifier wrapping [RunOrchestrator] from `soliplex_agent`.
///
/// Proof-of-concept wiring — lives alongside `ActiveRunNotifier` without
/// touching it. External callers see [RunState] transitions; tool yielding
/// is handled internally.
///
/// The `execute_python` tool is registered so the backend LLM can call it.
/// When the LLM yields an `execute_python` tool call, this notifier creates
/// a per-call [MontyToolExecutor] with isolated [HostApi] state and executes
/// the Python code via the Monty bridge. Charts produced by `chart_create()`
/// are published to [agentChartProvider].
class AgentRunNotifier extends Notifier<RunState> {
  late final RunOrchestrator _orchestrator;
  StreamSubscription<RunState>? _subscription;

  @override
  RunState build() {
    // Include execute_python so the LLM sees it.
    final baseRegistry = ref.watch(toolRegistryProvider);
    final registry = baseRegistry.register(
      ClientTool(
        definition: PythonExecutorTool.definition,
        // Dummy — handled in _executeToolsAndResume.
        executor: (_) => throw StateError('Handled by notifier'),
      ),
    );

    _orchestrator = RunOrchestrator(
      api: ref.watch(apiProvider),
      agUiClient: ref.watch(agUiClientProvider),
      toolRegistry: registry,
      platformConstraints: ref.watch(platformConstraintsProvider),
      logger: LogManager.instance.getLogger('AgentRun'),
    );
    _subscription = _orchestrator.stateChanges.listen(_onState);
    ref.onDispose(() {
      _subscription?.cancel();
      _orchestrator.dispose();
    });
    return const IdleState();
  }

  /// Starts a run for the given room/thread.
  Future<void> startRun({
    required String roomId,
    required String threadId,
    required String userMessage,
    String? existingRunId,
  }) async {
    await _orchestrator.startRun(
      key: toAgentThreadKey(roomId, threadId),
      userMessage: userMessage,
      existingRunId: existingRunId,
    );
  }

  /// Cancels the current run.
  void cancelRun() => _orchestrator.cancelRun();

  /// Resets to idle and clears charts.
  void reset() {
    ref.read(agentChartProvider.notifier).clear();
    _orchestrator.reset();
  }

  void _onState(RunState newState) {
    state = newState;
    if (newState is ToolYieldingState) {
      unawaited(_executeToolsAndResume(newState));
    }
  }

  Future<void> _executeToolsAndResume(ToolYieldingState yielding) async {
    final executed = await Future.wait(
      yielding.pendingToolCalls.map((tc) async {
        try {
          final String result;
          if (tc.name == PythonExecutorTool.toolName) {
            result = await _executePython(tc, yielding.threadKey);
          } else {
            result = await ref.read(toolRegistryProvider).execute(tc);
          }
          return tc.copyWith(
            status: ToolCallStatus.completed,
            result: result,
          );
        } on Object catch (e) {
          return tc.copyWith(
            status: ToolCallStatus.failed,
            result: 'Error: $e',
          );
        }
      }),
    );
    // Guard: state may have changed during async tool execution.
    if (state is! ToolYieldingState) return;
    await _orchestrator.submitToolOutputs(executed);
  }

  /// Executes Python code via Monty with isolated per-call host state.
  ///
  /// Charts produced by `chart_create()` are published to [agentChartProvider].
  Future<String> _executePython(
    ToolCallInfo tc,
    ThreadKey threadKey,
  ) async {
    final cache = ref.read(bridgeCacheProvider);
    final hostBundle = createFlutterHostBundle(
      onChartCreated: (_, config) {
        ref.read(agentChartProvider.notifier).add(config);
      },
    );
    final wiring = HostFunctionWiring(
      hostApi: hostBundle.hostApi,
      dfRegistry: hostBundle.dfRegistry,
    );
    final executor = MontyToolExecutor(
      threadKey: threadKey,
      bridgeCache: cache,
      hostWiring: wiring,
    );
    return executor.execute(tc);
  }
}

/// Provider for [AgentRunNotifier].
///
/// Non-autoDispose — lives for the app session. The existing
/// `activeRunNotifierProvider` is untouched; this is a parallel
/// proof-of-concept.
final agentRunProvider =
    NotifierProvider<AgentRunNotifier, RunState>(AgentRunNotifier.new);
