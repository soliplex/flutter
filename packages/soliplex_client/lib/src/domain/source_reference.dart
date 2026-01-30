import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

/// A stable, frontend-owned citation reference.
///
/// Unlike schema types (which are generated from backend and may change),
/// SourceReference is controlled by the frontend and provides a stable API
/// for UI components to display citation information.
@immutable
class SourceReference {
  /// Creates a source reference.
  const SourceReference({
    required this.documentId,
    required this.documentUri,
    required this.content,
    required this.chunkId,
    this.documentTitle,
    this.headings = const [],
    this.pageNumbers = const [],
    this.index,
  });

  /// Unique identifier for the document.
  final String documentId;

  /// URI to access the document.
  final String documentUri;

  /// The cited text content.
  final String content;

  /// Unique identifier for this chunk within the document.
  final String chunkId;

  /// Human-readable document title, if available.
  final String? documentTitle;

  /// Heading hierarchy leading to this content.
  final List<String> headings;

  /// Page numbers where this content appears.
  final List<int> pageNumbers;

  /// Display index for numbered citations.
  final int? index;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! SourceReference) return false;
    const listEquals = ListEquality<dynamic>();
    return documentId == other.documentId &&
        documentUri == other.documentUri &&
        content == other.content &&
        chunkId == other.chunkId &&
        documentTitle == other.documentTitle &&
        listEquals.equals(headings, other.headings) &&
        listEquals.equals(pageNumbers, other.pageNumbers) &&
        index == other.index;
  }

  @override
  int get hashCode => Object.hash(
        documentId,
        documentUri,
        content,
        chunkId,
        documentTitle,
        const ListEquality<String>().hash(headings),
        const ListEquality<int>().hash(pageNumbers),
        index,
      );

  @override
  String toString() => 'SourceReference('
      'documentId: $documentId, '
      'chunkId: $chunkId, '
      'index: $index)';
}
