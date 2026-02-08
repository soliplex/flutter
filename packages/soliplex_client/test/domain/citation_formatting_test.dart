import 'package:soliplex_client/soliplex_client.dart';
import 'package:test/test.dart';

void main() {
  group('CitationFormatting', () {
    Citation createCitation({
      List<int>? pageNumbers,
      String? documentTitle,
      String documentUri = 'https://example.com/document.pdf',
    }) {
      return Citation(
        chunkId: 'chunk-1',
        content: 'test content',
        documentId: 'doc-1',
        documentTitle: documentTitle,
        documentUri: documentUri,
        pageNumbers: pageNumbers,
      );
    }

    group('formattedPageNumbers', () {
      test('returns null when pageNumbers is null', () {
        final citation = createCitation();

        expect(citation.formattedPageNumbers, isNull);
      });

      test('returns null when pageNumbers is empty', () {
        final citation = createCitation(pageNumbers: []);

        expect(citation.formattedPageNumbers, isNull);
      });

      test('returns single page format for one page', () {
        final citation = createCitation(pageNumbers: [5]);

        expect(citation.formattedPageNumbers, 'p.5');
      });

      test('returns range format for consecutive pages', () {
        final citation = createCitation(pageNumbers: [1, 2, 3]);

        expect(citation.formattedPageNumbers, 'p.1-3');
      });

      test('returns range format for consecutive pages in any order', () {
        final citation = createCitation(pageNumbers: [3, 1, 2]);

        expect(citation.formattedPageNumbers, 'p.1-3');
      });

      test('returns comma format for non-consecutive pages', () {
        final citation = createCitation(pageNumbers: [5, 8]);

        expect(citation.formattedPageNumbers, 'p.5, 8');
      });

      test('returns comma format for scattered pages', () {
        final citation = createCitation(pageNumbers: [1, 5, 10]);

        expect(citation.formattedPageNumbers, 'p.1, 5, 10');
      });

      test('sorts and formats scattered pages', () {
        final citation = createCitation(pageNumbers: [10, 1, 5]);

        expect(citation.formattedPageNumbers, 'p.1, 5, 10');
      });

      test('handles two consecutive pages', () {
        final citation = createCitation(pageNumbers: [4, 5]);

        expect(citation.formattedPageNumbers, 'p.4-5');
      });

      test('handles mix of consecutive and scattered (uses comma)', () {
        final citation = createCitation(pageNumbers: [1, 2, 5]);

        expect(citation.formattedPageNumbers, 'p.1, 2, 5');
      });
    });

    group('displayTitle', () {
      test('returns documentTitle when present', () {
        final citation = createCitation(
          documentTitle: 'My Document',
          documentUri: 'https://example.com/file.pdf',
        );

        expect(citation.displayTitle, 'My Document');
      });

      test('returns filename from URI when documentTitle is null', () {
        final citation = createCitation(
          documentUri: 'https://example.com/path/to/document.pdf',
        );

        expect(citation.displayTitle, 'document.pdf');
      });

      test('returns filename from URI when documentTitle is empty', () {
        final citation = createCitation(
          documentTitle: '',
          documentUri: 'https://example.com/report.pdf',
        );

        expect(citation.displayTitle, 'report.pdf');
      });

      test('returns fallback for invalid URI', () {
        final citation = createCitation(
          documentUri: ':::invalid',
        );

        expect(citation.displayTitle, 'Unknown Document');
      });

      test('returns fallback for URI with no path segments', () {
        final citation = createCitation(
          documentUri: 'https://example.com',
        );

        expect(citation.displayTitle, 'Unknown Document');
      });

      test('handles file URI scheme', () {
        final citation = createCitation(
          documentUri: 'file:///home/user/docs/manual.pdf',
        );

        expect(citation.displayTitle, 'manual.pdf');
      });
    });

    group('isPdf', () {
      test('returns true for .pdf extension', () {
        final citation = createCitation();

        expect(citation.isPdf, isTrue);
      });

      test('returns true for .PDF extension (case insensitive)', () {
        final citation = createCitation(
          documentUri: 'https://example.com/document.PDF',
        );

        expect(citation.isPdf, isTrue);
      });

      test('returns false for non-pdf files', () {
        final citation = createCitation(
          documentUri: 'https://example.com/document.docx',
        );

        expect(citation.isPdf, isFalse);
      });

      test('returns false for URLs with pdf in path but different extension',
          () {
        final citation = createCitation(
          documentUri: 'https://example.com/pdf/document.txt',
        );

        expect(citation.isPdf, isFalse);
      });
    });
  });
}
