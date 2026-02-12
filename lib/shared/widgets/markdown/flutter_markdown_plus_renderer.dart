import 'package:flutter/material.dart';

import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import 'package:soliplex_frontend/design/design.dart';
import 'package:soliplex_frontend/shared/widgets/markdown/code_block_builder.dart';
import 'package:soliplex_frontend/shared/widgets/markdown/markdown_renderer.dart';

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
    final theme = Theme.of(context);
    final soliplexTheme = SoliplexTheme.of(context);

    return MarkdownBody(
      data: data,
      styleSheet: MarkdownStyleSheet(
        p: theme.textTheme.bodyLarge?.copyWith(
          color: theme.colorScheme.onSurface,
        ),
        code: context.monospace.copyWith(
          backgroundColor: theme.colorScheme.surfaceContainerHigh,
        ),
        codeblockDecoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(soliplexTheme.radii.sm),
        ),
      ),
      builders: {
        'code': CodeBlockBuilder(
          preferredStyle: context.monospace.copyWith(fontSize: 14),
        ),
      },
    );
  }
}
