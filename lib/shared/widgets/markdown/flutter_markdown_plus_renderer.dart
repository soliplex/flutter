import 'package:flutter/material.dart';

import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;

import 'package:soliplex_frontend/design/design.dart';
import 'package:soliplex_frontend/shared/widgets/markdown/code_block_builder.dart';
import 'package:soliplex_frontend/shared/widgets/markdown/markdown_block_extension.dart';
import 'package:soliplex_frontend/shared/widgets/markdown/markdown_renderer.dart';
import 'package:soliplex_frontend/shared/widgets/markdown/markdown_theme_extension.dart';

/// Renders markdown using `flutter_markdown_plus`.
///
/// This is the only file that imports the markdown package. Swapping packages
/// means rewriting this class and updating pubspec.yaml.
class FlutterMarkdownPlusRenderer extends MarkdownRenderer {
  const FlutterMarkdownPlusRenderer({
    required super.data,
    super.onLinkTap,
    super.onImageTap,
    super.blockExtensions,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final markdownTheme = Theme.of(context).extension<MarkdownThemeExtension>();
    final monoStyle = context.monospace;

    return MarkdownBody(
      data: _sanitize(data),
      styleSheet: markdownTheme?.toMarkdownStyleSheet(
        codeFontStyle: monoStyle,
      ),
      onTapLink: onLinkTap == null
          ? null
          : (_, href, title) {
              if (href != null) onLinkTap!(href, title);
            },
      imageBuilder: onImageTap == null ? null : _buildImage,
      blockSyntaxes: [
        for (final ext in blockExtensions.values) _ExtensionBlockSyntax(ext),
      ],
      builders: {
        'code': CodeBlockBuilder(
          preferredStyle: monoStyle.copyWith(fontSize: 14),
        ),
        for (final ext in blockExtensions.values)
          ext.tag: _ExtensionElementBuilder(ext),
      },
    );
  }

  Widget _buildImage(Uri uri, String? title, String? alt) {
    return GestureDetector(
      onTap: () => onImageTap!(uri.toString(), alt),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 400),
        child: Image.network(
          uri.toString(),
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const Icon(
            Icons.broken_image,
            size: 48,
            color: Colors.grey,
          ),
        ),
      ),
    );
  }

  static final _brTag = RegExp(r'<br\s*/?>');

  static String _sanitize(String markdown) => markdown.replaceAll(_brTag, '\n');
}

/// Adapts [MarkdownBlockExtension] to [md.BlockSyntax].
class _ExtensionBlockSyntax extends md.BlockSyntax {
  _ExtensionBlockSyntax(this._extension);

  final MarkdownBlockExtension _extension;

  @override
  RegExp get pattern => _extension.pattern;

  @override
  md.Node parse(md.BlockParser parser) {
    final endPattern = _extension.endPattern;
    if (endPattern != null) return _parseMultiLine(parser, endPattern);

    final line = parser.current.content;
    parser.advance();
    final match = pattern.firstMatch(line);
    final content =
        match != null && match.groupCount > 0 ? match.group(1)! : line;
    return md.Element.text(_extension.tag, content);
  }

  md.Node _parseMultiLine(md.BlockParser parser, RegExp endPattern) {
    parser.advance(); // skip opening fence
    final lines = <String>[];
    while (!parser.isDone) {
      if (endPattern.hasMatch(parser.current.content)) {
        parser.advance(); // skip closing fence
        break;
      }
      lines.add(parser.current.content);
      parser.advance();
    }
    return md.Element.text(_extension.tag, lines.join('\n'));
  }
}

/// Adapts [MarkdownBlockExtension] to [MarkdownElementBuilder].
class _ExtensionElementBuilder extends MarkdownElementBuilder {
  _ExtensionElementBuilder(this._extension);

  final MarkdownBlockExtension _extension;

  @override
  bool isBlockElement() => true;

  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    return _extension.builder(element.textContent, element.attributes);
  }
}
