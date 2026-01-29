import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:soliplex_client/soliplex_client.dart';
import 'package:soliplex_frontend/core/providers/api_provider.dart';
import 'package:soliplex_frontend/core/providers/chunk_visualization_provider.dart';

import '../../helpers/test_helpers.dart';

void main() {
  late MockSoliplexApi mockApi;

  setUp(() {
    mockApi = MockSoliplexApi();
  });

  group('chunkVisualizationProvider', () {
    test('fetches chunk visualization from API', () async {
      const expected = ChunkVisualization(
        chunkId: 'chunk-123',
        documentUri: 'doc.pdf',
        imagesBase64: ['img1', 'img2'],
      );

      when(() => mockApi.getChunkVisualization('room-1', 'chunk-123'))
          .thenAnswer((_) async => expected);

      final container = ProviderContainer(
        overrides: [apiProvider.overrideWithValue(mockApi)],
      );
      addTearDown(container.dispose);

      final result = await container.read(
        chunkVisualizationProvider((roomId: 'room-1', chunkId: 'chunk-123'))
            .future,
      );

      expect(result, equals(expected));
      verify(() => mockApi.getChunkVisualization('room-1', 'chunk-123'))
          .called(1);
    });

    test('uses correct parameters for different family keys', () async {
      when(() => mockApi.getChunkVisualization(any(), any())).thenAnswer(
        (_) async => const ChunkVisualization(
          chunkId: 'any',
          documentUri: null,
          imagesBase64: [],
        ),
      );

      final container = ProviderContainer(
        overrides: [apiProvider.overrideWithValue(mockApi)],
      );
      addTearDown(container.dispose);

      // Fetch two different chunks
      await container.read(
        chunkVisualizationProvider((roomId: 'room-A', chunkId: 'chunk-1'))
            .future,
      );
      await container.read(
        chunkVisualizationProvider((roomId: 'room-B', chunkId: 'chunk-2'))
            .future,
      );

      verify(() => mockApi.getChunkVisualization('room-A', 'chunk-1'))
          .called(1);
      verify(() => mockApi.getChunkVisualization('room-B', 'chunk-2'))
          .called(1);
    });

    test('caches result for same family key', () async {
      when(() => mockApi.getChunkVisualization('room-1', 'chunk-1')).thenAnswer(
        (_) async => const ChunkVisualization(
          chunkId: 'chunk-1',
          documentUri: null,
          imagesBase64: [],
        ),
      );

      final container = ProviderContainer(
        overrides: [apiProvider.overrideWithValue(mockApi)],
      );
      addTearDown(container.dispose);

      // Fetch same chunk twice
      await container.read(
        chunkVisualizationProvider((roomId: 'room-1', chunkId: 'chunk-1'))
            .future,
      );
      await container.read(
        chunkVisualizationProvider((roomId: 'room-1', chunkId: 'chunk-1'))
            .future,
      );

      // Should only call API once due to caching
      verify(() => mockApi.getChunkVisualization('room-1', 'chunk-1'))
          .called(1);
    });
  });
}
