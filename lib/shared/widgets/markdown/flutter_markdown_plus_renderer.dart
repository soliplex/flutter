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
      data: data,
      styleSheet: markdownTheme?.toMarkdownStyleSheet(
        codeFontStyle: monoStyle,
      ),
      builders: {
        'code': CodeBlockBuilder(
          preferredStyle: monoStyle.copyWith(fontSize: 14),
        ),
      },
    );
  }
}
