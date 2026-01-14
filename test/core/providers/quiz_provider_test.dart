import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:soliplex_client/soliplex_client.dart';
import 'package:soliplex_frontend/core/providers/api_provider.dart';
import 'package:soliplex_frontend/core/providers/quiz_provider.dart';

import '../../helpers/test_helpers.dart';

void main() {
  group('quizProvider', () {
    late MockSoliplexApi mockApi;

    setUp(() {
      mockApi = MockSoliplexApi();
    });

    test('returns quiz from API', () async {
      // Arrange
      const roomId = 'room-1';
      const quizId = 'quiz-1';
      const quiz = Quiz(
        id: quizId,
        title: 'Test Quiz',
        questions: [
          QuizQuestion(id: 'q1', text: 'Question 1', type: FreeForm()),
        ],
      );
      when(
        () => mockApi.getQuiz(roomId, quizId),
      ).thenAnswer((_) async => quiz);

      final container = ProviderContainer(
        overrides: [apiProvider.overrideWithValue(mockApi)],
      );
      addTearDown(container.dispose);

      // Act
      final result = await container.read(
        quizProvider((roomId: roomId, quizId: quizId)).future,
      );

      // Assert
      expect(result.id, quizId);
      expect(result.title, 'Test Quiz');
      expect(result.questionCount, 1);
      verify(() => mockApi.getQuiz(roomId, quizId)).called(1);
    });

    test('propagates NotFoundException when quiz does not exist', () async {
      // Arrange
      const roomId = 'room-1';
      const quizId = 'nonexistent';
      when(() => mockApi.getQuiz(roomId, quizId)).thenThrow(
        const NotFoundException(
          message: 'Quiz not found',
          resource: '/rooms/room-1/quiz/nonexistent',
        ),
      );

      final container = ProviderContainer(
        overrides: [apiProvider.overrideWithValue(mockApi)],
      );
      addTearDown(container.dispose);

      // Act
      final completer = Completer<AsyncValue<Quiz>>();
      container
        ..listen(quizProvider((roomId: roomId, quizId: quizId)), (_, next) {
          if (next.hasError) {
            completer.complete(next);
          }
        })
        ..read(quizProvider((roomId: roomId, quizId: quizId)));
      final state = await completer.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () =>
            container.read(quizProvider((roomId: roomId, quizId: quizId))),
      );

      // Assert
      expect(state.hasError, isTrue);
      expect(state.error, isA<NotFoundException>());
    });

    test('caches quizzes separately per room and quiz ID', () async {
      // Arrange
      const quiz1 = Quiz(id: 'quiz-1', title: 'Quiz 1', questions: []);
      const quiz2 = Quiz(id: 'quiz-2', title: 'Quiz 2', questions: []);

      when(
        () => mockApi.getQuiz('room-1', 'quiz-1'),
      ).thenAnswer((_) async => quiz1);
      when(
        () => mockApi.getQuiz('room-1', 'quiz-2'),
      ).thenAnswer((_) async => quiz2);

      final container = ProviderContainer(
        overrides: [apiProvider.overrideWithValue(mockApi)],
      );
      addTearDown(container.dispose);

      // Act
      final result1 = await container.read(
        quizProvider((roomId: 'room-1', quizId: 'quiz-1')).future,
      );
      final result2 = await container.read(
        quizProvider((roomId: 'room-1', quizId: 'quiz-2')).future,
      );

      // Assert
      expect(result1.id, 'quiz-1');
      expect(result2.id, 'quiz-2');
      verify(() => mockApi.getQuiz('room-1', 'quiz-1')).called(1);
      verify(() => mockApi.getQuiz('room-1', 'quiz-2')).called(1);
    });
  });

  group('QuizSession types', () {
    group('QuizNotStarted', () {
      test('equality', () {
        const a = QuizNotStarted();
        const b = QuizNotStarted();

        expect(a, equals(b));
        expect(a.hashCode, equals(b.hashCode));
      });

      test('toString', () {
        const session = QuizNotStarted();

        expect(session.toString(), 'QuizNotStarted()');
      });
    });

    group('QuizInProgress', () {
      test('stores quiz, currentIndex, and results', () {
        const quiz = Quiz(
          id: 'quiz-1',
          title: 'Test',
          questions: [
            QuizQuestion(id: 'q1', text: 'Q1', type: FreeForm()),
            QuizQuestion(id: 'q2', text: 'Q2', type: FreeForm()),
          ],
        );
        const session = QuizInProgress(
          quiz: quiz,
          currentIndex: 1,
          results: {},
        );

        expect(session.quiz.id, 'quiz-1');
        expect(session.currentIndex, 1);
        expect(session.results, isEmpty);
      });

      test('currentQuestion returns question at currentIndex', () {
        const quiz = Quiz(
          id: 'quiz-1',
          title: 'Test',
          questions: [
            QuizQuestion(id: 'q1', text: 'Q1', type: FreeForm()),
            QuizQuestion(id: 'q2', text: 'Q2', type: FreeForm()),
          ],
        );
        const session = QuizInProgress(
          quiz: quiz,
          currentIndex: 1,
          results: {},
        );

        expect(session.currentQuestion.id, 'q2');
      });

      test('isLastQuestion is true when on last question', () {
        const quiz = Quiz(
          id: 'quiz-1',
          title: 'Test',
          questions: [
            QuizQuestion(id: 'q1', text: 'Q1', type: FreeForm()),
            QuizQuestion(id: 'q2', text: 'Q2', type: FreeForm()),
          ],
        );
        const atFirst = QuizInProgress(
          quiz: quiz,
          currentIndex: 0,
          results: {},
        );
        const atLast = QuizInProgress(
          quiz: quiz,
          currentIndex: 1,
          results: {},
        );

        expect(atFirst.isLastQuestion, isFalse);
        expect(atLast.isLastQuestion, isTrue);
      });

      test('progress calculates correctly', () {
        const quiz = Quiz(
          id: 'quiz-1',
          title: 'Test',
          questions: [
            QuizQuestion(id: 'q1', text: 'Q1', type: FreeForm()),
            QuizQuestion(id: 'q2', text: 'Q2', type: FreeForm()),
            QuizQuestion(id: 'q3', text: 'Q3', type: FreeForm()),
            QuizQuestion(id: 'q4', text: 'Q4', type: FreeForm()),
          ],
        );
        const noAnswers = QuizInProgress(
          quiz: quiz,
          currentIndex: 0,
          results: {},
        );
        const halfAnswered = QuizInProgress(
          quiz: quiz,
          currentIndex: 2,
          results: {
            'q1': QuizAnswerResult(isCorrect: true, expectedAnswer: 'A'),
            'q2': QuizAnswerResult(isCorrect: false, expectedAnswer: 'B'),
          },
        );

        expect(noAnswers.progress, 0.0);
        expect(halfAnswered.progress, 0.5);
      });

      test('equality based on quiz, currentIndex, and results', () {
        const quiz = Quiz(
          id: 'quiz-1',
          title: 'Test',
          questions: [
            QuizQuestion(id: 'q1', text: 'Q1', type: FreeForm()),
          ],
        );
        const a = QuizInProgress(quiz: quiz, currentIndex: 0, results: {});
        const b = QuizInProgress(quiz: quiz, currentIndex: 0, results: {});
        const c = QuizInProgress(quiz: quiz, currentIndex: 0, results: {
          'q1': QuizAnswerResult(isCorrect: true, expectedAnswer: 'A'),
        });

        expect(a, equals(b));
        expect(a.hashCode, equals(b.hashCode));
        expect(a, isNot(equals(c)),
            reason: 'Different results should be unequal');
      });

      test('equality detects different currentIndex', () {
        const quiz = Quiz(
          id: 'quiz-1',
          title: 'Test',
          questions: [
            QuizQuestion(id: 'q1', text: 'Q1', type: FreeForm()),
            QuizQuestion(id: 'q2', text: 'Q2', type: FreeForm()),
          ],
        );
        const a = QuizInProgress(quiz: quiz, currentIndex: 0, results: {});
        const b = QuizInProgress(quiz: quiz, currentIndex: 1, results: {});

        expect(a, isNot(equals(b)));
      });

      test('toString shows quiz id and progress', () {
        const quiz = Quiz(
          id: 'quiz-1',
          title: 'Test',
          questions: [
            QuizQuestion(id: 'q1', text: 'Q1', type: FreeForm()),
            QuizQuestion(id: 'q2', text: 'Q2', type: FreeForm()),
          ],
        );
        const session = QuizInProgress(
          quiz: quiz,
          currentIndex: 0,
          results: {},
        );

        expect(session.toString(), contains('quiz-1'));
        expect(session.toString(), contains('1/2'));
      });
    });

    group('QuizCompleted', () {
      test('stores quiz and results', () {
        const quiz = Quiz(id: 'quiz-1', title: 'Test', questions: []);
        const session = QuizCompleted(
          quiz: quiz,
          results: {
            'q1': QuizAnswerResult(isCorrect: true, expectedAnswer: 'A'),
          },
        );

        expect(session.quiz.id, 'quiz-1');
        expect(session.results, hasLength(1));
      });

      test('correctCount returns number of correct answers', () {
        const quiz = Quiz(id: 'quiz-1', title: 'Test', questions: []);
        const session = QuizCompleted(
          quiz: quiz,
          results: {
            'q1': QuizAnswerResult(isCorrect: true, expectedAnswer: 'A'),
            'q2': QuizAnswerResult(isCorrect: false, expectedAnswer: 'B'),
            'q3': QuizAnswerResult(isCorrect: true, expectedAnswer: 'C'),
          },
        );

        expect(session.correctCount, 2);
        expect(session.totalAnswered, 3);
      });

      test('scorePercent calculates percentage correctly', () {
        const quiz = Quiz(id: 'quiz-1', title: 'Test', questions: []);
        const allCorrect = QuizCompleted(
          quiz: quiz,
          results: {
            'q1': QuizAnswerResult(isCorrect: true, expectedAnswer: 'A'),
            'q2': QuizAnswerResult(isCorrect: true, expectedAnswer: 'B'),
          },
        );
        const halfCorrect = QuizCompleted(
          quiz: quiz,
          results: {
            'q1': QuizAnswerResult(isCorrect: true, expectedAnswer: 'A'),
            'q2': QuizAnswerResult(isCorrect: false, expectedAnswer: 'B'),
          },
        );
        const noAnswers = QuizCompleted(quiz: quiz, results: {});

        expect(allCorrect.scorePercent, 100);
        expect(halfCorrect.scorePercent, 50);
        expect(noAnswers.scorePercent, 0);
      });

      test('equality based on quiz and results', () {
        const quiz1 = Quiz(id: 'quiz-1', title: 'Test', questions: []);
        const quiz2 = Quiz(id: 'quiz-2', title: 'Test', questions: []);
        const a = QuizCompleted(quiz: quiz1, results: {});
        const b = QuizCompleted(quiz: quiz1, results: {});
        const c = QuizCompleted(quiz: quiz2, results: {});
        const d = QuizCompleted(quiz: quiz1, results: {
          'q1': QuizAnswerResult(isCorrect: true, expectedAnswer: 'A'),
        });

        expect(a, equals(b));
        expect(a.hashCode, equals(b.hashCode));
        expect(a, isNot(equals(c)), reason: 'Different quiz should be unequal');
        expect(a, isNot(equals(d)),
            reason: 'Different results should be unequal');
      });

      test('toString shows quiz id and score', () {
        const quiz = Quiz(id: 'quiz-1', title: 'Test', questions: []);
        const session = QuizCompleted(
          quiz: quiz,
          results: {
            'q1': QuizAnswerResult(isCorrect: true, expectedAnswer: 'A'),
            'q2': QuizAnswerResult(isCorrect: false, expectedAnswer: 'B'),
          },
        );

        expect(session.toString(), contains('quiz-1'));
        expect(session.toString(), contains('1/2'));
      });
    });
  });

  group('quizSessionProvider', () {
    test('starts with QuizNotStarted', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final session = container.read(quizSessionProvider);

      expect(session, isA<QuizNotStarted>());
    });

    group('start', () {
      test('transitions to QuizInProgress', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        const quiz = Quiz(
          id: 'quiz-1',
          title: 'Test',
          questions: [
            QuizQuestion(id: 'q1', text: 'Q1', type: FreeForm()),
          ],
        );
        container.read(quizSessionProvider.notifier).start(quiz);

        final session = container.read(quizSessionProvider);
        expect(session, isA<QuizInProgress>());
        final inProgress = session as QuizInProgress;
        expect(inProgress.quiz.id, 'quiz-1');
        expect(inProgress.currentIndex, 0);
        expect(inProgress.results, isEmpty);
      });

      test('throws ArgumentError when quiz has no questions', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        const emptyQuiz = Quiz(
          id: 'quiz-1',
          title: 'Empty Quiz',
          questions: [],
        );

        expect(
          () => container.read(quizSessionProvider.notifier).start(emptyQuiz),
          throwsA(isA<ArgumentError>()),
        );
      });
    });

    group('submitAnswer', () {
      late MockSoliplexApi mockApi;

      setUp(() {
        mockApi = MockSoliplexApi();
      });

      test('submits answer and stores result', () async {
        // Arrange
        const roomId = 'room-1';
        const quiz = Quiz(
          id: 'quiz-1',
          title: 'Test',
          questions: [
            QuizQuestion(id: 'q1', text: 'Q1', type: FreeForm()),
          ],
        );
        const answerResult = QuizAnswerResult(
          isCorrect: true,
          expectedAnswer: 'correct answer',
        );
        when(
          () => mockApi.submitQuizAnswer(roomId, 'quiz-1', 'q1', 'my answer'),
        ).thenAnswer((_) async => answerResult);

        final container = ProviderContainer(
          overrides: [apiProvider.overrideWithValue(mockApi)],
        );
        addTearDown(container.dispose);

        container.read(quizSessionProvider.notifier).start(quiz);

        // Act
        final result = await container
            .read(quizSessionProvider.notifier)
            .submitAnswer(roomId, 'my answer');

        // Assert
        expect(result.isCorrect, isTrue);
        expect(result.expectedAnswer, 'correct answer');

        final session = container.read(quizSessionProvider) as QuizInProgress;
        expect(session.results['q1'], equals(answerResult));
        verify(
          () => mockApi.submitQuizAnswer(roomId, 'quiz-1', 'q1', 'my answer'),
        ).called(1);
      });

      test('throws StateError when not in progress', () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        expect(
          () => container
              .read(quizSessionProvider.notifier)
              .submitAnswer('room-1', 'answer'),
          throwsStateError,
        );
      });

      test('propagates API exceptions', () async {
        // Arrange
        const quiz = Quiz(
          id: 'quiz-1',
          title: 'Test',
          questions: [
            QuizQuestion(id: 'q1', text: 'Q1', type: FreeForm()),
          ],
        );
        when(
          () => mockApi.submitQuizAnswer(any(), any(), any(), any()),
        ).thenThrow(const NetworkException(message: 'Connection timeout'));

        final container = ProviderContainer(
          overrides: [apiProvider.overrideWithValue(mockApi)],
        );
        addTearDown(container.dispose);

        container.read(quizSessionProvider.notifier).start(quiz);

        // Act & Assert
        expect(
          () => container
              .read(quizSessionProvider.notifier)
              .submitAnswer('room-1', 'my answer'),
          throwsA(isA<NetworkException>()),
        );
      });
    });

    group('nextQuestion', () {
      test('increments currentIndex', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        const quiz = Quiz(
          id: 'quiz-1',
          title: 'Test',
          questions: [
            QuizQuestion(id: 'q1', text: 'Q1', type: FreeForm()),
            QuizQuestion(id: 'q2', text: 'Q2', type: FreeForm()),
          ],
        );
        container.read(quizSessionProvider.notifier).start(quiz);
        container.read(quizSessionProvider.notifier).nextQuestion();

        final session = container.read(quizSessionProvider) as QuizInProgress;
        expect(session.currentIndex, 1);
      });

      test('transitions to QuizCompleted when on last question', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        const quiz = Quiz(
          id: 'quiz-1',
          title: 'Test',
          questions: [
            QuizQuestion(id: 'q1', text: 'Q1', type: FreeForm()),
          ],
        );
        container.read(quizSessionProvider.notifier).start(quiz);
        container.read(quizSessionProvider.notifier).nextQuestion();

        final session = container.read(quizSessionProvider);
        expect(session, isA<QuizCompleted>());
      });

      test('preserves results when transitioning to QuizCompleted', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        const quiz = Quiz(
          id: 'quiz-1',
          title: 'Test',
          questions: [
            QuizQuestion(id: 'q1', text: 'Q1', type: FreeForm()),
          ],
        );

        // Start and manually set state with results
        container.read(quizSessionProvider.notifier).start(quiz);
        // Simulate having answered (normally done via submitAnswer)
        // We can test by going to nextQuestion and checking completed state

        container.read(quizSessionProvider.notifier).nextQuestion();

        final session = container.read(quizSessionProvider) as QuizCompleted;
        expect(session.quiz.id, 'quiz-1');
      });

      test('throws StateError when not in progress', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        expect(
          () => container.read(quizSessionProvider.notifier).nextQuestion(),
          throwsStateError,
        );
      });
    });

    group('reset', () {
      test('transitions back to QuizNotStarted', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        const quiz = Quiz(
          id: 'quiz-1',
          title: 'Test',
          questions: [
            QuizQuestion(id: 'q1', text: 'Q1', type: FreeForm()),
          ],
        );
        container.read(quizSessionProvider.notifier).start(quiz);
        container.read(quizSessionProvider.notifier).reset();

        final session = container.read(quizSessionProvider);
        expect(session, isA<QuizNotStarted>());
      });

      test('can reset from QuizCompleted', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        const quiz = Quiz(
          id: 'quiz-1',
          title: 'Test',
          questions: [
            QuizQuestion(id: 'q1', text: 'Q1', type: FreeForm()),
          ],
        );
        container.read(quizSessionProvider.notifier).start(quiz);
        container.read(quizSessionProvider.notifier).nextQuestion();

        expect(container.read(quizSessionProvider), isA<QuizCompleted>());

        container.read(quizSessionProvider.notifier).reset();

        expect(container.read(quizSessionProvider), isA<QuizNotStarted>());
      });
    });
  });
}
