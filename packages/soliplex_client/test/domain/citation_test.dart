import 'package:soliplex_client/soliplex_client.dart';
import 'package:test/test.dart';

void main() {
  group('Citation', () {
    group('construction', () {
      test('creates with required fields only', () {
        final citation = Citation(
          chunkId: 'chunk-1',
          content: 'Test content',
          documentId: 'doc-1',
          documentUri: 'https://example.com/doc.pdf',
        );

        expect(citation.chunkId, 'chunk-1');
        expect(citation.content, 'Test content');
        expect(citation.documentId, 'doc-1');
        expect(citation.documentUri, 'https://example.com/doc.pdf');
        expect(citation.documentTitle, isNull);
        expect(citation.headings, isNull);
        expect(citation.index, isNull);
        expect(citation.pageNumbers, isNull);
      });

      test('creates with all fields', () {
        final citation = Citation(
          chunkId: 'chunk-1',
          content: 'Test content',
          documentId: 'doc-1',
          documentUri: 'https://example.com/doc.pdf',
          documentTitle: 'Test Document',
          headings: ['Chapter 1', 'Section 2'],
          index: 3,
          pageNumbers: [1, 2, 3],
        );

        expect(citation.chunkId, 'chunk-1');
        expect(citation.content, 'Test content');
        expect(citation.documentId, 'doc-1');
        expect(citation.documentUri, 'https://example.com/doc.pdf');
        expect(citation.documentTitle, 'Test Document');
        expect(citation.headings, ['Chapter 1', 'Section 2']);
        expect(citation.index, 3);
        expect(citation.pageNumbers, [1, 2, 3]);
      });
    });

    group('serialization', () {
      test('fromJson parses all fields', () {
        final json = {
          'chunk_id': 'chunk-1',
          'content': 'Test content',
          'document_id': 'doc-1',
          'document_uri': 'https://example.com/doc.pdf',
          'document_title': 'Test Document',
          'headings': ['Chapter 1', 'Section 2'],
          'index': 3,
          'page_numbers': [1, 2, 3],
        };

        final citation = Citation.fromJson(json);

        expect(citation.chunkId, 'chunk-1');
        expect(citation.content, 'Test content');
        expect(citation.documentId, 'doc-1');
        expect(citation.documentUri, 'https://example.com/doc.pdf');
        expect(citation.documentTitle, 'Test Document');
        expect(citation.headings, ['Chapter 1', 'Section 2']);
        expect(citation.index, 3);
        expect(citation.pageNumbers, [1, 2, 3]);
      });

      test('fromJson handles missing optional fields', () {
        final json = {
          'chunk_id': 'chunk-1',
          'content': 'Test content',
          'document_id': 'doc-1',
          'document_uri': 'https://example.com/doc.pdf',
        };

        final citation = Citation.fromJson(json);

        expect(citation.documentTitle, isNull);
        // Generated code returns empty lists for missing array fields
        expect(citation.headings, isEmpty);
        expect(citation.index, isNull);
        expect(citation.pageNumbers, isEmpty);
      });

      test('fromJson handles empty arrays', () {
        final json = {
          'chunk_id': 'chunk-1',
          'content': 'Test content',
          'document_id': 'doc-1',
          'document_uri': 'https://example.com/doc.pdf',
          'headings': <dynamic>[],
          'page_numbers': <dynamic>[],
        };

        final citation = Citation.fromJson(json);

        expect(citation.headings, isEmpty);
        expect(citation.pageNumbers, isEmpty);
      });

      test('toJson serializes all fields', () {
        final citation = Citation(
          chunkId: 'chunk-1',
          content: 'Test content',
          documentId: 'doc-1',
          documentUri: 'https://example.com/doc.pdf',
          documentTitle: 'Test Document',
          headings: ['Chapter 1', 'Section 2'],
          index: 3,
          pageNumbers: [1, 2, 3],
        );

        final json = citation.toJson();

        expect(json['chunk_id'], 'chunk-1');
        expect(json['content'], 'Test content');
        expect(json['document_id'], 'doc-1');
        expect(json['document_uri'], 'https://example.com/doc.pdf');
        expect(json['document_title'], 'Test Document');
        expect(json['headings'], ['Chapter 1', 'Section 2']);
        expect(json['index'], 3);
        expect(json['page_numbers'], [1, 2, 3]);
      });

      test('roundtrip preserves all fields', () {
        final original = Citation(
          chunkId: 'chunk-1',
          content: 'Test content with special chars: <>&"',
          documentId: 'doc-1',
          documentUri: 'https://example.com/doc.pdf',
          documentTitle: 'Test Document',
          headings: ['Chapter 1', 'Section 2', 'Subsection 3'],
          index: 5,
          pageNumbers: [1, 2, 3, 10, 20],
        );

        final json = original.toJson();
        final restored = Citation.fromJson(json);

        expect(restored.chunkId, original.chunkId);
        expect(restored.content, original.content);
        expect(restored.documentId, original.documentId);
        expect(restored.documentUri, original.documentUri);
        expect(restored.documentTitle, original.documentTitle);
        expect(restored.headings, original.headings);
        expect(restored.index, original.index);
        expect(restored.pageNumbers, original.pageNumbers);
      });
    });

    group('headings field', () {
      test('handles single heading', () {
        final citation = Citation(
          chunkId: 'chunk-1',
          content: 'content',
          documentId: 'doc-1',
          documentUri: 'https://example.com/doc.pdf',
          headings: ['Single Heading'],
        );

        expect(citation.headings, ['Single Heading']);
      });

      test('handles deeply nested headings', () {
        final headings = [
          'Part I',
          'Chapter 1',
          'Section 1.1',
          'Subsection 1.1.1',
          'Paragraph A',
        ];

        final citation = Citation(
          chunkId: 'chunk-1',
          content: 'content',
          documentId: 'doc-1',
          documentUri: 'https://example.com/doc.pdf',
          headings: headings,
        );

        expect(citation.headings, hasLength(5));
        expect(citation.headings, headings);
      });
    });

    group('index field', () {
      test('handles zero index', () {
        final citation = Citation(
          chunkId: 'chunk-1',
          content: 'content',
          documentId: 'doc-1',
          documentUri: 'https://example.com/doc.pdf',
          index: 0,
        );

        expect(citation.index, 0);
      });

      test('handles large index', () {
        final citation = Citation(
          chunkId: 'chunk-1',
          content: 'content',
          documentId: 'doc-1',
          documentUri: 'https://example.com/doc.pdf',
          index: 999,
        );

        expect(citation.index, 999);
      });
    });
  });
}
