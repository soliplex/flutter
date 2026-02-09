import 'package:soliplex_client/src/domain/rag_document.dart';
import 'package:test/test.dart';

void main() {
  group('RagDocument', () {
    test('creates with required fields', () {
      const doc = RagDocument(id: 'doc-123', title: 'Manual.pdf');

      expect(doc.id, equals('doc-123'));
      expect(doc.title, equals('Manual.pdf'));
    });

    group('equality', () {
      test('equals by id only', () {
        const doc1 = RagDocument(id: 'doc-123', title: 'Title A');
        const doc2 = RagDocument(id: 'doc-123', title: 'Title B');

        expect(doc1, equals(doc2));
      });

      test('not equals with different id', () {
        const doc1 = RagDocument(id: 'doc-123', title: 'Title');
        const doc2 = RagDocument(id: 'doc-456', title: 'Title');

        expect(doc1, isNot(equals(doc2)));
      });

      test('identical documents are equal', () {
        const doc = RagDocument(id: 'doc-123', title: 'Title');

        expect(doc, equals(doc));
      });
    });

    group('hashCode', () {
      test('same hashCode for same id', () {
        const doc1 = RagDocument(id: 'doc-123', title: 'Title A');
        const doc2 = RagDocument(id: 'doc-123', title: 'Title B');

        expect(doc1.hashCode, equals(doc2.hashCode));
      });
    });

    group('copyWith', () {
      test('copies with new id', () {
        const original = RagDocument(id: 'doc-123', title: 'Title');
        final copy = original.copyWith(id: 'doc-456');

        expect(copy.id, equals('doc-456'));
        expect(copy.title, equals('Title'));
      });

      test('copies with new title', () {
        const original = RagDocument(id: 'doc-123', title: 'Title');
        final copy = original.copyWith(title: 'New Title');

        expect(copy.id, equals('doc-123'));
        expect(copy.title, equals('New Title'));
      });

      test('copies with no changes', () {
        const original = RagDocument(id: 'doc-123', title: 'Title');
        final copy = original.copyWith();

        expect(copy.id, equals(original.id));
        expect(copy.title, equals(original.title));
      });
    });

    group('toString', () {
      test('includes id and title', () {
        const doc = RagDocument(id: 'doc-123', title: 'Manual.pdf');

        expect(doc.toString(), contains('doc-123'));
        expect(doc.toString(), contains('Manual.pdf'));
      });
    });
  });
}
