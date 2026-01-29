import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soliplex_client/soliplex_client.dart' hide State;
import 'package:soliplex_frontend/features/chat/widgets/citations_section.dart';

import '../../../helpers/test_helpers.dart';

Citation _createCitation({
  String chunkId = 'chunk-1',
  String content = 'Test citation content for display.',
  String documentId = 'doc-1',
  String? documentTitle = 'Test Document',
  String documentUri = 'https://example.com/doc.pdf',
  List<String>? headings,
  int? index,
  List<int>? pageNumbers,
}) {
  return Citation(
    chunkId: chunkId,
    content: content,
    documentId: documentId,
    documentTitle: documentTitle,
    documentUri: documentUri,
    headings: headings,
    index: index,
    pageNumbers: pageNumbers,
  );
}

void main() {
  group('CitationsSection', () {
    testWidgets('shows citation count in header', (tester) async {
      final citations = [
        _createCitation(chunkId: 'c1'),
        _createCitation(chunkId: 'c2'),
      ];

      await tester.pumpWidget(
        createTestApp(home: CitationsSection(citations: citations)),
      );

      expect(find.text('2 sources'), findsOneWidget);
    });

    testWidgets('expands to show citation rows when header tapped',
        (tester) async {
      final citations = [
        _createCitation(documentTitle: 'Document A'),
        _createCitation(documentTitle: 'Document B'),
      ];

      await tester.pumpWidget(
        createTestApp(home: CitationsSection(citations: citations)),
      );

      // Initially collapsed - no document titles visible
      expect(find.text('Document A'), findsNothing);

      // Tap header to expand
      await tester.tap(find.text('2 sources'));
      await tester.pumpAndSettle();

      // Now document titles are visible
      expect(find.text('Document A'), findsOneWidget);
      expect(find.text('Document B'), findsOneWidget);
    });

    testWidgets('returns empty widget when citations list is empty',
        (tester) async {
      await tester.pumpWidget(
        createTestApp(home: const CitationsSection(citations: [])),
      );

      expect(find.byType(CitationsSection), findsOneWidget);
      expect(find.byType(SizedBox), findsWidgets);
    });
  });

  group('CitationsSection individual expand', () {
    testWidgets('citation row can be expanded by tapping', (tester) async {
      final citations = [
        _createCitation(
          documentTitle: 'Document A',
          content: 'Full content of the citation that should be visible.',
        ),
      ];

      await tester.pumpWidget(
        createTestApp(home: CitationsSection(citations: citations)),
      );

      // Expand the section first
      await tester.tap(find.text('1 source'));
      await tester.pumpAndSettle();

      // Citation row header visible, but content should be truncated initially
      expect(find.text('Document A'), findsOneWidget);

      // Find and tap the expand chevron on the citation row
      final expandIcons = find.byIcon(Icons.expand_more);
      expect(expandIcons, findsWidgets);
      await tester.tap(expandIcons.last);
      await tester.pumpAndSettle();

      // Content should now be fully visible (in scrollable container)
      expect(
        find.text('Full content of the citation that should be visible.'),
        findsOneWidget,
      );
    });

    testWidgets('expanded citation shows headings breadcrumb', (tester) async {
      final citations = [
        _createCitation(
          documentTitle: 'Document A',
          headings: ['Chapter 1', 'Section 2', 'Subsection'],
        ),
      ];

      await tester.pumpWidget(
        createTestApp(home: CitationsSection(citations: citations)),
      );

      // Expand section
      await tester.tap(find.text('1 source'));
      await tester.pumpAndSettle();

      // Expand citation row
      await tester.tap(find.byIcon(Icons.expand_more).last);
      await tester.pumpAndSettle();

      // Headings breadcrumb should be visible
      expect(find.text('Chapter 1 > Section 2 > Subsection'), findsOneWidget);
    });

    testWidgets('multiple citations can be expanded independently',
        (tester) async {
      final citations = [
        _createCitation(
          chunkId: 'c1',
          documentTitle: 'Document A',
          content: 'Content A',
        ),
        _createCitation(
          chunkId: 'c2',
          documentTitle: 'Document B',
          content: 'Content B',
        ),
      ];

      await tester.pumpWidget(
        createTestApp(home: CitationsSection(citations: citations)),
      );

      // Expand section
      await tester.tap(find.text('2 sources'));
      await tester.pumpAndSettle();

      // Both rows visible but collapsed
      expect(find.text('Document A'), findsOneWidget);
      expect(find.text('Document B'), findsOneWidget);

      // After section expands, section header shows expand_less,
      // so expand_more icons are only on citation rows
      final expandIcons = find.byIcon(Icons.expand_more);
      expect(expandIcons, findsNWidgets(2)); // Two citation rows

      // Expand first citation only
      await tester.tap(expandIcons.first);
      await tester.pumpAndSettle();

      // First citation expanded, second still collapsed
      expect(find.text('Content A'), findsOneWidget);
      expect(find.text('Content B'), findsNothing); // Still collapsed
    });

    testWidgets('collapsed citation hides detailed content', (tester) async {
      final citations = [
        _createCitation(
          documentTitle: 'Document A',
          content: 'Short preview of citation content.',
          headings: ['Chapter 1'],
        ),
      ];

      await tester.pumpWidget(
        createTestApp(home: CitationsSection(citations: citations)),
      );

      // Expand section
      await tester.tap(find.text('1 source'));
      await tester.pumpAndSettle();

      // Headings should NOT be visible when citation is collapsed
      expect(find.text('Chapter 1'), findsNothing);

      // Expand citation
      await tester.tap(find.byIcon(Icons.expand_more).last);
      await tester.pumpAndSettle();

      // Now headings visible
      expect(find.text('Chapter 1'), findsOneWidget);

      // Collapse citation
      await tester.tap(find.byIcon(Icons.expand_less).last);
      await tester.pumpAndSettle();

      // Headings hidden again
      expect(find.text('Chapter 1'), findsNothing);
    });
  });
}
