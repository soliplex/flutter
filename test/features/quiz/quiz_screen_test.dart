import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:soliplex_client/soliplex_client.dart';
import 'package:soliplex_frontend/core/providers/api_provider.dart';
import 'package:soliplex_frontend/features/quiz/quiz_screen.dart';
import 'package:soliplex_frontend/shared/widgets/loading_indicator.dart';

import '../../helpers/test_helpers.dart';

void main() {
  late MockSoliplexApi mockApi;

  setUp(() {
    mockApi = MockSoliplexApi();
  });

  Widget buildQuizScreen({
    required SoliplexApi api,
    required String roomId,
    required String quizId,
  }) {
    final router = GoRouter(
      initialLocation: '/rooms/$roomId/quiz/$quizId',
      routes: [
        GoRoute(
          path: '/rooms/:roomId',
          builder: (context, state) => const Scaffold(
            body: Center(child: Text('Room Screen')),
          ),
        ),
        GoRoute(
          path: '/rooms/:roomId/quiz/:quizId',
          builder: (context, state) => QuizScreen(
            roomId: state.pathParameters['roomId']!,
            quizId: state.pathParameters['quizId']!,
          ),
        ),
      ],
    );

    return UncontrolledProviderScope(
      container: ProviderContainer(
        overrides: [
          packageInfoProviderOverride(testPackageInfo),
          apiProvider.overrideWithValue(api),
        ],
      ),
      child: MaterialApp.router(
        routerConfig: router,
        theme: testThemeData,
      ),
    );
  }

  group('QuizScreen', () {
    testWidgets('shows loading indicator while fetching quiz', (tester) async {
      // Arrange - mock API that never completes
      when(
        () => mockApi.getQuiz('room-1', 'quiz-1'),
      ).thenAnswer((_) => Completer<Quiz>().future);

      // Act
      await tester.pumpWidget(
        buildQuizScreen(api: mockApi, roomId: 'room-1', quizId: 'quiz-1'),
      );
      // Pump frames to let GoRouter and Riverpod initialize
      await tester.pump();
      await tester.pump();

      // Assert - loading indicator shown while quiz is being fetched
      expect(find.byType(QuizScreen), findsOneWidget);
      expect(find.byType(LoadingIndicator), findsOneWidget);
    });

    testWidgets('shows start screen when quiz loaded', (tester) async {
      // Arrange
      final quiz = Quiz(
        id: 'quiz-1',
        title: 'Test Quiz',
        questions: const [
          QuizQuestion(id: 'q1', text: 'Question 1', type: FreeForm()),
        ],
      );
      when(() => mockApi.getQuiz('room-1', 'quiz-1'))
          .thenAnswer((_) async => quiz);

      // Act
      await tester.pumpWidget(
        buildQuizScreen(api: mockApi, roomId: 'room-1', quizId: 'quiz-1'),
      );
      await tester.pumpAndSettle();

      // Assert - title appears in AppBar and body
      expect(find.text('Test Quiz'), findsNWidgets(2));
      expect(find.text('1 question'), findsOneWidget);
      expect(find.text('Start Quiz'), findsOneWidget);
    });

    testWidgets('starts quiz and shows first question', (tester) async {
      // Arrange
      final quiz = Quiz(
        id: 'quiz-1',
        title: 'Test Quiz',
        questions: const [
          QuizQuestion(id: 'q1', text: 'What is 2+2?', type: FreeForm()),
        ],
      );
      when(() => mockApi.getQuiz('room-1', 'quiz-1'))
          .thenAnswer((_) async => quiz);

      await tester.pumpWidget(
        buildQuizScreen(api: mockApi, roomId: 'room-1', quizId: 'quiz-1'),
      );
      await tester.pumpAndSettle();

      // Act - tap start button
      await tester.tap(find.text('Start Quiz'));
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Question 1 of 1'), findsOneWidget);
      expect(find.text('What is 2+2?'), findsOneWidget);
      expect(find.text('Submit Answer'), findsOneWidget);
    });

    testWidgets('shows multiple choice options', (tester) async {
      // Arrange
      final quiz = Quiz(
        id: 'quiz-1',
        title: 'Test Quiz',
        questions: [
          QuizQuestion(
            id: 'q1',
            text: 'Pick one',
            type: MultipleChoice(const ['A', 'B', 'C']),
          ),
        ],
      );
      when(() => mockApi.getQuiz('room-1', 'quiz-1'))
          .thenAnswer((_) async => quiz);

      await tester.pumpWidget(
        buildQuizScreen(api: mockApi, roomId: 'room-1', quizId: 'quiz-1'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start Quiz'));
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('A'), findsOneWidget);
      expect(find.text('B'), findsOneWidget);
      expect(find.text('C'), findsOneWidget);
      expect(find.byType(Radio<String>), findsNWidgets(3));
    });

    testWidgets('submit button disabled until answer provided', (tester) async {
      // Arrange
      final quiz = Quiz(
        id: 'quiz-1',
        title: 'Test Quiz',
        questions: const [
          QuizQuestion(id: 'q1', text: 'Question?', type: FreeForm()),
        ],
      );
      when(() => mockApi.getQuiz('room-1', 'quiz-1'))
          .thenAnswer((_) async => quiz);

      await tester.pumpWidget(
        buildQuizScreen(api: mockApi, roomId: 'room-1', quizId: 'quiz-1'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start Quiz'));
      await tester.pumpAndSettle();

      // Assert - button should be disabled
      final submitButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Submit Answer'),
      );
      expect(submitButton.onPressed, isNull);

      // Act - enter text
      await tester.enterText(find.byType(TextField), 'my answer');
      await tester.pump();

      // Assert - button should now be enabled
      final updatedButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Submit Answer'),
      );
      expect(updatedButton.onPressed, isNotNull);
    });

    testWidgets('submits answer and shows feedback', (tester) async {
      // Arrange
      final quiz = Quiz(
        id: 'quiz-1',
        title: 'Test Quiz',
        questions: const [
          QuizQuestion(id: 'q1', text: 'Question?', type: FreeForm()),
        ],
      );
      const result = QuizAnswerResult(
        isCorrect: true,
        expectedAnswer: 'correct',
      );
      when(() => mockApi.getQuiz('room-1', 'quiz-1'))
          .thenAnswer((_) async => quiz);
      when(() => mockApi.submitQuizAnswer('room-1', 'quiz-1', 'q1', 'correct'))
          .thenAnswer((_) async => result);

      await tester.pumpWidget(
        buildQuizScreen(api: mockApi, roomId: 'room-1', quizId: 'quiz-1'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start Quiz'));
      await tester.pumpAndSettle();

      // Enter answer and submit
      await tester.enterText(find.byType(TextField), 'correct');
      await tester.pump();
      await tester.tap(find.text('Submit Answer'));
      await tester.pumpAndSettle();

      // Assert - feedback shown
      expect(find.text('Correct!'), findsOneWidget);
      expect(find.text('See Results'), findsOneWidget);
    });

    testWidgets('shows incorrect feedback with expected answer',
        (tester) async {
      // Arrange
      final quiz = Quiz(
        id: 'quiz-1',
        title: 'Test Quiz',
        questions: const [
          QuizQuestion(id: 'q1', text: 'Question?', type: FreeForm()),
        ],
      );
      const result = QuizAnswerResult(
        isCorrect: false,
        expectedAnswer: 'correct answer',
      );
      when(() => mockApi.getQuiz('room-1', 'quiz-1'))
          .thenAnswer((_) async => quiz);
      when(() => mockApi.submitQuizAnswer('room-1', 'quiz-1', 'q1', 'wrong'))
          .thenAnswer((_) async => result);

      await tester.pumpWidget(
        buildQuizScreen(api: mockApi, roomId: 'room-1', quizId: 'quiz-1'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start Quiz'));
      await tester.pumpAndSettle();

      // Enter wrong answer and submit
      await tester.enterText(find.byType(TextField), 'wrong');
      await tester.pump();
      await tester.tap(find.text('Submit Answer'));
      await tester.pumpAndSettle();

      // Assert - feedback shown
      expect(find.text('Incorrect'), findsOneWidget);
      expect(find.text('Expected: correct answer'), findsOneWidget);
    });

    testWidgets('shows results screen after completing quiz', (tester) async {
      // Arrange
      final quiz = Quiz(
        id: 'quiz-1',
        title: 'Test Quiz',
        questions: const [
          QuizQuestion(id: 'q1', text: 'Question?', type: FreeForm()),
        ],
      );
      const result = QuizAnswerResult(
        isCorrect: true,
        expectedAnswer: 'answer',
      );
      when(() => mockApi.getQuiz('room-1', 'quiz-1'))
          .thenAnswer((_) async => quiz);
      when(() => mockApi.submitQuizAnswer('room-1', 'quiz-1', 'q1', 'answer'))
          .thenAnswer((_) async => result);

      await tester.pumpWidget(
        buildQuizScreen(api: mockApi, roomId: 'room-1', quizId: 'quiz-1'),
      );
      await tester.pumpAndSettle();

      // Start quiz
      await tester.tap(find.text('Start Quiz'));
      await tester.pumpAndSettle();

      // Answer question
      await tester.enterText(find.byType(TextField), 'answer');
      await tester.pump();
      await tester.tap(find.text('Submit Answer'));
      await tester.pumpAndSettle();

      // Go to results
      await tester.tap(find.text('See Results'));
      await tester.pumpAndSettle();

      // Assert - results screen shown
      expect(find.text('Quiz Complete!'), findsOneWidget);
      expect(find.text('100%'), findsOneWidget);
      expect(find.text('1 of 1 correct'), findsOneWidget);
      expect(find.text('Back to Room'), findsOneWidget);
      expect(find.text('Retake Quiz'), findsOneWidget);
    });

    testWidgets('shows snackbar on submit error', (tester) async {
      // Arrange
      final quiz = Quiz(
        id: 'quiz-1',
        title: 'Test Quiz',
        questions: const [
          QuizQuestion(id: 'q1', text: 'Question?', type: FreeForm()),
        ],
      );
      when(() => mockApi.getQuiz('room-1', 'quiz-1'))
          .thenAnswer((_) async => quiz);
      when(() => mockApi.submitQuizAnswer('room-1', 'quiz-1', 'q1', 'answer'))
          .thenThrow(Exception('Network error'));

      await tester.pumpWidget(
        buildQuizScreen(api: mockApi, roomId: 'room-1', quizId: 'quiz-1'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start Quiz'));
      await tester.pumpAndSettle();

      // Enter answer and submit
      await tester.enterText(find.byType(TextField), 'answer');
      await tester.pump();
      await tester.tap(find.text('Submit Answer'));
      await tester.pumpAndSettle();

      // Assert - snackbar shown with error message
      expect(find.byType(SnackBar), findsOneWidget);
      expect(
        find.textContaining('Failed to submit answer'),
        findsOneWidget,
      );

      // Assert - button should still be enabled (input preserved)
      final submitButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Submit Answer'),
      );
      expect(submitButton.onPressed, isNotNull);
    });

    testWidgets('can retake quiz after completion', (tester) async {
      // Arrange
      final quiz = Quiz(
        id: 'quiz-1',
        title: 'Test Quiz',
        questions: const [
          QuizQuestion(id: 'q1', text: 'Question?', type: FreeForm()),
        ],
      );
      const result = QuizAnswerResult(
        isCorrect: true,
        expectedAnswer: 'answer',
      );
      when(() => mockApi.getQuiz('room-1', 'quiz-1'))
          .thenAnswer((_) async => quiz);
      when(() => mockApi.submitQuizAnswer('room-1', 'quiz-1', 'q1', 'answer'))
          .thenAnswer((_) async => result);

      await tester.pumpWidget(
        buildQuizScreen(api: mockApi, roomId: 'room-1', quizId: 'quiz-1'),
      );
      await tester.pumpAndSettle();

      // Complete the quiz
      await tester.tap(find.text('Start Quiz'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'answer');
      await tester.pump();
      await tester.tap(find.text('Submit Answer'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('See Results'));
      await tester.pumpAndSettle();

      // Verify we're on results screen
      expect(find.text('Quiz Complete!'), findsOneWidget);

      // Tap Retake Quiz
      await tester.tap(find.text('Retake Quiz'));
      await tester.pumpAndSettle();

      // Assert - back to question screen (retake starts the quiz)
      expect(find.text('Question 1 of 1'), findsOneWidget);
      expect(find.text('Question?'), findsOneWidget);
    });

    testWidgets('can select multiple choice option', (tester) async {
      // Arrange
      final quiz = Quiz(
        id: 'quiz-1',
        title: 'Test Quiz',
        questions: [
          QuizQuestion(
            id: 'q1',
            text: 'Pick one',
            type: MultipleChoice(const ['A', 'B', 'C']),
          ),
        ],
      );
      when(() => mockApi.getQuiz('room-1', 'quiz-1'))
          .thenAnswer((_) async => quiz);

      await tester.pumpWidget(
        buildQuizScreen(api: mockApi, roomId: 'room-1', quizId: 'quiz-1'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start Quiz'));
      await tester.pumpAndSettle();

      // Submit button should be disabled
      var submitButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Submit Answer'),
      );
      expect(submitButton.onPressed, isNull);

      // Tap on option B
      await tester.tap(find.text('B'));
      await tester.pump();

      // Submit button should now be enabled
      submitButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Submit Answer'),
      );
      expect(submitButton.onPressed, isNotNull);
    });
  });
}
