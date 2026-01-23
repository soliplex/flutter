import 'package:meta/meta.dart';

/// Represents a document available for narrowing RAG searches.
///
/// Documents are fetched from a room and can be selected to limit
/// the scope of RAG queries to specific documents.
@immutable
class RagDocument {
  /// Creates a RAG document.
  const RagDocument({required this.id, required this.title});

  /// Unique identifier for the document (UUID).
  final String id;

  /// Display title of the document.
  final String title;

  /// Creates a copy of this document with the given fields replaced.
  RagDocument copyWith({String? id, String? title}) {
    return RagDocument(id: id ?? this.id, title: title ?? this.title);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RagDocument && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'RagDocument(id: $id, title: $title)';
}
