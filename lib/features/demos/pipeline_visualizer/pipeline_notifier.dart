import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soliplex_agent/soliplex_agent.dart';
import 'package:soliplex_frontend/core/providers/api_provider.dart';
import 'package:soliplex_frontend/features/demos/pipeline_visualizer/pipeline_pattern.dart';
import 'package:soliplex_logging/soliplex_logging.dart';

// ---------------------------------------------------------------------------
// Per-node runtime state
// ---------------------------------------------------------------------------

class NodeState {
  const NodeState({
    required this.nodeId,
    this.status = NodeStatus.pending,
    this.input,
    this.output,
    this.elapsed,
  });

  final String nodeId;
  final NodeStatus status;
  final String? input;
  final String? output;
  final Duration? elapsed;

  NodeState copyWith({
    NodeStatus? status,
    String? input,
    String? output,
    Duration? elapsed,
  }) {
    return NodeState(
      nodeId: nodeId,
      status: status ?? this.status,
      input: input ?? this.input,
      output: output ?? this.output,
      elapsed: elapsed ?? this.elapsed,
    );
  }
}

// ---------------------------------------------------------------------------
// Pipeline state
// ---------------------------------------------------------------------------

enum PipelineStatus { idle, running, completed, error }

class PipelineState {
  const PipelineState({
    this.status = PipelineStatus.idle,
    this.pattern,
    this.prompt = '',
    this.nodeStates = const {},
    this.selectedNodeId,
    this.error = '',
    this.startedAt,
    this.completedAt,
  });

  final PipelineStatus status;
  final PipelinePattern? pattern;
  final String prompt;
  final Map<String, NodeState> nodeStates;
  final String? selectedNodeId;
  final String error;
  final DateTime? startedAt;
  final DateTime? completedAt;

  bool get isRunning => status == PipelineStatus.running;

  Duration? get elapsed {
    if (startedAt == null) return null;
    final end = completedAt ?? DateTime.now();
    return end.difference(startedAt!);
  }

  int get completedCount =>
      nodeStates.values.where((n) => n.status == NodeStatus.completed).length;

  int get totalNodes => nodeStates.length;

  NodeState? get selectedNode =>
      selectedNodeId != null ? nodeStates[selectedNodeId] : null;

  PipelineState copyWith({
    PipelineStatus? status,
    PipelinePattern? pattern,
    String? prompt,
    Map<String, NodeState>? nodeStates,
    String? selectedNodeId,
    String? error,
    DateTime? startedAt,
    DateTime? completedAt,
  }) {
    return PipelineState(
      status: status ?? this.status,
      pattern: pattern ?? this.pattern,
      prompt: prompt ?? this.prompt,
      nodeStates: nodeStates ?? this.nodeStates,
      selectedNodeId: selectedNodeId ?? this.selectedNodeId,
      error: error ?? this.error,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

final _log = LogManager.instance.getLogger('PipelineNotifier');

class PipelineNotifier extends Notifier<PipelineState> {
  static const _timeout = Duration(seconds: 120);

  @override
  PipelineState build() => const PipelineState();

  void selectPattern(PipelinePattern pattern) {
    state = PipelineState(pattern: pattern);
  }

  void selectNode(String? nodeId) {
    state = state.copyWith(selectedNodeId: nodeId);
  }

  Future<void> runPipeline(String prompt) async {
    final pattern = state.pattern;
    if (pattern == null || state.isRunning) return;

    _log.info(
      'Running pipeline "${pattern.name}" with prompt: '
      '"${prompt.substring(0, prompt.length.clamp(0, 60))}"',
    );

    final runtime = AgentRuntime(
      api: ref.read(apiProvider),
      agUiClient: ref.read(agUiClientProvider),
      toolRegistryResolver: (roomId) async => ref.read(toolRegistryProvider),
      platform: const NativePlatformConstraints(),
      logger: LogManager.instance.getLogger('PipelineViz'),
    );

    // Initialize all node states to pending.
    final initial = <String, NodeState>{
      for (final node in pattern.nodes) node.id: NodeState(nodeId: node.id),
    };

    state = state.copyWith(
      status: PipelineStatus.running,
      prompt: prompt,
      nodeStates: initial,
      error: '',
      startedAt: DateTime.now(),
    );

    final outputs = <String, String>{};

    try {
      final layers = pattern.executionLayers();

      for (var layerIdx = 0; layerIdx < layers.length; layerIdx++) {
        final layer = layers[layerIdx];
        _log.info(
          'Layer $layerIdx: '
          '${layer.map((n) => n.id).join(", ")}',
        );

        // Build prompts and mark nodes as running.
        final nodePrompts = <String, String>{};
        final updatedStates = Map<String, NodeState>.from(state.nodeStates);

        for (final node in layer) {
          final nodePrompt = _buildPrompt(node, prompt, outputs);
          nodePrompts[node.id] = nodePrompt;
          updatedStates[node.id] = updatedStates[node.id]!.copyWith(
            status: NodeStatus.running,
            input: nodePrompt,
          );
        }
        state = state.copyWith(nodeStates: updatedStates);

        // Spawn all nodes in this layer.
        final sessions = <String, AgentSession>{};
        for (final node in layer) {
          _log.debug(
            '  Spawning ${node.id} (room=${node.roomId})',
          );
          sessions[node.id] = await runtime.spawn(
            roomId: node.roomId,
            prompt: nodePrompts[node.id]!,
            ephemeral: false,
          );
        }

        // Wait for all nodes in this layer.
        if (sessions.length == 1) {
          final entry = sessions.entries.first;
          final sw = Stopwatch()..start();
          final result = await entry.value.awaitResult(
            timeout: _timeout,
          );
          sw.stop();
          _processResult(entry.key, result, sw.elapsed, outputs);
        } else {
          final keys = sessions.keys.toList();
          final sessionList = sessions.values.toList();
          final sw = Stopwatch()..start();
          final results = await runtime.waitAll(
            sessionList,
            timeout: _timeout,
          );
          sw.stop();
          for (var i = 0; i < keys.length; i++) {
            _processResult(
              keys[i],
              results[i],
              sw.elapsed,
              outputs,
            );
          }
        }
      }

      state = state.copyWith(
        status: PipelineStatus.completed,
        completedAt: DateTime.now(),
      );
      _log.info(
        'Pipeline complete in ${state.elapsed?.inSeconds}s',
      );
    } on Object catch (e, st) {
      _log.error('Pipeline failed', error: e, stackTrace: st);
      state = state.copyWith(
        status: PipelineStatus.error,
        error: e.toString(),
        completedAt: DateTime.now(),
      );
    }
  }

  void reset() => state = PipelineState(pattern: state.pattern);

  // -----------------------------------------------------------------------
  // Helpers
  // -----------------------------------------------------------------------

  void _processResult(
    String nodeId,
    AgentResult result,
    Duration elapsed,
    Map<String, String> outputs,
  ) {
    final updatedStates = Map<String, NodeState>.from(state.nodeStates);

    switch (result) {
      case AgentSuccess(:final output):
        outputs[nodeId] = output;
        updatedStates[nodeId] = updatedStates[nodeId]!.copyWith(
          status: NodeStatus.completed,
          output: output,
          elapsed: elapsed,
        );
        _log.info(
          '  $nodeId completed (${output.length} chars)',
        );
      case AgentFailure(:final error):
        updatedStates[nodeId] = updatedStates[nodeId]!.copyWith(
          status: NodeStatus.failed,
          output: 'Error: $error',
          elapsed: elapsed,
        );
        _log.error('  $nodeId failed: $error');
        throw Exception('Node $nodeId failed: $error');
      case AgentTimedOut(:final elapsed):
        updatedStates[nodeId] = updatedStates[nodeId]!.copyWith(
          status: NodeStatus.failed,
          output: 'Timed out after ${elapsed.inSeconds}s',
          elapsed: elapsed,
        );
        _log.error('  $nodeId timed out');
        throw Exception(
          'Node $nodeId timed out '
          'after ${elapsed.inSeconds}s',
        );
    }

    state = state.copyWith(nodeStates: updatedStates);
  }

  String _buildPrompt(
    DagNode node,
    String userPrompt,
    Map<String, String> outputs,
  ) {
    if (node.dependsOn.isEmpty) return userPrompt;
    final upstream = node.dependsOn
        .map(
          (id) => '=== $id ===\n${outputs[id] ?? "(pending)"}',
        )
        .join('\n\n');
    return 'Given these inputs:\n\n$upstream\n\n$userPrompt';
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final pipelineProvider = NotifierProvider<PipelineNotifier, PipelineState>(
  PipelineNotifier.new,
);
