import 'package:soliplex_client/src/api/mappers.dart';
import 'package:soliplex_client/src/domain/quiz.dart';
import 'package:soliplex_client/src/domain/rag_document.dart';
import 'package:soliplex_client/src/domain/room.dart';
import 'package:soliplex_client/src/domain/run_info.dart';
import 'package:soliplex_client/src/domain/thread_info.dart';
import 'package:test/test.dart';

void main() {
  group('BackendVersionInfo mappers', () {
    group('backendVersionInfoFromJson', () {
      test('parses correctly with all fields', () {
        final json = <String, dynamic>{
          'soliplex': {
            'version': '0.36.dev0',
            'editable_project_location': '/path',
          },
          'fastapi': {'version': '0.124.0'},
          'pydantic': {'version': '2.12.5'},
        };

        final info = backendVersionInfoFromJson(json);

        expect(info.soliplexVersion, equals('0.36.dev0'));
        expect(info.packageVersions, hasLength(3));
        expect(info.packageVersions['soliplex'], equals('0.36.dev0'));
        expect(info.packageVersions['fastapi'], equals('0.124.0'));
        expect(info.packageVersions['pydantic'], equals('2.12.5'));
      });

      test('returns Unknown when soliplex key is missing', () {
        final json = <String, dynamic>{
          'fastapi': {'version': '0.124.0'},
        };

        final info = backendVersionInfoFromJson(json);

        expect(info.soliplexVersion, equals('Unknown'));
        expect(info.packageVersions['fastapi'], equals('0.124.0'));
      });

      test('returns Unknown when soliplex version is null', () {
        final json = <String, dynamic>{
          'soliplex': {'version': null},
        };

        final info = backendVersionInfoFromJson(json);

        expect(info.soliplexVersion, equals('Unknown'));
      });

      test('handles empty response', () {
        final json = <String, dynamic>{};

        final info = backendVersionInfoFromJson(json);

        expect(info.soliplexVersion, equals('Unknown'));
        expect(info.packageVersions, isEmpty);
      });

      test('skips entries without version field', () {
        final json = <String, dynamic>{
          'soliplex': {'version': '0.36.dev0'},
          'invalid': {'no_version': 'here'},
          'also_invalid': 'not a map',
        };

        final info = backendVersionInfoFromJson(json);

        expect(info.packageVersions, hasLength(1));
        expect(info.packageVersions.containsKey('invalid'), isFalse);
        expect(info.packageVersions.containsKey('also_invalid'), isFalse);
      });
    });
  });

  group('Room mappers', () {
    group('roomFromJson', () {
      test('parses correctly with all fields', () {
        final json = <String, dynamic>{
          'id': 'room-1',
          'name': 'Test Room',
          'description': 'A test room',
          'metadata': {'key': 'value'},
        };

        final room = roomFromJson(json);

        expect(room.id, equals('room-1'));
        expect(room.name, equals('Test Room'));
        expect(room.description, equals('A test room'));
        expect(room.metadata, equals({'key': 'value'}));
      });

      test('parses correctly with only required fields', () {
        final json = <String, dynamic>{'id': 'room-1', 'name': 'Test Room'};

        final room = roomFromJson(json);

        expect(room.id, equals('room-1'));
        expect(room.name, equals('Test Room'));
        expect(room.description, equals(''));
        expect(room.metadata, equals(const <String, dynamic>{}));
      });

      test('handles null description', () {
        final json = <String, dynamic>{
          'id': 'room-1',
          'name': 'Test Room',
          'description': null,
        };

        final room = roomFromJson(json);

        expect(room.description, equals(''));
      });

      test('handles null metadata', () {
        final json = <String, dynamic>{
          'id': 'room-1',
          'name': 'Test Room',
          'metadata': null,
        };

        final room = roomFromJson(json);

        expect(room.metadata, equals(const <String, dynamic>{}));
      });

      test('parses suggestions correctly', () {
        final json = <String, dynamic>{
          'id': 'room-1',
          'name': 'Test Room',
          'suggestions': ['How can I help?', 'Tell me more'],
        };

        final room = roomFromJson(json);

        expect(room.suggestions, equals(['How can I help?', 'Tell me more']));
        expect(room.hasSuggestions, isTrue);
      });

      test('handles missing suggestions field', () {
        final json = <String, dynamic>{'id': 'room-1', 'name': 'Test Room'};

        final room = roomFromJson(json);

        expect(room.suggestions, isEmpty);
        expect(room.hasSuggestions, isFalse);
      });

      test('handles null suggestions', () {
        final json = <String, dynamic>{
          'id': 'room-1',
          'name': 'Test Room',
          'suggestions': null,
        };

        final room = roomFromJson(json);

        expect(room.suggestions, isEmpty);
        expect(room.hasSuggestions, isFalse);
      });

      test('filters out non-string suggestions', () {
        final json = <String, dynamic>{
          'id': 'room-1',
          'name': 'Test Room',
          'suggestions': ['Valid', 123, null, 'Also valid', true],
        };

        final room = roomFromJson(json);

        expect(room.suggestions, equals(['Valid', 'Also valid']));
      });
    });

    group('roomToJson', () {
      test('serializes correctly with all fields', () {
        const room = Room(
          id: 'room-1',
          name: 'Test Room',
          description: 'A test room',
          metadata: {'key': 'value'},
        );

        final json = roomToJson(room);

        expect(json['id'], equals('room-1'));
        expect(json['name'], equals('Test Room'));
        expect(json['description'], equals('A test room'));
        expect(json['metadata'], equals({'key': 'value'}));
      });

      test('excludes empty fields', () {
        const room = Room(id: 'room-1', name: 'Test Room');

        final json = roomToJson(room);

        expect(json.containsKey('id'), isTrue);
        expect(json.containsKey('name'), isTrue);
        expect(json.containsKey('description'), isFalse);
        expect(json.containsKey('metadata'), isFalse);
      });
    });

    test('roundtrip serialization', () {
      const original = Room(
        id: 'room-1',
        name: 'Test Room',
        description: 'A test room',
        metadata: {'key': 'value'},
      );

      final json = roomToJson(original);
      final restored = roomFromJson(json);

      expect(restored.id, equals(original.id));
      expect(restored.name, equals(original.name));
      expect(restored.description, equals(original.description));
      expect(restored.metadata, equals(original.metadata));
    });
  });

  group('RagDocument mappers', () {
    group('ragDocumentFromJson', () {
      test('parses correctly with all fields', () {
        final json = <String, dynamic>{
          'id': 'doc-uuid-123',
          'title': 'User Manual.pdf',
        };

        final doc = ragDocumentFromJson(json);

        expect(doc.id, equals('doc-uuid-123'));
        expect(doc.title, equals('User Manual.pdf'));
      });

      test('falls back to uri when title is null', () {
        final json = <String, dynamic>{
          'id': 'doc-uuid-123',
          'title': null,
          'uri': 'file:///docs/manual.pdf',
        };

        final doc = ragDocumentFromJson(json);

        expect(doc.id, equals('doc-uuid-123'));
        expect(doc.title, equals('file:///docs/manual.pdf'));
      });

      test('falls back to Untitled when title and uri are null', () {
        final json = <String, dynamic>{
          'id': 'doc-uuid-123',
          'title': null,
          'uri': null,
        };

        final doc = ragDocumentFromJson(json);

        expect(doc.id, equals('doc-uuid-123'));
        expect(doc.title, equals('Untitled'));
      });
    });

    group('ragDocumentToJson', () {
      test('serializes correctly', () {
        const doc = RagDocument(
          id: 'doc-uuid-123',
          title: 'User Manual.pdf',
        );

        final json = ragDocumentToJson(doc);

        expect(json['id'], equals('doc-uuid-123'));
        expect(json['title'], equals('User Manual.pdf'));
      });
    });

    test('roundtrip serialization', () {
      const original = RagDocument(
        id: 'doc-uuid-123',
        title: 'User Manual.pdf',
      );

      final json = ragDocumentToJson(original);
      final restored = ragDocumentFromJson(json);

      expect(restored.id, equals(original.id));
      expect(restored.title, equals(original.title));
    });
  });

  group('ThreadInfo mappers', () {
    group('threadInfoFromJson', () {
      test('parses correctly with all fields', () {
        final json = <String, dynamic>{
          'id': 'thread-1',
          'room_id': 'room-1',
          'initial_run_id': 'run-1',
          'name': 'Test Thread',
          'description': 'A test thread',
          'created_at': '2025-01-01T00:00:00.000Z',
          'updated_at': '2025-01-02T00:00:00.000Z',
          'metadata': {'key': 'value'},
        };

        final thread = threadInfoFromJson(json);

        expect(thread.id, equals('thread-1'));
        expect(thread.roomId, equals('room-1'));
        expect(thread.initialRunId, equals('run-1'));
        expect(thread.name, equals('Test Thread'));
        expect(thread.description, equals('A test thread'));
        expect(thread.createdAt, isNotNull);
        expect(thread.updatedAt, isNotNull);
        expect(thread.metadata, equals({'key': 'value'}));
      });

      test('parses correctly with only required fields', () {
        final json = <String, dynamic>{'id': 'thread-1', 'room_id': 'room-1'};

        final thread = threadInfoFromJson(json);

        expect(thread.id, equals('thread-1'));
        expect(thread.roomId, equals('room-1'));
        expect(thread.initialRunId, equals(''));
        expect(thread.name, equals(''));
        expect(thread.description, equals(''));
        expect(thread.createdAt, isNotNull);
        expect(thread.updatedAt, isNotNull);
        expect(thread.metadata, equals(const <String, dynamic>{}));
      });

      test('handles thread_id field', () {
        final json = <String, dynamic>{
          'thread_id': 'thread-1',
          'room_id': 'room-1',
        };

        final thread = threadInfoFromJson(json);

        expect(thread.id, equals('thread-1'));
      });

      test('handles missing room_id', () {
        final json = <String, dynamic>{'id': 'thread-1'};

        final thread = threadInfoFromJson(json);

        expect(thread.roomId, equals(''));
      });

      test('throws FormatException for invalid created_at DateTime', () {
        final json = <String, dynamic>{
          'id': 'thread-1',
          'room_id': 'room-1',
          'created_at': 'invalid-date',
        };

        expect(() => threadInfoFromJson(json), throwsFormatException);
      });

      test('throws FormatException for invalid updated_at DateTime', () {
        final json = <String, dynamic>{
          'id': 'thread-1',
          'room_id': 'room-1',
          'created_at': '2025-01-01T00:00:00.000Z',
          'updated_at': 'invalid-date',
        };

        expect(() => threadInfoFromJson(json), throwsFormatException);
      });

      test('handles null optional fields', () {
        final json = <String, dynamic>{
          'id': 'thread-1',
          'room_id': 'room-1',
          'initial_run_id': null,
          'name': null,
          'description': null,
          'metadata': null,
        };

        final thread = threadInfoFromJson(json);

        expect(thread.initialRunId, equals(''));
        expect(thread.name, equals(''));
        expect(thread.description, equals(''));
        expect(thread.metadata, equals(const <String, dynamic>{}));
      });
    });

    group('threadInfoToJson', () {
      test('serializes correctly with all fields', () {
        final createdAt = DateTime.utc(2025);
        final updatedAt = DateTime.utc(2025, 1, 2);
        final thread = ThreadInfo(
          id: 'thread-1',
          roomId: 'room-1',
          initialRunId: 'run-1',
          name: 'Test Thread',
          description: 'A test thread',
          createdAt: createdAt,
          updatedAt: updatedAt,
          metadata: const {'key': 'value'},
        );

        final json = threadInfoToJson(thread);

        expect(json['id'], equals('thread-1'));
        expect(json['room_id'], equals('room-1'));
        expect(json['initial_run_id'], equals('run-1'));
        expect(json['name'], equals('Test Thread'));
        expect(json['description'], equals('A test thread'));
        expect(json['created_at'], equals('2025-01-01T00:00:00.000Z'));
        expect(json['updated_at'], equals('2025-01-02T00:00:00.000Z'));
        expect(json['metadata'], equals({'key': 'value'}));
      });

      test('excludes empty fields', () {
        final thread = ThreadInfo(
          id: 'thread-1',
          roomId: 'room-1',
          createdAt: DateTime.utc(2025),
          updatedAt: DateTime.utc(2025),
        );

        final json = threadInfoToJson(thread);

        expect(json.containsKey('id'), isTrue);
        expect(json.containsKey('room_id'), isTrue);
        expect(json.containsKey('created_at'), isTrue);
        expect(json.containsKey('updated_at'), isTrue);
        expect(json.containsKey('initial_run_id'), isFalse);
        expect(json.containsKey('name'), isFalse);
        expect(json.containsKey('description'), isFalse);
        expect(json.containsKey('metadata'), isFalse);
      });
    });

    test('roundtrip serialization', () {
      final createdAt = DateTime.utc(2025);
      final updatedAt = DateTime.utc(2025, 1, 2);
      final original = ThreadInfo(
        id: 'thread-1',
        roomId: 'room-1',
        initialRunId: 'run-1',
        name: 'Test Thread',
        description: 'A test thread',
        createdAt: createdAt,
        updatedAt: updatedAt,
        metadata: const {'key': 'value'},
      );

      final json = threadInfoToJson(original);
      final restored = threadInfoFromJson(json);

      expect(restored.id, equals(original.id));
      expect(restored.roomId, equals(original.roomId));
      expect(restored.initialRunId, equals(original.initialRunId));
      expect(restored.name, equals(original.name));
      expect(restored.description, equals(original.description));
      expect(restored.createdAt, equals(original.createdAt));
      expect(restored.updatedAt, equals(original.updatedAt));
      expect(restored.metadata, equals(original.metadata));
    });
  });

  group('RunInfo mappers', () {
    group('runInfoFromJson', () {
      test('parses correctly with all fields', () {
        final json = <String, dynamic>{
          'id': 'run-1',
          'thread_id': 'thread-1',
          'label': 'Test Run',
          'created_at': '2025-01-01T00:00:00.000Z',
          'completed_at': '2025-01-02T00:00:00.000Z',
          'status': 'completed',
          'metadata': {'key': 'value'},
        };

        final run = runInfoFromJson(json);

        expect(run.id, equals('run-1'));
        expect(run.threadId, equals('thread-1'));
        expect(run.label, equals('Test Run'));
        expect(run.createdAt, isNotNull);
        expect(run.completion, isA<CompletedAt>());
        expect(run.status, equals(RunStatus.completed));
        expect(run.metadata, equals({'key': 'value'}));
      });

      test('parses correctly with only required fields', () {
        final json = <String, dynamic>{'id': 'run-1', 'thread_id': 'thread-1'};

        final run = runInfoFromJson(json);

        expect(run.id, equals('run-1'));
        expect(run.threadId, equals('thread-1'));
        expect(run.label, equals(''));
        expect(run.createdAt, isNotNull);
        expect(run.completion, isA<NotCompleted>());
        expect(run.status, equals(RunStatus.pending));
        expect(run.metadata, equals(const <String, dynamic>{}));
      });

      test('handles run_id field', () {
        final json = <String, dynamic>{
          'run_id': 'run-1',
          'thread_id': 'thread-1',
        };

        final run = runInfoFromJson(json);

        expect(run.id, equals('run-1'));
      });

      test('handles missing thread_id', () {
        final json = <String, dynamic>{'id': 'run-1'};

        final run = runInfoFromJson(json);

        expect(run.threadId, equals(''));
      });

      test('throws FormatException for invalid completed_at DateTime', () {
        final json = <String, dynamic>{
          'id': 'run-1',
          'thread_id': 'thread-1',
          'completed_at': 'invalid-date',
        };

        expect(() => runInfoFromJson(json), throwsFormatException);
      });

      test('throws FormatException for invalid created_at DateTime', () {
        final json = <String, dynamic>{
          'id': 'run-1',
          'thread_id': 'thread-1',
          'created_at': 'invalid-date',
        };

        expect(() => runInfoFromJson(json), throwsFormatException);
      });

      test('handles null label', () {
        final json = <String, dynamic>{
          'id': 'run-1',
          'thread_id': 'thread-1',
          'label': null,
        };

        final run = runInfoFromJson(json);

        expect(run.label, equals(''));
      });

      test('handles null metadata', () {
        final json = <String, dynamic>{
          'id': 'run-1',
          'thread_id': 'thread-1',
          'metadata': null,
        };

        final run = runInfoFromJson(json);

        expect(run.metadata, equals(const <String, dynamic>{}));
      });
    });

    group('runInfoToJson', () {
      test('serializes correctly with all fields', () {
        final createdAt = DateTime.utc(2025);
        final completedAt = DateTime.utc(2025, 1, 2);
        final run = RunInfo(
          id: 'run-1',
          threadId: 'thread-1',
          label: 'Test Run',
          createdAt: createdAt,
          completion: CompletedAt(completedAt),
          status: RunStatus.completed,
          metadata: const {'key': 'value'},
        );

        final json = runInfoToJson(run);

        expect(json['id'], equals('run-1'));
        expect(json['thread_id'], equals('thread-1'));
        expect(json['label'], equals('Test Run'));
        expect(json['created_at'], equals('2025-01-01T00:00:00.000Z'));
        expect(json['completed_at'], equals('2025-01-02T00:00:00.000Z'));
        expect(json['status'], equals('completed'));
        expect(json['metadata'], equals({'key': 'value'}));
      });

      test('excludes empty fields', () {
        final run = RunInfo(
          id: 'run-1',
          threadId: 'thread-1',
          createdAt: DateTime.utc(2025),
        );

        final json = runInfoToJson(run);

        expect(json.containsKey('id'), isTrue);
        expect(json.containsKey('thread_id'), isTrue);
        expect(json.containsKey('created_at'), isTrue);
        expect(json.containsKey('status'), isTrue);
        expect(json.containsKey('label'), isFalse);
        expect(json.containsKey('completed_at'), isFalse);
        expect(json.containsKey('metadata'), isFalse);
      });
    });

    test('roundtrip serialization', () {
      final createdAt = DateTime.utc(2025);
      final completedAt = DateTime.utc(2025, 1, 2);
      final original = RunInfo(
        id: 'run-1',
        threadId: 'thread-1',
        label: 'Test Run',
        createdAt: createdAt,
        completion: CompletedAt(completedAt),
        status: RunStatus.completed,
        metadata: const {'key': 'value'},
      );

      final json = runInfoToJson(original);
      final restored = runInfoFromJson(json);

      expect(restored.id, equals(original.id));
      expect(restored.threadId, equals(original.threadId));
      expect(restored.label, equals(original.label));
      expect(restored.createdAt, equals(original.createdAt));
      expect(restored.isCompleted, equals(original.isCompleted));
      expect(restored.status, equals(original.status));
      expect(restored.metadata, equals(original.metadata));
    });
  });

  group('runStatusFromString', () {
    test('parses valid status strings', () {
      expect(runStatusFromString('pending'), equals(RunStatus.pending));
      expect(runStatusFromString('running'), equals(RunStatus.running));
      expect(runStatusFromString('completed'), equals(RunStatus.completed));
      expect(runStatusFromString('failed'), equals(RunStatus.failed));
      expect(runStatusFromString('cancelled'), equals(RunStatus.cancelled));
    });

    test('handles uppercase status strings', () {
      expect(runStatusFromString('PENDING'), equals(RunStatus.pending));
      expect(runStatusFromString('Running'), equals(RunStatus.running));
      expect(runStatusFromString('COMPLETED'), equals(RunStatus.completed));
    });

    test('returns pending for null', () {
      expect(runStatusFromString(null), equals(RunStatus.pending));
    });

    test('returns unknown for unrecognized status', () {
      // 'unknown' is now a valid enum value, so it maps to itself
      expect(runStatusFromString('unknown'), equals(RunStatus.unknown));
      // Truly unrecognized values also map to unknown
      expect(runStatusFromString('invalid'), equals(RunStatus.unknown));
      expect(runStatusFromString('foobar'), equals(RunStatus.unknown));
    });
  });

  group('Quiz mappers', () {
    group('questionTypeFromJson', () {
      test('parses multiple-choice with options', () {
        final json = <String, dynamic>{
          'type': 'multiple-choice',
          'uuid': 'q-1',
          'options': ['A', 'B', 'C', 'D'],
        };

        final type = questionTypeFromJson(json);

        expect(type, isA<MultipleChoice>());
        expect((type as MultipleChoice).options, equals(['A', 'B', 'C', 'D']));
      });

      test('parses fill-blank', () {
        final json = <String, dynamic>{'type': 'fill-blank', 'uuid': 'q-1'};

        final type = questionTypeFromJson(json);

        expect(type, isA<FillBlank>());
      });

      test('parses qa as FreeForm', () {
        final json = <String, dynamic>{'type': 'qa', 'uuid': 'q-1'};

        final type = questionTypeFromJson(json);

        expect(type, isA<FreeForm>());
      });

      test('defaults unknown type to FreeForm', () {
        final json = <String, dynamic>{'type': 'unknown-type', 'uuid': 'q-1'};

        final type = questionTypeFromJson(json);

        expect(type, isA<FreeForm>());
      });
    });

    group('quizQuestionFromJson', () {
      test('parses question with multiple-choice', () {
        final json = <String, dynamic>{
          'inputs': 'What is the capital of France?',
          'expected_output': 'Paris',
          'metadata': {
            'type': 'multiple-choice',
            'uuid': 'q-123',
            'options': ['London', 'Paris', 'Berlin', 'Madrid'],
          },
        };

        final question = quizQuestionFromJson(json);

        expect(question.id, equals('q-123'));
        expect(question.text, equals('What is the capital of France?'));
        // Note: answer is intentionally not exposed in QuizQuestion
        expect(question.type, isA<MultipleChoice>());
        final options = (question.type as MultipleChoice).options;
        expect(options, equals(['London', 'Paris', 'Berlin', 'Madrid']));
      });

      test('parses question with fill-blank', () {
        final json = <String, dynamic>{
          'inputs': 'The sky is ____.',
          'expected_output': 'blue',
          'metadata': {'type': 'fill-blank', 'uuid': 'q-456'},
        };

        final question = quizQuestionFromJson(json);

        expect(question.id, equals('q-456'));
        expect(question.text, equals('The sky is ____.'));
        expect(question.type, isA<FillBlank>());
      });

      test('parses question with qa (free-form)', () {
        final json = <String, dynamic>{
          'inputs': 'Explain photosynthesis.',
          'expected_output': 'Process by which plants convert sunlight.',
          'metadata': {'type': 'qa', 'uuid': 'q-789'},
        };

        final question = quizQuestionFromJson(json);

        expect(question.id, equals('q-789'));
        expect(question.text, equals('Explain photosynthesis.'));
        expect(question.type, isA<FreeForm>());
      });
    });

    group('questionLimitFromJson', () {
      test('returns AllQuestions for null', () {
        final limit = questionLimitFromJson(null);

        expect(limit, isA<AllQuestions>());
      });

      test('returns LimitedQuestions for positive int', () {
        final limit = questionLimitFromJson(5);

        expect(limit, isA<LimitedQuestions>());
        expect((limit as LimitedQuestions).count, equals(5));
      });
    });

    group('quizFromJson', () {
      test('parses quiz with all fields', () {
        final json = <String, dynamic>{
          'id': 'quiz-1',
          'title': 'Geography Quiz',
          'randomize': true,
          'max_questions': 3,
          'questions': [
            {
              'inputs': 'What is the capital of France?',
              'expected_output': 'Paris',
              'metadata': {
                'type': 'multiple-choice',
                'uuid': 'q-1',
                'options': ['London', 'Paris', 'Berlin'],
              },
            },
            {
              'inputs': 'The largest ocean is ____.',
              'expected_output': 'Pacific',
              'metadata': {'type': 'fill-blank', 'uuid': 'q-2'},
            },
          ],
        };

        final quiz = quizFromJson(json);

        expect(quiz.id, equals('quiz-1'));
        expect(quiz.title, equals('Geography Quiz'));
        expect(quiz.randomize, isTrue);
        expect(quiz.questionLimit, isA<LimitedQuestions>());
        expect((quiz.questionLimit as LimitedQuestions).count, equals(3));
        expect(quiz.questions, hasLength(2));
        expect(quiz.questions[0].id, equals('q-1'));
        expect(quiz.questions[1].id, equals('q-2'));
      });

      test('parses quiz with minimal fields', () {
        final json = <String, dynamic>{
          'id': 'quiz-2',
          'title': 'Simple Quiz',
          'questions': <Map<String, dynamic>>[],
        };

        final quiz = quizFromJson(json);

        expect(quiz.id, equals('quiz-2'));
        expect(quiz.title, equals('Simple Quiz'));
        expect(quiz.randomize, isFalse);
        expect(quiz.questionLimit, isA<AllQuestions>());
        expect(quiz.questions, isEmpty);
      });

      test('handles null randomize', () {
        final json = <String, dynamic>{
          'id': 'quiz-3',
          'title': 'Quiz',
          'randomize': null,
          'questions': <Map<String, dynamic>>[],
        };

        final quiz = quizFromJson(json);

        expect(quiz.randomize, isFalse);
      });
    });

    group('quizAnswerResultFromJson', () {
      test('parses correct answer', () {
        final json = <String, dynamic>{
          'correct': 'true',
          'expected_output': 'The correct answer',
        };

        final result = quizAnswerResultFromJson(json);

        expect(result, isA<CorrectAnswer>());
        expect(result.isCorrect, isTrue);
      });

      test('parses incorrect answer', () {
        final json = <String, dynamic>{
          'correct': 'false',
          'expected_output': 'The correct answer',
        };

        final result = quizAnswerResultFromJson(json);

        expect(result, isA<IncorrectAnswer>());
        expect(result.isCorrect, isFalse);
        expect(
          (result as IncorrectAnswer).expectedAnswer,
          equals('The correct answer'),
        );
      });

      test('handles missing expected_output for incorrect answer', () {
        final json = <String, dynamic>{
          'correct': 'false',
        };

        final result = quizAnswerResultFromJson(json);

        expect(result, isA<IncorrectAnswer>());
        expect(
          (result as IncorrectAnswer).expectedAnswer,
          equals('(correct answer not provided)'),
        );
      });

      test('throws on invalid correct value', () {
        final json = <String, dynamic>{
          'correct': 'maybe',
          'expected_output': 'Answer',
        };

        expect(
          () => quizAnswerResultFromJson(json),
          throwsA(isA<FormatException>()),
        );
      });
    });

    group('roomFromJson with quizIds', () {
      test('extracts quiz IDs from quizzes map', () {
        final json = <String, dynamic>{
          'id': 'room-1',
          'name': 'Test Room',
          'quizzes': {
            'quiz-1': {'id': 'quiz-1', 'title': 'Quiz 1'},
            'quiz-2': {'id': 'quiz-2', 'title': 'Quiz 2'},
          },
        };

        final room = roomFromJson(json);

        expect(room.quizIds, containsAll(['quiz-1', 'quiz-2']));
        expect(room.hasQuizzes, isTrue);
      });

      test('handles missing quizzes field', () {
        final json = <String, dynamic>{'id': 'room-1', 'name': 'Test Room'};

        final room = roomFromJson(json);

        expect(room.quizIds, isEmpty);
        expect(room.hasQuizzes, isFalse);
      });

      test('handles null quizzes field', () {
        final json = <String, dynamic>{
          'id': 'room-1',
          'name': 'Test Room',
          'quizzes': null,
        };

        final room = roomFromJson(json);

        expect(room.quizIds, isEmpty);
        expect(room.hasQuizzes, isFalse);
      });

      test('handles empty quizzes map', () {
        final json = <String, dynamic>{
          'id': 'room-1',
          'name': 'Test Room',
          'quizzes': <String, dynamic>{},
        };

        final room = roomFromJson(json);

        expect(room.quizIds, isEmpty);
        expect(room.hasQuizzes, isFalse);
      });
    });
  });
}
