import 'package:flutter/widgets.dart';

/// Defines a custom markdown block type that renders as a native widget.
///
/// The concrete markdown renderer translates each extension into the
/// underlying package's syntax parser and element builder.
class MarkdownBlockExtension {
  const MarkdownBlockExtension({
    required this.pattern,
    required this.tag,
    required this.builder,
    this.endPattern,
  });

  /// Pattern to detect this block type in markdown text.
  final RegExp pattern;

  /// Closing pattern for multi-line blocks. When set, the parser
  /// consumes lines until this pattern matches, collecting them
  /// as the block content.
  final RegExp? endPattern;

  /// Tag name used to identify this block type.
  final String tag;

  /// Builds a widget from the matched block content and attributes.
  final Widget Function(String content, Map<String, String> attributes) builder;
}
