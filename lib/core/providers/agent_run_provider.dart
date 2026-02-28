import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soliplex_agent/soliplex_agent.dart';
import 'package:soliplex_client/soliplex_client.dart';
import 'package:soliplex_frontend/core/providers/api_provider.dart';
import 'package:soliplex_logging/soliplex_logging.dart';

/// Converts the app's 2-tuple thread identifier to the agent package's
/// 3-tuple [ThreadKey]. Uses `'default'` for serverId since the app
/// currently targets a single backend.
ThreadKey toAgentThreadKey(String roomId, String threadId) =>
    (serverId: 'default', roomId: roomId, threadId: threadId);

/// Riverpod notifier wrapping [RunOrchestrator] from `soliplex_agent`.
///
/// Proof-of-concept wiring — lives alongside `ActiveRunNotifier` without
/// touching it. External callers see [RunState] transitions; tool yielding
/// is handled internally.
class AgentRunNotifier extends Notifier<RunState> {
  late final RunOrchestrator _orchestrator;
  StreamSubscription<RunState>? _subscription;

  @override
  RunState build() {
    _orchestrator = RunOrchestrator(
      api: ref.watch(apiProvider),
      agUiClient: ref.watch(agUiClientProvider),
      toolRegistry: ref.watch(toolRegistryProvider),
      platformConstraints: const NativePlatformConstraints(),
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

  /// Resets to idle.
  void reset() => _orchestrator.reset();

  void _onState(RunState newState) {
    state = newState;
    if (newState is ToolYieldingState) {
      unawaited(_executeToolsAndResume(newState));
    }
  }

  Future<void> _executeToolsAndResume(ToolYieldingState yielding) async {
    final registry = ref.read(toolRegistryProvider);
    final executed = await Future.wait(
      yielding.pendingToolCalls.map((tc) async {
        try {
          final result = await registry.execute(tc);
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
}

/// Provider for [AgentRunNotifier].
///
/// Non-autoDispose — lives for the app session. The existing
/// `activeRunNotifierProvider` is untouched; this is a parallel
/// proof-of-concept.
final agentRunProvider =
    NotifierProvider<AgentRunNotifier, RunState>(AgentRunNotifier.new);
