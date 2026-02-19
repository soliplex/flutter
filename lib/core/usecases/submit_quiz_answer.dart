import 'package:soliplex_client/soliplex_client.dart';
import 'package:soliplex_frontend/core/domain/quiz_session.dart';

/// Submits a quiz answer, orchestrating I/O and domain transitions.
///
/// Expects the session to already be in [Submitting] state (the Notifier
/// owns that transition for immediate UI feedback). Calls domain methods:
/// - [QuizInProgress.withAnswer] — records the result on success
/// - [QuizInProgress.withSubmissionFailed] — recovers on API failure
///
/// Always returns a valid domain state. On success, [QuestionState]
/// is [Answered]. On failure, [QuestionState] is [SubmissionFailed]
/// with the error and stack trace preserved for the UI.
class SubmitQuizAnswer {
  SubmitQuizAnswer(this._api);

  final SoliplexApi _api;

  Future<QuizInProgress> call({
    required QuizSessionKey key,
    required QuizInProgress session,
  }) async {
    final input = (session.questionState as Submitting).input;

    try {
      // I/O: submit via API using data from domain objects.
      final answer = await _api.submitQuizAnswer(
        key.roomId,
        session.quiz.id,
        session.currentQuestion.id,
        input.answerText,
      );
      // Domain: record the answer.
      return session.withAnswer(answer);
    } on Exception catch (e, stackTrace) {
      // Domain: recover with error information.
      return session.withSubmissionFailed(e, stackTrace);
    }
  }
}
