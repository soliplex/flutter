import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soliplex_client/soliplex_client.dart';
import 'package:soliplex_frontend/core/logging/loggers.dart';
import 'package:soliplex_frontend/core/providers/api_provider.dart';

/// Provider for fetching a quiz by room and quiz ID.
///
/// **Usage**:
/// ```dart
/// final quizAsync = ref.watch(
///   quizProvider((roomId: 'room-1', quizId: 'quiz-1')),
/// );
/// ```
///
/// **Error Handling**:
/// Throws [SoliplexException] subtypes which should be handled in the UI:
/// - [NetworkException]: Connection failures, timeouts
/// - [NotFoundException]: Quiz not found (404)
/// - [AuthException]: 401/403 authentication errors
/// - [ApiException]: Other server errors
final quizProvider =
    FutureProvider.family<Quiz, ({String roomId, String quizId})>((
  ref,
  params,
) async {
  final api = ref.watch(apiProvider);
  return api.getQuiz(params.roomId, params.quizId);
});

// ============================================================
// QuizInput - user's answer input (null-free)
// ============================================================

/// User's current input for a question.
///
/// Use pattern matching to handle different input types:
/// ```dart
/// switch (input) {
///   case MultipleChoiceInput(:final selectedOption):
///     // Handle selection
///   case TextInput(:final text):
///     // Handle text entry
/// }
/// ```
@immutable
sealed class QuizInput {
  const QuizInput();

  /// The answer text to submit to the API.
  String get answerText;

  /// Whether this input is valid for submission.
  bool get isValid;
}

/// Multiple choice selection.
@immutable
class MultipleChoiceInput extends QuizInput {
  const MultipleChoiceInput(this.selectedOption);

  /// The selected option text.
  final String selectedOption;

  @override
  String get answerText => selectedOption;

  @override
  bool get isValid => true;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MultipleChoiceInput && selectedOption == other.selectedOption;

  @override
  int get hashCode => selectedOption.hashCode;

  @override
  String toString() => 'MultipleChoiceInput($selectedOption)';
}

/// Free-form or fill-in-the-blank text input.
@immutable
class TextInput extends QuizInput {
  const TextInput(this.text);

  /// The entered text.
  final String text;

  @override
  String get answerText => text.trim();

  @override
  bool get isValid => text.trim().isNotEmpty;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is TextInput && text == other.text;

  @override
  int get hashCode => text.hashCode;

  @override
  String toString() => 'TextInput($text)';
}

// ============================================================
// QuestionState - submission state machine (null-free)
// ============================================================

/// State machine for the current question's answer submission.
///
/// Transitions:
/// ```text
/// AwaitingInput ──(input)──► Composing ◄──(clear)───┐
///                                │                   │
///                                └───────────────────┘
///                                │ (submit)
///                                ▼
///                           Submitting
///                             │    │
///                  (success)  │    │ (error)
///                             ▼    ▼
///                        Answered  Composing (preserved input)
///                             │
///                      (next question)
///                             ▼
///                       AwaitingInput
/// ```
@immutable
sealed class QuestionState {
  const QuestionState();
}

/// User hasn't entered any input yet.
@immutable
class AwaitingInput extends QuestionState {
  const AwaitingInput();

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is AwaitingInput;

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() => 'AwaitingInput()';
}

/// User is composing an answer.
@immutable
class Composing extends QuestionState {
  const Composing(this.input);

  /// The current input.
  final QuizInput input;

  /// Whether the input is valid for submission.
  bool get canSubmit => input.isValid;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Composing && input == other.input;

  @override
  int get hashCode => input.hashCode;

  @override
  String toString() => 'Composing($input)';
}

/// Answer is being submitted to the server.
@immutable
class Submitting extends QuestionState {
  const Submitting(this.input);

  /// The input being submitted.
  final QuizInput input;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Submitting && input == other.input;

  @override
  int get hashCode => input.hashCode;

  @override
  String toString() => 'Submitting($input)';
}

/// Server has responded with the result.
@immutable
class Answered extends QuestionState {
  const Answered(this.input, this.result);

  /// The submitted input.
  final QuizInput input;

  /// The result from the server.
  final QuizAnswerResult result;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Answered && input == other.input && result == other.result;

  @override
  int get hashCode => Object.hash(input, result);

  @override
  String toString() => 'Answered($input, correct: ${result.isCorrect})';
}

// ============================================================
// QuizSession - sealed state for quiz progression
// ============================================================

/// Sealed class representing the quiz session state.
///
/// Use pattern matching for exhaustive handling:
/// ```dart
/// switch (session) {
///   case QuizNotStarted():
///     // Show quiz intro or selection
///   case QuizInProgress(:final currentIndex, :final questionState):
///     // Show current question based on questionState
///   case QuizCompleted(:final results):
///     // Show results summary
/// }
/// ```
///
/// Each quiz (identified by roomId + quizId) has isolated session state
/// via the family provider.
@immutable
sealed class QuizSession {
  const QuizSession();
}

/// No quiz is currently in progress.
///
/// This is the initial state before the user starts a quiz.
@immutable
class QuizNotStarted extends QuizSession {
  const QuizNotStarted();

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is QuizNotStarted;

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() => 'QuizNotStarted()';
}

/// A quiz is currently in progress.
///
/// Invariants:
/// - [quiz] must have at least one question
/// - [currentIndex] must be >= 0 and < quiz.questionCount
///
/// These invariants are enforced by [QuizSessionNotifier.start] which is the
/// only production entry point. Direct construction is allowed for testing
/// but callers must ensure validity.
@immutable
class QuizInProgress extends QuizSession {
  /// Creates a quiz in progress state.
  ///
  /// The [results] map is made unmodifiable to preserve immutability.
  QuizInProgress({
    required this.quiz,
    required this.currentIndex,
    required Map<String, QuizAnswerResult> results,
    required this.questionState,
  })  : assert(currentIndex >= 0, 'currentIndex must be non-negative'),
        results = Map.unmodifiable(results);

  /// The quiz being taken.
  final Quiz quiz;

  /// Index of the current question (0-based).
  final int currentIndex;

  /// Results for answered questions, keyed by question ID (unmodifiable).
  final Map<String, QuizAnswerResult> results;

  /// Current question's answer state machine.
  final QuestionState questionState;

  /// The current question.
  QuizQuestion get currentQuestion => quiz.questions[currentIndex];

  /// Whether we're on the last question.
  bool get isLastQuestion => currentIndex >= quiz.questionCount - 1;

  /// Number of questions answered so far.
  int get answeredCount => results.length;

  /// Progress as a fraction (0.0 to 1.0).
  double get progress =>
      quiz.questionCount > 0 ? answeredCount / quiz.questionCount : 0.0;

  /// Creates a copy with the given fields replaced.
  QuizInProgress copyWith({
    int? currentIndex,
    Map<String, QuizAnswerResult>? results,
    QuestionState? questionState,
  }) =>
      QuizInProgress(
        quiz: quiz,
        currentIndex: currentIndex ?? this.currentIndex,
        results: results ?? this.results,
        questionState: questionState ?? this.questionState,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QuizInProgress &&
          quiz == other.quiz &&
          currentIndex == other.currentIndex &&
          mapEquals(results, other.results) &&
          questionState == other.questionState;

  @override
  int get hashCode => Object.hash(
        quiz,
        currentIndex,
        Object.hashAll(results.entries),
        questionState,
      );

  @override
  String toString() =>
      'QuizInProgress(quiz: ${quiz.id}, question: ${currentIndex + 1}/'
      '${quiz.questionCount}, state: $questionState)';
}

/// Quiz has been completed.
@immutable
class QuizCompleted extends QuizSession {
  /// Creates a completed quiz state.
  ///
  /// The [results] map is made unmodifiable to preserve immutability.
  QuizCompleted({
    required this.quiz,
    required Map<String, QuizAnswerResult> results,
  }) : results = Map.unmodifiable(results);

  /// The completed quiz.
  final Quiz quiz;

  /// Results for all answered questions, keyed by question ID (unmodifiable).
  final Map<String, QuizAnswerResult> results;

  /// Number of correct answers.
  int get correctCount => results.values.where((r) => r.isCorrect).length;

  /// Total number of questions answered.
  int get totalAnswered => results.length;

  /// Score as a percentage (0-100).
  int get scorePercent =>
      totalAnswered > 0 ? (correctCount * 100 ~/ totalAnswered) : 0;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QuizCompleted &&
          quiz == other.quiz &&
          mapEquals(results, other.results);

  @override
  int get hashCode => Object.hash(quiz, Object.hashAll(results.entries));

  @override
  String toString() =>
      'QuizCompleted(quiz: ${quiz.id}, score: $correctCount/$totalAnswered)';
}

// ============================================================
// QuizSessionNotifier - manages quiz session state
// ============================================================

/// Family key for quiz session provider.
typedef QuizSessionKey = ({String roomId, String quizId});

/// Notifier for quiz session state.
///
/// Manages transitions between quiz states and handles answer submission.
/// Reads [apiProvider] directly for API calls (idiomatic Riverpod pattern;
/// for testing, override [apiProvider]).
///
/// Each quiz (identified by roomId + quizId) has isolated session state.
///
/// **Usage**:
/// ```dart
/// final key = (roomId: 'room-1', quizId: 'quiz-1');
///
/// // Start a quiz
/// ref.read(quizSessionProvider(key).notifier).start(quiz);
///
/// // Update answer input
/// ref.read(quizSessionProvider(key).notifier).updateInput(TextInput('ans'));
///
/// // Submit answer (roomId comes from the family key)
/// await ref.read(quizSessionProvider(key).notifier).submitAnswer();
///
/// // Move to next question
/// ref.read(quizSessionProvider(key).notifier).nextQuestion();
///
/// // Reset to start over
/// ref.read(quizSessionProvider(key).notifier).reset();
/// ```
class QuizSessionNotifier extends Notifier<QuizSession> {
  /// Creates a notifier for the given quiz session key.
  QuizSessionNotifier(this.arg);

  /// The family key containing roomId and quizId.
  final QuizSessionKey arg;

  @override
  QuizSession build() => const QuizNotStarted();

  /// Starts a new quiz session.
  ///
  /// Transitions from any state to [QuizInProgress] at question 0.
  ///
  /// Throws [ArgumentError] if [quiz] has no questions.
  void start(Quiz quiz) {
    if (!quiz.hasQuestions) {
      throw ArgumentError.value(
        quiz,
        'quiz',
        'Quiz must have at least one question',
      );
    }
    state = QuizInProgress(
      quiz: quiz,
      currentIndex: 0,
      results: const {},
      questionState: const AwaitingInput(),
    );
  }

  /// Updates the input for the current question.
  ///
  /// Transitions from [AwaitingInput] or [Composing] to [Composing].
  /// Ignored if not in [QuizInProgress] or already [Submitting]/[Answered].
  void updateInput(QuizInput input) {
    final currentState = state;
    if (currentState is! QuizInProgress) return;

    // Only allow input changes in AwaitingInput or Composing states
    if (currentState.questionState is Submitting ||
        currentState.questionState is Answered) {
      return;
    }

    state = currentState.copyWith(questionState: Composing(input));
  }

  /// Clears the current input, returning to [AwaitingInput] state.
  ///
  /// Only effective when in [Composing] state.
  void clearInput() {
    final currentState = state;
    if (currentState is! QuizInProgress) return;
    if (currentState.questionState is! Composing) return;

    state = currentState.copyWith(questionState: const AwaitingInput());
  }

  /// Submits the current input to the server.
  ///
  /// Transitions: [Composing] → [Submitting] → [Answered]
  /// On error: [Submitting] → [Composing] (input preserved)
  ///
  /// Returns the [QuizAnswerResult] from the backend.
  /// Uses roomId from the family key.
  ///
  /// Throws [StateError] if not in [QuizInProgress] with [Composing] state.
  /// Throws [ArgumentError] if input is empty.
  Future<QuizAnswerResult> submitAnswer() async {
    final currentState = state;
    if (currentState is! QuizInProgress) {
      throw StateError('Cannot submit answer when not in progress');
    }
    final questionState = currentState.questionState;
    if (questionState is! Composing) {
      throw StateError('Cannot submit answer when not composing');
    }
    if (!questionState.canSubmit) {
      throw ArgumentError('Answer cannot be empty');
    }

    final input = questionState.input;

    // Transition to Submitting
    state = currentState.copyWith(questionState: Submitting(input));

    try {
      final api = ref.read(apiProvider);
      final questionId = currentState.currentQuestion.id;
      final result = await api.submitQuizAnswer(
        arg.roomId,
        currentState.quiz.id,
        questionId,
        input.answerText,
      );

      // Re-read state after async gap to avoid race conditions
      final afterState = state;
      if (afterState is! QuizInProgress) {
        // State changed during await (e.g., reset) - just return result
        return result;
      }

      // Update results map and transition to Answered
      final newResults = {...afterState.results, questionId: result};
      state = afterState.copyWith(
        results: newResults,
        questionState: Answered(input, result),
      );

      return result;
    } catch (e, stackTrace) {
      Loggers.quiz.error(
        'Quiz submitAnswer failed',
        error: e,
        stackTrace: stackTrace,
      );

      // Re-read state after async gap
      final afterState = state;
      if (afterState is! QuizInProgress) {
        // State changed during await - just rethrow
        rethrow;
      }
      // On error, return to Composing with input preserved
      state = afterState.copyWith(questionState: Composing(input));
      rethrow;
    }
  }

  /// Moves to the next question or completes the quiz.
  ///
  /// If on the last question, transitions to [QuizCompleted].
  /// Otherwise, increments current question index with [AwaitingInput].
  ///
  /// Throws [StateError] if not in [QuizInProgress] with [Answered] state.
  void nextQuestion() {
    final currentState = state;
    if (currentState is! QuizInProgress) {
      throw StateError('Cannot advance question when not in progress');
    }
    if (currentState.questionState is! Answered) {
      throw StateError('Cannot advance question before answering');
    }

    if (currentState.isLastQuestion) {
      state = QuizCompleted(
        quiz: currentState.quiz,
        results: currentState.results,
      );
    } else {
      state = currentState.copyWith(
        currentIndex: currentState.currentIndex + 1,
        questionState: const AwaitingInput(),
      );
    }
  }

  /// Resets the quiz session.
  ///
  /// Transitions back to [QuizNotStarted].
  void reset() {
    state = const QuizNotStarted();
  }

  /// Restarts the quiz from the beginning.
  ///
  /// Can be called from [QuizInProgress] or [QuizCompleted] state.
  /// Throws [StateError] if called from [QuizNotStarted].
  void retake() {
    final currentState = state;
    final quiz = switch (currentState) {
      QuizInProgress(:final quiz) => quiz,
      QuizCompleted(:final quiz) => quiz,
      QuizNotStarted() => throw StateError(
          'Cannot retake quiz that was never started',
        ),
    };

    state = QuizInProgress(
      quiz: quiz,
      currentIndex: 0,
      results: const {},
      questionState: const AwaitingInput(),
    );
  }
}

/// Provider for the quiz session state.
///
/// Family provider keyed by (roomId, quizId) - each quiz has isolated state.
///
/// **Usage**:
/// ```dart
/// final key = (roomId: 'room-1', quizId: 'quiz-1');
///
/// // Watch the current state
/// final session = ref.watch(quizSessionProvider(key));
///
/// // Access the notifier for mutations
/// ref.read(quizSessionProvider(key).notifier).start(quiz);
/// ```
final quizSessionProvider =
    NotifierProvider.family<QuizSessionNotifier, QuizSession, QuizSessionKey>(
  QuizSessionNotifier.new,
);
