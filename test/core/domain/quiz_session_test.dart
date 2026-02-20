import 'package:flutter_test/flutter_test.dart';
import 'package:soliplex_client/soliplex_client.dart';
import 'package:soliplex_frontend/core/domain/quiz_session.dart';

void main() {
  final twoQuestionQuiz = Quiz(
    id: 'quiz-1',
    title: 'Test',
    questions: const [
      QuizQuestion(id: 'q1', text: 'Q1', type: FreeForm()),
      QuizQuestion(id: 'q2', text: 'Q2', type: FreeForm()),
    ],
  );

  final oneQuestionQuiz = Quiz(
    id: 'quiz-1',
    title: 'Test',
    questions: const [
      QuizQuestion(id: 'q1', text: 'Q1', type: FreeForm()),
    ],
  );

  group('QuizInput', () {
    test('MultipleChoiceInput is always valid', () {
      const input = MultipleChoiceInput('A');
      expect(input.isValid, isTrue);
      expect(input.answerText, 'A');
    });

    test('TextInput is valid when non-empty after trimming', () {
      expect(const TextInput('answer').isValid, isTrue);
      expect(const TextInput('  answer  ').answerText, 'answer');
    });

    test('TextInput is invalid when empty or whitespace-only', () {
      expect(const TextInput('').isValid, isFalse);
      expect(const TextInput('   ').isValid, isFalse);
    });

    test('MultipleChoiceInput equality', () {
      expect(
        const MultipleChoiceInput('A'),
        equals(const MultipleChoiceInput('A')),
      );
      expect(
        const MultipleChoiceInput('A'),
        isNot(equals(const MultipleChoiceInput('B'))),
      );
    });

    test('TextInput equality', () {
      expect(const TextInput('a'), equals(const TextInput('a')));
      expect(const TextInput('a'), isNot(equals(const TextInput('b'))));
    });
  });

  group('QuestionState', () {
    test('AwaitingInput equality', () {
      expect(const AwaitingInput(), equals(const AwaitingInput()));
    });

    test('Composing equality and canSubmit', () {
      const a = Composing(TextInput('answer'));
      const b = Composing(TextInput('answer'));
      expect(a, equals(b));
      expect(a.canSubmit, isTrue);
      expect(const Composing(TextInput('')).canSubmit, isFalse);
    });

    test('Submitting equality', () {
      const a = Submitting(TextInput('answer'));
      const b = Submitting(TextInput('answer'));
      expect(a, equals(b));
    });

    test('Answered equality', () {
      const a = Answered(TextInput('answer'), CorrectAnswer());
      const b = Answered(TextInput('answer'), CorrectAnswer());
      expect(a, equals(b));
    });

    test('SubmissionFailed equality', () {
      const error = NetworkException(message: 'timeout');
      const a = SubmissionFailed(input: TextInput('answer'), error: error);
      const b = SubmissionFailed(input: TextInput('answer'), error: error);
      expect(a, equals(b));
    });
  });

  group('QuizSession.start', () {
    test('returns QuizInProgress at question 0', () {
      final session = QuizSession.start(oneQuestionQuiz);
      expect(session.quiz.id, 'quiz-1');
      expect(session.currentIndex, 0);
      expect(session.results, isEmpty);
      expect(session.questionState, isA<AwaitingInput>());
    });

    test('throws ArgumentError for empty quiz', () {
      final emptyQuiz = Quiz(id: 'q', title: 'E', questions: const []);
      expect(() => QuizSession.start(emptyQuiz), throwsA(isA<ArgumentError>()));
    });
  });

  group('QuizNotStarted', () {
    test('equality', () {
      expect(const QuizNotStarted(), equals(const QuizNotStarted()));
    });

    test('withInput returns self', () {
      const session = QuizNotStarted();
      expect(session.withInput(const TextInput('x')), same(session));
    });

    test('withInputCleared returns self', () {
      const session = QuizNotStarted();
      expect(session.withInputCleared(), same(session));
    });

    test('advance throws StateError', () {
      expect(
        () => const QuizNotStarted().advance(),
        throwsStateError,
      );
    });

    test('retake throws StateError', () {
      expect(
        () => const QuizNotStarted().retake(),
        throwsStateError,
      );
    });
  });

  group('QuizInProgress', () {
    test('currentQuestion returns question at currentIndex', () {
      final session = QuizSession.start(twoQuestionQuiz);
      expect(session.currentQuestion.id, 'q1');
    });

    test('isLastQuestion', () {
      final first = QuizSession.start(twoQuestionQuiz);
      expect(first.isLastQuestion, isFalse);

      final last = first.copyWith(currentIndex: 1);
      expect(last.isLastQuestion, isTrue);
    });

    test('progress', () {
      final session = QuizInProgress(
        quiz: twoQuestionQuiz,
        currentIndex: 0,
        results: const {'q1': CorrectAnswer()},
        questionState: const AwaitingInput(),
      );
      expect(session.progress, 0.5);
    });

    group('withInput', () {
      test('transitions from AwaitingInput to Composing', () {
        final session = QuizSession.start(oneQuestionQuiz);
        final updated = session.withInput(const TextInput('answer'));
        expect(updated.questionState, isA<Composing>());
      });

      test('updates existing Composing input', () {
        final session = QuizSession.start(oneQuestionQuiz)
            .withInput(const TextInput('old'));
        final updated = session.withInput(const TextInput('new'));
        expect(
          (updated.questionState as Composing).input,
          equals(const TextInput('new')),
        );
      });

      test('no-op during Submitting', () {
        final session = QuizSession.start(oneQuestionQuiz)
            .withInput(const TextInput('answer'))
            .submitting();
        final updated = session.withInput(const TextInput('changed'));
        expect(updated.questionState, isA<Submitting>());
      });

      test('no-op during Answered', () {
        final session = QuizSession.start(oneQuestionQuiz)
            .withInput(const TextInput('answer'))
            .submitting()
            .withAnswer(const CorrectAnswer());
        final updated = session.withInput(const TextInput('changed'));
        expect(updated.questionState, isA<Answered>());
      });

      test('transitions from SubmissionFailed to Composing', () {
        const error = NetworkException(message: 'timeout');
        final session = QuizSession.start(oneQuestionQuiz)
            .withInput(const TextInput('answer'))
            .submitting()
            .withSubmissionFailed(error);
        final updated = session.withInput(const TextInput('new'));
        expect(updated.questionState, isA<Composing>());
      });
    });

    group('withInputCleared', () {
      test('transitions from Composing to AwaitingInput', () {
        final session = QuizSession.start(oneQuestionQuiz)
            .withInput(const TextInput('answer'));
        final cleared = session.withInputCleared();
        expect(cleared.questionState, isA<AwaitingInput>());
      });

      test('transitions from SubmissionFailed to AwaitingInput', () {
        const error = NetworkException(message: 'timeout');
        final session = QuizSession.start(oneQuestionQuiz)
            .withInput(const TextInput('answer'))
            .submitting()
            .withSubmissionFailed(error);
        final cleared = session.withInputCleared();
        expect(cleared.questionState, isA<AwaitingInput>());
      });

      test('no-op from AwaitingInput', () {
        final session = QuizSession.start(oneQuestionQuiz);
        expect(session.withInputCleared(), same(session));
      });
    });

    group('submitting', () {
      test('transitions from Composing to Submitting', () {
        final session = QuizSession.start(oneQuestionQuiz)
            .withInput(const TextInput('answer'));
        final submitting = session.submitting();
        expect(submitting.questionState, isA<Submitting>());
        expect(
          (submitting.questionState as Submitting).input,
          equals(const TextInput('answer')),
        );
      });

      test('transitions from SubmissionFailed to Submitting (retry)', () {
        const error = NetworkException(message: 'timeout');
        final session = QuizSession.start(oneQuestionQuiz)
            .withInput(const TextInput('answer'))
            .submitting()
            .withSubmissionFailed(error);
        final retrying = session.submitting();
        expect(retrying.questionState, isA<Submitting>());
      });

      test('throws StateError from AwaitingInput', () {
        final session = QuizSession.start(oneQuestionQuiz);
        expect(session.submitting, throwsStateError);
      });

      test('throws ArgumentError for invalid input', () {
        final session = QuizSession.start(oneQuestionQuiz)
            .withInput(const TextInput('   '));
        expect(session.submitting, throwsA(isA<ArgumentError>()));
      });
    });

    group('withAnswer', () {
      test('transitions from Submitting to Answered with result', () {
        final session = QuizSession.start(oneQuestionQuiz)
            .withInput(const TextInput('answer'))
            .submitting();
        final answered = session.withAnswer(const CorrectAnswer());
        expect(answered.questionState, isA<Answered>());
        expect(answered.results['q1'], isA<CorrectAnswer>());
      });

      test('no-op if not Submitting', () {
        final session = QuizSession.start(oneQuestionQuiz)
            .withInput(const TextInput('answer'));
        expect(session.withAnswer(const CorrectAnswer()), same(session));
      });
    });

    group('withSubmissionFailed', () {
      test('transitions from Submitting to SubmissionFailed', () {
        const error = NetworkException(message: 'timeout');
        final session = QuizSession.start(oneQuestionQuiz)
            .withInput(const TextInput('answer'))
            .submitting();
        final failed = session.withSubmissionFailed(error);
        expect(failed.questionState, isA<SubmissionFailed>());
        final state = failed.questionState as SubmissionFailed;
        expect(state.input, equals(const TextInput('answer')));
        expect(state.error, isA<NetworkException>());
      });

      test('no-op if not Submitting', () {
        final session = QuizSession.start(oneQuestionQuiz);
        expect(
          session.withSubmissionFailed(Exception('fail')),
          same(session),
        );
      });
    });

    group('advance', () {
      test('moves to next question', () {
        final session = QuizSession.start(twoQuestionQuiz)
            .withInput(const TextInput('answer'))
            .submitting()
            .withAnswer(const CorrectAnswer());
        final next = session.advance();
        expect(next, isA<QuizInProgress>());
        expect((next as QuizInProgress).currentIndex, 1);
        expect(next.questionState, isA<AwaitingInput>());
      });

      test('completes quiz on last question', () {
        final session = QuizSession.start(oneQuestionQuiz)
            .withInput(const TextInput('answer'))
            .submitting()
            .withAnswer(const CorrectAnswer());
        final completed = session.advance();
        expect(completed, isA<QuizCompleted>());
        expect(
          (completed as QuizCompleted).results['q1'],
          isA<CorrectAnswer>(),
        );
      });

      test('throws StateError if not Answered', () {
        final session = QuizSession.start(oneQuestionQuiz);
        expect(session.advance, throwsStateError);
      });
    });

    group('retake', () {
      test('restarts from beginning', () {
        final session = QuizSession.start(twoQuestionQuiz)
            .withInput(const TextInput('answer'))
            .submitting()
            .withAnswer(const CorrectAnswer());
        final retaken = session.retake();
        expect(retaken.currentIndex, 0);
        expect(retaken.results, isEmpty);
        expect(retaken.questionState, isA<AwaitingInput>());
      });
    });

    test('equality', () {
      final a = QuizSession.start(oneQuestionQuiz);
      final b = QuizSession.start(oneQuestionQuiz);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));

      final c = a.withInput(const TextInput('x'));
      expect(a, isNot(equals(c)));
    });
  });

  group('QuizCompleted', () {
    test('correctCount and scorePercent', () {
      final session = QuizCompleted(
        quiz: twoQuestionQuiz,
        results: const {
          'q1': CorrectAnswer(),
          'q2': IncorrectAnswer(expectedAnswer: 'B'),
        },
      );
      expect(session.correctCount, 1);
      expect(session.totalAnswered, 2);
      expect(session.scorePercent, 50);
    });

    test('retake restarts quiz', () {
      final session = QuizCompleted(
        quiz: oneQuestionQuiz,
        results: const {'q1': CorrectAnswer()},
      );
      final retaken = session.retake();
      expect(retaken.currentIndex, 0);
      expect(retaken.results, isEmpty);
      expect(retaken.questionState, isA<AwaitingInput>());
    });

    test('equality', () {
      final a = QuizCompleted(quiz: oneQuestionQuiz, results: const {});
      final b = QuizCompleted(quiz: oneQuestionQuiz, results: const {});
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });
  });
}
