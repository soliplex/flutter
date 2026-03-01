import 'package:soliplex_schema/soliplex_schema.dart';
import 'package:test/test.dart';

void main() {
  late SchemaParser parser;

  setUp(() {
    parser = SchemaParser();
  });

  group('SchemaStateView', () {
    group('scalars', () {
      late ObjectSchema schema;

      setUp(() {
        schema = parser.parse({
          'type': 'object',
          'properties': {
            'name': {'type': 'string'},
            'count': {'type': 'integer', 'default': 0},
            'score': {'type': 'number', 'default': 0.9},
            'active': {'type': 'boolean', 'default': true},
            'nullable_name': {
              'anyOf': [
                {'type': 'string'},
                {'type': 'null'},
              ],
              'default': null,
            },
          },
          'required': ['name'],
        });
      });

      test('returns value when present', () {
        final view = SchemaStateView(
          const {'name': 'test', 'count': 5, 'score': 1.5, 'active': false},
          schema,
        );

        expect(view.getScalar<String>('name'), 'test');
        expect(view.getScalar<int>('count'), 5);
        expect(view.getScalar<double>('score'), 1.5);
        expect(view.getScalar<bool>('active'), isFalse);
      });

      test('returns schema default when absent', () {
        final view = SchemaStateView(const {'name': 'test'}, schema);

        expect(view.getScalar<int>('count'), 0);
        expect(view.getScalar<double>('score'), 0.9);
        expect(view.getScalar<bool>('active'), isTrue);
      });

      test('returns null when absent with no default', () {
        final view = SchemaStateView(const {}, schema);
        expect(view.getScalar<String>('name'), isNull);
      });

      test('returns null for nullable absent field', () {
        final view = SchemaStateView(const {}, schema);
        expect(view.getScalar<String>('nullable_name'), isNull);
      });

      test('coerces num to int', () {
        final view = SchemaStateView(const {'count': 5.0}, schema);
        expect(view.getScalar<int>('count'), 5);
      });

      test('coerces num to double', () {
        final view = SchemaStateView(const {'score': 2}, schema);
        expect(view.getScalar<double>('score'), 2.0);
      });

      test('coerces string to int via tryParse', () {
        final view = SchemaStateView(const {'count': '42'}, schema);
        expect(view.getScalar<int>('count'), 42);
      });

      test('returns null for non-parseable string', () {
        final view = SchemaStateView(const {'count': 'not-a-number'}, schema);
        expect(view.getScalar<int>('count'), isNull);
      });
    });

    group('objects', () {
      late ObjectSchema schema;

      setUp(() {
        schema = parser.parse({
          r'$defs': {
            'Inner': {
              'type': 'object',
              'properties': {
                'value': {'type': 'string', 'default': ''},
              },
            },
          },
          'type': 'object',
          'properties': {
            'nested': {
              'anyOf': [
                {r'$ref': r'#/$defs/Inner'},
                {'type': 'null'},
              ],
              'default': null,
            },
          },
        });
      });

      test('returns view when present', () {
        final view = SchemaStateView(
          const {
            'nested': {'value': 'hello'},
          },
          schema,
        );
        final nested = view.getObject('nested');
        expect(nested, isNotNull);
        expect(nested!.getScalar<String>('value'), 'hello');
      });

      test('returns null when absent', () {
        final view = SchemaStateView(const {}, schema);
        expect(view.getObject('nested'), isNull);
      });

      test('returns null when null in data', () {
        final view = SchemaStateView(const {'nested': null}, schema);
        expect(view.getObject('nested'), isNull);
      });
    });

    group('object lists', () {
      late ObjectSchema schema;

      setUp(() {
        schema = parser.parse({
          r'$defs': {
            'Item': {
              'type': 'object',
              'properties': {
                'id': {'type': 'string'},
                'count': {'type': 'integer', 'default': 0},
              },
              'required': ['id'],
            },
          },
          'type': 'object',
          'properties': {
            'items': {
              'default': <dynamic>[],
              'items': {r'$ref': r'#/$defs/Item'},
              'type': 'array',
            },
          },
        });
      });

      test('returns typed views', () {
        final view = SchemaStateView(
          const {
            'items': [
              {'id': 'a', 'count': 1},
              {'id': 'b'},
            ],
          },
          schema,
        );

        final items = view.getObjectList('items');
        expect(items, hasLength(2));
        expect(items[0].getScalar<String>('id'), 'a');
        expect(items[0].getScalar<int>('count'), 1);
        expect(items[1].getScalar<String>('id'), 'b');
        expect(items[1].getScalar<int>('count'), 0); // default
      });

      test('returns empty list when absent', () {
        final view = SchemaStateView(const {}, schema);
        expect(view.getObjectList('items'), isEmpty);
      });

      test('returns list length', () {
        final view = SchemaStateView(
          const {
            'items': [
              {'id': 'a'},
              {'id': 'b'},
              {'id': 'c'},
            ],
          },
          schema,
        );
        expect(view.getListLength('items'), 3);
      });

      test('returns 0 length when absent', () {
        final view = SchemaStateView(const {}, schema);
        expect(view.getListLength('items'), 0);
      });
    });

    group('scalar lists', () {
      late ObjectSchema schema;

      setUp(() {
        schema = parser.parse({
          'type': 'object',
          'properties': {
            'tags': {
              'default': <dynamic>[],
              'items': {'type': 'string'},
              'type': 'array',
            },
            'numbers': {
              'items': {'type': 'integer'},
              'type': 'array',
            },
          },
        });
      });

      test('returns typed scalars', () {
        final view = SchemaStateView(
          const {
            'tags': ['a', 'b'],
            'numbers': [1, 2, 3],
          },
          schema,
        );

        expect(view.getScalarList<String>('tags'), ['a', 'b']);
        expect(view.getScalarList<int>('numbers'), [1, 2, 3]);
      });

      test('returns empty list when absent', () {
        final view = SchemaStateView(const {}, schema);
        expect(view.getScalarList<String>('tags'), isEmpty);
      });

      test('coerces num items to int', () {
        final view = SchemaStateView(
          const {
            'numbers': [1.0, 2.0],
          },
          schema,
        );
        expect(view.getScalarList<int>('numbers'), [1, 2]);
      });
    });

    group('nested object lists', () {
      late ObjectSchema schema;

      setUp(() {
        schema = parser.parse({
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
      });

      test('returns nested list of views', () {
        final view = SchemaStateView(
          const {
            'citations_history': [
              [
                {'content': 'first'},
              ],
              [
                {'content': 'second'},
                {'content': 'third'},
              ],
            ],
          },
          schema,
        );

        final history = view.getNestedObjectList('citations_history');
        expect(history, hasLength(2));
        expect(history[0], hasLength(1));
        expect(history[0][0].getScalar<String>('content'), 'first');
        expect(history[1], hasLength(2));
        expect(
          history[1][1].getScalar<String>('content'),
          'third',
        );
      });

      test('returns empty list when absent', () {
        final view = SchemaStateView(const {}, schema);
        expect(
          view.getNestedObjectList('citations_history'),
          isEmpty,
        );
      });
    });

    group('maps', () {
      late ObjectSchema schema;

      setUp(() {
        schema = parser.parse({
          'type': 'object',
          'properties': {
            'registry': {
              'additionalProperties': {'type': 'integer'},
              'default': <String, dynamic>{},
              'type': 'object',
            },
          },
        });
      });

      test('returns typed map', () {
        final view = SchemaStateView(
          const {
            'registry': {'a': 1, 'b': 2},
          },
          schema,
        );

        final registry = view.getMap<int>('registry');
        expect(registry, {'a': 1, 'b': 2});
      });

      test('returns empty map when absent', () {
        final view = SchemaStateView(const {}, schema);
        expect(view.getMap<int>('registry'), isEmpty);
      });

      test('coerces num values to int', () {
        final view = SchemaStateView(
          const {
            'registry': {'a': 1.0},
          },
          schema,
        );
        expect(view.getMap<int>('registry'), {'a': 1});
      });
    });

    group('raw access', () {
      test('get returns raw value', () {
        const view = SchemaStateView(
          {'key': 'value'},
          ObjectSchema(fields: {}),
        );
        expect(view.get('key'), 'value');
        expect(view.get('missing'), isNull);
      });

      test('hasField checks presence', () {
        const view = SchemaStateView(
          {'key': null},
          ObjectSchema(fields: {}),
        );
        expect(view.hasField('key'), isTrue);
        expect(view.hasField('missing'), isFalse);
      });

      test('fieldNames returns data keys', () {
        const view = SchemaStateView(
          {'a': 1, 'b': 2},
          ObjectSchema(fields: {}),
        );
        expect(view.fieldNames, containsAll(['a', 'b']));
      });

      test('getRawMapList returns untyped maps', () {
        const view = SchemaStateView(
          {
            'items': [
              {'id': 'a'},
              {'id': 'b'},
            ],
          },
          ObjectSchema(fields: {}),
        );
        expect(view.getRawMapList('items'), hasLength(2));
        expect(view.getRawMapList('missing'), isEmpty);
      });
    });
  });

  group('golden: haiku.rag.chat parity', () {
    late ObjectSchema schema;
    late SchemaStateView view;

    setUp(() {
      schema = parser.parse(_haikuRagChatSchema);
      view = SchemaStateView(_haikuRagChatData, schema);
    });

    test('initial_context', () {
      expect(view.getScalar<String>('initial_context'), isNull);
    });

    test('citations list', () {
      final citations = view.getObjectList('citations');
      expect(citations, hasLength(1));
      expect(
        citations[0].getScalar<String>('document_id'),
        'doc-1',
      );
      expect(citations[0].getScalar<String>('content'), 'Some text');
      expect(citations[0].getScalar<int>('index'), isNull);
      expect(
        citations[0].getScalar<String>('document_title'),
        'My Doc',
      );
      expect(
        citations[0].getScalarList<int>('page_numbers'),
        [1, 2],
      );
      expect(
        citations[0].getScalarList<String>('headings'),
        ['Chapter 1'],
      );
    });

    test('citations length', () {
      expect(view.getListLength('citations'), 1);
    });

    test('qa_history with nested citations', () {
      final qaHistory = view.getObjectList('qa_history');
      expect(qaHistory, hasLength(1));

      final entry = qaHistory[0];
      expect(entry.getScalar<String>('question'), 'What is this?');
      expect(entry.getScalar<String>('answer'), 'It is a test.');
      expect(entry.getScalar<double>('confidence'), 0.95);

      final citations = entry.getObjectList('citations');
      expect(citations, hasLength(1));
      expect(
        citations[0].getScalar<String>('document_id'),
        'doc-1',
      );
    });

    test('session_context nullable object', () {
      final session = view.getObject('session_context');
      expect(session, isNotNull);
      expect(session!.getScalar<String>('summary'), 'A summary');
      expect(
        session.getScalar<String>('last_updated'),
        '2024-01-01T00:00:00Z',
      );
    });

    test('document_filter scalar list', () {
      expect(
        view.getScalarList<String>('document_filter'),
        ['doc-1'],
      );
    });

    test('citation_registry map', () {
      expect(
        view.getMap<int>('citation_registry'),
        {'cite-1': 0},
      );
    });

    test('citations_history nested list', () {
      final history = view.getNestedObjectList('citations_history');
      expect(history, hasLength(1));
      expect(history[0], hasLength(1));
      expect(
        history[0][0].getScalar<String>('content'),
        'Some text',
      );
    });

    test('absent field returns schema default', () {
      final emptyView = SchemaStateView(const {}, schema);
      expect(emptyView.getScalar<String>('initial_context'), isNull);
      expect(emptyView.getObjectList('citations'), isEmpty);
      expect(emptyView.getObjectList('qa_history'), isEmpty);
      expect(
        emptyView.getScalarList<String>('document_filter'),
        isEmpty,
      );
      expect(emptyView.getMap<int>('citation_registry'), isEmpty);
      expect(emptyView.getObject('session_context'), isNull);
    });
  });
}

const _haikuRagChatSchema = <String, dynamic>{
  r'$defs': {
    'Citation': {
      'properties': {
        'index': {
          'anyOf': [
            {'type': 'integer'},
            {'type': 'null'},
          ],
          'default': null,
        },
        'document_id': {'type': 'string'},
        'chunk_id': {'type': 'string'},
        'document_uri': {'type': 'string'},
        'document_title': {
          'anyOf': [
            {'type': 'string'},
            {'type': 'null'},
          ],
          'default': null,
        },
        'page_numbers': {
          'items': {'type': 'integer'},
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
        },
        'content': {'type': 'string'},
      },
      'required': ['document_id', 'chunk_id', 'document_uri', 'content'],
      'type': 'object',
    },
    'QAHistoryEntry': {
      'properties': {
        'question': {'type': 'string'},
        'answer': {'type': 'string'},
        'confidence': {'default': 0.9, 'type': 'number'},
        'citations': {
          'default': <dynamic>[],
          'items': {r'$ref': r'#/$defs/Citation'},
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
        },
      },
      'required': ['question', 'answer'],
      'type': 'object',
    },
    'SessionContext': {
      'properties': {
        'summary': {'default': '', 'type': 'string'},
        'last_updated': {
          'anyOf': [
            {'format': 'date-time', 'type': 'string'},
            {'type': 'null'},
          ],
          'default': null,
        },
      },
      'type': 'object',
    },
  },
  'type': 'object',
  'properties': {
    'initial_context': {
      'anyOf': [
        {'type': 'string'},
        {'type': 'null'},
      ],
      'default': null,
    },
    'citations': {
      'default': <dynamic>[],
      'items': {r'$ref': r'#/$defs/Citation'},
      'type': 'array',
    },
    'citations_history': {
      'default': <dynamic>[],
      'items': {
        'items': {r'$ref': r'#/$defs/Citation'},
        'type': 'array',
      },
      'type': 'array',
    },
    'qa_history': {
      'default': <dynamic>[],
      'items': {r'$ref': r'#/$defs/QAHistoryEntry'},
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
      'type': 'array',
    },
    'citation_registry': {
      'additionalProperties': {'type': 'integer'},
      'default': <String, dynamic>{},
      'type': 'object',
    },
  },
  'title': 'ChatSessionState',
};

const _haikuRagChatData = <String, dynamic>{
  'initial_context': null,
  'citations': [
    {
      'document_id': 'doc-1',
      'chunk_id': 'chunk-1',
      'document_uri': 'https://example.com/doc.pdf',
      'document_title': 'My Doc',
      'content': 'Some text',
      'page_numbers': [1, 2],
      'headings': ['Chapter 1'],
    },
  ],
  'citations_history': [
    [
      {
        'document_id': 'doc-1',
        'chunk_id': 'chunk-1',
        'document_uri': 'https://example.com/doc.pdf',
        'content': 'Some text',
      },
    ],
  ],
  'qa_history': [
    {
      'question': 'What is this?',
      'answer': 'It is a test.',
      'confidence': 0.95,
      'citations': [
        {
          'document_id': 'doc-1',
          'chunk_id': 'chunk-1',
          'document_uri': 'https://example.com/doc.pdf',
          'content': 'Some text',
        },
      ],
    },
  ],
  'session_context': {
    'summary': 'A summary',
    'last_updated': '2024-01-01T00:00:00Z',
  },
  'document_filter': ['doc-1'],
  'citation_registry': {'cite-1': 0},
};
