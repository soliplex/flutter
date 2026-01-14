import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soliplex_client/soliplex_client.dart';
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
    FutureProvider.family<Quiz, ({String roomId, String quizId})>(
  (ref, params) async {
    final api = ref.watch(apiProvider);
    return api.getQuiz(params.roomId, params.quizId);
  },
);

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
///   case QuizInProgress(:final quiz, :final currentIndex, :final results):
///     // Show current question
///   case QuizCompleted(:final quiz, :final results, :final score):
///     // Show results summary
/// }
/// ```
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
/// Note: [quiz] should have at least one question. This invariant is enforced
/// by [QuizSessionNotifier.start] which is the only production entry point.
/// Direct construction is allowed for testing but callers must ensure validity.
@immutable
class QuizInProgress extends QuizSession {
  /// Creates a quiz in progress state.
  const QuizInProgress({
    required this.quiz,
    required this.currentIndex,
    required this.results,
  });

  /// The quiz being taken.
  final Quiz quiz;

  /// Index of the current question (0-based).
  final int currentIndex;

  /// Results for answered questions, keyed by question ID.
  final Map<String, QuizAnswerResult> results;

  /// The current question.
  QuizQuestion get currentQuestion => quiz.questions[currentIndex];

  /// Whether we're on the last question.
  bool get isLastQuestion => currentIndex >= quiz.questionCount - 1;

  /// Number of questions answered so far.
  int get answeredCount => results.length;

  /// Progress as a fraction (0.0 to 1.0).
  double get progress =>
      quiz.questionCount > 0 ? answeredCount / quiz.questionCount : 0.0;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QuizInProgress &&
          quiz == other.quiz &&
          currentIndex == other.currentIndex &&
          mapEquals(results, other.results);

  @override
  int get hashCode =>
      Object.hash(quiz, currentIndex, Object.hashAll(results.entries));

  @override
  String toString() =>
      'QuizInProgress(quiz: ${quiz.id}, question: ${currentIndex + 1}/'
      '${quiz.questionCount})';
}

/// Quiz has been completed.
@immutable
class QuizCompleted extends QuizSession {
  /// Creates a completed quiz state.
  const QuizCompleted({
    required this.quiz,
    required this.results,
  });

  /// The completed quiz.
  final Quiz quiz;

  /// Results for all answered questions, keyed by question ID.
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

/// Notifier for quiz session state.
///
/// Manages transitions between quiz states and handles answer submission.
///
/// **Usage**:
/// ```dart
/// // Start a quiz
/// ref.read(quizSessionProvider.notifier).start(quiz);
///
/// // Submit an answer
/// final result = await ref.read(quizSessionProvider.notifier)
///     .submitAnswer(roomId, answer);
///
/// // Move to next question
/// ref.read(quizSessionProvider.notifier).nextQuestion();
///
/// // Reset to start over
/// ref.read(quizSessionProvider.notifier).reset();
/// ```
class QuizSessionNotifier extends Notifier<QuizSession> {
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
          quiz, 'quiz', 'Quiz must have at least one question');
    }
    state = QuizInProgress(
      quiz: quiz,
      currentIndex: 0,
      results: const {},
    );
  }

  /// Submits an answer to the current question.
  ///
  /// Returns the [QuizAnswerResult] from the backend.
  /// Updates the session state with the result.
  ///
  /// Throws [StateError] if not in [QuizInProgress] state.
  Future<QuizAnswerResult> submitAnswer(String roomId, String answer) async {
    final currentState = state;
    if (currentState is! QuizInProgress) {
      throw StateError('Cannot submit answer when not in progress');
    }

    final api = ref.read(apiProvider);
    final result = await api.submitQuizAnswer(
      roomId,
      currentState.quiz.id,
      currentState.currentQuestion.id,
      answer,
    );

    // Update results map
    final newResults = Map<String, QuizAnswerResult>.from(currentState.results);
    newResults[currentState.currentQuestion.id] = result;

    state = QuizInProgress(
      quiz: currentState.quiz,
      currentIndex: currentState.currentIndex,
      results: newResults,
    );

    return result;
  }

  /// Moves to the next question or completes the quiz.
  ///
  /// If on the last question, transitions to [QuizCompleted].
  /// Otherwise, increments the current question index.
  ///
  /// Throws [StateError] if not in [QuizInProgress] state.
  void nextQuestion() {
    final currentState = state;
    if (currentState is! QuizInProgress) {
      throw StateError('Cannot advance question when not in progress');
    }

    if (currentState.isLastQuestion) {
      state = QuizCompleted(
        quiz: currentState.quiz,
        results: currentState.results,
      );
    } else {
      state = QuizInProgress(
        quiz: currentState.quiz,
        currentIndex: currentState.currentIndex + 1,
        results: currentState.results,
      );
    }
  }

  /// Resets the quiz session.
  ///
  /// Transitions back to [QuizNotStarted].
  void reset() {
    state = const QuizNotStarted();
  }
}

/// Provider for the quiz session state.
///
/// **Usage**:
/// ```dart
/// // Watch the current state
/// final session = ref.watch(quizSessionProvider);
///
/// // Access the notifier for mutations
/// ref.read(quizSessionProvider.notifier).start(quiz);
/// ```
final quizSessionProvider = NotifierProvider<QuizSessionNotifier, QuizSession>(
  QuizSessionNotifier.new,
);
