import 'package:flutter/material.dart';

/// Returns the appropriate icon for a document based on its file extension.
///
/// Maps common file types to recognizable Material icons:
/// - PDF files: [Icons.picture_as_pdf]
/// - Word documents (.doc, .docx): [Icons.description]
/// - Excel spreadsheets (.xls, .xlsx): [Icons.table_chart]
/// - PowerPoint presentations (.ppt, .pptx): [Icons.slideshow]
/// - Images (.png, .jpg, .jpeg, .gif, .webp, .bmp): [Icons.image]
/// - Text/markdown (.txt, .md): [Icons.article]
/// - Unknown/missing extensions: [Icons.insert_drive_file]
///
/// Extension matching is case-insensitive.
///
/// Example:
/// ```dart
/// final icon = getFileTypeIcon('document.pdf');  // Icons.picture_as_pdf
/// final icon = getFileTypeIcon('/path/to/file.DOCX');  // Icons.description
/// final icon = getFileTypeIcon('unknown');  // Icons.insert_drive_file
/// ```
IconData getFileTypeIcon(String path) {
  final extension = _extractExtension(path);

  return switch (extension) {
    'pdf' => Icons.picture_as_pdf,
    'doc' || 'docx' => Icons.description,
    'xls' || 'xlsx' => Icons.table_chart,
    'ppt' || 'pptx' => Icons.slideshow,
    'png' || 'jpg' || 'jpeg' || 'gif' || 'webp' || 'bmp' => Icons.image,
    'txt' || 'md' => Icons.article,
    _ => Icons.insert_drive_file,
  };
}

/// Extracts the lowercase file extension from a path.
///
/// Returns an empty string if no extension is found.
String _extractExtension(String path) {
  // Remove query strings and fragments
  var cleanPath = path.split('?').first.split('#').first;

  // Remove file:// prefix if present
  if (cleanPath.startsWith('file://')) {
    cleanPath = cleanPath.substring(7);
  }

  // Get the filename (last path segment)
  final segments = cleanPath.split('/');
  final filename = segments.isNotEmpty ? segments.last : cleanPath;

  // Find the last dot that has characters after it
  final lastDot = filename.lastIndexOf('.');
  if (lastDot == -1 || lastDot == filename.length - 1) {
    return '';
  }

  return filename.substring(lastDot + 1).toLowerCase();
}
