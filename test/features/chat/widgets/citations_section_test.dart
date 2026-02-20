import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soliplex_client/soliplex_client.dart' show SourceReference;
import 'package:soliplex_frontend/core/providers/citations_expanded_provider.dart';
import 'package:soliplex_frontend/core/providers/threads_provider.dart';
import 'package:soliplex_frontend/features/chat/widgets/chunk_visualization_page.dart';
import 'package:soliplex_frontend/features/chat/widgets/citations_section.dart';
import 'package:soliplex_frontend/shared/widgets/markdown/flutter_markdown_plus_renderer.dart';

import '../../../helpers/test_helpers.dart';

const _testThreadId = 'test-thread';

SourceReference _createSourceReference({
  String chunkId = 'chunk-1',
  String content = 'Test citation content for display.',
  String documentId = 'doc-1',
  String? documentTitle = 'Test Document',
  String documentUri = 'https://example.com/doc.pdf',
  List<String> headings = const [],
  int? index,
  List<int> pageNumbers = const [],
}) {
  return SourceReference(
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
      final sourceRefs = [
        _createSourceReference(chunkId: 'c1'),
        _createSourceReference(chunkId: 'c2'),
      ];

      await tester.pumpWidget(
        createTestApp(
          home: CitationsSection(
            messageId: 'test-msg',
            sourceReferences: sourceRefs,
          ),
          overrides: [
            threadSelectionProviderOverride(
              const ThreadSelected(_testThreadId),
            ),
          ],
        ),
      );

      expect(find.text('2 sources'), findsOneWidget);
    });

    testWidgets('expands to show citation rows when header tapped',
        (tester) async {
      final sourceRefs = [
        _createSourceReference(documentTitle: 'Document A'),
        _createSourceReference(documentTitle: 'Document B'),
      ];

      await tester.pumpWidget(
        createTestApp(
          home: CitationsSection(
            messageId: 'test-msg',
            sourceReferences: sourceRefs,
          ),
          overrides: [
            threadSelectionProviderOverride(
              const ThreadSelected(_testThreadId),
            ),
          ],
        ),
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

    testWidgets('returns empty widget when sourceReferences list is empty',
        (tester) async {
      await tester.pumpWidget(
        createTestApp(
          home: const CitationsSection(
            messageId: 'empty-msg',
            sourceReferences: [],
          ),
          overrides: [
            threadSelectionProviderOverride(
              const ThreadSelected(_testThreadId),
            ),
          ],
        ),
      );

      expect(find.byType(CitationsSection), findsOneWidget);
      expect(find.byType(SizedBox), findsWidgets);
    });

    testWidgets('returns empty widget when no thread selected', (tester) async {
      final sourceRefs = [_createSourceReference(documentTitle: 'Document A')];

      await tester.pumpWidget(
        createTestApp(
          home: CitationsSection(
            messageId: 'test-msg',
            sourceReferences: sourceRefs,
          ),
          overrides: [
            threadSelectionProviderOverride(const NoThreadSelected()),
          ],
        ),
      );

      // Should render nothing when no thread is selected
      expect(find.text('1 source'), findsNothing);
    });

    testWidgets('expand state persists in provider', (tester) async {
      final sourceRefs = [_createSourceReference(documentTitle: 'Document A')];
      late ProviderContainer container;

      await tester.pumpWidget(
        createTestApp(
          home: CitationsSection(
            messageId: 'persist-msg',
            sourceReferences: sourceRefs,
          ),
          overrides: [
            threadSelectionProviderOverride(
              const ThreadSelected(_testThreadId),
            ),
          ],
          onContainerCreated: (c) => container = c,
        ),
      );

      // Initially collapsed
      expect(
        container
            .read(citationsExpandedProvider(_testThreadId))
            .contains('persist-msg'),
        isFalse,
      );

      // Tap to expand
      await tester.tap(find.text('1 source'));
      await tester.pumpAndSettle();

      // Provider state updated
      expect(
        container
            .read(citationsExpandedProvider(_testThreadId))
            .contains('persist-msg'),
        isTrue,
      );

      // Tap to collapse
      await tester.tap(find.text('1 source'));
      await tester.pumpAndSettle();

      // Provider state updated
      expect(
        container
            .read(citationsExpandedProvider(_testThreadId))
            .contains('persist-msg'),
        isFalse,
      );
    });
  });

  group('CitationsSection individual expand', () {
    testWidgets('citation row can be expanded by tapping', (tester) async {
      final sourceRefs = [
        _createSourceReference(
          documentTitle: 'Document A',
          content: 'Full content of the citation that should be visible.',
        ),
      ];

      await tester.pumpWidget(
        createTestApp(
          home: CitationsSection(
            messageId: 'test-msg',
            sourceReferences: sourceRefs,
          ),
          overrides: [
            threadSelectionProviderOverride(
              const ThreadSelected(_testThreadId),
            ),
          ],
        ),
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
      final sourceRefs = [
        _createSourceReference(
          documentTitle: 'Document A',
          headings: ['Chapter 1', 'Section 2', 'Subsection'],
        ),
      ];

      await tester.pumpWidget(
        createTestApp(
          home: CitationsSection(
            messageId: 'test-msg',
            sourceReferences: sourceRefs,
          ),
          overrides: [
            threadSelectionProviderOverride(
              const ThreadSelected(_testThreadId),
            ),
          ],
        ),
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
      final sourceRefs = [
        _createSourceReference(
          chunkId: 'c1',
          documentTitle: 'Document A',
          content: 'Content A',
        ),
        _createSourceReference(
          chunkId: 'c2',
          documentTitle: 'Document B',
          content: 'Content B',
        ),
      ];

      await tester.pumpWidget(
        createTestApp(
          home: CitationsSection(
            messageId: 'test-msg',
            sourceReferences: sourceRefs,
          ),
          overrides: [
            threadSelectionProviderOverride(
              const ThreadSelected(_testThreadId),
            ),
          ],
        ),
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

    testWidgets('expanded citation shows file path', (tester) async {
      final sourceRefs = [
        _createSourceReference(
          documentTitle: 'Document A',
          documentUri: 'file:///path/to/document.pdf',
        ),
      ];

      await tester.pumpWidget(
        createTestApp(
          home: CitationsSection(
            messageId: 'test-msg',
            sourceReferences: sourceRefs,
          ),
          overrides: [
            threadSelectionProviderOverride(
              const ThreadSelected(_testThreadId),
            ),
          ],
        ),
      );

      // Expand section
      await tester.tap(find.text('1 source'));
      await tester.pumpAndSettle();

      // Expand citation row
      await tester.tap(find.byIcon(Icons.expand_more).last);
      await tester.pumpAndSettle();

      // File path should be visible
      expect(find.text('file:///path/to/document.pdf'), findsOneWidget);
    });

    testWidgets('collapsed citation hides detailed content', (tester) async {
      final sourceRefs = [
        _createSourceReference(
          documentTitle: 'Document A',
          content: 'Short preview of citation content.',
          headings: ['Chapter 1'],
        ),
      ];

      await tester.pumpWidget(
        createTestApp(
          home: CitationsSection(
            messageId: 'test-msg',
            sourceReferences: sourceRefs,
          ),
          overrides: [
            threadSelectionProviderOverride(
              const ThreadSelected(_testThreadId),
            ),
          ],
        ),
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

    testWidgets('individual citation expand state persists in provider',
        (tester) async {
      final sourceRefs = [
        _createSourceReference(
          documentTitle: 'Document A',
          content: 'Content A',
        ),
      ];
      late ProviderContainer container;

      await tester.pumpWidget(
        createTestApp(
          home: CitationsSection(
            messageId: 'persist-msg',
            sourceReferences: sourceRefs,
          ),
          overrides: [
            threadSelectionProviderOverride(
              const ThreadSelected(_testThreadId),
            ),
          ],
          onContainerCreated: (c) => container = c,
        ),
      );

      // Expand section first
      await tester.tap(find.text('1 source'));
      await tester.pumpAndSettle();

      // Individual citation initially collapsed
      expect(
        container
            .read(citationsExpandedProvider(_testThreadId))
            .contains('persist-msg:0'),
        isFalse,
      );

      // Expand citation
      await tester.tap(find.byIcon(Icons.expand_more).last);
      await tester.pumpAndSettle();

      // Provider state updated with composite key
      expect(
        container
            .read(citationsExpandedProvider(_testThreadId))
            .contains('persist-msg:0'),
        isTrue,
      );
    });
  });

  group('CitationsSection markdown rendering', () {
    testWidgets('renders citation content as markdown', (tester) async {
      final sourceRefs = [
        _createSourceReference(
          content: 'Some **bold** text and a [link](https://example.com).',
        ),
      ];

      await tester.pumpWidget(
        createTestApp(
          home: CitationsSection(
            messageId: 'test-msg',
            sourceReferences: sourceRefs,
          ),
          overrides: [
            threadSelectionProviderOverride(
              const ThreadSelected(_testThreadId),
            ),
          ],
        ),
      );

      // Expand section
      await tester.tap(find.text('1 source'));
      await tester.pumpAndSettle();

      // Expand individual citation
      await tester.tap(find.byIcon(Icons.expand_more).last);
      await tester.pumpAndSettle();

      // Content should be rendered via markdown renderer, not plain Text
      expect(
        find.byType(FlutterMarkdownPlusRenderer),
        findsOneWidget,
      );
    });
  });

  group('CitationsSection PDF visibility button', () {
    testWidgets('shows visibility button for PDF citations', (tester) async {
      // Default _createCitation uses .pdf extension
      final sourceRefs = [_createSourceReference()];

      await tester.pumpWidget(
        createTestApp(
          home: CitationsSection(
            messageId: 'test-msg',
            sourceReferences: sourceRefs,
          ),
          overrides: [
            threadSelectionProviderOverride(
              const ThreadSelected(_testThreadId),
            ),
            currentRoomIdProviderOverride('test-room'),
          ],
        ),
      );

      // Expand section
      await tester.tap(find.text('1 source'));
      await tester.pumpAndSettle();

      // Visibility button should be visible
      expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
    });

    testWidgets('does not show visibility button for non-PDF citations',
        (tester) async {
      final sourceRefs = [
        _createSourceReference(documentUri: 'https://example.com/doc.html'),
      ];

      await tester.pumpWidget(
        createTestApp(
          home: CitationsSection(
            messageId: 'test-msg',
            sourceReferences: sourceRefs,
          ),
          overrides: [
            threadSelectionProviderOverride(
              const ThreadSelected(_testThreadId),
            ),
            currentRoomIdProviderOverride('test-room'),
          ],
        ),
      );

      // Expand section
      await tester.tap(find.text('1 source'));
      await tester.pumpAndSettle();

      // Visibility button should NOT be visible
      expect(find.byIcon(Icons.visibility_outlined), findsNothing);
    });

    testWidgets('does not show visibility button when no room selected',
        (tester) async {
      // Default _createCitation uses .pdf extension
      final sourceRefs = [_createSourceReference()];

      await tester.pumpWidget(
        createTestApp(
          home: CitationsSection(
            messageId: 'test-msg',
            sourceReferences: sourceRefs,
          ),
          overrides: [
            threadSelectionProviderOverride(
              const ThreadSelected(_testThreadId),
            ),
            currentRoomIdProviderOverride(null),
          ],
        ),
      );

      // Expand section
      await tester.tap(find.text('1 source'));
      await tester.pumpAndSettle();

      // Visibility button should NOT be visible (no room context)
      expect(find.byIcon(Icons.visibility_outlined), findsNothing);
    });

    testWidgets('opens dialog when visibility button tapped', (tester) async {
      // Default _createCitation uses .pdf extension
      final sourceRefs = [_createSourceReference()];

      await tester.pumpWidget(
        createTestApp(
          home: CitationsSection(
            messageId: 'test-msg',
            sourceReferences: sourceRefs,
          ),
          overrides: [
            threadSelectionProviderOverride(
              const ThreadSelected(_testThreadId),
            ),
            currentRoomIdProviderOverride('test-room'),
          ],
        ),
      );

      // Expand section
      await tester.tap(find.text('1 source'));
      await tester.pumpAndSettle();

      // Tap visibility button
      await tester.tap(find.byIcon(Icons.visibility_outlined));
      await tester.pumpAndSettle();

      // Full-screen page should open with document title
      expect(find.byType(ChunkVisualizationPage), findsOneWidget);
      expect(find.text('Test Document'), findsWidgets);
    });
  });
}
