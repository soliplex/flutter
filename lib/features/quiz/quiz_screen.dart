import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:soliplex_client/soliplex_client.dart';
import 'package:soliplex_frontend/core/logging/loggers.dart';
import 'package:soliplex_frontend/core/providers/quiz_provider.dart';
import 'package:soliplex_frontend/core/providers/shell_config_provider.dart';
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
  const QuizScreen({required this.roomId, required this.quizId, super.key});

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
    final features = ref.watch(featuresProvider);

    return AppShell(
      config: ShellConfig(
        leading: IconButton(
          icon: Icon(Icons.adaptive.arrow_back),
          tooltip: 'Back to room',
          onPressed: _handleBack,
        ),
        title: quizAsync.whenOrNull(data: (quiz) => Text(quiz.title)),
        actions: [
          if (features.enableSettings)
            Semantics(
              label: 'Settings',
              child: IconButton(
                icon: const Icon(Icons.settings),
                onPressed: () => context.push('/settings'),
                tooltip: 'Open settings',
              ),
            ),
        ],
      ),
      body: quizAsync.when(
        data: (quiz) => _buildQuizContent(context, quiz),
        loading: () => const LoadingIndicator(),
        error: (error, stack) => switch (error) {
          NotFoundException() => ErrorDisplay(
              error: error,
              stackTrace: stack,
              onRetry: _handleBack,
              retryLabel: 'Back to Room',
            ),
          _ => ErrorDisplay(
              error: error,
              stackTrace: stack,
              onRetry: () => ref.invalidate(quizProvider(_sessionKey)),
            ),
        },
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
          backgroundColor: Theme.of(
            context,
          ).colorScheme.surfaceContainerHighest,
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
      FillBlank() || FreeForm() => _buildTextInput(
          context,
          hint: 'Type your answer...',
          questionState: questionState,
        ),
    };
  }

  Widget _buildMultipleChoice(
    BuildContext context, {
    required List<String> options,
    required String? selectedOption,
    required QuestionState questionState,
  }) {
    final isDisabled = questionState is Answered || questionState is Submitting;

    // Extract result from Answered state via pattern matching
    final answeredResult = switch (questionState) {
      Answered(:final result) => result,
      _ => null,
    };

    final radii = SoliplexTheme.of(context).radii;
    final colorScheme = Theme.of(context).colorScheme;

    return RadioGroup<String>(
      groupValue: selectedOption,
      onChanged: (v) => _selectOption(v!),
      child: Column(
        children: options.map((option) {
          final isSelected = selectedOption == option;
          final isCorrect = switch (answeredResult) {
            CorrectAnswer() => isSelected, // selected option is correct
            IncorrectAnswer(:final expectedAnswer) =>
              expectedAnswer.trim().toLowerCase() ==
                  option.trim().toLowerCase(),
            _ => false,
          };
          final isWrong =
              answeredResult != null && isSelected && !answeredResult.isCorrect;

          final backgroundColor = switch ((isCorrect, isWrong, isSelected)) {
            (true, _, _) => colorScheme.primaryContainer,
            (_, true, _) => colorScheme.errorContainer,
            (_, _, true) => colorScheme.secondaryContainer,
            _ => colorScheme.surface,
          };
          final foregroundColor = switch ((isCorrect, isWrong, isSelected)) {
            (true, _, _) => colorScheme.onPrimaryContainer,
            (_, true, _) => colorScheme.onErrorContainer,
            (_, _, true) => colorScheme.onSecondaryContainer,
            _ => colorScheme.onSurface,
          };

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
      textInputAction: TextInputAction.done,
      onSubmitted: isDisabled ? null : (_) => _submitAnswer(),
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
          Icon(isCorrect ? Icons.check_circle : Icons.cancel, color: iconColor),
          const SizedBox(width: SoliplexSpacing.s2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isCorrect ? 'Correct!' : 'Incorrect',
                  style: textTheme.titleMedium?.copyWith(color: contentColor),
                ),
                if (result case IncorrectAnswer(:final expectedAnswer)) ...[
                  const SizedBox(height: SoliplexSpacing.s1),
                  Text(
                    'Expected: $expectedAnswer',
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
          child: Text(session.isLastQuestion ? 'See Results' : 'Next Question'),
        ),
    };
  }

  Widget _buildResultsScreen(BuildContext context, QuizCompleted session) {
    final colorScheme = Theme.of(context).colorScheme;
    final percent = session.scorePercent;

    final (scoreColor, scoreIcon) = switch (percent) {
      >= 70 => (colorScheme.primary, Icons.emoji_events),
      >= 40 => (colorScheme.tertiary, Icons.thumb_up),
      _ => (colorScheme.error, Icons.refresh),
    };

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.all(SoliplexSpacing.s4),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(scoreIcon, size: 64, color: scoreColor),
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
    Loggers.quiz.info(
      'Quiz started: ${widget.quizId}'
      ' (${quiz.questionCount} questions)',
    );
    ref.read(quizSessionProvider(_sessionKey).notifier).start(quiz);
  }

  void _selectOption(String option) {
    ref
        .read(quizSessionProvider(_sessionKey).notifier)
        .updateInput(MultipleChoiceInput(option));
  }

  Future<void> _submitAnswer() async {
    Loggers.quiz.debug('Answer submitted for quiz ${widget.quizId}');
    try {
      await ref.read(quizSessionProvider(_sessionKey).notifier).submitAnswer();
    } on NetworkException catch (e, stackTrace) {
      Loggers.quiz.error(
        'Quiz submit failed: Network error - ${e.message}',
        error: e,
        stackTrace: stackTrace,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Network error: ${e.message}'),
            action: SnackBarAction(label: 'Retry', onPressed: _submitAnswer),
          ),
        );
      }
    } on AuthException catch (e, stackTrace) {
      Loggers.quiz.error(
        'Quiz submit failed: Auth error - ${e.message}',
        error: e,
        stackTrace: stackTrace,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Session expired. Please sign in again.'),
          ),
        );
      }
    } on SoliplexException catch (e, stackTrace) {
      Loggers.quiz.error(
        'Quiz submit failed: $e',
        error: e,
        stackTrace: stackTrace,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Something went wrong: $e\nPlease try again.'),
          ),
        );
      }
    } catch (e, stackTrace) {
      Loggers.quiz.error(
        'Quiz submit failed: $e',
        error: e,
        stackTrace: stackTrace,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unexpected error: $e'),
            action: SnackBarAction(label: 'Retry', onPressed: _submitAnswer),
          ),
        );
      }
    }
  }

  void _nextQuestion() {
    final session = ref.read(quizSessionProvider(_sessionKey));
    if (session is QuizInProgress && session.isLastQuestion) {
      Loggers.quiz.info('Quiz completed: ${widget.quizId}');
    }
    _answerController.clear();
    ref.read(quizSessionProvider(_sessionKey).notifier).nextQuestion();
  }

  void _retakeQuiz() {
    Loggers.quiz.info('Quiz retaken: ${widget.quizId}');
    _answerController.clear();
    ref.read(quizSessionProvider(_sessionKey).notifier).retake();
  }
}
