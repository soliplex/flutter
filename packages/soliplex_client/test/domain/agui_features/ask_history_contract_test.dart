// ignore_for_file: prefer_const_constructors

import 'dart:convert';

import 'package:soliplex_client/src/domain/agui_features/ask_history.dart';
import 'package:soliplex_client/src/domain/agui_features/haiku_rag_chat.dart'
    as haiku_rag_chat;
import 'package:test/test.dart';

/// Contract tests for ask_history.dart generated types.
///
/// These tests document and enforce the API surface that consuming code depends
/// on. They will fail to compile if required fields are renamed or removed,
/// alerting us to update consuming code.
///
/// IMPORTANT: This file also contains a field parity test for Citation types.
/// Both haiku_rag_chat.dart and ask_history.dart define a Citation class.
/// The Conversation._extractCitationsFromAskHistory() method manually maps
/// fields between them. The field parity test ensures both types have
/// identical fields, so schema changes cause compile-time failures.
void main() {
  group('AskHistory contract', () {
    group('fields required by _extractCitationsFromAskHistory()', () {
      test('questions field returns List<QuestionResponseCitations>?', () {
        // Conversation._extractCitationsFromAskHistory() accesses:
        //   final questions = history.questions ?? [];
        final history = AskHistory();

        // This access will fail to compile if the field is renamed or removed
        final questions = history.questions;
        expect(questions, isNull);
      });

      test('can construct with empty questions', () {
        final history = AskHistory(questions: []);

        expect(history.questions, isEmpty);
      });

      test('can construct with questions containing citations', () {
        final history = AskHistory(
          questions: [
            QuestionResponseCitations(
              question: 'What is X?',
              response: 'X is...',
              citations: [
                Citation(
                  chunkId: 'c1',
                  content: 'content',
                  documentId: 'd1',
                  documentUri: 'uri',
                ),
              ],
            ),
          ],
        );

        expect(history.questions, hasLength(1));
        expect(history.questions!.first.citations, hasLength(1));
      });
    });

    group('JSON keys required for parsing', () {
      test('parses from ask_history state format', () {
        final json = {
          'questions': <Map<String, dynamic>>[],
        };

        final history = AskHistory.fromJson(json);
        expect(history.questions, isEmpty);
      });

      test('parses questions with nested citations', () {
        final json = {
          'questions': [
            {
              'question': 'What is X?',
              'response': 'X is...',
              'citations': [
                {
                  'chunk_id': 'c1',
                  'content': 'content',
                  'document_id': 'd1',
                  'document_uri': 'uri',
                },
              ],
            },
          ],
        };

        final history = AskHistory.fromJson(json);
        expect(history.questions, hasLength(1));
        expect(history.questions!.first.citations, hasLength(1));
      });
    });
  });

  group('QuestionResponseCitations contract', () {
    group('fields required by _extractCitationsFromAskHistory()', () {
      test('citations field exists and returns List<Citation>?', () {
        // Conversation._extractCitationsFromAskHistory() accesses:
        //   final citations = qrc.citations ?? [];
        final qrc = QuestionResponseCitations(
          question: 'q',
          response: 'r',
        );

        // This access will fail to compile if the field is renamed or removed
        final citations = qrc.citations;
        expect(citations, isNull);
      });

      test('question is required String', () {
        final qrc = QuestionResponseCitations(
          question: 'What is X?',
          response: 'X is...',
        );

        final question = qrc.question;
        expect(question, equals('What is X?'));
      });

      test('response is required String', () {
        final qrc = QuestionResponseCitations(
          question: 'q',
          response: 'The response',
        );

        final response = qrc.response;
        expect(response, equals('The response'));
      });
    });

    group('JSON keys for parsing', () {
      test('required JSON keys', () {
        final json = {
          'question': 'What is X?',
          'response': 'X is...',
        };

        final qrc = QuestionResponseCitations.fromJson(json);
        expect(qrc.question, equals('What is X?'));
        expect(qrc.response, equals('X is...'));
      });

      test('citations key is optional', () {
        final json = {
          'question': 'q',
          'response': 'r',
          'citations': [
            {
              'chunk_id': 'c1',
              'content': 'content',
              'document_id': 'd1',
              'document_uri': 'uri',
            },
          ],
        };

        final qrc = QuestionResponseCitations.fromJson(json);
        expect(qrc.citations, hasLength(1));
      });
    });
  });

  group('Citation contract (ask_history)', () {
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

    group('optional fields', () {
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

      test('index field exists', () {
        final citation = Citation(
          chunkId: 'c1',
          content: 'content',
          documentId: 'd1',
          documentUri: 'uri',
          index: 1,
        );

        expect(citation.index, equals(1));
      });

      test('headings field exists', () {
        final citation = Citation(
          chunkId: 'c1',
          content: 'content',
          documentId: 'd1',
          documentUri: 'uri',
          headings: ['Section 1'],
        );

        expect(citation.headings, hasLength(1));
      });

      test('pageNumbers field exists', () {
        final citation = Citation(
          chunkId: 'c1',
          content: 'content',
          documentId: 'd1',
          documentUri: 'uri',
          pageNumbers: [1, 2],
        );

        expect(citation.pageNumbers, hasLength(2));
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

  group('Citation field parity', () {
    // CRITICAL: This test ensures both Citation types have identical fields.
    // Conversation._extractCitationsFromAskHistory() manually maps fields
    // from ask_history.Citation to haiku_rag_chat.Citation. If either type
    // changes, this test will fail to compile.
    //
    // The mapping code in conversation.dart:
    //   allCitations.add(
    //     Citation(  // haiku_rag_chat.Citation
    //       chunkId: c.chunkId,       // from ask_history.Citation
    //       content: c.content,
    //       documentId: c.documentId,
    //       documentTitle: c.documentTitle,
    //       documentUri: c.documentUri,
    //       headings: c.headings,
    //       index: c.index,
    //       pageNumbers: c.pageNumbers,
    //     ),
    //   );

    test('both Citation types have identical required fields', () {
      // Create ask_history.Citation
      final askCitation = Citation(
        chunkId: 'c1',
        content: 'content',
        documentId: 'd1',
        documentUri: 'uri',
      );

      // Create haiku_rag_chat.Citation with same values
      // This will fail to compile if field names differ
      final haikuCitation = haiku_rag_chat.Citation(
        chunkId: askCitation.chunkId,
        content: askCitation.content,
        documentId: askCitation.documentId,
        documentUri: askCitation.documentUri,
      );

      expect(haikuCitation.chunkId, equals(askCitation.chunkId));
      expect(haikuCitation.content, equals(askCitation.content));
      expect(haikuCitation.documentId, equals(askCitation.documentId));
      expect(haikuCitation.documentUri, equals(askCitation.documentUri));
    });

    test('both Citation types have identical optional fields', () {
      // Create ask_history.Citation with all fields
      final askCitation = Citation(
        chunkId: 'c1',
        content: 'content',
        documentId: 'd1',
        documentUri: 'uri',
        documentTitle: 'Title',
        headings: ['H1', 'H2'],
        index: 5,
        pageNumbers: [1, 2, 3],
      );

      // Create haiku_rag_chat.Citation mapping all fields
      // This will fail to compile if field names differ
      final haikuCitation = haiku_rag_chat.Citation(
        chunkId: askCitation.chunkId,
        content: askCitation.content,
        documentId: askCitation.documentId,
        documentUri: askCitation.documentUri,
        documentTitle: askCitation.documentTitle,
        headings: askCitation.headings,
        index: askCitation.index,
        pageNumbers: askCitation.pageNumbers,
      );

      expect(haikuCitation.documentTitle, equals(askCitation.documentTitle));
      expect(haikuCitation.headings, equals(askCitation.headings));
      expect(haikuCitation.index, equals(askCitation.index));
      expect(haikuCitation.pageNumbers, equals(askCitation.pageNumbers));
    });

    test('both Citation types produce identical JSON', () {
      final askCitation = Citation(
        chunkId: 'c1',
        content: 'content',
        documentId: 'd1',
        documentUri: 'uri',
        documentTitle: 'Title',
        headings: ['H1'],
        index: 1,
        pageNumbers: [1],
      );

      final haikuCitation = haiku_rag_chat.Citation(
        chunkId: askCitation.chunkId,
        content: askCitation.content,
        documentId: askCitation.documentId,
        documentUri: askCitation.documentUri,
        documentTitle: askCitation.documentTitle,
        headings: askCitation.headings,
        index: askCitation.index,
        pageNumbers: askCitation.pageNumbers,
      );

      // Both should produce identical JSON
      final askJson = askCitation.toJson();
      final haikuJson = haikuCitation.toJson();

      expect(askJson.keys.toSet(), equals(haikuJson.keys.toSet()));
      for (final key in askJson.keys) {
        expect(askJson[key], equals(haikuJson[key]));
      }
    });
  });
}
