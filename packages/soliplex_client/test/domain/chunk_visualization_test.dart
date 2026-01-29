import 'package:soliplex_client/soliplex_client.dart';
import 'package:test/test.dart';

void main() {
  group('ChunkVisualization', () {
    group('construction', () {
      test('creates with all required fields', () {
        const visualization = ChunkVisualization(
          chunkId: 'chunk-123',
          documentUri: 'doc.pdf',
          imagesBase64: ['abc123', 'def456'],
        );

        expect(visualization.chunkId, equals('chunk-123'));
        expect(visualization.documentUri, equals('doc.pdf'));
        expect(visualization.imagesBase64, equals(['abc123', 'def456']));
      });

      test('creates with null documentUri', () {
        const visualization = ChunkVisualization(
          chunkId: 'chunk-123',
          documentUri: null,
          imagesBase64: ['abc123'],
        );

        expect(visualization.documentUri, isNull);
      });

      test('creates with empty images list', () {
        const visualization = ChunkVisualization(
          chunkId: 'chunk-123',
          documentUri: null,
          imagesBase64: [],
        );

        expect(visualization.imagesBase64, isEmpty);
      });
    });

    group('fromJson', () {
      test('parses complete JSON', () {
        final json = {
          'chunk_id': 'chunk-abc',
          'document_uri': 'file.pdf',
          'images_base_64': ['img1', 'img2'],
        };

        final visualization = ChunkVisualization.fromJson(json);

        expect(visualization.chunkId, equals('chunk-abc'));
        expect(visualization.documentUri, equals('file.pdf'));
        expect(visualization.imagesBase64, equals(['img1', 'img2']));
      });

      test('parses JSON with null document_uri', () {
        final json = {
          'chunk_id': 'chunk-abc',
          'document_uri': null,
          'images_base_64': ['img1'],
        };

        final visualization = ChunkVisualization.fromJson(json);

        expect(visualization.documentUri, isNull);
      });

      test('parses JSON with empty images array', () {
        final json = {
          'chunk_id': 'chunk-abc',
          'document_uri': 'doc.pdf',
          'images_base_64': <String>[],
        };

        final visualization = ChunkVisualization.fromJson(json);

        expect(visualization.imagesBase64, isEmpty);
      });
    });

    group('toJson', () {
      test('serializes all fields', () {
        const visualization = ChunkVisualization(
          chunkId: 'chunk-123',
          documentUri: 'doc.pdf',
          imagesBase64: ['abc', 'def'],
        );

        final json = visualization.toJson();

        expect(json['chunk_id'], equals('chunk-123'));
        expect(json['document_uri'], equals('doc.pdf'));
        expect(json['images_base_64'], equals(['abc', 'def']));
      });

      test('serializes null document_uri', () {
        const visualization = ChunkVisualization(
          chunkId: 'chunk-123',
          documentUri: null,
          imagesBase64: [],
        );

        final json = visualization.toJson();

        expect(json['document_uri'], isNull);
      });
    });

    group('roundtrip', () {
      test('fromJson/toJson preserves all data', () {
        const original = ChunkVisualization(
          chunkId: 'chunk-roundtrip',
          documentUri: 'test.pdf',
          imagesBase64: ['img1', 'img2', 'img3'],
        );

        final json = original.toJson();
        final restored = ChunkVisualization.fromJson(json);

        expect(restored.chunkId, equals(original.chunkId));
        expect(restored.documentUri, equals(original.documentUri));
        expect(restored.imagesBase64, equals(original.imagesBase64));
      });
    });

    group('computed properties', () {
      test('hasImages returns true when images exist', () {
        const visualization = ChunkVisualization(
          chunkId: 'chunk-123',
          documentUri: null,
          imagesBase64: ['img1'],
        );

        expect(visualization.hasImages, isTrue);
      });

      test('hasImages returns false when images empty', () {
        const visualization = ChunkVisualization(
          chunkId: 'chunk-123',
          documentUri: null,
          imagesBase64: [],
        );

        expect(visualization.hasImages, isFalse);
      });

      test('imageCount returns correct count', () {
        const visualization = ChunkVisualization(
          chunkId: 'chunk-123',
          documentUri: null,
          imagesBase64: ['a', 'b', 'c'],
        );

        expect(visualization.imageCount, equals(3));
      });

      test('imageCount returns zero for empty list', () {
        const visualization = ChunkVisualization(
          chunkId: 'chunk-123',
          documentUri: null,
          imagesBase64: [],
        );

        expect(visualization.imageCount, equals(0));
      });
    });

    group('equality', () {
      test('equal when chunkId matches', () {
        const a = ChunkVisualization(
          chunkId: 'chunk-123',
          documentUri: 'doc1.pdf',
          imagesBase64: ['img1'],
        );
        const b = ChunkVisualization(
          chunkId: 'chunk-123',
          documentUri: 'doc2.pdf',
          imagesBase64: ['img2', 'img3'],
        );

        expect(a, equals(b));
        expect(a.hashCode, equals(b.hashCode));
      });

      test('not equal when chunkId differs', () {
        const a = ChunkVisualization(
          chunkId: 'chunk-123',
          documentUri: 'doc.pdf',
          imagesBase64: ['img1'],
        );
        const b = ChunkVisualization(
          chunkId: 'chunk-456',
          documentUri: 'doc.pdf',
          imagesBase64: ['img1'],
        );

        expect(a, isNot(equals(b)));
      });
    });

    group('toString', () {
      test('includes chunkId and image count', () {
        const visualization = ChunkVisualization(
          chunkId: 'chunk-test',
          documentUri: null,
          imagesBase64: ['a', 'b'],
        );

        expect(visualization.toString(), contains('chunk-test'));
        expect(visualization.toString(), contains('2'));
      });
    });
  });
}
