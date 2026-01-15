import 'package:soliplex_client/soliplex_client.dart';
import 'package:test/test.dart';

void main() {
  group('QuestionLimit', () {
    group('AllQuestions', () {
      test('creates const instance', () {
        const limit = AllQuestions();
        expect(limit, isA<QuestionLimit>());
      });

      test('equality', () {
        const limit1 = AllQuestions();
        const limit2 = AllQuestions();
        expect(limit1, equals(limit2));
      });

      test('hashCode consistent', () {
        const limit1 = AllQuestions();
        const limit2 = AllQuestions();
        expect(limit1.hashCode, equals(limit2.hashCode));
      });

      test('toString', () {
        const limit = AllQuestions();
        expect(limit.toString(), equals('AllQuestions()'));
      });

      test('identical returns true', () {
        const limit = AllQuestions();
        expect(limit == limit, isTrue);
      });
    });

    group('LimitedQuestions', () {
      test('creates with count', () {
        const limit = LimitedQuestions(5);
        expect(limit, isA<QuestionLimit>());
        expect(limit.count, equals(5));
      });

      test('equality based on count', () {
        const limit1 = LimitedQuestions(5);
        const limit2 = LimitedQuestions(5);
        const limit3 = LimitedQuestions(10);
        expect(limit1, equals(limit2));
        expect(limit1, isNot(equals(limit3)));
      });

      test('hashCode consistent', () {
        const limit1 = LimitedQuestions(5);
        const limit2 = LimitedQuestions(5);
        expect(limit1.hashCode, equals(limit2.hashCode));
      });

      test('toString', () {
        const limit = LimitedQuestions(5);
        expect(limit.toString(), equals('LimitedQuestions(5)'));
      });

      test('identical returns true', () {
        const limit = LimitedQuestions(5);
        expect(limit == limit, isTrue);
      });
    });
  });

  group('QuestionType', () {
    group('MultipleChoice', () {
      test('creates with options', () {
        final type = MultipleChoice(const ['A', 'B', 'C']);
        expect(type, isA<QuestionType>());
        expect(type.options, equals(['A', 'B', 'C']));
      });

      test('options are unmodifiable', () {
        final original = ['A', 'B'];
        final type = MultipleChoice(original);
        original.add('C'); // Modify original list
        // Type's options should be unaffected
        expect(type.options, equals(['A', 'B']));
      });

      test('throws ArgumentError when fewer than 2 options', () {
        expect(
          () => MultipleChoice(const []),
          throwsA(isA<ArgumentError>()),
        );
        expect(
          () => MultipleChoice(const ['A']),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('allows exactly 2 options', () {
        final type = MultipleChoice(const ['A', 'B']);
        expect(type.options.length, equals(2));
      });

      test('equality based on options', () {
        final type1 = MultipleChoice(const ['A', 'B']);
        final type2 = MultipleChoice(const ['A', 'B']);
        final type3 = MultipleChoice(const ['A', 'C']);
        final type4 = MultipleChoice(const ['A', 'B', 'C']);
        expect(type1, equals(type2));
        expect(type1, isNot(equals(type3)));
        expect(type1, isNot(equals(type4)));
      });

      test('hashCode consistent', () {
        final type1 = MultipleChoice(const ['A', 'B']);
        final type2 = MultipleChoice(const ['A', 'B']);
        expect(type1.hashCode, equals(type2.hashCode));
      });

      test('toString includes option count', () {
        final type = MultipleChoice(const ['A', 'B', 'C']);
        expect(type.toString(), contains('3 options'));
      });

      test('identical returns true', () {
        final type = MultipleChoice(const ['A', 'B']);
        expect(type == type, isTrue);
      });
    });

    group('FillBlank', () {
      test('creates const instance', () {
        const type = FillBlank();
        expect(type, isA<QuestionType>());
      });

      test('equality', () {
        const type1 = FillBlank();
        const type2 = FillBlank();
        expect(type1, equals(type2));
      });

      test('hashCode consistent', () {
        const type1 = FillBlank();
        const type2 = FillBlank();
        expect(type1.hashCode, equals(type2.hashCode));
      });

      test('toString', () {
        const type = FillBlank();
        expect(type.toString(), equals('FillBlank()'));
      });

      test('identical returns true', () {
        const type = FillBlank();
        expect(type == type, isTrue);
      });
    });

    group('FreeForm', () {
      test('creates const instance', () {
        const type = FreeForm();
        expect(type, isA<QuestionType>());
      });

      test('equality', () {
        const type1 = FreeForm();
        const type2 = FreeForm();
        expect(type1, equals(type2));
      });

      test('hashCode consistent', () {
        const type1 = FreeForm();
        const type2 = FreeForm();
        expect(type1.hashCode, equals(type2.hashCode));
      });

      test('toString', () {
        const type = FreeForm();
        expect(type.toString(), equals('FreeForm()'));
      });

      test('identical returns true', () {
        const type = FreeForm();
        expect(type == type, isTrue);
      });
    });
  });

  group('QuizQuestion', () {
    test('creates with required fields', () {
      const question = QuizQuestion(
        id: 'q-1',
        text: 'What is 2+2?',
        type: FreeForm(),
      );

      expect(question.id, equals('q-1'));
      expect(question.text, equals('What is 2+2?'));
      expect(question.type, isA<FreeForm>());
    });

    test('creates with MultipleChoice type', () {
      final question = QuizQuestion(
        id: 'q-1',
        text: 'Pick one',
        type: MultipleChoice(const ['A', 'B', 'C']),
      );

      expect(question.type, isA<MultipleChoice>());
      final options = (question.type as MultipleChoice).options;
      expect(options, equals(['A', 'B', 'C']));
    });

    group('equality', () {
      test('equal based on id only', () {
        const q1 = QuizQuestion(
          id: 'q-1',
          text: 'Question 1',
          type: FreeForm(),
        );
        const q2 = QuizQuestion(
          id: 'q-1',
          text: 'Different text',
          type: FillBlank(),
        );
        const q3 = QuizQuestion(
          id: 'q-2',
          text: 'Question 1',
          type: FreeForm(),
        );

        expect(q1, equals(q2));
        expect(q1, isNot(equals(q3)));
      });

      test('identical returns true', () {
        const question = QuizQuestion(
          id: 'q-1',
          text: 'Question',
          type: FreeForm(),
        );
        expect(question == question, isTrue);
      });
    });

    test('hashCode based on id only', () {
      const q1 = QuizQuestion(
        id: 'q-1',
        text: 'Question 1',
        type: FreeForm(),
      );
      const q2 = QuizQuestion(
        id: 'q-1',
        text: 'Different',
        type: FillBlank(),
      );

      expect(q1.hashCode, equals(q2.hashCode));
    });

    test('toString includes id and type', () {
      const question = QuizQuestion(
        id: 'q-1',
        text: 'Question',
        type: FreeForm(),
      );

      final str = question.toString();

      expect(str, contains('q-1'));
      expect(str, contains('FreeForm'));
    });
  });

  group('Quiz', () {
    test('creates with required fields', () {
      final quiz = Quiz(
        id: 'quiz-1',
        title: 'Test Quiz',
        questions: const [],
      );

      expect(quiz.id, equals('quiz-1'));
      expect(quiz.title, equals('Test Quiz'));
      expect(quiz.randomize, isFalse);
      expect(quiz.questionLimit, isA<AllQuestions>());
      expect(quiz.questions, isEmpty);
      expect(quiz.questionCount, equals(0));
      expect(quiz.hasQuestions, isFalse);
    });

    test('creates with all fields', () {
      final questions = [
        const QuizQuestion(
          id: 'q-1',
          text: 'Question 1',
          type: FreeForm(),
        ),
        const QuizQuestion(
          id: 'q-2',
          text: 'Question 2',
          type: FillBlank(),
        ),
      ];

      final quiz = Quiz(
        id: 'quiz-1',
        title: 'Test Quiz',
        randomize: true,
        questionLimit: const LimitedQuestions(5),
        questions: questions,
      );

      expect(quiz.id, equals('quiz-1'));
      expect(quiz.title, equals('Test Quiz'));
      expect(quiz.randomize, isTrue);
      expect(quiz.questionLimit, isA<LimitedQuestions>());
      expect((quiz.questionLimit as LimitedQuestions).count, equals(5));
      expect(quiz.questions, hasLength(2));
      expect(quiz.questionCount, equals(2));
      expect(quiz.hasQuestions, isTrue);
    });

    group('equality', () {
      test('equal based on id only', () {
        final quiz1 = Quiz(
          id: 'quiz-1',
          title: 'Quiz 1',
          questions: const [],
        );
        final quiz2 = Quiz(
          id: 'quiz-1',
          title: 'Different title',
          randomize: true,
          questions: const [],
        );
        final quiz3 = Quiz(
          id: 'quiz-2',
          title: 'Quiz 1',
          questions: const [],
        );

        expect(quiz1, equals(quiz2));
        expect(quiz1, isNot(equals(quiz3)));
      });

      test('identical returns true', () {
        final quiz = Quiz(id: 'quiz-1', title: 'Quiz', questions: const []);
        expect(quiz == quiz, isTrue);
      });
    });

    test('hashCode based on id only', () {
      final quiz1 = Quiz(id: 'quiz-1', title: 'Quiz 1', questions: const []);
      final quiz2 = Quiz(id: 'quiz-1', title: 'Different', questions: const []);

      expect(quiz1.hashCode, equals(quiz2.hashCode));
    });

    test('toString includes id, title, and question count', () {
      final quiz = Quiz(
        id: 'quiz-1',
        title: 'Test Quiz',
        questions: const [
          QuizQuestion(
            id: 'q-1',
            text: 'Q',
            type: FreeForm(),
          ),
        ],
      );

      final str = quiz.toString();

      expect(str, contains('quiz-1'));
      expect(str, contains('Test Quiz'));
      expect(str, contains('1 questions'));
    });
  });

  group('QuizAnswerResult', () {
    test('creates correct result', () {
      const result = QuizAnswerResult(
        isCorrect: true,
        expectedAnswer: 'The answer',
      );

      expect(result.isCorrect, isTrue);
      expect(result.expectedAnswer, equals('The answer'));
    });

    test('creates incorrect result', () {
      const result = QuizAnswerResult(
        isCorrect: false,
        expectedAnswer: 'The answer',
      );

      expect(result.isCorrect, isFalse);
      expect(result.expectedAnswer, equals('The answer'));
    });

    group('equality', () {
      test('equal based on all fields', () {
        const result1 = QuizAnswerResult(
          isCorrect: true,
          expectedAnswer: 'A',
        );
        const result2 = QuizAnswerResult(
          isCorrect: true,
          expectedAnswer: 'A',
        );
        const result3 = QuizAnswerResult(
          isCorrect: false,
          expectedAnswer: 'A',
        );
        const result4 = QuizAnswerResult(
          isCorrect: true,
          expectedAnswer: 'B',
        );

        expect(result1, equals(result2));
        expect(result1, isNot(equals(result3)));
        expect(result1, isNot(equals(result4)));
      });

      test('identical returns true', () {
        const result = QuizAnswerResult(
          isCorrect: true,
          expectedAnswer: 'A',
        );
        expect(result == result, isTrue);
      });
    });

    test('hashCode consistent', () {
      const result1 = QuizAnswerResult(
        isCorrect: true,
        expectedAnswer: 'A',
      );
      const result2 = QuizAnswerResult(
        isCorrect: true,
        expectedAnswer: 'A',
      );

      expect(result1.hashCode, equals(result2.hashCode));
    });

    test('toString includes isCorrect and expectedAnswer', () {
      const result = QuizAnswerResult(
        isCorrect: true,
        expectedAnswer: 'The answer',
      );

      final str = result.toString();

      expect(str, contains('true'));
      expect(str, contains('The answer'));
    });
  });
}
