import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/github.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
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
      child: _CodeBlock(
        code: code,
        language: language,
        codeStyle: this.preferredStyle,
      ),
    );
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
