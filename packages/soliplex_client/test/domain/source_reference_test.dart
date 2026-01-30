import 'package:soliplex_client/src/domain/source_reference.dart';
import 'package:test/test.dart';

void main() {
  group('SourceReference', () {
    test('creates with required fields only', () {
      const ref = SourceReference(
        documentId: 'doc-1',
        documentUri: 'https://example.com/doc.pdf',
        content: 'Test content',
        chunkId: 'chunk-1',
      );

      expect(ref.documentId, 'doc-1');
      expect(ref.documentUri, 'https://example.com/doc.pdf');
      expect(ref.content, 'Test content');
      expect(ref.chunkId, 'chunk-1');
      expect(ref.documentTitle, isNull);
      expect(ref.headings, isEmpty);
      expect(ref.pageNumbers, isEmpty);
      expect(ref.index, isNull);
    });

    test('creates with all fields', () {
      const ref = SourceReference(
        documentId: 'doc-1',
        documentUri: 'https://example.com/doc.pdf',
        content: 'Test content',
        chunkId: 'chunk-1',
        documentTitle: 'Test Document',
        headings: ['Chapter 1', 'Section 2'],
        pageNumbers: [1, 2, 3],
        index: 5,
      );

      expect(ref.documentId, 'doc-1');
      expect(ref.documentUri, 'https://example.com/doc.pdf');
      expect(ref.content, 'Test content');
      expect(ref.chunkId, 'chunk-1');
      expect(ref.documentTitle, 'Test Document');
      expect(ref.headings, ['Chapter 1', 'Section 2']);
      expect(ref.pageNumbers, [1, 2, 3]);
      expect(ref.index, 5);
    });

    group('equality', () {
      test('equal references are equal', () {
        const ref1 = SourceReference(
          documentId: 'doc-1',
          documentUri: 'https://example.com/doc.pdf',
          content: 'Test content',
          chunkId: 'chunk-1',
        );
        const ref2 = SourceReference(
          documentId: 'doc-1',
          documentUri: 'https://example.com/doc.pdf',
          content: 'Test content',
          chunkId: 'chunk-1',
        );

        expect(ref1, equals(ref2));
        expect(ref1.hashCode, equals(ref2.hashCode));
      });

      test('different chunkId makes references unequal', () {
        const ref1 = SourceReference(
          documentId: 'doc-1',
          documentUri: 'https://example.com/doc.pdf',
          content: 'Test content',
          chunkId: 'chunk-1',
        );
        const ref2 = SourceReference(
          documentId: 'doc-1',
          documentUri: 'https://example.com/doc.pdf',
          content: 'Test content',
          chunkId: 'chunk-2',
        );

        expect(ref1, isNot(equals(ref2)));
      });
    });
  });
}
