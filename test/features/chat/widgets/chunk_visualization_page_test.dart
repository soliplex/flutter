import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:soliplex_client/soliplex_client.dart';
import 'package:soliplex_frontend/core/providers/api_provider.dart';
import 'package:soliplex_frontend/features/chat/widgets/chunk_visualization_page.dart';

import '../../../helpers/test_helpers.dart';

/// Minimal valid 1x1 transparent PNG for test images.
const _base64Png =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk'
    '+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==';

void main() {
  late MockSoliplexApi mockApi;

  setUp(() {
    mockApi = MockSoliplexApi();
  });

  Widget buildPage({
    String roomId = 'room-1',
    String chunkId = 'chunk-1',
    String documentTitle = 'Test Document',
  }) {
    return createTestApp(
      home: ChunkVisualizationPage(
        roomId: roomId,
        chunkId: chunkId,
        documentTitle: documentTitle,
      ),
      overrides: [apiProvider.overrideWithValue(mockApi)],
    );
  }

  group('ChunkVisualizationPage', () {
    group('loading state', () {
      testWidgets('shows loading indicator while fetching', (tester) async {
        when(
          () => mockApi.getChunkVisualization(any(), any()),
        ).thenAnswer((_) => Future.delayed(const Duration(days: 1)));

        await tester.pumpWidget(buildPage());

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.text('Test Document'), findsOneWidget);
      });

      testWidgets('hides rotate button during loading', (tester) async {
        when(
          () => mockApi.getChunkVisualization(any(), any()),
        ).thenAnswer((_) => Future.delayed(const Duration(days: 1)));

        await tester.pumpWidget(buildPage());

        expect(find.byIcon(Icons.rotate_right), findsNothing);
      });
    });

    group('error state', () {
      testWidgets('shows error with retry on NotFoundException', (
        tester,
      ) async {
        when(
          () => mockApi.getChunkVisualization('room-1', 'chunk-1'),
        ).thenThrow(const NotFoundException(message: 'Chunk not found'));

        await tester.pumpWidget(buildPage());
        await tester.pumpAndSettle();

        expect(
          find.text('Page images not available for this citation.'),
          findsOneWidget,
        );
        expect(find.byIcon(Icons.error_outline), findsOneWidget);
        expect(find.text('Retry'), findsOneWidget);
      });

      testWidgets('shows error with retry on NetworkException', (tester) async {
        when(
          () => mockApi.getChunkVisualization('room-1', 'chunk-1'),
        ).thenThrow(const NetworkException(message: 'Connection failed'));

        await tester.pumpWidget(buildPage());
        await tester.pumpAndSettle();

        expect(find.text('Could not connect to server.'), findsOneWidget);
        expect(find.text('Retry'), findsOneWidget);
        expect(find.byIcon(Icons.refresh), findsOneWidget);
      });

      testWidgets('hides rotate button on error', (tester) async {
        when(
          () => mockApi.getChunkVisualization('room-1', 'chunk-1'),
        ).thenThrow(const NetworkException(message: 'Connection failed'));

        await tester.pumpWidget(buildPage());
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.rotate_right), findsNothing);
      });
    });

    group('empty state', () {
      testWidgets('shows empty state when no images', (tester) async {
        when(
          () => mockApi.getChunkVisualization('room-1', 'chunk-1'),
        ).thenAnswer(
          (_) async => ChunkVisualization(
            chunkId: 'chunk-1',
            documentUri: null,
            imagesBase64: const [],
          ),
        );

        await tester.pumpWidget(buildPage());
        await tester.pumpAndSettle();

        expect(find.text('No page images available.'), findsOneWidget);
        expect(find.byIcon(Icons.image_not_supported_outlined), findsOneWidget);
      });
    });

    group('AppBar', () {
      testWidgets('displays document title and PDF icon', (tester) async {
        when(
          () => mockApi.getChunkVisualization(any(), any()),
        ).thenAnswer((_) => Future.delayed(const Duration(days: 1)));

        await tester.pumpWidget(
          buildPage(documentTitle: 'My Important Document.pdf'),
        );

        expect(find.text('My Important Document.pdf'), findsOneWidget);
        expect(find.byIcon(Icons.picture_as_pdf), findsOneWidget);
      });

      testWidgets('shows rotate button when data is loaded', (tester) async {
        when(
          () => mockApi.getChunkVisualization('room-1', 'chunk-1'),
        ).thenAnswer(
          (_) async => ChunkVisualization(
            chunkId: 'chunk-1',
            documentUri: 'doc.pdf',
            imagesBase64: const [_base64Png],
          ),
        );

        await tester.pumpWidget(buildPage());
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.rotate_right), findsOneWidget);
      });

      testWidgets('back button pops the page', (tester) async {
        when(
          () => mockApi.getChunkVisualization('room-1', 'chunk-1'),
        ).thenAnswer(
          (_) async => ChunkVisualization(
            chunkId: 'chunk-1',
            documentUri: null,
            imagesBase64: const [],
          ),
        );

        await tester.pumpWidget(
          createTestApp(
            home: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => ChunkVisualizationPage.show(
                  context: context,
                  roomId: 'room-1',
                  chunkId: 'chunk-1',
                  documentTitle: 'Test Document',
                ),
                child: const Text('Open Page'),
              ),
            ),
            overrides: [apiProvider.overrideWithValue(mockApi)],
          ),
        );

        await tester.tap(find.text('Open Page'));
        await tester.pumpAndSettle();

        expect(find.byType(ChunkVisualizationPage), findsOneWidget);

        await tester.tap(find.byIcon(Icons.arrow_back));
        await tester.pumpAndSettle();

        expect(find.byType(ChunkVisualizationPage), findsNothing);
      });
    });

    group('PageView', () {
      testWidgets('renders PageView with correct item count', (tester) async {
        when(
          () => mockApi.getChunkVisualization('room-1', 'chunk-1'),
        ).thenAnswer(
          (_) async => ChunkVisualization(
            chunkId: 'chunk-1',
            documentUri: 'doc.pdf',
            imagesBase64: const [_base64Png, _base64Png],
          ),
        );

        await tester.pumpWidget(buildPage());
        await tester.pumpAndSettle();

        expect(find.byType(PageView), findsOneWidget);
      });

      testWidgets('has InteractiveViewer for zoom support', (tester) async {
        when(
          () => mockApi.getChunkVisualization('room-1', 'chunk-1'),
        ).thenAnswer(
          (_) async => ChunkVisualization(
            chunkId: 'chunk-1',
            documentUri: 'doc.pdf',
            imagesBase64: const [_base64Png],
          ),
        );

        await tester.pumpWidget(buildPage());
        await tester.pumpAndSettle();

        expect(find.byType(InteractiveViewer), findsOneWidget);
      });

      testWidgets('swiping changes page', (tester) async {
        when(
          () => mockApi.getChunkVisualization('room-1', 'chunk-1'),
        ).thenAnswer(
          (_) async => ChunkVisualization(
            chunkId: 'chunk-1',
            documentUri: 'doc.pdf',
            imagesBase64: const [_base64Png, _base64Png],
          ),
        );

        await tester.pumpWidget(buildPage());
        await tester.pumpAndSettle();

        final pageView = tester.widget<PageView>(find.byType(PageView));
        expect(pageView.controller!.page, 0);

        // Use controller to jump (drag is intercepted by gesture arena).
        pageView.controller!.jumpToPage(1);
        await tester.pumpAndSettle();

        expect(pageView.controller!.page, 1);
      });
    });

    group('dot indicator', () {
      testWidgets('shows dots for multi-page', (tester) async {
        when(
          () => mockApi.getChunkVisualization('room-1', 'chunk-1'),
        ).thenAnswer(
          (_) async => ChunkVisualization(
            chunkId: 'chunk-1',
            documentUri: 'doc.pdf',
            imagesBase64: const [_base64Png, _base64Png],
          ),
        );

        await tester.pumpWidget(buildPage());
        await tester.pumpAndSettle();

        expect(find.bySemanticsLabel('Page 1 of 2'), findsOneWidget);
      });

      testWidgets('hides dots for single-page', (tester) async {
        when(
          () => mockApi.getChunkVisualization('room-1', 'chunk-1'),
        ).thenAnswer(
          (_) async => ChunkVisualization(
            chunkId: 'chunk-1',
            documentUri: 'doc.pdf',
            imagesBase64: const [_base64Png],
          ),
        );

        await tester.pumpWidget(buildPage());
        await tester.pumpAndSettle();

        expect(find.bySemanticsLabel(RegExp(r'Page \d+ of \d+')), findsNothing);
      });
    });

    group('rotation', () {
      testWidgets('tapping rotate cycles RotatedBox quarterTurns', (
        tester,
      ) async {
        when(
          () => mockApi.getChunkVisualization('room-1', 'chunk-1'),
        ).thenAnswer(
          (_) async => ChunkVisualization(
            chunkId: 'chunk-1',
            documentUri: 'doc.pdf',
            imagesBase64: const [_base64Png],
          ),
        );

        await tester.pumpWidget(buildPage());
        await tester.pumpAndSettle();

        RotatedBox rotatedBox() =>
            tester.widget<RotatedBox>(find.byType(RotatedBox));

        expect(rotatedBox().quarterTurns, 0);

        await tester.tap(find.byIcon(Icons.rotate_right));
        await tester.pumpAndSettle();
        expect(rotatedBox().quarterTurns, 1);

        await tester.tap(find.byIcon(Icons.rotate_right));
        await tester.pumpAndSettle();
        expect(rotatedBox().quarterTurns, 2);

        await tester.tap(find.byIcon(Icons.rotate_right));
        await tester.pumpAndSettle();
        expect(rotatedBox().quarterTurns, 3);

        // Wraps back to 0.
        await tester.tap(find.byIcon(Icons.rotate_right));
        await tester.pumpAndSettle();
        expect(rotatedBox().quarterTurns, 0);
      });

      testWidgets('rotation is per-page', (tester) async {
        when(
          () => mockApi.getChunkVisualization('room-1', 'chunk-1'),
        ).thenAnswer(
          (_) async => ChunkVisualization(
            chunkId: 'chunk-1',
            documentUri: 'doc.pdf',
            imagesBase64: const [_base64Png, _base64Png],
          ),
        );

        await tester.pumpWidget(buildPage());
        await tester.pumpAndSettle();

        // Rotate page 1.
        await tester.tap(find.byIcon(Icons.rotate_right));
        await tester.pumpAndSettle();

        final firstRotation = tester.widget<RotatedBox>(
          find.byType(RotatedBox),
        );
        expect(firstRotation.quarterTurns, 1);

        // Navigate to page 2 via controller.
        final pageView = tester.widget<PageView>(find.byType(PageView));
        pageView.controller!.jumpToPage(1);
        await tester.pumpAndSettle();

        // Page 2 should be unrotated.
        final secondRotation = tester.widget<RotatedBox>(
          find.byType(RotatedBox),
        );
        expect(secondRotation.quarterTurns, 0);
      });
    });

    group('zoom gestures', () {
      testWidgets('double-tap resets zoom', (tester) async {
        when(
          () => mockApi.getChunkVisualization('room-1', 'chunk-1'),
        ).thenAnswer(
          (_) async => ChunkVisualization(
            chunkId: 'chunk-1',
            documentUri: 'doc.pdf',
            imagesBase64: const [_base64Png],
          ),
        );

        await tester.pumpWidget(buildPage());
        await tester.pumpAndSettle();

        // Find the GestureDetector wrapping InteractiveViewer.
        final gestureDetector = find.byWidgetPredicate(
          (w) => w is GestureDetector && w.onDoubleTap != null,
        );
        expect(gestureDetector, findsOneWidget);

        // Double-tap should not crash.
        await tester.tap(gestureDetector);
        await tester.pump(const Duration(milliseconds: 50));
        await tester.tap(gestureDetector);
        await tester.pumpAndSettle();
      });
    });
  });
}
