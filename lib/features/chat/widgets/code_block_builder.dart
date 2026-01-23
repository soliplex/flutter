import 'package:flutter/material.dart';

import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/github.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;

/// Custom markdown builder for code blocks with syntax highlighting.
class CodeBlockBuilder extends MarkdownElementBuilder {
  CodeBlockBuilder({required this.preferredStyle});

  final TextStyle preferredStyle;

  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final code = element.textContent;
    var language = 'plaintext';

    // Get language from class attribute (e.g., "language-dart")
    final className = element.attributes['class'];
    if (className != null && className.startsWith('language-')) {
      language = className.replaceFirst('language-', '');
    }

    final semanticLabel =
        language == 'plaintext' ? 'Code block' : 'Code block in $language';

    return Semantics(
      label: semanticLabel,
      child: Container(
        padding: const EdgeInsets.all(12),
        child: HighlightView(
          code,
          language: language,
          theme: githubTheme,
          padding: EdgeInsets.zero,
          textStyle: this.preferredStyle,
        ),
      ),
    );
  }
}
