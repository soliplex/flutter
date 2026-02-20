import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:soliplex_client/soliplex_client.dart';
import 'package:soliplex_frontend/core/domain/quiz_session.dart';
import 'package:soliplex_frontend/core/usecases/submit_quiz_answer.dart';

import '../../helpers/test_helpers.dart';

void main() {
  late MockSoliplexApi mockApi;
  late SubmitQuizAnswer useCase;

  final quiz = Quiz(
    id: 'quiz-1',
    title: 'Test',
    questions: const [
      QuizQuestion(id: 'q1', text: 'Q1', type: FreeForm()),
      QuizQuestion(id: 'q2', text: 'Q2', type: FreeForm()),
    ],
  );

  const key = (roomId: 'room-1', quizId: 'quiz-1');

  setUp(() {
    mockApi = MockSoliplexApi();
    useCase = SubmitQuizAnswer(mockApi);
  });

  group('SubmitQuizAnswer', () {
    test('returns Answered state on API success', () async {
      const result = CorrectAnswer();
      when(
        () => mockApi.submitQuizAnswer('room-1', 'quiz-1', 'q1', 'my answer'),
      ).thenAnswer((_) async => result);

      final session = QuizSession.start(quiz)
          .withInput(const TextInput('my answer'))
          .submitting();

      final updated = await useCase.call(key: key, session: session);

      expect(updated.questionState, isA<Answered>());
      final answered = updated.questionState as Answered;
      expect(answered.result, isA<CorrectAnswer>());
      expect(updated.results['q1'], isA<CorrectAnswer>());
      verify(
        () => mockApi.submitQuizAnswer('room-1', 'quiz-1', 'q1', 'my answer'),
      ).called(1);
    });

    test('returns SubmissionFailed state on API error', () async {
      when(
        () => mockApi.submitQuizAnswer(any(), any(), any(), any()),
      ).thenThrow(const NetworkException(message: 'Connection timeout'));

      final session = QuizSession.start(quiz)
          .withInput(const TextInput('my answer'))
          .submitting();

      final updated = await useCase.call(key: key, session: session);

      expect(updated.questionState, isA<SubmissionFailed>());
      final failed = updated.questionState as SubmissionFailed;
      expect(failed.input, equals(const TextInput('my answer')));
      expect(failed.error, isA<NetworkException>());
    });

    test('captures stack trace on API error', () async {
      when(
        () => mockApi.submitQuizAnswer(any(), any(), any(), any()),
      ).thenThrow(const NetworkException(message: 'timeout'));

      final session = QuizSession.start(quiz)
          .withInput(const TextInput('answer'))
          .submitting();

      final updated = await useCase.call(key: key, session: session);

      final failed = updated.questionState as SubmissionFailed;
      expect(failed.stackTrace, isNotNull);
    });

    test('extracts data from domain objects for API call', () async {
      when(
        () => mockApi.submitQuizAnswer(any(), any(), any(), any()),
      ).thenAnswer((_) async => const CorrectAnswer());

      // Start at question 2 (index 1) to verify correct question is used
      final session = QuizSession.start(quiz)
          .withInput(const TextInput('answer1'))
          .submitting()
          .withAnswer(const CorrectAnswer())
          .advance() as QuizInProgress;
      final submitting =
          session.withInput(const TextInput('answer2')).submitting();

      await useCase.call(key: key, session: submitting);

      verify(
        () => mockApi.submitQuizAnswer('room-1', 'quiz-1', 'q2', 'answer2'),
      ).called(1);
    });

    test('trims text input before submitting', () async {
      when(
        () => mockApi.submitQuizAnswer(any(), any(), any(), any()),
      ).thenAnswer((_) async => const CorrectAnswer());

      final session = QuizSession.start(quiz)
          .withInput(const TextInput('  padded answer  '))
          .submitting();

      await useCase.call(key: key, session: session);

      verify(
        () => mockApi.submitQuizAnswer(
          'room-1',
          'quiz-1',
          'q1',
          'padded answer',
        ),
      ).called(1);
    });

    test('works with MultipleChoiceInput', () async {
      when(
        () => mockApi.submitQuizAnswer(any(), any(), any(), any()),
      ).thenAnswer((_) async => const IncorrectAnswer(expectedAnswer: 'B'));

      final session = QuizSession.start(quiz)
          .withInput(const MultipleChoiceInput('A'))
          .submitting();

      final updated = await useCase.call(key: key, session: session);

      expect(updated.questionState, isA<Answered>());
      final answered = updated.questionState as Answered;
      expect(answered.result, isA<IncorrectAnswer>());
      verify(
        () => mockApi.submitQuizAnswer('room-1', 'quiz-1', 'q1', 'A'),
      ).called(1);
    });
  });
}
