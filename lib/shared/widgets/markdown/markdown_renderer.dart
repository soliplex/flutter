import 'package:flutter/widgets.dart';

import 'package:soliplex_frontend/shared/widgets/markdown/markdown_block_extension.dart';

/// Handler for link taps in markdown content.
typedef MarkdownLinkHandler = void Function(String href, String? title);

/// Handler for image taps in markdown content.
typedef MarkdownImageHandler = void Function(String src, String? alt);

/// Renders markdown text as Flutter widgets.
///
/// Consumers depend on this type. The concrete implementation encapsulates
/// the specific markdown package used, making it easy to swap packages by
/// changing only the implementation class.
abstract class MarkdownRenderer extends StatelessWidget {
  const MarkdownRenderer({
    required this.data,
    this.onLinkTap,
    this.onImageTap,
    this.blockExtensions = const {},
    super.key,
  });

  /// The markdown text to render.
  final String data;

  /// Called when the user taps a link.
  final MarkdownLinkHandler? onLinkTap;

  /// Called when the user taps an image.
  final MarkdownImageHandler? onImageTap;

  /// Custom block extensions keyed by tag name.
  final Map<String, MarkdownBlockExtension> blockExtensions;
}
