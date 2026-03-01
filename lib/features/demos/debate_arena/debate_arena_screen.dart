import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soliplex_frontend/design/design.dart';
import 'package:soliplex_frontend/features/demos/debate_arena/debate_notifier.dart';

class DebateArenaScreen extends ConsumerStatefulWidget {
  const DebateArenaScreen({super.key});

  @override
  ConsumerState<DebateArenaScreen> createState() => _DebateArenaScreenState();
}

class _DebateArenaScreenState extends ConsumerState<DebateArenaScreen> {
  final _topicController = TextEditingController();
  Timer? _elapsedTimer;

  @override
  void dispose() {
    _topicController.dispose();
    _elapsedTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final debate = ref.watch(debateProvider);
    final theme = Theme.of(context);

    // Tick the elapsed time while running.
    if (debate.isRunning && _elapsedTimer == null) {
      _elapsedTimer = Timer.periodic(
        const Duration(seconds: 1),
        (_) => setState(() {}),
      );
    } else if (!debate.isRunning && _elapsedTimer != null) {
      _elapsedTimer?.cancel();
      _elapsedTimer = null;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(SoliplexSpacing.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _TopicInput(
            controller: _topicController,
            isRunning: debate.isRunning,
            onStart: _startDebate,
            onReset: _reset,
            canReset: debate.stage != DebateStage.idle,
          ),
          const SizedBox(height: SoliplexSpacing.s4),
          _StageIndicator(stage: debate.stage),
          if (debate.elapsed != null) ...[
            const SizedBox(height: SoliplexSpacing.s2),
            Text(
              '${debate.elapsed!.inSeconds}s',
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: SoliplexSpacing.s4),
          _DebatePanels(debate: debate),
          if (debate.verdictText.isNotEmpty) ...[
            const SizedBox(height: SoliplexSpacing.s4),
            _VerdictPanel(verdict: debate.verdictText),
          ],
          if (debate.error.isNotEmpty) ...[
            const SizedBox(height: SoliplexSpacing.s4),
            _ErrorPanel(error: debate.error),
          ],
        ],
      ),
    );
  }

  void _startDebate() {
    final topic = _topicController.text.trim();
    if (topic.isEmpty) return;
    ref.read(debateProvider.notifier).startDebate(topic);
  }

  void _reset() {
    ref.read(debateProvider.notifier).reset();
    _topicController.clear();
  }
}

// ---------------------------------------------------------------------------
// Topic input
// ---------------------------------------------------------------------------

class _TopicInput extends StatelessWidget {
  const _TopicInput({
    required this.controller,
    required this.isRunning,
    required this.onStart,
    required this.onReset,
    required this.canReset,
  });

  final TextEditingController controller;
  final bool isRunning;
  final VoidCallback onStart;
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
              labelText: 'Debate Topic',
              hintText: 'e.g. "Remote work is better than office work"',
              border: OutlineInputBorder(),
            ),
            onSubmitted: isRunning ? null : (_) => onStart(),
          ),
        ),
        const SizedBox(width: SoliplexSpacing.s2),
        FilledButton.icon(
          onPressed: isRunning ? null : onStart,
          icon: isRunning
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.play_arrow),
          label: const Text('Start Debate'),
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
// Stage indicator
// ---------------------------------------------------------------------------

class _StageIndicator extends StatelessWidget {
  const _StageIndicator({required this.stage});

  final DebateStage stage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stages = [
      (DebateStage.advocating, 'Advocate'),
      (DebateStage.critiquing, 'Critic'),
      (DebateStage.rebutting, 'Rebuttal'),
      (DebateStage.judging, 'Judge'),
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < stages.length; i++) ...[
          if (i > 0)
            Container(
              width: 24,
              height: 2,
              color: _stageReached(stages[i].$1)
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outlineVariant,
            ),
          _StageChip(
            label: stages[i].$2,
            status: _chipStatus(stages[i].$1),
          ),
        ],
      ],
    );
  }

  bool _stageReached(DebateStage target) {
    return stage.index >= target.index;
  }

  _ChipStatus _chipStatus(DebateStage target) {
    if (stage == target) return _ChipStatus.active;
    if (stage == DebateStage.error) {
      return stage.index > target.index
          ? _ChipStatus.done
          : _ChipStatus.pending;
    }
    if (stage.index > target.index || stage == DebateStage.complete) {
      return _ChipStatus.done;
    }
    return _ChipStatus.pending;
  }
}

enum _ChipStatus { pending, active, done }

class _StageChip extends StatelessWidget {
  const _StageChip({required this.label, required this.status});

  final String label;
  final _ChipStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final (bgColor, fgColor, icon) = switch (status) {
      _ChipStatus.pending => (
          theme.colorScheme.surfaceContainerHighest,
          theme.colorScheme.onSurfaceVariant,
          null,
        ),
      _ChipStatus.active => (
          theme.colorScheme.primaryContainer,
          theme.colorScheme.onPrimaryContainer,
          const SizedBox.square(
            dimension: 12,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      _ChipStatus.done => (
          theme.colorScheme.primary,
          theme.colorScheme.onPrimary,
          const Icon(Icons.check, size: 14),
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: SoliplexSpacing.s3,
        vertical: SoliplexSpacing.s1,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            IconTheme(data: IconThemeData(color: fgColor), child: icon),
            const SizedBox(width: 4),
          ],
          Text(label, style: TextStyle(color: fgColor, fontSize: 12)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Debate panels (FOR vs AGAINST)
// ---------------------------------------------------------------------------

class _DebatePanels extends StatelessWidget {
  const _DebatePanels({required this.debate});

  final DebateState debate;

  @override
  Widget build(BuildContext context) {
    if (debate.stage == DebateStage.idle) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 600;
        final forPanel = _AgentPanel(
          title: 'FOR (Advocate)',
          icon: Icons.thumb_up_outlined,
          color: Colors.green,
          text: debate.advocateText,
          isActive: debate.stage == DebateStage.advocating,
          rebuttalText: debate.rebuttalText,
        );
        final againstPanel = _AgentPanel(
          title: 'AGAINST (Critic)',
          icon: Icons.thumb_down_outlined,
          color: Colors.red,
          text: debate.criticText,
          isActive: debate.stage == DebateStage.critiquing,
        );

        if (isWide) {
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: forPanel),
                const SizedBox(width: SoliplexSpacing.s4),
                Expanded(child: againstPanel),
              ],
            ),
          );
        }
        return Column(
          children: [
            forPanel,
            const SizedBox(height: SoliplexSpacing.s4),
            againstPanel,
          ],
        );
      },
    );
  }
}

class _AgentPanel extends StatelessWidget {
  const _AgentPanel({
    required this.title,
    required this.icon,
    required this.color,
    required this.text,
    required this.isActive,
    this.rebuttalText,
  });

  final String title;
  final IconData icon;
  final Color color;
  final String text;
  final bool isActive;
  final String? rebuttalText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: isActive ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isActive ? BorderSide(color: color, width: 2) : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(SoliplexSpacing.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: SoliplexSpacing.s2),
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(color: color),
                ),
                if (isActive) ...[
                  const Spacer(),
                  SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: color,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: SoliplexSpacing.s3),
            if (text.isEmpty && isActive)
              const Text(
                'Thinking...',
                style: TextStyle(fontStyle: FontStyle.italic),
              )
            else if (text.isEmpty)
              const SizedBox.shrink()
            else
              SelectableText(text),
            if (rebuttalText != null && rebuttalText!.isNotEmpty) ...[
              const Divider(height: 24),
              Text(
                'REBUTTAL',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: SoliplexSpacing.s1),
              SelectableText(rebuttalText!),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Verdict panel
// ---------------------------------------------------------------------------

class _VerdictPanel extends StatelessWidget {
  const _VerdictPanel({required this.verdict});

  final String verdict;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 2,
      color: theme.colorScheme.tertiaryContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(SoliplexSpacing.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.gavel,
                  color: theme.colorScheme.onTertiaryContainer,
                ),
                const SizedBox(width: SoliplexSpacing.s2),
                Text(
                  'JUDGE VERDICT',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.onTertiaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: SoliplexSpacing.s3),
            SelectableText(
              verdict,
              style: TextStyle(
                color: theme.colorScheme.onTertiaryContainer,
              ),
            ),
          ],
        ),
      ),
    );
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
