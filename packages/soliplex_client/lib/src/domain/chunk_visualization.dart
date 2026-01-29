import 'package:meta/meta.dart';

/// Page images for a chunk, with chunk text highlighted.
///
/// Used to display visual context for PDF citations.
@immutable
class ChunkVisualization {
  /// Creates a ChunkVisualization with the given properties.
  const ChunkVisualization({
    required this.chunkId,
    required this.documentUri,
    required this.imagesBase64,
  });

  /// Creates a ChunkVisualization from JSON.
  factory ChunkVisualization.fromJson(Map<String, dynamic> json) {
    return ChunkVisualization(
      chunkId: json['chunk_id'] as String,
      documentUri: json['document_uri'] as String?,
      imagesBase64: (json['images_base_64'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
    );
  }

  /// The chunk ID this visualization is for.
  final String chunkId;

  /// The document URI, if available.
  final String? documentUri;

  /// Base64-encoded page images with chunk text highlighted.
  final List<String> imagesBase64;

  /// Whether there are images to display.
  bool get hasImages => imagesBase64.isNotEmpty;

  /// Number of page images.
  int get imageCount => imagesBase64.length;

  /// Converts this ChunkVisualization to JSON.
  Map<String, dynamic> toJson() => {
        'chunk_id': chunkId,
        'document_uri': documentUri,
        'images_base_64': imagesBase64,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChunkVisualization && chunkId == other.chunkId;

  @override
  int get hashCode => chunkId.hashCode;

  @override
  String toString() =>
      'ChunkVisualization(chunkId: $chunkId, images: $imageCount)';
}
