import 'package:flutter/material.dart';

import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import 'package:soliplex_frontend/design/design.dart';
import 'package:soliplex_frontend/shared/widgets/markdown/code_block_builder.dart';
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
      builders: {
        'code': CodeBlockBuilder(
          preferredStyle: monoStyle.copyWith(fontSize: 14),
        ),
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
