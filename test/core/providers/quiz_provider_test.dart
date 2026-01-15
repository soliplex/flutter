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
      final quiz = Quiz(
        id: quizId,
        title: 'Test Quiz',
        questions: const [
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
      final quiz1 = Quiz(id: 'quiz-1', title: 'Quiz 1', questions: const []);
      final quiz2 = Quiz(id: 'quiz-2', title: 'Quiz 2', questions: const []);

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
      test('stores quiz, currentIndex, results, and questionState', () {
        final quiz = Quiz(
          id: 'quiz-1',
          title: 'Test',
          questions: const [
            QuizQuestion(id: 'q1', text: 'Q1', type: FreeForm()),
            QuizQuestion(id: 'q2', text: 'Q2', type: FreeForm()),
          ],
        );
        final session = QuizInProgress(
          quiz: quiz,
          currentIndex: 1,
          results: const {},
          questionState: const AwaitingInput(),
        );

        expect(session.quiz.id, 'quiz-1');
        expect(session.currentIndex, 1);
        expect(session.results, isEmpty);
        expect(session.questionState, isA<AwaitingInput>());
      });

      test('currentQuestion returns question at currentIndex', () {
        final quiz = Quiz(
          id: 'quiz-1',
          title: 'Test',
          questions: const [
            QuizQuestion(id: 'q1', text: 'Q1', type: FreeForm()),
            QuizQuestion(id: 'q2', text: 'Q2', type: FreeForm()),
          ],
        );
        final session = QuizInProgress(
          quiz: quiz,
          currentIndex: 1,
          results: const {},
          questionState: const AwaitingInput(),
        );

        expect(session.currentQuestion.id, 'q2');
      });

      test('isLastQuestion is true when on last question', () {
        final quiz = Quiz(
          id: 'quiz-1',
          title: 'Test',
          questions: const [
            QuizQuestion(id: 'q1', text: 'Q1', type: FreeForm()),
            QuizQuestion(id: 'q2', text: 'Q2', type: FreeForm()),
          ],
        );
        final atFirst = QuizInProgress(
          quiz: quiz,
          currentIndex: 0,
          results: const {},
          questionState: const AwaitingInput(),
        );
        final atLast = QuizInProgress(
          quiz: quiz,
          currentIndex: 1,
          results: const {},
          questionState: const AwaitingInput(),
        );

        expect(atFirst.isLastQuestion, isFalse);
        expect(atLast.isLastQuestion, isTrue);
      });

      test('progress calculates correctly', () {
        final quiz = Quiz(
          id: 'quiz-1',
          title: 'Test',
          questions: const [
            QuizQuestion(id: 'q1', text: 'Q1', type: FreeForm()),
            QuizQuestion(id: 'q2', text: 'Q2', type: FreeForm()),
            QuizQuestion(id: 'q3', text: 'Q3', type: FreeForm()),
            QuizQuestion(id: 'q4', text: 'Q4', type: FreeForm()),
          ],
        );
        final noAnswers = QuizInProgress(
          quiz: quiz,
          currentIndex: 0,
          results: const {},
          questionState: const AwaitingInput(),
        );
        final halfAnswered = QuizInProgress(
          quiz: quiz,
          currentIndex: 2,
          results: const {
            'q1': QuizAnswerResult(isCorrect: true, expectedAnswer: 'A'),
            'q2': QuizAnswerResult(isCorrect: false, expectedAnswer: 'B'),
          },
          questionState: const AwaitingInput(),
        );

        expect(noAnswers.progress, 0.0);
        expect(halfAnswered.progress, 0.5);
      });

      test('equality based on quiz, currentIndex, results, and questionState',
          () {
        final quiz = Quiz(
          id: 'quiz-1',
          title: 'Test',
          questions: const [
            QuizQuestion(id: 'q1', text: 'Q1', type: FreeForm()),
          ],
        );
        final a = QuizInProgress(
          quiz: quiz,
          currentIndex: 0,
          results: const {},
          questionState: const AwaitingInput(),
        );
        final b = QuizInProgress(
          quiz: quiz,
          currentIndex: 0,
          results: const {},
          questionState: const AwaitingInput(),
        );
        final c = QuizInProgress(
          quiz: quiz,
          currentIndex: 0,
          results: const {
            'q1': QuizAnswerResult(isCorrect: true, expectedAnswer: 'A'),
          },
          questionState: const AwaitingInput(),
        );

        expect(a, equals(b));
        expect(a.hashCode, equals(b.hashCode));
        expect(
          a,
          isNot(equals(c)),
          reason: 'Different results should be unequal',
        );
      });

      test('equality detects different currentIndex', () {
        final quiz = Quiz(
          id: 'quiz-1',
          title: 'Test',
          questions: const [
            QuizQuestion(id: 'q1', text: 'Q1', type: FreeForm()),
            QuizQuestion(id: 'q2', text: 'Q2', type: FreeForm()),
          ],
        );
        final a = QuizInProgress(
          quiz: quiz,
          currentIndex: 0,
          results: const {},
          questionState: const AwaitingInput(),
        );
        final b = QuizInProgress(
          quiz: quiz,
          currentIndex: 1,
          results: const {},
          questionState: const AwaitingInput(),
        );

        expect(a, isNot(equals(b)));
      });

      test('toString shows quiz id and progress', () {
        final quiz = Quiz(
          id: 'quiz-1',
          title: 'Test',
          questions: const [
            QuizQuestion(id: 'q1', text: 'Q1', type: FreeForm()),
            QuizQuestion(id: 'q2', text: 'Q2', type: FreeForm()),
          ],
        );
        final session = QuizInProgress(
          quiz: quiz,
          currentIndex: 0,
          results: const {},
          questionState: const AwaitingInput(),
        );

        expect(session.toString(), contains('quiz-1'));
        expect(session.toString(), contains('1/2'));
      });
    });

    group('QuizCompleted', () {
      test('stores quiz and results', () {
        final quiz = Quiz(id: 'quiz-1', title: 'Test', questions: const []);
        final session = QuizCompleted(
          quiz: quiz,
          results: const {
            'q1': QuizAnswerResult(isCorrect: true, expectedAnswer: 'A'),
          },
        );

        expect(session.quiz.id, 'quiz-1');
        expect(session.results, hasLength(1));
      });

      test('correctCount returns number of correct answers', () {
        final quiz = Quiz(id: 'quiz-1', title: 'Test', questions: const []);
        final session = QuizCompleted(
          quiz: quiz,
          results: const {
            'q1': QuizAnswerResult(isCorrect: true, expectedAnswer: 'A'),
            'q2': QuizAnswerResult(isCorrect: false, expectedAnswer: 'B'),
            'q3': QuizAnswerResult(isCorrect: true, expectedAnswer: 'C'),
          },
        );

        expect(session.correctCount, 2);
        expect(session.totalAnswered, 3);
      });

      test('scorePercent calculates percentage correctly', () {
        final quiz = Quiz(id: 'quiz-1', title: 'Test', questions: const []);
        final allCorrect = QuizCompleted(
          quiz: quiz,
          results: const {
            'q1': QuizAnswerResult(isCorrect: true, expectedAnswer: 'A'),
            'q2': QuizAnswerResult(isCorrect: true, expectedAnswer: 'B'),
          },
        );
        final halfCorrect = QuizCompleted(
          quiz: quiz,
          results: const {
            'q1': QuizAnswerResult(isCorrect: true, expectedAnswer: 'A'),
            'q2': QuizAnswerResult(isCorrect: false, expectedAnswer: 'B'),
          },
        );
        final noAnswers = QuizCompleted(quiz: quiz, results: const {});

        expect(allCorrect.scorePercent, 100);
        expect(halfCorrect.scorePercent, 50);
        expect(noAnswers.scorePercent, 0);
      });

      test('equality based on quiz and results', () {
        final quiz1 = Quiz(id: 'quiz-1', title: 'Test', questions: const []);
        final quiz2 = Quiz(id: 'quiz-2', title: 'Test', questions: const []);
        final a = QuizCompleted(quiz: quiz1, results: const {});
        final b = QuizCompleted(quiz: quiz1, results: const {});
        final c = QuizCompleted(quiz: quiz2, results: const {});
        final d = QuizCompleted(
          quiz: quiz1,
          results: const {
            'q1': QuizAnswerResult(isCorrect: true, expectedAnswer: 'A'),
          },
        );

        expect(a, equals(b));
        expect(a.hashCode, equals(b.hashCode));
        expect(
          a,
          isNot(equals(c)),
          reason: 'Different quiz should be unequal',
        );
        expect(
          a,
          isNot(equals(d)),
          reason: 'Different results should be unequal',
        );
      });

      test('toString shows quiz id and score', () {
        final quiz = Quiz(id: 'quiz-1', title: 'Test', questions: const []);
        final session = QuizCompleted(
          quiz: quiz,
          results: const {
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
    const testKey = (roomId: 'room-1', quizId: 'quiz-1');

    test('starts with QuizNotStarted', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final session = container.read(quizSessionProvider(testKey));

      expect(session, isA<QuizNotStarted>());
    });

    group('start', () {
      test('transitions to QuizInProgress', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final quiz = Quiz(
          id: 'quiz-1',
          title: 'Test',
          questions: const [
            QuizQuestion(id: 'q1', text: 'Q1', type: FreeForm()),
          ],
        );
        container.read(quizSessionProvider(testKey).notifier).start(quiz);

        final session = container.read(quizSessionProvider(testKey));
        expect(session, isA<QuizInProgress>());
        final inProgress = session as QuizInProgress;
        expect(inProgress.quiz.id, 'quiz-1');
        expect(inProgress.currentIndex, 0);
        expect(inProgress.results, isEmpty);
      });

      test('throws ArgumentError when quiz has no questions', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final emptyQuiz = Quiz(
          id: 'quiz-1',
          title: 'Empty Quiz',
          questions: const [],
        );

        expect(
          () => container
              .read(quizSessionProvider(testKey).notifier)
              .start(emptyQuiz),
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
        final quiz = Quiz(
          id: 'quiz-1',
          title: 'Test',
          questions: const [
            QuizQuestion(id: 'q1', text: 'Q1', type: FreeForm()),
          ],
        );
        const answerResult = QuizAnswerResult(
          isCorrect: true,
          expectedAnswer: 'correct answer',
        );
        when(
          () => mockApi.submitQuizAnswer(
            testKey.roomId,
            'quiz-1',
            'q1',
            'my answer',
          ),
        ).thenAnswer((_) async => answerResult);

        final container = ProviderContainer(
          overrides: [apiProvider.overrideWithValue(mockApi)],
        );
        addTearDown(container.dispose);

        container.read(quizSessionProvider(testKey).notifier).start(quiz);
        container
            .read(quizSessionProvider(testKey).notifier)
            .updateInput(const TextInput('my answer'));

        // Act
        final result = await container
            .read(quizSessionProvider(testKey).notifier)
            .submitAnswer();

        // Assert
        expect(result.isCorrect, isTrue);
        expect(result.expectedAnswer, 'correct answer');

        final session =
            container.read(quizSessionProvider(testKey)) as QuizInProgress;
        expect(session.results['q1'], equals(answerResult));
        expect(session.questionState, isA<Answered>());
        verify(
          () => mockApi.submitQuizAnswer(
            testKey.roomId,
            'quiz-1',
            'q1',
            'my answer',
          ),
        ).called(1);
      });

      test('throws StateError when not in progress', () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        expect(
          () => container
              .read(quizSessionProvider(testKey).notifier)
              .submitAnswer(),
          throwsStateError,
        );
      });

      test('throws StateError when not composing', () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final quiz = Quiz(
          id: 'quiz-1',
          title: 'Test',
          questions: const [
            QuizQuestion(id: 'q1', text: 'Q1', type: FreeForm()),
          ],
        );
        container.read(quizSessionProvider(testKey).notifier).start(quiz);
        // Don't call updateInput - still in AwaitingInput state

        expect(
          () => container
              .read(quizSessionProvider(testKey).notifier)
              .submitAnswer(),
          throwsStateError,
        );
      });

      test('throws ArgumentError when input is empty', () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final quiz = Quiz(
          id: 'quiz-1',
          title: 'Test',
          questions: const [
            QuizQuestion(id: 'q1', text: 'Q1', type: FreeForm()),
          ],
        );
        container.read(quizSessionProvider(testKey).notifier).start(quiz);
        // Update with whitespace-only input (invalid)
        container
            .read(quizSessionProvider(testKey).notifier)
            .updateInput(const TextInput('   '));

        expect(
          () => container
              .read(quizSessionProvider(testKey).notifier)
              .submitAnswer(),
          throwsArgumentError,
        );
      });

      test('propagates API exceptions and returns to Composing', () async {
        // Arrange
        final quiz = Quiz(
          id: 'quiz-1',
          title: 'Test',
          questions: const [
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

        container.read(quizSessionProvider(testKey).notifier).start(quiz);
        container
            .read(quizSessionProvider(testKey).notifier)
            .updateInput(const TextInput('my answer'));

        // Act & Assert
        await expectLater(
          () => container
              .read(quizSessionProvider(testKey).notifier)
              .submitAnswer(),
          throwsA(isA<NetworkException>()),
        );

        // Verify state returned to Composing with input preserved
        final session =
            container.read(quizSessionProvider(testKey)) as QuizInProgress;
        expect(session.questionState, isA<Composing>());
        final composing = session.questionState as Composing;
        expect(composing.input, isA<TextInput>());
        expect((composing.input as TextInput).text, 'my answer');
      });
    });

    group('nextQuestion', () {
      late MockSoliplexApi mockApi;

      setUp(() {
        mockApi = MockSoliplexApi();
      });

      test('increments currentIndex after answering', () async {
        const answerResult = QuizAnswerResult(
          isCorrect: true,
          expectedAnswer: 'A',
        );
        when(
          () => mockApi.submitQuizAnswer(any(), any(), any(), any()),
        ).thenAnswer((_) async => answerResult);

        final container = ProviderContainer(
          overrides: [apiProvider.overrideWithValue(mockApi)],
        );
        addTearDown(container.dispose);

        final quiz = Quiz(
          id: 'quiz-1',
          title: 'Test',
          questions: const [
            QuizQuestion(id: 'q1', text: 'Q1', type: FreeForm()),
            QuizQuestion(id: 'q2', text: 'Q2', type: FreeForm()),
          ],
        );
        container.read(quizSessionProvider(testKey).notifier).start(quiz);
        container
            .read(quizSessionProvider(testKey).notifier)
            .updateInput(const TextInput('answer'));
        await container
            .read(quizSessionProvider(testKey).notifier)
            .submitAnswer();
        container.read(quizSessionProvider(testKey).notifier).nextQuestion();

        final session =
            container.read(quizSessionProvider(testKey)) as QuizInProgress;
        expect(session.currentIndex, 1);
        expect(session.questionState, isA<AwaitingInput>());
      });

      test('transitions to QuizCompleted when on last question', () async {
        const answerResult = QuizAnswerResult(
          isCorrect: true,
          expectedAnswer: 'A',
        );
        when(
          () => mockApi.submitQuizAnswer(any(), any(), any(), any()),
        ).thenAnswer((_) async => answerResult);

        final container = ProviderContainer(
          overrides: [apiProvider.overrideWithValue(mockApi)],
        );
        addTearDown(container.dispose);

        final quiz = Quiz(
          id: 'quiz-1',
          title: 'Test',
          questions: const [
            QuizQuestion(id: 'q1', text: 'Q1', type: FreeForm()),
          ],
        );
        container.read(quizSessionProvider(testKey).notifier).start(quiz);
        container
            .read(quizSessionProvider(testKey).notifier)
            .updateInput(const TextInput('answer'));
        await container
            .read(quizSessionProvider(testKey).notifier)
            .submitAnswer();
        container.read(quizSessionProvider(testKey).notifier).nextQuestion();

        final session = container.read(quizSessionProvider(testKey));
        expect(session, isA<QuizCompleted>());
      });

      test('preserves results when transitioning to QuizCompleted', () async {
        const answerResult = QuizAnswerResult(
          isCorrect: true,
          expectedAnswer: 'A',
        );
        when(
          () => mockApi.submitQuizAnswer(any(), any(), any(), any()),
        ).thenAnswer((_) async => answerResult);

        final container = ProviderContainer(
          overrides: [apiProvider.overrideWithValue(mockApi)],
        );
        addTearDown(container.dispose);

        final quiz = Quiz(
          id: 'quiz-1',
          title: 'Test',
          questions: const [
            QuizQuestion(id: 'q1', text: 'Q1', type: FreeForm()),
          ],
        );

        container.read(quizSessionProvider(testKey).notifier).start(quiz);
        container
            .read(quizSessionProvider(testKey).notifier)
            .updateInput(const TextInput('answer'));
        await container
            .read(quizSessionProvider(testKey).notifier)
            .submitAnswer();
        container.read(quizSessionProvider(testKey).notifier).nextQuestion();

        final session =
            container.read(quizSessionProvider(testKey)) as QuizCompleted;
        expect(session.quiz.id, 'quiz-1');
        expect(session.results['q1'], equals(answerResult));
      });

      test('throws StateError when not in progress', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        expect(
          () => container
              .read(quizSessionProvider(testKey).notifier)
              .nextQuestion(),
          throwsStateError,
        );
      });

      test('throws StateError when not answered yet', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final quiz = Quiz(
          id: 'quiz-1',
          title: 'Test',
          questions: const [
            QuizQuestion(id: 'q1', text: 'Q1', type: FreeForm()),
          ],
        );
        container.read(quizSessionProvider(testKey).notifier).start(quiz);
        // Don't answer - should throw

        expect(
          () => container
              .read(quizSessionProvider(testKey).notifier)
              .nextQuestion(),
          throwsStateError,
        );
      });
    });

    group('reset', () {
      test('transitions back to QuizNotStarted', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final quiz = Quiz(
          id: 'quiz-1',
          title: 'Test',
          questions: const [
            QuizQuestion(id: 'q1', text: 'Q1', type: FreeForm()),
          ],
        );
        container.read(quizSessionProvider(testKey).notifier).start(quiz);
        container.read(quizSessionProvider(testKey).notifier).reset();

        final session = container.read(quizSessionProvider(testKey));
        expect(session, isA<QuizNotStarted>());
      });

      test('can reset from QuizCompleted', () async {
        late MockSoliplexApi mockApi;
        mockApi = MockSoliplexApi();

        const answerResult = QuizAnswerResult(
          isCorrect: true,
          expectedAnswer: 'A',
        );
        when(
          () => mockApi.submitQuizAnswer(any(), any(), any(), any()),
        ).thenAnswer((_) async => answerResult);

        final container = ProviderContainer(
          overrides: [apiProvider.overrideWithValue(mockApi)],
        );
        addTearDown(container.dispose);

        final quiz = Quiz(
          id: 'quiz-1',
          title: 'Test',
          questions: const [
            QuizQuestion(id: 'q1', text: 'Q1', type: FreeForm()),
          ],
        );
        container.read(quizSessionProvider(testKey).notifier).start(quiz);
        container
            .read(quizSessionProvider(testKey).notifier)
            .updateInput(const TextInput('answer'));
        await container
            .read(quizSessionProvider(testKey).notifier)
            .submitAnswer();
        container.read(quizSessionProvider(testKey).notifier).nextQuestion();

        expect(
          container.read(quizSessionProvider(testKey)),
          isA<QuizCompleted>(),
        );

        container.read(quizSessionProvider(testKey).notifier).reset();

        expect(
          container.read(quizSessionProvider(testKey)),
          isA<QuizNotStarted>(),
        );
      });
    });

    group('retake', () {
      test('restarts quiz from QuizCompleted', () async {
        late MockSoliplexApi mockApi;
        mockApi = MockSoliplexApi();

        const answerResult = QuizAnswerResult(
          isCorrect: true,
          expectedAnswer: 'A',
        );
        when(
          () => mockApi.submitQuizAnswer(any(), any(), any(), any()),
        ).thenAnswer((_) async => answerResult);

        final container = ProviderContainer(
          overrides: [apiProvider.overrideWithValue(mockApi)],
        );
        addTearDown(container.dispose);

        final quiz = Quiz(
          id: 'quiz-1',
          title: 'Test',
          questions: const [
            QuizQuestion(id: 'q1', text: 'Q1', type: FreeForm()),
          ],
        );
        container.read(quizSessionProvider(testKey).notifier).start(quiz);
        container
            .read(quizSessionProvider(testKey).notifier)
            .updateInput(const TextInput('answer'));
        await container
            .read(quizSessionProvider(testKey).notifier)
            .submitAnswer();
        container.read(quizSessionProvider(testKey).notifier).nextQuestion();

        expect(
          container.read(quizSessionProvider(testKey)),
          isA<QuizCompleted>(),
        );

        container.read(quizSessionProvider(testKey).notifier).retake();

        final session =
            container.read(quizSessionProvider(testKey)) as QuizInProgress;
        expect(session.currentIndex, 0);
        expect(session.results, isEmpty);
        expect(session.questionState, isA<AwaitingInput>());
      });

      test('throws StateError when quiz not started', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        expect(
          () => container.read(quizSessionProvider(testKey).notifier).retake(),
          throwsStateError,
        );
      });
    });

    group('updateInput', () {
      late MockSoliplexApi mockApi;

      setUp(() {
        mockApi = MockSoliplexApi();
      });

      test('transitions from AwaitingInput to Composing', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final quiz = Quiz(
          id: 'quiz-1',
          title: 'Test',
          questions: const [
            QuizQuestion(id: 'q1', text: 'Q1', type: FreeForm()),
          ],
        );
        container.read(quizSessionProvider(testKey).notifier).start(quiz);
        container
            .read(quizSessionProvider(testKey).notifier)
            .updateInput(const TextInput('answer'));

        final session =
            container.read(quizSessionProvider(testKey)) as QuizInProgress;
        expect(session.questionState, isA<Composing>());
        final composing = session.questionState as Composing;
        expect((composing.input as TextInput).text, 'answer');
      });

      test('multiple choice input is valid for submission', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final quiz = Quiz(
          id: 'quiz-1',
          title: 'Test',
          questions: [
            QuizQuestion(
              id: 'q1',
              text: 'Q1',
              type: MultipleChoice(const ['A', 'B', 'C']),
            ),
          ],
        );
        container.read(quizSessionProvider(testKey).notifier).start(quiz);
        container
            .read(quizSessionProvider(testKey).notifier)
            .updateInput(const MultipleChoiceInput('A'));

        final session =
            container.read(quizSessionProvider(testKey)) as QuizInProgress;
        final composing = session.questionState as Composing;
        expect(composing.canSubmit, isTrue);
      });

      test('empty text input is not valid for submission', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final quiz = Quiz(
          id: 'quiz-1',
          title: 'Test',
          questions: const [
            QuizQuestion(id: 'q1', text: 'Q1', type: FreeForm()),
          ],
        );
        container.read(quizSessionProvider(testKey).notifier).start(quiz);
        container
            .read(quizSessionProvider(testKey).notifier)
            .updateInput(const TextInput(''));

        final session =
            container.read(quizSessionProvider(testKey)) as QuizInProgress;
        final composing = session.questionState as Composing;
        expect(composing.canSubmit, isFalse);
      });

      test('ignores input updates while submitting', () async {
        // Arrange: Use a slow mock that we can control
        final completer = Completer<QuizAnswerResult>();
        when(
          () => mockApi.submitQuizAnswer(any(), any(), any(), any()),
        ).thenAnswer((_) => completer.future);

        final container = ProviderContainer(
          overrides: [apiProvider.overrideWithValue(mockApi)],
        );
        addTearDown(container.dispose);

        final quiz = Quiz(
          id: 'quiz-1',
          title: 'Test',
          questions: const [
            QuizQuestion(id: 'q1', text: 'Q1', type: FreeForm()),
          ],
        );
        container.read(quizSessionProvider(testKey).notifier).start(quiz);
        container
            .read(quizSessionProvider(testKey).notifier)
            .updateInput(const TextInput('original answer'));

        // Act: Start submission (don't await yet)
        final submitFuture = container
            .read(quizSessionProvider(testKey).notifier)
            .submitAnswer();

        // Verify we're in Submitting state
        var session =
            container.read(quizSessionProvider(testKey)) as QuizInProgress;
        expect(session.questionState, isA<Submitting>());

        // Try to update input while submitting - should be ignored
        container
            .read(quizSessionProvider(testKey).notifier)
            .updateInput(const TextInput('changed answer'));

        // Verify input was NOT changed (still Submitting with original)
        session =
            container.read(quizSessionProvider(testKey)) as QuizInProgress;
        expect(session.questionState, isA<Submitting>());
        final submitting = session.questionState as Submitting;
        expect((submitting.input as TextInput).text, 'original answer');

        // Complete the submission
        completer.complete(
          const QuizAnswerResult(
            isCorrect: true,
            expectedAnswer: 'original answer',
          ),
        );
        await submitFuture;

        // Verify final state shows original answer, not changed
        session =
            container.read(quizSessionProvider(testKey)) as QuizInProgress;
        expect(session.questionState, isA<Answered>());
        final answered = session.questionState as Answered;
        expect((answered.input as TextInput).text, 'original answer');
      });

      test('ignores input updates when already answered', () async {
        when(
          () => mockApi.submitQuizAnswer(any(), any(), any(), any()),
        ).thenAnswer(
          (_) async =>
              const QuizAnswerResult(isCorrect: true, expectedAnswer: 'answer'),
        );

        final container = ProviderContainer(
          overrides: [apiProvider.overrideWithValue(mockApi)],
        );
        addTearDown(container.dispose);

        final quiz = Quiz(
          id: 'quiz-1',
          title: 'Test',
          questions: const [
            QuizQuestion(id: 'q1', text: 'Q1', type: FreeForm()),
          ],
        );
        container.read(quizSessionProvider(testKey).notifier).start(quiz);
        container
            .read(quizSessionProvider(testKey).notifier)
            .updateInput(const TextInput('answer'));
        await container
            .read(quizSessionProvider(testKey).notifier)
            .submitAnswer();

        // Now in Answered state - try to update input
        container
            .read(quizSessionProvider(testKey).notifier)
            .updateInput(const TextInput('new answer'));

        // Verify state is still Answered (not changed to Composing)
        final session =
            container.read(quizSessionProvider(testKey)) as QuizInProgress;
        expect(session.questionState, isA<Answered>());
      });
    });

    group('clearInput', () {
      late MockSoliplexApi mockApi;

      setUp(() {
        mockApi = MockSoliplexApi();
      });

      test('transitions from Composing back to AwaitingInput', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final quiz = Quiz(
          id: 'quiz-1',
          title: 'Test',
          questions: const [
            QuizQuestion(id: 'q1', text: 'Q1', type: FreeForm()),
          ],
        );
        container.read(quizSessionProvider(testKey).notifier).start(quiz);
        container
            .read(quizSessionProvider(testKey).notifier)
            .updateInput(const TextInput('answer'));
        container.read(quizSessionProvider(testKey).notifier).clearInput();

        final session =
            container.read(quizSessionProvider(testKey)) as QuizInProgress;
        expect(session.questionState, isA<AwaitingInput>());
      });

      test('no-op when in AwaitingInput state', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final quiz = Quiz(
          id: 'quiz-1',
          title: 'Test',
          questions: const [
            QuizQuestion(id: 'q1', text: 'Q1', type: FreeForm()),
          ],
        );
        container.read(quizSessionProvider(testKey).notifier).start(quiz);

        // State is AwaitingInput - clearInput should be no-op
        container.read(quizSessionProvider(testKey).notifier).clearInput();

        final session =
            container.read(quizSessionProvider(testKey)) as QuizInProgress;
        expect(session.questionState, isA<AwaitingInput>());
      });

      test('no-op when in Submitting state', () async {
        final completer = Completer<QuizAnswerResult>();
        when(
          () => mockApi.submitQuizAnswer(any(), any(), any(), any()),
        ).thenAnswer((_) => completer.future);

        final container = ProviderContainer(
          overrides: [apiProvider.overrideWithValue(mockApi)],
        );
        addTearDown(container.dispose);

        final quiz = Quiz(
          id: 'quiz-1',
          title: 'Test',
          questions: const [
            QuizQuestion(id: 'q1', text: 'Q1', type: FreeForm()),
          ],
        );
        container.read(quizSessionProvider(testKey).notifier).start(quiz);
        container
            .read(quizSessionProvider(testKey).notifier)
            .updateInput(const TextInput('answer'));

        // Start submission (don't await)
        unawaited(
          container.read(quizSessionProvider(testKey).notifier).submitAnswer(),
        );

        // State is Submitting - clearInput should be no-op
        container.read(quizSessionProvider(testKey).notifier).clearInput();

        final session =
            container.read(quizSessionProvider(testKey)) as QuizInProgress;
        expect(session.questionState, isA<Submitting>());

        // Cleanup
        completer.complete(
          const QuizAnswerResult(isCorrect: true, expectedAnswer: 'answer'),
        );
      });

      test('no-op when in Answered state', () async {
        when(
          () => mockApi.submitQuizAnswer(any(), any(), any(), any()),
        ).thenAnswer(
          (_) async =>
              const QuizAnswerResult(isCorrect: true, expectedAnswer: 'answer'),
        );

        final container = ProviderContainer(
          overrides: [apiProvider.overrideWithValue(mockApi)],
        );
        addTearDown(container.dispose);

        final quiz = Quiz(
          id: 'quiz-1',
          title: 'Test',
          questions: const [
            QuizQuestion(id: 'q1', text: 'Q1', type: FreeForm()),
          ],
        );
        container.read(quizSessionProvider(testKey).notifier).start(quiz);
        container
            .read(quizSessionProvider(testKey).notifier)
            .updateInput(const TextInput('answer'));
        await container
            .read(quizSessionProvider(testKey).notifier)
            .submitAnswer();

        // State is Answered - clearInput should be no-op
        container.read(quizSessionProvider(testKey).notifier).clearInput();

        final session =
            container.read(quizSessionProvider(testKey)) as QuizInProgress;
        expect(session.questionState, isA<Answered>());
      });

      test('no-op when quiz not started', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        // Quiz not started - clearInput should be no-op (no crash)
        container.read(quizSessionProvider(testKey).notifier).clearInput();

        expect(
          container.read(quizSessionProvider(testKey)),
          isA<QuizNotStarted>(),
        );
      });
    });

    group('race conditions', () {
      late MockSoliplexApi mockApi;

      setUp(() {
        mockApi = MockSoliplexApi();
      });

      test('handles reset during submitAnswer gracefully', () async {
        // Arrange: Use a slow mock that we can control
        final completer = Completer<QuizAnswerResult>();
        when(
          () => mockApi.submitQuizAnswer(any(), any(), any(), any()),
        ).thenAnswer((_) => completer.future);

        final container = ProviderContainer(
          overrides: [apiProvider.overrideWithValue(mockApi)],
        );
        addTearDown(container.dispose);

        final quiz = Quiz(
          id: 'quiz-1',
          title: 'Test',
          questions: const [
            QuizQuestion(id: 'q1', text: 'Q1', type: FreeForm()),
          ],
        );
        container.read(quizSessionProvider(testKey).notifier).start(quiz);
        container
            .read(quizSessionProvider(testKey).notifier)
            .updateInput(const TextInput('answer'));

        // Act: Start submission (don't await yet)
        final submitFuture = container
            .read(quizSessionProvider(testKey).notifier)
            .submitAnswer();

        // Reset the quiz while submission is in-flight
        container.read(quizSessionProvider(testKey).notifier).reset();

        // Verify state is now QuizNotStarted
        expect(
          container.read(quizSessionProvider(testKey)),
          isA<QuizNotStarted>(),
        );

        // Complete the API call
        completer.complete(
          const QuizAnswerResult(isCorrect: true, expectedAnswer: 'answer'),
        );

        // Await should complete without throwing
        final result = await submitFuture;
        expect(result.isCorrect, isTrue);

        // State should still be QuizNotStarted (not corrupted)
        expect(
          container.read(quizSessionProvider(testKey)),
          isA<QuizNotStarted>(),
        );
      });
    });

    test('isolates state per quiz key', () async {
      final mockApi = MockSoliplexApi();
      const answerResult = QuizAnswerResult(
        isCorrect: true,
        expectedAnswer: 'A',
      );
      when(
        () => mockApi.submitQuizAnswer(any(), any(), any(), any()),
      ).thenAnswer((_) async => answerResult);

      final container = ProviderContainer(
        overrides: [apiProvider.overrideWithValue(mockApi)],
      );
      addTearDown(container.dispose);

      const key1 = (roomId: 'room-1', quizId: 'quiz-1');
      const key2 = (roomId: 'room-1', quizId: 'quiz-2');

      final quiz1 = Quiz(
        id: 'quiz-1',
        title: 'Quiz 1',
        questions: const [
          QuizQuestion(id: 'q1', text: 'Q1', type: FreeForm()),
        ],
      );
      final quiz2 = Quiz(
        id: 'quiz-2',
        title: 'Quiz 2',
        questions: const [
          QuizQuestion(id: 'q2', text: 'Q2', type: FreeForm()),
        ],
      );

      // Start quiz 1
      container.read(quizSessionProvider(key1).notifier).start(quiz1);

      // Start quiz 2
      container.read(quizSessionProvider(key2).notifier).start(quiz2);

      // Verify both have independent state
      final session1 =
          container.read(quizSessionProvider(key1)) as QuizInProgress;
      final session2 =
          container.read(quizSessionProvider(key2)) as QuizInProgress;

      expect(session1.quiz.id, 'quiz-1');
      expect(session2.quiz.id, 'quiz-2');

      // Progress quiz 1 without affecting quiz 2
      container
          .read(quizSessionProvider(key1).notifier)
          .updateInput(const TextInput('answer'));
      await container.read(quizSessionProvider(key1).notifier).submitAnswer();
      container.read(quizSessionProvider(key1).notifier).nextQuestion();

      // Quiz 1 completed, quiz 2 still in progress
      expect(
        container.read(quizSessionProvider(key1)),
        isA<QuizCompleted>(),
      );
      expect(
        container.read(quizSessionProvider(key2)),
        isA<QuizInProgress>(),
      );
    });
  });
}
