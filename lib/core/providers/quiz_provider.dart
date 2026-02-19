import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soliplex_client/soliplex_client.dart';
import 'package:soliplex_frontend/core/domain/quiz_session.dart';
import 'package:soliplex_frontend/core/providers/api_provider.dart';
import 'package:soliplex_frontend/core/usecases/submit_quiz_answer.dart';

// Re-export domain types so existing imports keep working.
export 'package:soliplex_frontend/core/domain/quiz_session.dart';

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

/// Notifier for quiz session state.
///
/// Thin adapter that delegates to domain methods on [QuizSession] and
/// the [SubmitQuizAnswer] use case. Each quiz (identified by roomId +
/// quizId) has isolated session state via the family provider.
class QuizSessionNotifier extends Notifier<QuizSession> {
  /// Creates a notifier for the given quiz session key.
  QuizSessionNotifier(this.arg);

  /// The family key containing roomId and quizId.
  final QuizSessionKey arg;

  @override
  QuizSession build() => const QuizNotStarted();

  /// Starts a new quiz session at question 0.
  void start(Quiz quiz) => state = QuizSession.start(quiz);

  /// Updates the input for the current question.
  void updateInput(QuizInput input) => state = state.withInput(input);

  /// Clears the current input.
  void clearInput() => state = state.withInputCleared();

  /// Advances to the next question or completes the quiz.
  void nextQuestion() => state = state.advance();

  /// Resets the quiz session to [QuizNotStarted].
  void reset() => state = const QuizNotStarted();

  /// Restarts the quiz from the beginning.
  void retake() => state = state.retake();

  /// Submits the current answer via [SubmitQuizAnswer].
  ///
  /// Sets intermediate [Submitting] state for immediate UI feedback,
  /// then delegates to the use case which handles both success and
  /// failure domain transitions.
  Future<void> submitAnswer() async {
    final session = state;
    if (session is! QuizInProgress) {
      throw StateError('Quiz is not in progress');
    }
    final submitting = session.submitting();
    state = submitting;
    final result = await SubmitQuizAnswer(ref.read(apiProvider)).call(
      key: arg,
      session: submitting,
    );
    // Race condition guard: only update if still in progress
    // (e.g., user may have called reset() during the API call).
    if (state is QuizInProgress) state = result;
  }
}

/// Provider for the quiz session state.
///
/// Family provider keyed by (roomId, quizId) — each quiz has isolated state.
final quizSessionProvider =
    NotifierProvider.family<QuizSessionNotifier, QuizSession, QuizSessionKey>(
  QuizSessionNotifier.new,
);
