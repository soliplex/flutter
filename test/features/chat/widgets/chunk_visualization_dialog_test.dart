import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:soliplex_client/soliplex_client.dart';
import 'package:soliplex_frontend/core/providers/api_provider.dart';
import 'package:soliplex_frontend/features/chat/widgets/chunk_visualization_dialog.dart';

import '../../../helpers/test_helpers.dart';

void main() {
  late MockSoliplexApi mockApi;

  setUp(() {
    mockApi = MockSoliplexApi();
  });

  group('ChunkVisualizationDialog', () {
    testWidgets('shows loading indicator while fetching', (tester) async {
      // Never complete the future to keep loading state
      when(() => mockApi.getChunkVisualization(any(), any()))
          .thenAnswer((_) => Future.delayed(const Duration(days: 1)));

      await tester.pumpWidget(
        createTestApp(
          home: const ChunkVisualizationDialog(
            roomId: 'room-1',
            chunkId: 'chunk-1',
            documentTitle: 'Test Document',
          ),
          overrides: [apiProvider.overrideWithValue(mockApi)],
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Test Document'), findsOneWidget);
    });

    testWidgets('shows images when loaded successfully', (tester) async {
      // Use a minimal valid PNG (1x1 transparent pixel)
      const base64Png =
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk'
          '+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==';

      when(() => mockApi.getChunkVisualization('room-1', 'chunk-1')).thenAnswer(
        (_) async => const ChunkVisualization(
          chunkId: 'chunk-1',
          documentUri: 'doc.pdf',
          imagesBase64: [base64Png, base64Png],
        ),
      );

      await tester.pumpWidget(
        createTestApp(
          home: const ChunkVisualizationDialog(
            roomId: 'room-1',
            chunkId: 'chunk-1',
            documentTitle: 'Test Document',
          ),
          overrides: [apiProvider.overrideWithValue(mockApi)],
        ),
      );

      await tester.pumpAndSettle();

      // Should show page numbers
      expect(find.text('Page 1 of 2'), findsOneWidget);
      expect(find.text('Page 2 of 2'), findsOneWidget);
    });

    testWidgets('shows empty state when no images', (tester) async {
      when(() => mockApi.getChunkVisualization('room-1', 'chunk-1')).thenAnswer(
        (_) async => const ChunkVisualization(
          chunkId: 'chunk-1',
          documentUri: null,
          imagesBase64: [],
        ),
      );

      await tester.pumpWidget(
        createTestApp(
          home: const ChunkVisualizationDialog(
            roomId: 'room-1',
            chunkId: 'chunk-1',
            documentTitle: 'Test Document',
          ),
          overrides: [apiProvider.overrideWithValue(mockApi)],
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('No page images available.'), findsOneWidget);
      expect(find.byIcon(Icons.image_not_supported_outlined), findsOneWidget);
    });

    testWidgets('shows error state with retry on NotFoundException',
        (tester) async {
      when(() => mockApi.getChunkVisualization('room-1', 'chunk-1'))
          .thenThrow(const NotFoundException(message: 'Chunk not found'));

      await tester.pumpWidget(
        createTestApp(
          home: const ChunkVisualizationDialog(
            roomId: 'room-1',
            chunkId: 'chunk-1',
            documentTitle: 'Test Document',
          ),
          overrides: [apiProvider.overrideWithValue(mockApi)],
        ),
      );

      await tester.pumpAndSettle();

      expect(
        find.text('Page images not available for this citation.'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('shows error state with retry on NetworkException',
        (tester) async {
      when(() => mockApi.getChunkVisualization('room-1', 'chunk-1'))
          .thenThrow(const NetworkException(message: 'Connection failed'));

      await tester.pumpWidget(
        createTestApp(
          home: const ChunkVisualizationDialog(
            roomId: 'room-1',
            chunkId: 'chunk-1',
            documentTitle: 'Test Document',
          ),
          overrides: [apiProvider.overrideWithValue(mockApi)],
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Could not connect to server.'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('retry button is present on error', (tester) async {
      when(() => mockApi.getChunkVisualization('room-1', 'chunk-1'))
          .thenThrow(const NetworkException(message: 'Connection failed'));

      await tester.pumpWidget(
        createTestApp(
          home: const ChunkVisualizationDialog(
            roomId: 'room-1',
            chunkId: 'chunk-1',
            documentTitle: 'Test Document',
          ),
          overrides: [apiProvider.overrideWithValue(mockApi)],
        ),
      );

      await tester.pumpAndSettle();

      // Shows error state with retry button
      expect(find.text('Could not connect to server.'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.byIcon(Icons.refresh), findsOneWidget);
    });

    testWidgets('close button dismisses dialog', (tester) async {
      when(() => mockApi.getChunkVisualization('room-1', 'chunk-1')).thenAnswer(
        (_) async => const ChunkVisualization(
          chunkId: 'chunk-1',
          documentUri: null,
          imagesBase64: [],
        ),
      );

      await tester.pumpWidget(
        createTestApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => ChunkVisualizationDialog.show(
                context: context,
                roomId: 'room-1',
                chunkId: 'chunk-1',
                documentTitle: 'Test Document',
              ),
              child: const Text('Open Dialog'),
            ),
          ),
          overrides: [apiProvider.overrideWithValue(mockApi)],
        ),
      );

      // Open dialog
      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.byType(ChunkVisualizationDialog), findsOneWidget);

      // Close dialog
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(find.byType(ChunkVisualizationDialog), findsNothing);
    });

    testWidgets('displays document title in header', (tester) async {
      when(() => mockApi.getChunkVisualization(any(), any()))
          .thenAnswer((_) => Future.delayed(const Duration(days: 1)));

      await tester.pumpWidget(
        createTestApp(
          home: const ChunkVisualizationDialog(
            roomId: 'room-1',
            chunkId: 'chunk-1',
            documentTitle: 'My Important Document.pdf',
          ),
          overrides: [apiProvider.overrideWithValue(mockApi)],
        ),
      );

      expect(find.text('My Important Document.pdf'), findsOneWidget);
      expect(find.byIcon(Icons.picture_as_pdf), findsOneWidget);
    });
  });
}
