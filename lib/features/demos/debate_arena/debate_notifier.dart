import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soliplex_agent/soliplex_agent.dart';
import 'package:soliplex_frontend/core/providers/api_provider.dart';
import 'package:soliplex_logging/soliplex_logging.dart';

// ---------------------------------------------------------------------------
// State model
// ---------------------------------------------------------------------------

enum DebateStage {
  idle,
  advocating,
  critiquing,
  rebutting,
  judging,
  complete,
  error,
}

class DebateState {
  const DebateState({
    this.stage = DebateStage.idle,
    this.topic = '',
    this.advocateText = '',
    this.criticText = '',
    this.rebuttalText = '',
    this.verdictText = '',
    this.error = '',
    this.startedAt,
    this.completedAt,
  });

  final DebateStage stage;
  final String topic;
  final String advocateText;
  final String criticText;
  final String rebuttalText;
  final String verdictText;
  final String error;
  final DateTime? startedAt;
  final DateTime? completedAt;

  bool get isRunning =>
      stage != DebateStage.idle &&
      stage != DebateStage.complete &&
      stage != DebateStage.error;

  Duration? get elapsed {
    if (startedAt == null) return null;
    final end = completedAt ?? DateTime.now();
    return end.difference(startedAt!);
  }

  DebateState copyWith({
    DebateStage? stage,
    String? topic,
    String? advocateText,
    String? criticText,
    String? rebuttalText,
    String? verdictText,
    String? error,
    DateTime? startedAt,
    DateTime? completedAt,
  }) {
    return DebateState(
      stage: stage ?? this.stage,
      topic: topic ?? this.topic,
      advocateText: advocateText ?? this.advocateText,
      criticText: criticText ?? this.criticText,
      rebuttalText: rebuttalText ?? this.rebuttalText,
      verdictText: verdictText ?? this.verdictText,
      error: error ?? this.error,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

final _log = LogManager.instance.getLogger('DebateNotifier');

class DebateNotifier extends Notifier<DebateState> {
  static const _timeout = Duration(seconds: 120);

  @override
  DebateState build() => const DebateState();

  Future<void> startDebate(String topic) async {
    if (state.isRunning) return;

    _log.info('Starting debate: "$topic"');

    final runtime = AgentRuntime(
      api: ref.read(apiProvider),
      agUiClient: ref.read(agUiClientProvider),
      toolRegistryResolver: (roomId) async => ref.read(toolRegistryProvider),
      platform: const NativePlatformConstraints(),
      logger: LogManager.instance.getLogger('DebateArena'),
    );

    state = DebateState(
      stage: DebateStage.advocating,
      topic: topic,
      startedAt: DateTime.now(),
    );

    try {
      // Stage 1: Advocate argues FOR
      _log.info('[Stage 1] Spawning advocate (room=debate-advocate)');
      final advSession = await runtime.spawn(
        roomId: 'debate-advocate',
        prompt: 'Argue FOR: $topic',
        ephemeral: false,
      );
      _log.debug('[Stage 1] Waiting for advocate result...');
      final advResult = await advSession.awaitResult(timeout: _timeout);
      final forArgs = _extractOutput(advResult, 'Advocate');
      _log.info(
        '[Stage 1] Advocate done (${forArgs.length} chars): '
        '${forArgs.substring(0, forArgs.length.clamp(0, 80))}...',
      );
      state = state.copyWith(
        stage: DebateStage.critiquing,
        advocateText: forArgs,
      );

      // Stage 2: Critic argues AGAINST
      _log.info('[Stage 2] Spawning critic (room=debate-critic)');
      final crtSession = await runtime.spawn(
        roomId: 'debate-critic',
        prompt: 'Counter these arguments:\n$forArgs',
        ephemeral: false,
      );
      _log.debug('[Stage 2] Waiting for critic result...');
      final crtResult = await crtSession.awaitResult(timeout: _timeout);
      final againstArgs = _extractOutput(crtResult, 'Critic');
      _log.info(
        '[Stage 2] Critic done (${againstArgs.length} chars): '
        '${againstArgs.substring(0, againstArgs.length.clamp(0, 80))}...',
      );
      state = state.copyWith(
        stage: DebateStage.rebutting,
        criticText: againstArgs,
      );

      // Stage 3: Advocate rebuttal
      _log.info('[Stage 3] Spawning rebuttal (room=debate-advocate)');
      final rebSession = await runtime.spawn(
        roomId: 'debate-advocate',
        prompt: 'A critic responded:\n$againstArgs\n'
            'Defend your strongest point in 2 sentences.',
        ephemeral: false,
      );
      _log.debug('[Stage 3] Waiting for rebuttal result...');
      final rebResult = await rebSession.awaitResult(timeout: _timeout);
      final rebuttal = _extractOutput(rebResult, 'Rebuttal');
      _log.info(
        '[Stage 3] Rebuttal done (${rebuttal.length} chars): '
        '${rebuttal.substring(0, rebuttal.length.clamp(0, 80))}...',
      );
      state = state.copyWith(
        stage: DebateStage.judging,
        rebuttalText: rebuttal,
      );

      // Stage 4: Judge verdict
      _log.info('[Stage 4] Spawning judge (room=debate-judge)');
      final jdgSession = await runtime.spawn(
        roomId: 'debate-judge',
        prompt: 'Topic: "$topic"\n'
            'FOR:\n$forArgs\n\nAGAINST:\n$againstArgs\n\n'
            'REBUTTAL:\n$rebuttal\n\nRender your verdict.',
        ephemeral: false,
      );
      _log.debug('[Stage 4] Waiting for judge result...');
      final jdgResult = await jdgSession.awaitResult(timeout: _timeout);
      final verdict = _extractOutput(jdgResult, 'Judge');
      _log.info(
        '[Stage 4] Judge done (${verdict.length} chars): '
        '${verdict.substring(0, verdict.length.clamp(0, 80))}...',
      );
      state = state.copyWith(
        stage: DebateStage.complete,
        verdictText: verdict,
        completedAt: DateTime.now(),
      );
      _log.info('Debate complete in ${state.elapsed?.inSeconds}s');
    } on Object catch (e, st) {
      _log.error(
        'Debate failed at stage ${state.stage}',
        error: e,
        stackTrace: st,
      );
      state = state.copyWith(
        stage: DebateStage.error,
        error: e.toString(),
        completedAt: DateTime.now(),
      );
    }
  }

  void reset() => state = const DebateState();

  String _extractOutput(AgentResult result, String stageName) {
    return switch (result) {
      AgentSuccess(:final output) => output,
      AgentFailure(:final error) =>
        throw Exception('$stageName failed: $error'),
      AgentTimedOut(:final elapsed) =>
        throw Exception('$stageName timed out after ${elapsed.inSeconds}s'),
    };
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final debateProvider =
    NotifierProvider<DebateNotifier, DebateState>(DebateNotifier.new);
