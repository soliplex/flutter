import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/github.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;

/// Renders inline code as a styled span with background, padding, and
/// border radius — matching typical markdown renderers (GitHub, VS Code).
///
/// Registered for the `'code'` tag. Fenced code blocks are handled by
/// [CodeBlockBuilder] under the `'pre'` tag.
///
/// For fenced code blocks (`pre > code`), this builder also fires for the
/// inner `code` element, but the returned widget is discarded — the `'pre'`
/// builder's result takes precedence in flutter_markdown_plus's pipeline.
class InlineCodeBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          colorScheme.onSurface.withAlpha(30),
          colorScheme.surface,
        ),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        element.textContent,
        style: preferredStyle?.copyWith(backgroundColor: Colors.transparent),
      ),
    );
  }
}

/// Custom markdown builder for fenced code blocks with syntax highlighting.
///
/// Registered for the `'pre'` tag so that inline code (`<code>`) is handled
/// separately by [InlineCodeBuilder].
class CodeBlockBuilder extends MarkdownElementBuilder {
  CodeBlockBuilder({required this.preferredStyle});

  final TextStyle preferredStyle;

  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final code = element.textContent;
    final language = _languageFrom(element);

    final semanticLabel =
        language == 'plaintext' ? 'Code block' : 'Code block in $language';

    return Semantics(
      label: semanticLabel,
      child: _CodeBlock(
        code: code,
        language: language,
        codeStyle: this.preferredStyle,
      ),
    );
  }

  /// Extracts the language from the child `code` element's class attribute.
  ///
  /// A fenced code block's AST is `pre > code(class="language-xxx") > Text`.
  static String _languageFrom(md.Element pre) {
    final children = pre.children;
    if (children != null) {
      for (final child in children) {
        if (child is md.Element && child.tag == 'code') {
          final className = child.attributes['class'];
          if (className != null && className.startsWith('language-')) {
            return className.replaceFirst('language-', '');
          }
        }
      }
    }
    return 'plaintext';
  }
}

class _CodeBlock extends StatelessWidget {
  const _CodeBlock({
    required this.code,
    required this.language,
    required this.codeStyle,
  });

  final String code;
  final String language;
  final TextStyle codeStyle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            if (language != 'plaintext')
              Padding(
                padding: const EdgeInsets.only(left: 12, top: 4),
                child: Text(
                  language,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.only(right: 4, top: 4),
              child: Tooltip(
                message: 'Copy code',
                child: InkWell(
                  borderRadius: BorderRadius.circular(4),
                  onTap: () => _copy(context),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      Icons.copy,
                      size: 16,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: HighlightView(
            code,
            language: language,
            theme: githubTheme,
            padding: EdgeInsets.zero,
            textStyle: codeStyle,
          ),
        ),
      ],
    );
  }

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (!context.mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      const SnackBar(content: Text('Copied to clipboard')),
    );
  }
}
