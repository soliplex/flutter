// ignore_for_file: prefer_const_constructors

import 'dart:convert';

import 'package:soliplex_client/src/schema/agui_features/rag.dart';
import 'package:test/test.dart';

/// Contract tests for rag.dart generated types.
///
/// These tests document and enforce the API surface that consuming code depends
/// on. They will fail to compile if required fields are renamed or removed,
/// alerting us to update consuming code.
///
/// These are NOT tests of JSON parsing correctness (that's quicktype's job).
/// They are tests of the SHAPE of the API we consume.
void main() {
  group('Rag contract', () {
    group('fields required by CitationExtractor', () {
      test('citations field exists and returns List<Citation>?', () {
        final rag = Rag();

        final citations = rag.citations;
        expect(citations, isNull);
      });

      test('can construct with empty citations', () {
        final rag = Rag(citations: []);

        expect(rag.citations, isEmpty);
      });
    });

    group('qaHistory field', () {
      test('qaHistory field exists and returns List<QaHistoryEntry>?', () {
        final rag = Rag();
        final history = rag.qaHistory;
        expect(history, isNull);
      });

      test('can construct with qa history', () {
        final rag = Rag(
          qaHistory: [
            QaHistoryEntry(answer: 'A1', question: 'Q1'),
          ],
        );
        expect(rag.qaHistory, hasLength(1));
      });
    });

    group('documentFilter field', () {
      test('documentFilter is String?', () {
        final rag = Rag();
        expect(rag.documentFilter, isNull);
      });

      test('can construct with documentFilter', () {
        final rag = Rag(documentFilter: "title = 'Report'");
        expect(rag.documentFilter, equals("title = 'Report'"));
      });
    });

    group('JSON keys required for parsing', () {
      test('parses from rag state format', () {
        final json = {
          'citations': <Map<String, dynamic>>[],
          'searches': <String, dynamic>{},
        };

        final rag = Rag.fromJson(json);
        expect(rag.citations, isEmpty);
      });

      test('citations key must exist as array', () {
        final json = {
          'citations': [
            {
              'chunk_id': 'c1',
              'content': 'text',
              'document_id': 'd1',
              'document_uri': 'uri',
            },
          ],
          'searches': <String, dynamic>{},
        };

        final rag = Rag.fromJson(json);
        expect(rag.citations, hasLength(1));
      });

      test('searches is required in fromJson', () {
        final json = <String, dynamic>{
          'searches': <String, dynamic>{
            'query1': <Map<String, dynamic>>[],
          },
        };

        final rag = Rag.fromJson(json);
        expect(rag.searches, isNotNull);
        expect(rag.searches!.containsKey('query1'), isTrue);
      });
    });
  });

  group('Citation contract', () {
    group('fields required by CitationsSection UI', () {
      test('documentTitle is optional String for display header', () {
        final citation = Citation(
          chunkId: 'c1',
          content: 'content',
          documentId: 'd1',
          documentUri: 'https://example.com/doc',
        );

        final title = citation.documentTitle;
        expect(title, isNull);
      });

      test('documentUri is required String for fallback display', () {
        final citation = Citation(
          chunkId: 'c1',
          content: 'content',
          documentId: 'd1',
          documentUri: 'https://example.com/doc',
        );

        final uri = citation.documentUri;
        expect(uri, isNotEmpty);
      });

      test('content is required String for snippet display', () {
        final citation = Citation(
          chunkId: 'c1',
          content: 'This is the citation content snippet',
          documentId: 'd1',
          documentUri: 'uri',
        );

        final content = citation.content;
        expect(content, contains('snippet'));
      });

      test('documentUri is used for "View source" link', () {
        final citation = Citation(
          chunkId: 'c1',
          content: 'content',
          documentId: 'd1',
          documentUri: 'https://example.com/document.pdf',
        );

        final uri = Uri.tryParse(citation.documentUri);
        expect(uri, isNotNull);
        expect(uri!.scheme, anyOf('http', 'https'));
      });
    });

    group('required constructor parameters', () {
      test('chunkId is required', () {
        final citation = Citation(
          chunkId: 'chunk-123',
          content: 'content',
          documentId: 'doc-456',
          documentUri: 'uri',
        );

        expect(citation.chunkId, equals('chunk-123'));
      });

      test('content is required', () {
        final citation = Citation(
          chunkId: 'c1',
          content: 'required content',
          documentId: 'd1',
          documentUri: 'uri',
        );

        expect(citation.content, equals('required content'));
      });

      test('documentId is required', () {
        final citation = Citation(
          chunkId: 'c1',
          content: 'content',
          documentId: 'doc-id',
          documentUri: 'uri',
        );

        expect(citation.documentId, equals('doc-id'));
      });

      test('documentUri is required', () {
        final citation = Citation(
          chunkId: 'c1',
          content: 'content',
          documentId: 'd1',
          documentUri: 'https://example.com',
        );

        expect(citation.documentUri, equals('https://example.com'));
      });
    });

    group('optional fields the UI handles', () {
      test('documentTitle defaults to null', () {
        final citation = Citation(
          chunkId: 'c1',
          content: 'content',
          documentId: 'd1',
          documentUri: 'uri',
        );

        expect(citation.documentTitle, isNull);
      });

      test('documentTitle can be provided', () {
        final citation = Citation(
          chunkId: 'c1',
          content: 'content',
          documentId: 'd1',
          documentUri: 'uri',
          documentTitle: 'My Document',
        );

        expect(citation.documentTitle, equals('My Document'));
      });

      test('index field exists for display ordering', () {
        final citation = Citation(
          chunkId: 'c1',
          content: 'content',
          documentId: 'd1',
          documentUri: 'uri',
          index: 1,
        );

        final index = citation.index;
        expect(index, equals(1));
      });

      test('headings field exists', () {
        final citation = Citation(
          chunkId: 'c1',
          content: 'content',
          documentId: 'd1',
          documentUri: 'uri',
          headings: ['Section 1', 'Subsection A'],
        );

        final headings = citation.headings;
        expect(headings, hasLength(2));
      });

      test('pageNumbers field exists', () {
        final citation = Citation(
          chunkId: 'c1',
          content: 'content',
          documentId: 'd1',
          documentUri: 'uri',
          pageNumbers: [1, 2, 3],
        );

        final pages = citation.pageNumbers;
        expect(pages, hasLength(3));
      });
    });

    group('JSON keys for parsing', () {
      test('required JSON keys match snake_case convention', () {
        final json = {
          'chunk_id': 'c1',
          'content': 'text',
          'document_id': 'd1',
          'document_uri': 'uri',
        };

        final citation = Citation.fromJson(json);
        expect(citation.chunkId, equals('c1'));
        expect(citation.content, equals('text'));
        expect(citation.documentId, equals('d1'));
        expect(citation.documentUri, equals('uri'));
      });

      test('optional JSON keys match snake_case convention', () {
        final json = {
          'chunk_id': 'c1',
          'content': 'text',
          'document_id': 'd1',
          'document_uri': 'uri',
          'document_title': 'Title',
          'headings': ['H1'],
          'index': 5,
          'page_numbers': [1],
        };

        final citation = Citation.fromJson(json);
        expect(citation.documentTitle, equals('Title'));
        expect(citation.headings, equals(['H1']));
        expect(citation.index, equals(5));
        expect(citation.pageNumbers, equals([1]));
      });

      test('toJson produces expected keys', () {
        final citation = Citation(
          chunkId: 'c1',
          content: 'text',
          documentId: 'd1',
          documentUri: 'uri',
          documentTitle: 'Title',
        );

        final json = citation.toJson();

        expect(json.containsKey('chunk_id'), isTrue);
        expect(json.containsKey('content'), isTrue);
        expect(json.containsKey('document_id'), isTrue);
        expect(json.containsKey('document_uri'), isTrue);
        expect(json.containsKey('document_title'), isTrue);
      });
    });

    group('roundtrip serialization', () {
      test('Citation survives JSON roundtrip', () {
        final original = Citation(
          chunkId: 'c1',
          content: 'content',
          documentId: 'd1',
          documentUri: 'https://example.com',
          documentTitle: 'Test Doc',
          index: 1,
          headings: ['Section 1'],
          pageNumbers: [1, 2],
        );

        final jsonString = jsonEncode(original.toJson());
        final decoded = Citation.fromJson(
          jsonDecode(jsonString) as Map<String, dynamic>,
        );

        expect(decoded.chunkId, equals(original.chunkId));
        expect(decoded.content, equals(original.content));
        expect(decoded.documentId, equals(original.documentId));
        expect(decoded.documentUri, equals(original.documentUri));
        expect(decoded.documentTitle, equals(original.documentTitle));
        expect(decoded.index, equals(original.index));
        expect(decoded.headings, equals(original.headings));
        expect(decoded.pageNumbers, equals(original.pageNumbers));
      });
    });
  });

  group('QaHistoryEntry contract', () {
    group('fields that exist in the schema', () {
      test('answer is required String', () {
        final qa = QaHistoryEntry(
          answer: 'The answer',
          question: 'The question',
        );

        final answer = qa.answer;
        expect(answer, equals('The answer'));
      });

      test('question is required String', () {
        final qa = QaHistoryEntry(answer: 'answer', question: 'What is X?');

        final question = qa.question;
        expect(question, equals('What is X?'));
      });

      test('citations is optional List<Citation>', () {
        final qa = QaHistoryEntry(
          answer: 'answer',
          question: 'question',
          citations: [
            Citation(
              chunkId: 'c1',
              content: 'content',
              documentId: 'd1',
              documentUri: 'uri',
            ),
          ],
        );

        final citations = qa.citations;
        expect(citations, hasLength(1));
      });

      test('confidence is optional double', () {
        final qa = QaHistoryEntry(
          answer: 'answer',
          question: 'question',
          confidence: 0.95,
        );

        final confidence = qa.confidence;
        expect(confidence, equals(0.95));
      });
    });

    group('JSON keys for parsing', () {
      test('required JSON keys', () {
        final json = {
          'answer': 'The answer',
          'question': 'The question',
        };

        final qa = QaHistoryEntry.fromJson(json);
        expect(qa.answer, equals('The answer'));
        expect(qa.question, equals('The question'));
      });
    });
  });
}
