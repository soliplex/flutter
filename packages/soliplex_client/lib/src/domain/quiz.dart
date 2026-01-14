import 'package:meta/meta.dart';

// ============================================================
// QuestionLimit - how many questions to show
// ============================================================

/// Limit on how many questions to show from a quiz.
///
/// Use pattern matching for exhaustive handling:
/// ```dart
/// switch (limit) {
///   case AllQuestions():
///     // Show all questions in the quiz
///   case LimitedQuestions(:final count):
///     // Show at most [count] questions
/// }
/// ```
@immutable
sealed class QuestionLimit {
  const QuestionLimit();
}

/// Show all questions in the quiz.
@immutable
final class AllQuestions extends QuestionLimit {
  /// Creates an all-questions limit.
  const AllQuestions();

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is AllQuestions;

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() => 'AllQuestions()';
}

/// Show at most [count] questions from the quiz.
@immutable
final class LimitedQuestions extends QuestionLimit {
  /// Creates a limit with the given [count].
  ///
  /// [count] must be greater than zero.
  const LimitedQuestions(this.count) : assert(count > 0, 'count must be > 0');

  /// Maximum number of questions to show.
  final int count;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LimitedQuestions && count == other.count;

  @override
  int get hashCode => Object.hash(runtimeType, count);

  @override
  String toString() => 'LimitedQuestions($count)';
}

// ============================================================
// QuestionType - type of question with type-specific data
// ============================================================

/// Type of quiz question, with type-specific data.
///
/// Use pattern matching for exhaustive handling:
/// ```dart
/// switch (type) {
///   case MultipleChoice(:final options):
///     // Render radio buttons with [options]
///   case FillBlank():
///     // Render text field for fill-in-the-blank
///   case FreeForm():
///     // Render text field for open-ended answer
/// }
/// ```
@immutable
sealed class QuestionType {
  const QuestionType();
}

/// Multiple choice question with predefined options.
@immutable
final class MultipleChoice extends QuestionType {
  /// Creates a multiple choice type with the given [options].
  ///
  /// The options list is made unmodifiable to preserve immutability.
  MultipleChoice(List<String> options) : options = List.unmodifiable(options);

  /// Available answer options (unmodifiable).
  final List<String> options;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! MultipleChoice) return false;
    if (options.length != other.options.length) return false;
    for (var i = 0; i < options.length; i++) {
      if (options[i] != other.options[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll([runtimeType, ...options]);

  @override
  String toString() => 'MultipleChoice(${options.length} options)';
}

/// Fill-in-the-blank question requiring exact text.
@immutable
final class FillBlank extends QuestionType {
  /// Creates a fill-in-the-blank type.
  const FillBlank();

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is FillBlank;

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() => 'FillBlank()';
}

/// Free-form question allowing open-ended text answer.
@immutable
final class FreeForm extends QuestionType {
  /// Creates a free-form type.
  const FreeForm();

  @override
  bool operator ==(Object other) => identical(this, other) || other is FreeForm;

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() => 'FreeForm()';
}

// ============================================================
// QuizQuestion
// ============================================================

/// A question within a quiz.
///
/// Note: The correct answer is intentionally not included in this model.
/// The backend returns it, but exposing it to UI code would defeat the
/// purpose of a quiz. Users see the correct answer only after submitting
/// via [QuizAnswerResult.expectedAnswer].
@immutable
class QuizQuestion {
  /// Creates a quiz question.
  const QuizQuestion({
    required this.id,
    required this.text,
    required this.type,
  });

  /// Unique identifier for this question (used for answer submission).
  final String id;

  /// The question text displayed to the user.
  final String text;

  /// Type of question with type-specific data.
  final QuestionType type;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is QuizQuestion && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'QuizQuestion(id: $id, type: $type)';
}

// ============================================================
// Quiz
// ============================================================

/// A quiz associated with a room.
@immutable
class Quiz {
  /// Creates a quiz.
  const Quiz({
    required this.id,
    required this.title,
    required this.questions,
    this.randomize = false,
    this.questionLimit = const AllQuestions(),
  });

  /// Unique identifier for this quiz.
  final String id;

  /// Display title of the quiz.
  final String title;

  /// Whether to randomize question order.
  final bool randomize;

  /// Limit on how many questions to show.
  final QuestionLimit questionLimit;

  /// Questions in this quiz.
  final List<QuizQuestion> questions;

  /// Number of questions in this quiz.
  int get questionCount => questions.length;

  /// Whether this quiz has any questions.
  bool get hasQuestions => questions.isNotEmpty;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Quiz && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'Quiz(id: $id, title: $title, ${questions.length} questions)';
}

// ============================================================
// QuizAnswerResult
// ============================================================

/// Result of submitting an answer to a quiz question.
@immutable
class QuizAnswerResult {
  /// Creates an answer result.
  const QuizAnswerResult({
    required this.isCorrect,
    required this.expectedAnswer,
  });

  /// Whether the submitted answer was correct.
  final bool isCorrect;

  /// The expected correct answer.
  final String expectedAnswer;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is QuizAnswerResult &&
        other.isCorrect == isCorrect &&
        other.expectedAnswer == expectedAnswer;
  }

  @override
  int get hashCode => Object.hash(isCorrect, expectedAnswer);

  @override
  String toString() => 'QuizAnswerResult('
      'isCorrect: $isCorrect, expectedAnswer: $expectedAnswer)';
}
