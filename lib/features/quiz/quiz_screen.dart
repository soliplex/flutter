import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:soliplex_client/soliplex_client.dart';
import 'package:soliplex_frontend/core/providers/quiz_provider.dart';
import 'package:soliplex_frontend/design/design.dart';
import 'package:soliplex_frontend/shared/widgets/app_shell.dart';
import 'package:soliplex_frontend/shared/widgets/error_display.dart';
import 'package:soliplex_frontend/shared/widgets/loading_indicator.dart';
import 'package:soliplex_frontend/shared/widgets/shell_config.dart';

/// Screen for taking a quiz.
///
/// Displays questions one at a time, collects answers, and shows results.
/// Uses [quizSessionProvider] to manage quiz state with sealed classes.
class QuizScreen extends ConsumerStatefulWidget {
  const QuizScreen({
    required this.roomId,
    required this.quizId,
    super.key,
  });

  final String roomId;
  final String quizId;

  @override
  ConsumerState<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends ConsumerState<QuizScreen> {
  /// Controller for text input fields.
  ///
  /// Cleared by action handlers ([_nextQuestion], [_retakeQuiz]) when
  /// transitioning to a new question. The provider's [QuestionState] is the
  /// source of truth; this controller just drives the TextField widget.
  final _answerController = TextEditingController();

  /// Key for the quiz session family provider.
  QuizSessionKey get _sessionKey =>
      (roomId: widget.roomId, quizId: widget.quizId);

  @override
  void dispose() {
    _answerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final quizAsync = ref.watch(quizProvider(_sessionKey));

    return AppShell(
      config: ShellConfig(
        leading: IconButton(
          icon: Icon(Icons.adaptive.arrow_back),
          tooltip: 'Back to room',
          onPressed: _handleBack,
        ),
        title: quizAsync.whenOrNull(
          data: (quiz) => Text(quiz.title),
        ),
      ),
      body: quizAsync.when(
        data: (quiz) => _buildQuizContent(context, quiz),
        loading: () => const LoadingIndicator(),
        error: (error, stack) => ErrorDisplay(
          error: error.toString(),
          onRetry: () => ref.invalidate(quizProvider(_sessionKey)),
        ),
      ),
    );
  }

  Widget _buildQuizContent(BuildContext context, Quiz quiz) {
    final session = ref.watch(quizSessionProvider(_sessionKey));

    return switch (session) {
      QuizNotStarted() => _buildStartScreen(context, quiz),
      QuizInProgress() => _buildQuestionScreen(context, session),
      QuizCompleted() => _buildResultsScreen(context, session),
    };
  }

  Widget _buildStartScreen(BuildContext context, Quiz quiz) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.all(SoliplexSpacing.s4),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.quiz,
                size: 64,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: SoliplexSpacing.s4),
              Text(
                quiz.title,
                style: Theme.of(context).textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: SoliplexSpacing.s2),
              Text(
                quiz.questionCount == 1
                    ? '1 question'
                    : '${quiz.questionCount} questions',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: SoliplexSpacing.s6),
              FilledButton.icon(
                onPressed: () => _startQuiz(quiz),
                icon: const Icon(Icons.play_arrow),
                label: const Text('Start Quiz'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuestionScreen(BuildContext context, QuizInProgress session) {
    final question = session.currentQuestion;
    final questionState = session.questionState;

    return Column(
      children: [
        // Progress bar
        LinearProgressIndicator(
          value: session.progress,
          backgroundColor:
              Theme.of(context).colorScheme.surfaceContainerHighest,
        ),

        // Question content
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(SoliplexSpacing.s4),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Question number
                    Text(
                      'Question ${session.currentIndex + 1} of '
                      '${session.quiz.questionCount}',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: SoliplexSpacing.s2),

                    // Question text
                    Text(
                      question.text,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: SoliplexSpacing.s4),

                    // Answer input
                    _buildAnswerInput(context, question, questionState),

                    // Feedback (if answered)
                    if (questionState case Answered(:final result)) ...[
                      const SizedBox(height: SoliplexSpacing.s4),
                      _buildFeedback(context, result),
                    ],

                    const SizedBox(height: SoliplexSpacing.s4),

                    // Action buttons
                    _buildActionButtons(context, session),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAnswerInput(
    BuildContext context,
    QuizQuestion question,
    QuestionState questionState,
  ) {
    final selectedOption = switch (questionState) {
      Composing(input: MultipleChoiceInput(:final selectedOption)) =>
        selectedOption,
      Submitting(input: MultipleChoiceInput(:final selectedOption)) =>
        selectedOption,
      Answered(input: MultipleChoiceInput(:final selectedOption)) =>
        selectedOption,
      _ => null,
    };

    return switch (question.type) {
      MultipleChoice(:final options) => _buildMultipleChoice(
          context,
          options: options,
          selectedOption: selectedOption,
          questionState: questionState,
        ),
      FillBlank() => _buildTextInput(
          context,
          hint: 'Type your answer...',
          questionState: questionState,
        ),
      FreeForm() => _buildTextInput(
          context,
          hint: 'Type your answer...',
          questionState: questionState,
          maxLines: 3,
        ),
    };
  }

  Widget _buildMultipleChoice(
    BuildContext context, {
    required List<String> options,
    required String? selectedOption,
    required QuestionState questionState,
  }) {
    final isAnswered = questionState is Answered;
    final result = questionState is Answered ? questionState.result : null;
    final isDisabled = isAnswered || questionState is Submitting;

    final radii = SoliplexTheme.of(context).radii;
    final colorScheme = Theme.of(context).colorScheme;

    return RadioGroup<String>(
      groupValue: selectedOption,
      onChanged: (v) => _selectOption(v!),
      child: Column(
        children: options.map((option) {
          final isSelected = selectedOption == option;
          final isCorrect = isAnswered && result!.expectedAnswer == option;
          final isWrong = isAnswered && isSelected && !result!.isCorrect;

          final backgroundColor = isCorrect
              ? colorScheme.primaryContainer
              : isWrong
                  ? colorScheme.errorContainer
                  : isSelected
                      ? colorScheme.secondaryContainer
                      : colorScheme.surface;
          final foregroundColor = isCorrect
              ? colorScheme.onPrimaryContainer
              : isWrong
                  ? colorScheme.onErrorContainer
                  : isSelected
                      ? colorScheme.onSecondaryContainer
                      : colorScheme.onSurface;

          return Padding(
            padding: const EdgeInsets.only(bottom: SoliplexSpacing.s2),
            child: Material(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(radii.md),
              child: InkWell(
                onTap: isDisabled ? null : () => _selectOption(option),
                borderRadius: BorderRadius.circular(radii.md),
                child: Container(
                  padding: const EdgeInsets.all(SoliplexSpacing.s4),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: isSelected
                          ? colorScheme.primary
                          : colorScheme.outline,
                      width: isSelected ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(radii.md),
                  ),
                  child: Row(
                    children: [
                      Radio<String>(value: option, enabled: !isDisabled),
                      Expanded(
                        child: Text(
                          option,
                          style: TextStyle(color: foregroundColor),
                        ),
                      ),
                      if (isCorrect)
                        Icon(Icons.check_circle, color: foregroundColor),
                      if (isWrong) Icon(Icons.cancel, color: foregroundColor),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTextInput(
    BuildContext context, {
    required String hint,
    required QuestionState questionState,
    int maxLines = 1,
  }) {
    final isDisabled = questionState is Answered || questionState is Submitting;

    // Sync controller from provider state (provider is source of truth)
    final providerText = switch (questionState) {
      Composing(input: TextInput(:final text)) => text,
      Submitting(input: TextInput(:final text)) => text,
      Answered(input: TextInput(:final text)) => text,
      _ => '',
    };
    if (_answerController.text != providerText) {
      _answerController.text = providerText;
    }

    return TextField(
      controller: _answerController,
      enabled: !isDisabled,
      maxLines: maxLines,
      onChanged: (text) {
        ref
            .read(quizSessionProvider(_sessionKey).notifier)
            .updateInput(TextInput(text));
      },
      decoration: InputDecoration(
        hintText: hint,
        border: const OutlineInputBorder(),
      ),
    );
  }

  Widget _buildFeedback(BuildContext context, QuizAnswerResult result) {
    final radii = SoliplexTheme.of(context).radii;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final isCorrect = result.isCorrect;
    final containerColor =
        isCorrect ? colorScheme.primaryContainer : colorScheme.errorContainer;
    final contentColor = isCorrect
        ? colorScheme.onPrimaryContainer
        : colorScheme.onErrorContainer;
    final iconColor = isCorrect ? colorScheme.primary : colorScheme.error;

    return Container(
      padding: const EdgeInsets.all(SoliplexSpacing.s4),
      decoration: BoxDecoration(
        color: containerColor,
        borderRadius: BorderRadius.circular(radii.md),
      ),
      child: Row(
        children: [
          Icon(
            isCorrect ? Icons.check_circle : Icons.cancel,
            color: iconColor,
          ),
          const SizedBox(width: SoliplexSpacing.s2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isCorrect ? 'Correct!' : 'Incorrect',
                  style: textTheme.titleMedium?.copyWith(color: contentColor),
                ),
                if (!isCorrect) ...[
                  const SizedBox(height: SoliplexSpacing.s1),
                  Text(
                    'Expected: ${result.expectedAnswer}',
                    style: textTheme.bodyMedium?.copyWith(color: contentColor),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, QuizInProgress session) {
    final questionState = session.questionState;

    return switch (questionState) {
      AwaitingInput() => const FilledButton(
          onPressed: null,
          child: Text('Submit Answer'),
        ),
      Composing(:final canSubmit) => FilledButton(
          onPressed: canSubmit ? _submitAnswer : null,
          child: const Text('Submit Answer'),
        ),
      Submitting() => const FilledButton(
          onPressed: null,
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      Answered() => FilledButton(
          onPressed: _nextQuestion,
          child: Text(
            session.isLastQuestion ? 'See Results' : 'Next Question',
          ),
        ),
    };
  }

  Widget _buildResultsScreen(BuildContext context, QuizCompleted session) {
    final scoreColor = session.scorePercent >= 70
        ? Theme.of(context).colorScheme.primary
        : session.scorePercent >= 40
            ? Theme.of(context).colorScheme.tertiary
            : Theme.of(context).colorScheme.error;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.all(SoliplexSpacing.s4),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                session.scorePercent >= 70
                    ? Icons.emoji_events
                    : session.scorePercent >= 40
                        ? Icons.thumb_up
                        : Icons.refresh,
                size: 64,
                color: scoreColor,
              ),
              const SizedBox(height: SoliplexSpacing.s4),
              Text(
                'Quiz Complete!',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: SoliplexSpacing.s2),
              Text(
                '${session.scorePercent}%',
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                      color: scoreColor,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: SoliplexSpacing.s2),
              Text(
                '${session.correctCount} of ${session.totalAnswered} correct',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: SoliplexSpacing.s6),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: SoliplexSpacing.s2,
                runSpacing: SoliplexSpacing.s2,
                children: [
                  OutlinedButton(
                    onPressed: _handleBack,
                    child: const Text('Back to Room'),
                  ),
                  FilledButton(
                    onPressed: _retakeQuiz,
                    child: const Text('Retake Quiz'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleBack() {
    ref.invalidate(quizSessionProvider(_sessionKey));
    context.go('/rooms/${widget.roomId}');
  }

  void _startQuiz(Quiz quiz) {
    ref.read(quizSessionProvider(_sessionKey).notifier).start(quiz);
  }

  void _selectOption(String option) {
    ref
        .read(quizSessionProvider(_sessionKey).notifier)
        .updateInput(MultipleChoiceInput(option));
  }

  Future<void> _submitAnswer() async {
    try {
      await ref.read(quizSessionProvider(_sessionKey).notifier).submitAnswer();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit answer: $e')),
        );
      }
    }
  }

  void _nextQuestion() {
    _answerController.clear();
    ref.read(quizSessionProvider(_sessionKey).notifier).nextQuestion();
  }

  void _retakeQuiz() {
    _answerController.clear();
    ref.read(quizSessionProvider(_sessionKey).notifier).retake();
  }
}
