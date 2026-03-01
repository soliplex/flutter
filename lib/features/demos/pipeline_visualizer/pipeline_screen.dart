import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soliplex_frontend/design/design.dart';
import 'package:soliplex_frontend/features/demos/pipeline_visualizer/pipeline_notifier.dart';
import 'package:soliplex_frontend/features/demos/pipeline_visualizer/pipeline_pattern.dart';

class PipelineScreen extends ConsumerStatefulWidget {
  const PipelineScreen({super.key});

  @override
  ConsumerState<PipelineScreen> createState() => _PipelineScreenState();
}

class _PipelineScreenState extends ConsumerState<PipelineScreen> {
  final _promptController = TextEditingController();
  Timer? _elapsedTimer;

  @override
  void dispose() {
    _promptController.dispose();
    _elapsedTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pipeline = ref.watch(pipelineProvider);

    // Tick the elapsed time while running.
    if (pipeline.isRunning && _elapsedTimer == null) {
      _elapsedTimer = Timer.periodic(
        const Duration(seconds: 1),
        (_) => setState(() {}),
      );
    } else if (!pipeline.isRunning && _elapsedTimer != null) {
      _elapsedTimer?.cancel();
      _elapsedTimer = null;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(SoliplexSpacing.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PatternSelector(
            selected: pipeline.pattern,
            onChanged: pipeline.isRunning
                ? null
                : (p) => ref.read(pipelineProvider.notifier).selectPattern(p),
          ),
          const SizedBox(height: SoliplexSpacing.s3),
          _PromptInput(
            controller: _promptController,
            isRunning: pipeline.isRunning,
            canRun: pipeline.pattern != null,
            onRun: _runPipeline,
            onReset: _reset,
            canReset: pipeline.status != PipelineStatus.idle,
          ),
          if (pipeline.elapsed != null) ...[
            const SizedBox(height: SoliplexSpacing.s2),
            _StatusBar(pipeline: pipeline),
          ],
          const SizedBox(height: SoliplexSpacing.s4),
          if (pipeline.pattern != null)
            _DagView(
              pattern: pipeline.pattern!,
              nodeStates: pipeline.nodeStates,
              selectedNodeId: pipeline.selectedNodeId,
              onNodeTap: (id) =>
                  ref.read(pipelineProvider.notifier).selectNode(id),
            ),
          if (pipeline.selectedNode != null) ...[
            const SizedBox(height: SoliplexSpacing.s4),
            _NodeDetailPanel(
              nodeState: pipeline.selectedNode!,
              pattern: pipeline.pattern!,
            ),
          ],
          if (pipeline.error.isNotEmpty) ...[
            const SizedBox(height: SoliplexSpacing.s4),
            _ErrorPanel(error: pipeline.error),
          ],
        ],
      ),
    );
  }

  void _runPipeline() {
    final prompt = _promptController.text.trim();
    if (prompt.isEmpty) return;
    ref.read(pipelineProvider.notifier).runPipeline(prompt);
  }

  void _reset() {
    ref.read(pipelineProvider.notifier).reset();
    _promptController.clear();
  }
}

// ---------------------------------------------------------------------------
// Pattern selector
// ---------------------------------------------------------------------------

class _PatternSelector extends StatelessWidget {
  const _PatternSelector({
    required this.selected,
    required this.onChanged,
  });

  final PipelinePattern? selected;
  final ValueChanged<PipelinePattern>? onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: selected?.id,
      decoration: const InputDecoration(
        labelText: 'Pipeline Pattern',
        border: OutlineInputBorder(),
      ),
      items: builtInPatterns
          .map(
            (p) => DropdownMenuItem(
              value: p.id,
              child: Text(p.name),
            ),
          )
          .toList(),
      onChanged: onChanged == null
          ? null
          : (id) {
              final pattern = builtInPatterns.firstWhere(
                (p) => p.id == id,
              );
              onChanged!(pattern);
            },
    );
  }
}

// ---------------------------------------------------------------------------
// Prompt input
// ---------------------------------------------------------------------------

class _PromptInput extends StatelessWidget {
  const _PromptInput({
    required this.controller,
    required this.isRunning,
    required this.canRun,
    required this.onRun,
    required this.onReset,
    required this.canReset,
  });

  final TextEditingController controller;
  final bool isRunning;
  final bool canRun;
  final VoidCallback onRun;
  final VoidCallback onReset;
  final bool canReset;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            enabled: !isRunning,
            decoration: const InputDecoration(
              labelText: 'Prompt',
              hintText: 'e.g. "Describe a futuristic city"',
              border: OutlineInputBorder(),
            ),
            onSubmitted: isRunning || !canRun ? null : (_) => onRun(),
          ),
        ),
        const SizedBox(width: SoliplexSpacing.s2),
        FilledButton.icon(
          onPressed: isRunning || !canRun ? null : onRun,
          icon: isRunning
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                )
              : const Icon(Icons.play_arrow),
          label: const Text('Run'),
        ),
        if (canReset) ...[
          const SizedBox(width: SoliplexSpacing.s2),
          OutlinedButton(
            onPressed: isRunning ? null : onReset,
            child: const Text('Reset'),
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Status bar
// ---------------------------------------------------------------------------

class _StatusBar extends StatelessWidget {
  const _StatusBar({required this.pipeline});

  final PipelineState pipeline;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final elapsed = pipeline.elapsed;
    final completed = pipeline.completedCount;
    final total = pipeline.totalNodes;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (elapsed != null)
          Text(
            '${elapsed.inSeconds}s',
            style: theme.textTheme.bodySmall,
          ),
        const SizedBox(width: SoliplexSpacing.s4),
        Text(
          '$completed / $total nodes complete',
          style: theme.textTheme.bodySmall,
        ),
        if (pipeline.status == PipelineStatus.completed) ...[
          const SizedBox(width: SoliplexSpacing.s2),
          Icon(
            Icons.check_circle,
            size: 16,
            color: theme.colorScheme.primary,
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// DAG visualization
// ---------------------------------------------------------------------------

class _DagView extends StatelessWidget {
  const _DagView({
    required this.pattern,
    required this.nodeStates,
    required this.selectedNodeId,
    required this.onNodeTap,
  });

  final PipelinePattern pattern;
  final Map<String, NodeState> nodeStates;
  final String? selectedNodeId;
  final ValueChanged<String> onNodeTap;

  @override
  Widget build(BuildContext context) {
    final layers = pattern.executionLayers();
    return Column(
      children: [
        for (var i = 0; i < layers.length; i++) ...[
          if (i > 0) _buildEdges(context, layers[i - 1], layers[i]),
          _buildLayer(context, layers[i]),
        ],
      ],
    );
  }

  Widget _buildLayer(
    BuildContext context,
    List<DagNode> nodes,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: SoliplexSpacing.s1,
      ),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: SoliplexSpacing.s3,
        runSpacing: SoliplexSpacing.s2,
        children: nodes.map((node) {
          final ns = nodeStates[node.id];
          final status = ns?.status ?? NodeStatus.pending;
          final isSelected = node.id == selectedNodeId;
          return _DagNodeChip(
            node: node,
            status: status,
            isSelected: isSelected,
            onTap: () => onNodeTap(node.id),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEdges(
    BuildContext context,
    List<DagNode> fromLayer,
    List<DagNode> toLayer,
  ) {
    final theme = Theme.of(context);
    // Simple arrow indicator between layers.
    final anyCompleted = fromLayer.any((n) {
      final s = nodeStates[n.id]?.status;
      return s == NodeStatus.completed;
    });

    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: SoliplexSpacing.s1,
      ),
      child: Icon(
        Icons.arrow_downward,
        size: 20,
        color: anyCompleted
            ? theme.colorScheme.primary
            : theme.colorScheme.outlineVariant,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// DAG node chip
// ---------------------------------------------------------------------------

class _DagNodeChip extends StatelessWidget {
  const _DagNodeChip({
    required this.node,
    required this.status,
    required this.isSelected,
    required this.onTap,
  });

  final DagNode node;
  final NodeStatus status;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final (bgColor, fgColor, icon) = switch (status) {
      NodeStatus.pending => (
          theme.colorScheme.surfaceContainerHighest,
          theme.colorScheme.onSurfaceVariant,
          const Icon(Icons.circle_outlined, size: 14),
        ),
      NodeStatus.running => (
          theme.colorScheme.primaryContainer,
          theme.colorScheme.onPrimaryContainer,
          const SizedBox.square(
            dimension: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
            ),
          ),
        ),
      NodeStatus.completed => (
          theme.colorScheme.primary,
          theme.colorScheme.onPrimary,
          const Icon(Icons.check, size: 14),
        ),
      NodeStatus.failed => (
          theme.colorScheme.error,
          theme.colorScheme.onError,
          const Icon(Icons.close, size: 14),
        ),
      NodeStatus.cancelled => (
          Colors.orange,
          Colors.white,
          const Icon(Icons.cancel_outlined, size: 14),
        ),
    };

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(
          horizontal: SoliplexSpacing.s3,
          vertical: SoliplexSpacing.s2,
        ),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: isSelected
              ? Border.all(
                  color: theme.colorScheme.primary,
                  width: 2,
                )
              : null,
          boxShadow: status == NodeStatus.running
              ? [
                  BoxShadow(
                    color: theme.colorScheme.primary.withAlpha(51),
                    blurRadius: 8,
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconTheme(
              data: IconThemeData(color: fgColor),
              child: icon,
            ),
            const SizedBox(width: 6),
            Text(
              node.label,
              style: TextStyle(
                color: fgColor,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '(${node.roomId})',
              style: TextStyle(
                color: fgColor.withAlpha(153),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Node detail panel
// ---------------------------------------------------------------------------

class _NodeDetailPanel extends StatelessWidget {
  const _NodeDetailPanel({
    required this.nodeState,
    required this.pattern,
  });

  final NodeState nodeState;
  final PipelinePattern pattern;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final node = pattern.nodes.firstWhere(
      (n) => n.id == nodeState.nodeId,
    );

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(SoliplexSpacing.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.info_outline, size: 18),
                const SizedBox(width: SoliplexSpacing.s2),
                Text(
                  '${node.label} (${node.roomId})',
                  style: theme.textTheme.titleSmall,
                ),
                const Spacer(),
                if (nodeState.elapsed != null)
                  Text(
                    '${nodeState.elapsed!.inMilliseconds}ms',
                    style: theme.textTheme.bodySmall,
                  ),
              ],
            ),
            if (nodeState.input != null) ...[
              const SizedBox(height: SoliplexSpacing.s3),
              Text(
                'INPUT',
                style: theme.textTheme.labelSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: SoliplexSpacing.s1),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(SoliplexSpacing.s2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(
                  _truncate(nodeState.input!, 500),
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
            if (nodeState.output != null) ...[
              const SizedBox(height: SoliplexSpacing.s3),
              Text(
                'OUTPUT',
                style: theme.textTheme.labelSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: SoliplexSpacing.s1),
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(
                  maxHeight: 200,
                ),
                padding: const EdgeInsets.all(SoliplexSpacing.s2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    nodeState.output!,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _truncate(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, math.min(text.length, maxLength))}...';
  }
}

// ---------------------------------------------------------------------------
// Error panel
// ---------------------------------------------------------------------------

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.error});

  final String error;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(SoliplexSpacing.s4),
        child: Row(
          children: [
            Icon(
              Icons.error_outline,
              color: Theme.of(context).colorScheme.onErrorContainer,
            ),
            const SizedBox(width: SoliplexSpacing.s2),
            Expanded(
              child: SelectableText(
                error,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
