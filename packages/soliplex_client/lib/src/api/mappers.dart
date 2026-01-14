import 'package:soliplex_client/src/domain/quiz.dart';
import 'package:soliplex_client/src/domain/room.dart';
import 'package:soliplex_client/src/domain/run_info.dart';
import 'package:soliplex_client/src/domain/thread_info.dart';

// ============================================================
// Room mappers
// ============================================================

/// Creates a [Room] from JSON.
Room roomFromJson(Map<String, dynamic> json) {
  // Extract quiz IDs from quizzes map (keys are quiz IDs)
  final quizzes = json['quizzes'] as Map<String, dynamic>?;
  final quizIds = quizzes?.keys.toList() ?? const <String>[];

  return Room(
    id: json['id'] as String,
    name: json['name'] as String,
    description: (json['description'] as String?) ?? '',
    metadata: (json['metadata'] as Map<String, dynamic>?) ?? const {},
    quizIds: quizIds,
  );
}

/// Converts a [Room] to JSON.
Map<String, dynamic> roomToJson(Room room) {
  return {
    'id': room.id,
    'name': room.name,
    if (room.description.isNotEmpty) 'description': room.description,
    if (room.metadata.isNotEmpty) 'metadata': room.metadata,
  };
}

// ============================================================
// ThreadInfo mappers
// ============================================================

/// Creates a [ThreadInfo] from JSON.
ThreadInfo threadInfoFromJson(Map<String, dynamic> json) {
  final createdAt = json['created_at'] != null
      ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
      : DateTime.now();
  return ThreadInfo(
    id: json['id'] as String? ?? json['thread_id'] as String,
    roomId: json['room_id'] as String? ?? '',
    initialRunId: (json['initial_run_id'] as String?) ?? '',
    name: (json['name'] as String?) ?? '',
    description: (json['description'] as String?) ?? '',
    createdAt: createdAt,
    updatedAt: json['updated_at'] != null
        ? DateTime.tryParse(json['updated_at'] as String) ?? createdAt
        : createdAt,
    metadata: (json['metadata'] as Map<String, dynamic>?) ?? const {},
  );
}

/// Converts a [ThreadInfo] to JSON.
Map<String, dynamic> threadInfoToJson(ThreadInfo thread) {
  return {
    'id': thread.id,
    'room_id': thread.roomId,
    if (thread.initialRunId.isNotEmpty) 'initial_run_id': thread.initialRunId,
    if (thread.name.isNotEmpty) 'name': thread.name,
    if (thread.description.isNotEmpty) 'description': thread.description,
    'created_at': thread.createdAt.toIso8601String(),
    'updated_at': thread.updatedAt.toIso8601String(),
    if (thread.metadata.isNotEmpty) 'metadata': thread.metadata,
  };
}

// ============================================================
// RunInfo mappers
// ============================================================

/// Creates a [RunInfo] from JSON.
RunInfo runInfoFromJson(Map<String, dynamic> json) {
  return RunInfo(
    id: json['id'] as String? ?? json['run_id'] as String,
    threadId: json['thread_id'] as String? ?? '',
    label: (json['label'] as String?) ?? '',
    createdAt: json['created_at'] != null
        ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
        : DateTime.now(),
    completion: json['completed_at'] != null
        ? CompletedAt(
            DateTime.tryParse(json['completed_at'] as String) ?? DateTime.now(),
          )
        : const NotCompleted(),
    status: runStatusFromString(json['status'] as String?),
    metadata: (json['metadata'] as Map<String, dynamic>?) ?? const {},
  );
}

/// Converts a [RunInfo] to JSON.
Map<String, dynamic> runInfoToJson(RunInfo run) {
  return {
    'id': run.id,
    'thread_id': run.threadId,
    if (run.label.isNotEmpty) 'label': run.label,
    'created_at': run.createdAt.toIso8601String(),
    if (run.completion case CompletedAt(:final time))
      'completed_at': time.toIso8601String(),
    'status': run.status.name,
    if (run.metadata.isNotEmpty) 'metadata': run.metadata,
  };
}

/// Creates a [RunStatus] from a string value.
RunStatus runStatusFromString(String? value) {
  if (value == null) return RunStatus.pending;
  return RunStatus.values.firstWhere(
    (e) => e.name == value.toLowerCase(),
    orElse: () => RunStatus.pending,
  );
}

// ============================================================
// Quiz mappers
// ============================================================

/// Creates a [QuestionType] from JSON metadata.
///
/// Unknown question types fall back to [FreeForm] with a warning logged.
/// This provides graceful degradation when the backend adds new types that
/// the client doesn't yet support - users can still answer via text input.
QuestionType questionTypeFromJson(Map<String, dynamic> json) {
  final type = json['type'] as String;
  return switch (type) {
    'multiple-choice' => MultipleChoice(
        (json['options'] as List<dynamic>).cast<String>(),
      ),
    'fill-blank' => const FillBlank(),
    'qa' => const FreeForm(),
    _ => () {
        // Log warning for observability when backend adds new types.
        // Uses print() since soliplex_client is pure Dart without logging deps.
        // ignore: avoid_print
        print('Warning: Unknown question type "$type", '
            'falling back to FreeForm');
        return const FreeForm();
      }(),
  };
}

/// Creates a [QuizQuestion] from JSON.
///
/// Note: The `expected_output` field from JSON is intentionally not mapped.
/// The correct answer is only revealed after submission via [QuizAnswerResult].
QuizQuestion quizQuestionFromJson(Map<String, dynamic> json) {
  final metadata = json['metadata'] as Map<String, dynamic>;
  return QuizQuestion(
    id: metadata['uuid'] as String,
    text: json['inputs'] as String,
    type: questionTypeFromJson(metadata),
  );
}

/// Creates a [QuestionLimit] from a nullable max_questions value.
QuestionLimit questionLimitFromJson(int? maxQuestions) {
  if (maxQuestions == null) return const AllQuestions();
  return LimitedQuestions(maxQuestions);
}

/// Creates a [Quiz] from JSON.
Quiz quizFromJson(Map<String, dynamic> json) {
  final questions = (json['questions'] as List<dynamic>)
      .map((q) => quizQuestionFromJson(q as Map<String, dynamic>))
      .toList();

  return Quiz(
    id: json['id'] as String,
    title: json['title'] as String,
    randomize: json['randomize'] as bool? ?? false,
    questionLimit: questionLimitFromJson(json['max_questions'] as int?),
    questions: questions,
  );
}

/// Creates a [QuizAnswerResult] from JSON.
QuizAnswerResult quizAnswerResultFromJson(Map<String, dynamic> json) {
  final correct = json['correct'] as String;
  return QuizAnswerResult(
    isCorrect: switch (correct) {
      'true' => true,
      'false' => false,
      _ => throw FormatException('Invalid correct value: $correct'),
    },
    expectedAnswer: json['expected_output'] as String,
  );
}
