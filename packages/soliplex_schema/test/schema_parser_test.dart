import 'package:soliplex_schema/soliplex_schema.dart';
import 'package:test/test.dart';

void main() {
  late SchemaParser parser;

  setUp(() {
    parser = SchemaParser();
  });

  group('SchemaParser', () {
    test('parses simple object with scalar fields', () {
      final schema = parser.parse({
        'type': 'object',
        'properties': {
          'name': {'type': 'string', 'title': 'Name'},
          'age': {'type': 'integer'},
          'score': {'type': 'number', 'default': 0.9},
          'active': {'type': 'boolean', 'default': true},
        },
        'required': ['name'],
      });

      expect(schema.fields, hasLength(4));

      final name = schema['name']!;
      expect(name.type, FieldType.string);
      expect(name.required, isTrue);

      final age = schema['age']!;
      expect(age.type, FieldType.integer);
      expect(age.required, isFalse);

      final score = schema['score']!;
      expect(score.type, FieldType.number);
      expect(score.defaultValue, 0.9);

      final active = schema['active']!;
      expect(active.type, FieldType.boolean);
      expect(active.defaultValue, true);
    });

    test('parses nullable scalar (anyOf with null)', () {
      final schema = parser.parse({
        'type': 'object',
        'properties': {
          'initial_context': {
            'anyOf': [
              {'type': 'string'},
              {'type': 'null'},
            ],
            'default': null,
            'title': 'Initial Context',
          },
        },
      });

      final field = schema['initial_context']!;
      expect(field.type, FieldType.string);
      expect(field.nullable, isTrue);
    });

    test('parses nullable scalar with format', () {
      final schema = parser.parse({
        'type': 'object',
        'properties': {
          'last_updated': {
            'anyOf': [
              {'format': 'date-time', 'type': 'string'},
              {'type': 'null'},
            ],
            'default': null,
          },
        },
      });

      final field = schema['last_updated']!;
      expect(field.type, FieldType.string);
      expect(field.nullable, isTrue);
      expect(field.format, 'date-time');
    });

    test('parses scalar array', () {
      final schema = parser.parse({
        'type': 'object',
        'properties': {
          'document_filter': {
            'default': <dynamic>[],
            'items': {'type': 'string'},
            'type': 'array',
          },
        },
      });

      final field = schema['document_filter']!;
      expect(field.type, FieldType.array);
      expect(field.itemType, FieldType.string);
      expect(field.itemSchema, isNull);
    });

    test('parses nullable scalar array (anyOf)', () {
      final schema = parser.parse({
        'type': 'object',
        'properties': {
          'headings': {
            'anyOf': [
              {
                'items': {'type': 'string'},
                'type': 'array',
              },
              {'type': 'null'},
            ],
            'default': null,
          },
        },
      });

      final field = schema['headings']!;
      expect(field.type, FieldType.array);
      expect(field.nullable, isTrue);
      expect(field.itemType, FieldType.string);
    });

    test(r'parses object array with $ref', () {
      final schema = parser.parse({
        r'$defs': {
          'Citation': {
            'type': 'object',
            'properties': {
              'document_id': {'type': 'string'},
              'content': {'type': 'string'},
            },
            'required': ['document_id', 'content'],
          },
        },
        'type': 'object',
        'properties': {
          'citations': {
            'default': <dynamic>[],
            'items': {r'$ref': r'#/$defs/Citation'},
            'type': 'array',
          },
        },
      });

      final field = schema['citations']!;
      expect(field.type, FieldType.array);
      expect(field.itemSchema, isNotNull);
      expect(field.itemSchema!.fields, hasLength(2));
      expect(field.itemSchema!['document_id']!.required, isTrue);
    });

    test(r'parses nullable object (anyOf with $ref)', () {
      final schema = parser.parse({
        r'$defs': {
          'SessionContext': {
            'type': 'object',
            'properties': {
              'summary': {
                'default': '',
                'type': 'string',
              },
            },
          },
        },
        'type': 'object',
        'properties': {
          'session_context': {
            'anyOf': [
              {r'$ref': r'#/$defs/SessionContext'},
              {'type': 'null'},
            ],
            'default': null,
          },
        },
      });

      final field = schema['session_context']!;
      expect(field.type, FieldType.object);
      expect(field.nullable, isTrue);
      expect(field.objectSchema, isNotNull);
      expect(field.objectSchema!['summary']!.defaultValue, '');
    });

    test('parses additionalProperties (map)', () {
      final schema = parser.parse({
        'type': 'object',
        'properties': {
          'citation_registry': {
            'additionalProperties': {'type': 'integer'},
            'default': <String, dynamic>{},
            'type': 'object',
          },
        },
      });

      final field = schema['citation_registry']!;
      expect(field.type, FieldType.map);
      expect(field.valueType, FieldType.integer);
    });

    test('parses nested array (array of arrays)', () {
      final schema = parser.parse({
        r'$defs': {
          'Citation': {
            'type': 'object',
            'properties': {
              'content': {'type': 'string'},
            },
          },
        },
        'type': 'object',
        'properties': {
          'citations_history': {
            'default': <dynamic>[],
            'items': {
              'items': {r'$ref': r'#/$defs/Citation'},
              'type': 'array',
            },
            'type': 'array',
          },
        },
      });

      final field = schema['citations_history']!;
      expect(field.type, FieldType.array);
      expect(field.nestedItemSchema, isNotNull);
      expect(field.nestedItemSchema!.type, FieldType.array);
      expect(field.nestedItemSchema!.itemSchema, isNotNull);
    });

    test('parses title and description', () {
      final schema = parser.parse({
        'type': 'object',
        'title': 'ChatSessionState',
        'description': 'State shared between frontend and agent.',
        'properties': {
          'field': {'type': 'string', 'title': 'Field Title'},
        },
      });

      expect(schema.title, 'ChatSessionState');
      expect(schema.description, 'State shared between frontend and agent.');
      expect(schema['field']!.title, 'Field Title');
    });

    test('handles empty schema gracefully', () {
      final schema = parser.parse({});
      expect(schema.fields, isEmpty);
    });

    test('handles missing properties gracefully', () {
      final schema = parser.parse({'type': 'object'});
      expect(schema.fields, isEmpty);
    });
  });

  group('SchemaParser with real schema', () {
    test('parses haiku.rag.chat from schema.json', () {
      final schema = parser.parse(_haikuRagChatSchema);

      expect(schema.title, 'ChatSessionState');
      expect(schema.fields, hasLength(7));

      // initial_context: nullable string
      expect(schema['initial_context']!.type, FieldType.string);
      expect(schema['initial_context']!.nullable, isTrue);

      // citations: array of Citation objects
      expect(schema['citations']!.type, FieldType.array);
      expect(schema['citations']!.itemSchema, isNotNull);
      expect(
        schema['citations']!.itemSchema!.fields,
        hasLength(8),
      );

      // citations_history: array of arrays of Citations
      expect(schema['citations_history']!.type, FieldType.array);
      expect(
        schema['citations_history']!.nestedItemSchema,
        isNotNull,
      );

      // qa_history: array of QAHistoryEntry objects
      expect(schema['qa_history']!.type, FieldType.array);
      expect(schema['qa_history']!.itemSchema, isNotNull);
      expect(
        schema['qa_history']!.itemSchema!['question']!.required,
        isTrue,
      );

      // session_context: nullable SessionContext object
      expect(schema['session_context']!.type, FieldType.object);
      expect(schema['session_context']!.nullable, isTrue);
      expect(schema['session_context']!.objectSchema, isNotNull);

      // document_filter: array of strings
      expect(schema['document_filter']!.type, FieldType.array);
      expect(schema['document_filter']!.itemType, FieldType.string);

      // citation_registry: map<string, int>
      expect(schema['citation_registry']!.type, FieldType.map);
      expect(
        schema['citation_registry']!.valueType,
        FieldType.integer,
      );
    });
  });
}

/// The haiku.rag.chat schema from schemas/schema.json.
const _haikuRagChatSchema = <String, dynamic>{
  r'$defs': {
    'Citation': {
      'description': 'Resolved citation with full metadata.',
      'properties': {
        'index': {
          'anyOf': [
            {'type': 'integer'},
            {'type': 'null'},
          ],
          'default': null,
          'title': 'Index',
        },
        'document_id': {'title': 'Document Id', 'type': 'string'},
        'chunk_id': {'title': 'Chunk Id', 'type': 'string'},
        'document_uri': {'title': 'Document Uri', 'type': 'string'},
        'document_title': {
          'anyOf': [
            {'type': 'string'},
            {'type': 'null'},
          ],
          'default': null,
          'title': 'Document Title',
        },
        'page_numbers': {
          'items': {'type': 'integer'},
          'title': 'Page Numbers',
          'type': 'array',
        },
        'headings': {
          'anyOf': [
            {
              'items': {'type': 'string'},
              'type': 'array',
            },
            {'type': 'null'},
          ],
          'default': null,
          'title': 'Headings',
        },
        'content': {'title': 'Content', 'type': 'string'},
      },
      'required': ['document_id', 'chunk_id', 'document_uri', 'content'],
      'title': 'Citation',
      'type': 'object',
    },
    'QAHistoryEntry': {
      'description': 'A Q&A pair.',
      'properties': {
        'question': {'title': 'Question', 'type': 'string'},
        'answer': {'title': 'Answer', 'type': 'string'},
        'confidence': {
          'default': 0.9,
          'title': 'Confidence',
          'type': 'number',
        },
        'citations': {
          'default': <dynamic>[],
          'items': {r'$ref': r'#/$defs/Citation'},
          'title': 'Citations',
          'type': 'array',
        },
        'question_embedding': {
          'anyOf': [
            {
              'items': {'type': 'number'},
              'type': 'array',
            },
            {'type': 'null'},
          ],
          'default': null,
          'title': 'Question Embedding',
        },
      },
      'required': ['question', 'answer'],
      'title': 'QAHistoryEntry',
      'type': 'object',
    },
    'SessionContext': {
      'description': 'Compressed summary.',
      'properties': {
        'summary': {
          'default': '',
          'title': 'Summary',
          'type': 'string',
        },
        'last_updated': {
          'anyOf': [
            {'format': 'date-time', 'type': 'string'},
            {'type': 'null'},
          ],
          'default': null,
          'title': 'Last Updated',
        },
      },
      'title': 'SessionContext',
      'type': 'object',
    },
  },
  'description': 'State shared between frontend and agent via AG-UI.',
  'properties': {
    'initial_context': {
      'anyOf': [
        {'type': 'string'},
        {'type': 'null'},
      ],
      'default': null,
      'title': 'Initial Context',
    },
    'citations': {
      'default': <dynamic>[],
      'items': {r'$ref': r'#/$defs/Citation'},
      'title': 'Citations',
      'type': 'array',
    },
    'citations_history': {
      'default': <dynamic>[],
      'items': {
        'items': {r'$ref': r'#/$defs/Citation'},
        'type': 'array',
      },
      'title': 'Citations History',
      'type': 'array',
    },
    'qa_history': {
      'default': <dynamic>[],
      'items': {r'$ref': r'#/$defs/QAHistoryEntry'},
      'title': 'Qa History',
      'type': 'array',
    },
    'session_context': {
      'anyOf': [
        {r'$ref': r'#/$defs/SessionContext'},
        {'type': 'null'},
      ],
      'default': null,
    },
    'document_filter': {
      'default': <dynamic>[],
      'items': {'type': 'string'},
      'title': 'Document Filter',
      'type': 'array',
    },
    'citation_registry': {
      'additionalProperties': {'type': 'integer'},
      'default': <String, dynamic>{},
      'title': 'Citation Registry',
      'type': 'object',
    },
  },
  'title': 'ChatSessionState',
  'type': 'object',
};
