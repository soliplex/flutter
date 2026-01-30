import 'package:soliplex_client/src/schema/agui_features/haiku_rag_chat.dart';

/// Formatting utilities for [Citation] display.
extension CitationFormatting on Citation {
  /// Formats page numbers for display.
  ///
  /// Returns:
  /// - `null` if no page numbers
  /// - `"p.5"` for single page
  /// - `"p.1-3"` for consecutive pages
  /// - `"p.1, 5, 10"` for non-consecutive pages
  String? get formattedPageNumbers {
    final pages = pageNumbers;
    if (pages == null || pages.isEmpty) return null;
    if (pages.length == 1) return 'p.${pages.first}';

    final sorted = [...pages]..sort();

    var isConsecutive = true;
    for (var i = 1; i < sorted.length; i++) {
      if (sorted[i] != sorted[i - 1] + 1) {
        isConsecutive = false;
        break;
      }
    }

    if (isConsecutive) {
      return 'p.${sorted.first}-${sorted.last}';
    } else {
      return 'p.${sorted.join(', ')}';
    }
  }

  /// Returns a display-friendly title for the citation.
  ///
  /// Uses [documentTitle] if present, otherwise extracts filename from
  /// [documentUri]. Falls back to "Unknown Document" if neither works.
  String get displayTitle {
    if (documentTitle != null && documentTitle!.isNotEmpty) {
      return documentTitle!;
    }

    final uri = Uri.tryParse(documentUri);
    if (uri != null && uri.pathSegments.isNotEmpty) {
      return uri.pathSegments.last;
    }

    return 'Unknown Document';
  }

  /// Whether this citation references a PDF document.
  bool get isPdf => documentUri.toLowerCase().endsWith('.pdf');
}
