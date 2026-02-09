import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soliplex_client/soliplex_client.dart';
import 'package:soliplex_frontend/core/logging/loggers.dart';
import 'package:soliplex_frontend/core/providers/chunk_visualization_provider.dart';
import 'package:soliplex_frontend/design/design.dart';

/// Full-screen page for viewing PDF chunk page images with zoom support.
///
/// Shows loading state, handles errors with retry, and displays images with
/// pinch-to-zoom via InteractiveViewer.
class ChunkVisualizationPage extends ConsumerWidget {
  /// Creates a page for the given room and chunk.
  const ChunkVisualizationPage({
    required this.roomId,
    required this.chunkId,
    required this.documentTitle,
    super.key,
  });

  /// The room ID.
  final String roomId;

  /// The chunk ID to visualize.
  final String chunkId;

  /// Document title for the app bar.
  final String documentTitle;

  /// Navigates to this page.
  static Future<void> show({
    required BuildContext context,
    required String roomId,
    required String chunkId,
    required String documentTitle,
  }) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => ChunkVisualizationPage(
          roomId: roomId,
          chunkId: chunkId,
          documentTitle: documentTitle,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncValue = ref.watch(
      chunkVisualizationProvider((roomId: roomId, chunkId: chunkId)),
    );

    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Back',
        ),
        title: Row(
          children: [
            const Icon(Icons.picture_as_pdf, size: 20),
            const SizedBox(width: SoliplexSpacing.s2),
            Expanded(
              child: Text(
                documentTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      body: asyncValue.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) =>
            _buildError(context, ref, error, stackTrace, theme),
        data: (visualization) => _buildContent(context, visualization, theme),
      ),
    );
  }

  Widget _buildError(
    BuildContext context,
    WidgetRef ref,
    Object error,
    StackTrace? stackTrace,
    ThemeData theme,
  ) {
    Loggers.chat.error(
      'ChunkVisualization error for chunk $chunkId',
      error: error,
      stackTrace: stackTrace,
    );

    final message = switch (error) {
      NotFoundException() => 'Page images not available for this citation.',
      NetworkException() => 'Could not connect to server.',
      _ => 'Failed to load page images.',
    };

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline,
            size: 48,
            color: theme.colorScheme.error,
          ),
          const SizedBox(height: SoliplexSpacing.s4),
          Text(
            message,
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: SoliplexSpacing.s4),
          FilledButton.icon(
            onPressed: () => ref.invalidate(
              chunkVisualizationProvider((roomId: roomId, chunkId: chunkId)),
            ),
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    ChunkVisualization visualization,
    ThemeData theme,
  ) {
    if (!visualization.hasImages) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.image_not_supported_outlined,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: SoliplexSpacing.s4),
            Text(
              'No page images available.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return InteractiveViewer(
      constrained: false,
      minScale: 0.5,
      maxScale: 4,
      child: Padding(
        padding: const EdgeInsets.all(SoliplexSpacing.s4),
        child: Column(
          children: [
            for (var i = 0; i < visualization.imageCount; i++) ...[
              if (i > 0) const SizedBox(height: SoliplexSpacing.s4),
              _PageImage(
                imageBase64: visualization.imagesBase64[i],
                pageNumber: i + 1,
                totalPages: visualization.imageCount,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PageImage extends StatelessWidget {
  const _PageImage({
    required this.imageBase64,
    required this.pageNumber,
    required this.totalPages,
  });

  final String imageBase64;
  final int pageNumber;
  final int totalPages;

  Uint8List? _decodeImage() {
    try {
      return base64Decode(imageBase64);
    } on FormatException catch (e, s) {
      Loggers.chat.error(
        'Failed to decode base64 for page $pageNumber',
        error: e,
        stackTrace: s,
      );
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final soliplexTheme = SoliplexTheme.of(context);
    final imageBytes = _decodeImage();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          constraints: const BoxConstraints(maxWidth: 300, maxHeight: 400),
          decoration: BoxDecoration(
            border: Border.all(color: theme.colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(soliplexTheme.radii.md),
          ),
          clipBehavior: Clip.antiAlias,
          child: imageBytes != null
              ? Image.memory(
                  imageBytes,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stack) {
                    Loggers.chat.error(
                      'Image decode error for page $pageNumber',
                      error: error,
                      stackTrace: stack,
                    );
                    return _buildBrokenImage(theme);
                  },
                )
              : _buildBrokenImage(theme),
        ),
        const SizedBox(height: SoliplexSpacing.s2),
        Text(
          'Page $pageNumber of $totalPages',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildBrokenImage(ThemeData theme) {
    return Container(
      width: 200,
      height: 250,
      color: theme.colorScheme.errorContainer,
      child: Center(
        child: Icon(
          Icons.broken_image,
          color: theme.colorScheme.onErrorContainer,
          size: 48,
        ),
      ),
    );
  }
}
