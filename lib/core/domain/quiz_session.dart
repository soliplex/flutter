import 'package:equatable/equatable.dart';
import 'package:soliplex_client/soliplex_client.dart';

// ============================================================
// QuizSessionKey - domain identity for a quiz session
// ============================================================

/// Identifies a quiz session by room and quiz.
typedef QuizSessionKey = ({String roomId, String quizId});

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
sealed class QuizInput extends Equatable {
  const QuizInput();

  /// The answer text to submit to the API.
  String get answerText;

  /// Whether this input is valid for submission.
  bool get isValid;
}

/// Multiple choice selection.
class MultipleChoiceInput extends QuizInput {
  const MultipleChoiceInput(this.selectedOption);

  /// The selected option text.
  final String selectedOption;

  @override
  String get answerText => selectedOption;

  @override
  bool get isValid => true;

  @override
  List<Object?> get props => [selectedOption];
}

/// Free-form or fill-in-the-blank text input.
class TextInput extends QuizInput {
  const TextInput(this.text);

  /// The entered text.
  final String text;

  @override
  String get answerText => text.trim();

  @override
  bool get isValid => text.trim().isNotEmpty;

  @override
  List<Object?> get props => [text];
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
///                                │ (user submits)
///                                ▼
///                           Submitting ◄──(user retries)──┐
///                             │    │                      │
///                  (success)  │    │ (API error)          │
///                             ▼    ▼                      │
///                        Answered  SubmissionFailed ───────┘
///                             │         │
///                      (next question)  │ (user edits input)
///                             ▼         ▼
///                       AwaitingInput  Composing
/// ```
sealed class QuestionState extends Equatable {
  const QuestionState();
}

/// User hasn't entered any input yet.
class AwaitingInput extends QuestionState {
  const AwaitingInput();

  @override
  List<Object?> get props => [];
}

/// User is composing an answer.
class Composing extends QuestionState {
  const Composing(this.input);

  /// The current input.
  final QuizInput input;

  /// Whether the input is valid for submission.
  bool get canSubmit => input.isValid;

  @override
  List<Object?> get props => [input];
}

/// Answer is being submitted to the server.
class Submitting extends QuestionState {
  const Submitting(this.input);

  /// The input being submitted.
  final QuizInput input;

  @override
  List<Object?> get props => [input];
}

/// Server has responded with the result.
class Answered extends QuestionState {
  const Answered(this.input, this.result);

  /// The submitted input.
  final QuizInput input;

  /// The result from the server.
  final QuizAnswerResult result;

  @override
  List<Object?> get props => [input, result];

  @override
  String toString() => 'Answered($input, correct: ${result.isCorrect})';
}

/// Submission failed. Input is preserved for retry, error and stack trace
/// are available for the UI to display and for logging.
class SubmissionFailed extends QuestionState {
  const SubmissionFailed({
    required this.input,
    required this.error,
    this.stackTrace,
  });

  /// The input that was being submitted (preserved for retry).
  final QuizInput input;

  /// The error from the failed API call.
  final Exception error;

  /// The stack trace from the failed API call (for logging).
  final StackTrace? stackTrace;

  @override
  List<Object?> get props => [input, error];
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
sealed class QuizSession extends Equatable {
  const QuizSession();

  /// Starts a quiz. Returns [QuizInProgress] at question 0.
  ///
  /// Throws [ArgumentError] if [quiz] has no questions.
  static QuizInProgress start(Quiz quiz) {
    if (!quiz.hasQuestions) {
      throw ArgumentError.value(
        quiz,
        'quiz',
        'Quiz must have at least one question',
      );
    }
    return QuizInProgress(
      quiz: quiz,
      currentIndex: 0,
      results: const {},
      questionState: const AwaitingInput(),
    );
  }

  // -- Default behaviors for states that don't support these operations --

  /// Updates user input. No-op outside [QuizInProgress].
  QuizSession withInput(QuizInput input);

  /// Clears input. No-op outside [QuizInProgress].
  QuizSession withInputCleared();

  /// Advances to next question or completes the quiz.
  ///
  /// Throws [StateError] outside [QuizInProgress].
  QuizSession advance() =>
      throw StateError('Cannot advance question when not in progress');

  /// Restarts the quiz from the beginning.
  ///
  /// Throws [StateError] from [QuizNotStarted].
  QuizSession retake() =>
      throw StateError('Cannot retake quiz that was never started');
}

/// No quiz is currently in progress.
///
/// This is the initial state before the user starts a quiz.
class QuizNotStarted extends QuizSession {
  const QuizNotStarted();

  @override
  QuizSession withInput(QuizInput input) => const QuizNotStarted();

  @override
  QuizSession withInputCleared() => const QuizNotStarted();

  @override
  List<Object?> get props => [];
}

/// A quiz is currently in progress.
///
/// Invariants:
/// - [quiz] must have at least one question
/// - [currentIndex] must be >= 0 and < quiz.questionCount
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

  // -- State transition methods --

  /// Updates user input. Transitions to [Composing].
  ///
  /// No-op if currently [Submitting] or [Answered].
  @override
  QuizInProgress withInput(QuizInput input) {
    if (questionState is Submitting || questionState is Answered) return this;
    return copyWith(questionState: Composing(input));
  }

  /// Clears input. Transitions to [AwaitingInput].
  ///
  /// No-op if not in [Composing] or [SubmissionFailed] state.
  @override
  QuizInProgress withInputCleared() {
    return switch (questionState) {
      Composing() ||
      SubmissionFailed() =>
        copyWith(questionState: const AwaitingInput()),
      _ => this,
    };
  }

  /// Marks the current question as being submitted.
  ///
  /// Accepts [Composing] or [SubmissionFailed] state (for retry).
  /// Throws [StateError] if in any other state.
  /// Throws [ArgumentError] if input is not valid.
  QuizInProgress submitting() {
    return switch (questionState) {
      Composing(:final input) when input.isValid =>
        copyWith(questionState: Submitting(input)),
      SubmissionFailed(:final input) when input.isValid =>
        copyWith(questionState: Submitting(input)),
      Composing() ||
      SubmissionFailed() =>
        throw ArgumentError('Answer cannot be empty'),
      _ => throw StateError('Cannot submit answer when not composing'),
    };
  }

  /// Records an answer result from the backend.
  ///
  /// Returns new state with [Answered] questionState and updated results.
  /// No-op if not in [Submitting] state (race condition safety).
  QuizInProgress withAnswer(QuizAnswerResult result) {
    return switch (questionState) {
      Submitting(:final input) => copyWith(
          results: {...results, currentQuestion.id: result},
          questionState: Answered(input, result),
        ),
      _ => this,
    };
  }

  /// Records a submission failure. Transitions to [SubmissionFailed] with
  /// input preserved for retry and [error] available for the UI.
  ///
  /// No-op if not in [Submitting] state (race condition safety).
  QuizInProgress withSubmissionFailed(
    Exception error, [
    StackTrace? stackTrace,
  ]) {
    return switch (questionState) {
      Submitting(:final input) => copyWith(
          questionState: SubmissionFailed(
            input: input,
            error: error,
            stackTrace: stackTrace,
          ),
        ),
      _ => this,
    };
  }

  /// Advances to next question or completes the quiz.
  ///
  /// Returns [QuizInProgress] for the next question, or [QuizCompleted]
  /// if this was the last question.
  ///
  /// Throws [StateError] if current question is not [Answered].
  @override
  QuizSession advance() {
    if (questionState is! Answered) {
      throw StateError('Cannot advance question before answering');
    }
    if (isLastQuestion) {
      return QuizCompleted(quiz: quiz, results: results);
    }
    return copyWith(
      currentIndex: currentIndex + 1,
      questionState: const AwaitingInput(),
    );
  }

  /// Restarts the quiz from the beginning.
  @override
  QuizInProgress retake() {
    return QuizInProgress(
      quiz: quiz,
      currentIndex: 0,
      results: const {},
      questionState: const AwaitingInput(),
    );
  }

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
  List<Object?> get props => [quiz, currentIndex, results, questionState];

  @override
  String toString() =>
      'QuizInProgress(quiz: ${quiz.id}, question: ${currentIndex + 1}/'
      '${quiz.questionCount}, state: $questionState)';
}

/// Quiz has been completed.
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
  QuizSession withInput(QuizInput input) =>
      QuizCompleted(quiz: quiz, results: results);

  @override
  QuizSession withInputCleared() => QuizCompleted(quiz: quiz, results: results);

  /// Restarts the quiz from the beginning.
  @override
  QuizInProgress retake() {
    return QuizInProgress(
      quiz: quiz,
      currentIndex: 0,
      results: const {},
      questionState: const AwaitingInput(),
    );
  }

  @override
  List<Object?> get props => [quiz, results];

  @override
  String toString() =>
      'QuizCompleted(quiz: ${quiz.id}, score: $correctCount/$totalAnswered)';
}
