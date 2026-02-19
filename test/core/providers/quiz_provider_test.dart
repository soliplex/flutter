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
      final quiz = Quiz(
        id: 'quiz-1',
        title: 'Test Quiz',
        questions: const [
          QuizQuestion(id: 'q1', text: 'Q1', type: FreeForm()),
        ],
      );
      when(() => mockApi.getQuiz('room-1', 'quiz-1'))
          .thenAnswer((_) async => quiz);

      final container = ProviderContainer(
        overrides: [apiProvider.overrideWithValue(mockApi)],
      );
      addTearDown(container.dispose);

      final result = await container.read(
        quizProvider((roomId: 'room-1', quizId: 'quiz-1')).future,
      );

      expect(result.id, 'quiz-1');
      expect(result.title, 'Test Quiz');
      verify(() => mockApi.getQuiz('room-1', 'quiz-1')).called(1);
    });

    test('propagates NotFoundException', () async {
      when(() => mockApi.getQuiz('room-1', 'missing')).thenThrow(
        const NotFoundException(
          message: 'Not found',
          resource: '/rooms/room-1/quiz/missing',
        ),
      );

      final container = ProviderContainer(
        overrides: [apiProvider.overrideWithValue(mockApi)],
      );
      addTearDown(container.dispose);

      final completer = Completer<AsyncValue<Quiz>>();
      container
        ..listen(quizProvider((roomId: 'room-1', quizId: 'missing')),
            (_, next) {
          if (next.hasError) completer.complete(next);
        })
        ..read(quizProvider((roomId: 'room-1', quizId: 'missing')));
      final state = await completer.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () =>
            container.read(quizProvider((roomId: 'room-1', quizId: 'missing'))),
      );

      expect(state.hasError, isTrue);
      expect(state.error, isA<NotFoundException>());
    });

    test('caches separately per family key', () async {
      final quiz1 = Quiz(id: 'q1', title: 'Q1', questions: const []);
      final quiz2 = Quiz(id: 'q2', title: 'Q2', questions: const []);
      when(() => mockApi.getQuiz('r1', 'q1')).thenAnswer((_) async => quiz1);
      when(() => mockApi.getQuiz('r1', 'q2')).thenAnswer((_) async => quiz2);

      final container = ProviderContainer(
        overrides: [apiProvider.overrideWithValue(mockApi)],
      );
      addTearDown(container.dispose);

      final r1 = await container.read(
        quizProvider((roomId: 'r1', quizId: 'q1')).future,
      );
      final r2 = await container.read(
        quizProvider((roomId: 'r1', quizId: 'q2')).future,
      );

      expect(r1.id, 'q1');
      expect(r2.id, 'q2');
    });
  });

  group('quizSessionProvider', () {
    const testKey = (roomId: 'room-1', quizId: 'quiz-1');
    final quiz = Quiz(
      id: 'quiz-1',
      title: 'Test',
      questions: const [
        QuizQuestion(id: 'q1', text: 'Q1', type: FreeForm()),
        QuizQuestion(id: 'q2', text: 'Q2', type: FreeForm()),
      ],
    );

    test('starts with QuizNotStarted', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(
        container.read(quizSessionProvider(testKey)),
        isA<QuizNotStarted>(),
      );
    });

    test('start delegates to QuizSession.start', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(quizSessionProvider(testKey).notifier).start(quiz);

      final session = container.read(quizSessionProvider(testKey));
      expect(session, isA<QuizInProgress>());
      expect((session as QuizInProgress).currentIndex, 0);
    });

    test('updateInput delegates to state.withInput', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(quizSessionProvider(testKey).notifier).start(quiz);
      container
          .read(quizSessionProvider(testKey).notifier)
          .updateInput(const TextInput('answer'));

      final session =
          container.read(quizSessionProvider(testKey)) as QuizInProgress;
      expect(session.questionState, isA<Composing>());
    });

    test('clearInput delegates to state.withInputCleared', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(quizSessionProvider(testKey).notifier).start(quiz);
      container
          .read(quizSessionProvider(testKey).notifier)
          .updateInput(const TextInput('answer'));
      container.read(quizSessionProvider(testKey).notifier).clearInput();

      final session =
          container.read(quizSessionProvider(testKey)) as QuizInProgress;
      expect(session.questionState, isA<AwaitingInput>());
    });

    test('nextQuestion delegates to state.advance', () async {
      late MockSoliplexApi mockApi;
      mockApi = MockSoliplexApi();
      when(
        () => mockApi.submitQuizAnswer(any(), any(), any(), any()),
      ).thenAnswer((_) async => const CorrectAnswer());

      final container = ProviderContainer(
        overrides: [apiProvider.overrideWithValue(mockApi)],
      );
      addTearDown(container.dispose);

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
    });

    test('reset sets state to QuizNotStarted', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(quizSessionProvider(testKey).notifier).start(quiz);
      container.read(quizSessionProvider(testKey).notifier).reset();

      expect(
        container.read(quizSessionProvider(testKey)),
        isA<QuizNotStarted>(),
      );
    });

    test('retake delegates to state.retake', () async {
      late MockSoliplexApi mockApi;
      mockApi = MockSoliplexApi();
      when(
        () => mockApi.submitQuizAnswer(any(), any(), any(), any()),
      ).thenAnswer((_) async => const CorrectAnswer());

      final singleQuestionQuiz = Quiz(
        id: 'quiz-1',
        title: 'Test',
        questions: const [
          QuizQuestion(id: 'q1', text: 'Q1', type: FreeForm()),
        ],
      );

      final container = ProviderContainer(
        overrides: [apiProvider.overrideWithValue(mockApi)],
      );
      addTearDown(container.dispose);

      container
          .read(quizSessionProvider(testKey).notifier)
          .start(singleQuestionQuiz);
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
    });

    group('submitAnswer', () {
      late MockSoliplexApi mockApi;

      setUp(() {
        mockApi = MockSoliplexApi();
      });

      test('calls API and transitions to Answered', () async {
        when(
          () => mockApi.submitQuizAnswer(any(), any(), any(), any()),
        ).thenAnswer((_) async => const CorrectAnswer());

        final container = ProviderContainer(
          overrides: [apiProvider.overrideWithValue(mockApi)],
        );
        addTearDown(container.dispose);

        container.read(quizSessionProvider(testKey).notifier).start(quiz);
        container
            .read(quizSessionProvider(testKey).notifier)
            .updateInput(const TextInput('my answer'));

        await container
            .read(quizSessionProvider(testKey).notifier)
            .submitAnswer();

        final session =
            container.read(quizSessionProvider(testKey)) as QuizInProgress;
        expect(session.questionState, isA<Answered>());
        expect(session.results['q1'], isA<CorrectAnswer>());
      });

      test('transitions to SubmissionFailed on API error', () async {
        when(
          () => mockApi.submitQuizAnswer(any(), any(), any(), any()),
        ).thenThrow(const NetworkException(message: 'timeout'));

        final container = ProviderContainer(
          overrides: [apiProvider.overrideWithValue(mockApi)],
        );
        addTearDown(container.dispose);

        container.read(quizSessionProvider(testKey).notifier).start(quiz);
        container
            .read(quizSessionProvider(testKey).notifier)
            .updateInput(const TextInput('answer'));

        await container
            .read(quizSessionProvider(testKey).notifier)
            .submitAnswer();

        final session =
            container.read(quizSessionProvider(testKey)) as QuizInProgress;
        expect(session.questionState, isA<SubmissionFailed>());
        final failed = session.questionState as SubmissionFailed;
        expect(failed.error, isA<NetworkException>());
        expect(failed.input, equals(const TextInput('answer')));
      });

      test('sets intermediate Submitting state for UI feedback', () async {
        final completer = Completer<QuizAnswerResult>();
        when(
          () => mockApi.submitQuizAnswer(any(), any(), any(), any()),
        ).thenAnswer((_) => completer.future);

        final container = ProviderContainer(
          overrides: [apiProvider.overrideWithValue(mockApi)],
        );
        addTearDown(container.dispose);

        container.read(quizSessionProvider(testKey).notifier).start(quiz);
        container
            .read(quizSessionProvider(testKey).notifier)
            .updateInput(const TextInput('answer'));

        unawaited(
          container.read(quizSessionProvider(testKey).notifier).submitAnswer(),
        );

        final session =
            container.read(quizSessionProvider(testKey)) as QuizInProgress;
        expect(session.questionState, isA<Submitting>());

        completer.complete(const CorrectAnswer());
      });

      test('throws StateError when not in progress', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        expect(
          () => container
              .read(quizSessionProvider(testKey).notifier)
              .submitAnswer(),
          throwsStateError,
        );
      });
    });

    group('race conditions', () {
      test('reset during in-flight submit preserves QuizNotStarted', () async {
        final mockApi = MockSoliplexApi();
        final completer = Completer<QuizAnswerResult>();
        when(
          () => mockApi.submitQuizAnswer(any(), any(), any(), any()),
        ).thenAnswer((_) => completer.future);

        final container = ProviderContainer(
          overrides: [apiProvider.overrideWithValue(mockApi)],
        );
        addTearDown(container.dispose);

        container.read(quizSessionProvider(testKey).notifier).start(quiz);
        container
            .read(quizSessionProvider(testKey).notifier)
            .updateInput(const TextInput('answer'));

        final submitFuture = container
            .read(quizSessionProvider(testKey).notifier)
            .submitAnswer();

        container.read(quizSessionProvider(testKey).notifier).reset();
        expect(
          container.read(quizSessionProvider(testKey)),
          isA<QuizNotStarted>(),
        );

        completer.complete(const CorrectAnswer());
        await submitFuture;

        // State must still be QuizNotStarted — race guard prevented overwrite
        expect(
          container.read(quizSessionProvider(testKey)),
          isA<QuizNotStarted>(),
        );
      });
    });

    test('isolates state per family key', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      const key1 = (roomId: 'room-1', quizId: 'quiz-1');
      const key2 = (roomId: 'room-1', quizId: 'quiz-2');

      final quiz1 = Quiz(
        id: 'quiz-1',
        title: 'Q1',
        questions: const [
          QuizQuestion(id: 'q1', text: 'Q1', type: FreeForm()),
        ],
      );
      final quiz2 = Quiz(
        id: 'quiz-2',
        title: 'Q2',
        questions: const [
          QuizQuestion(id: 'q2', text: 'Q2', type: FreeForm()),
        ],
      );

      container.read(quizSessionProvider(key1).notifier).start(quiz1);
      container.read(quizSessionProvider(key2).notifier).start(quiz2);

      final s1 = container.read(quizSessionProvider(key1)) as QuizInProgress;
      final s2 = container.read(quizSessionProvider(key2)) as QuizInProgress;

      expect(s1.quiz.id, 'quiz-1');
      expect(s2.quiz.id, 'quiz-2');
    });
  });
}
