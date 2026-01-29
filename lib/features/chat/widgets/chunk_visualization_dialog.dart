import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soliplex_client/soliplex_client.dart';
import 'package:soliplex_frontend/core/providers/chunk_visualization_provider.dart';
import 'package:soliplex_frontend/design/design.dart';

/// Dialog for viewing PDF chunk page images with highlighted text.
///
/// Shows loading state, handles errors with retry, and displays images in a
/// horizontally scrollable row with page numbers.
class ChunkVisualizationDialog extends ConsumerWidget {
  /// Creates a dialog for the given room and chunk.
  const ChunkVisualizationDialog({
    required this.roomId,
    required this.chunkId,
    required this.documentTitle,
    super.key,
  });

  /// The room ID.
  final String roomId;

  /// The chunk ID to visualize.
  final String chunkId;

  /// Document title for the dialog header.
  final String documentTitle;

  /// Shows the dialog.
  static Future<void> show({
    required BuildContext context,
    required String roomId,
    required String chunkId,
    required String documentTitle,
  }) {
    return showDialog<void>(
      context: context,
      builder: (context) => ChunkVisualizationDialog(
        roomId: roomId,
        chunkId: chunkId,
        documentTitle: documentTitle,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncValue = ref.watch(
      chunkVisualizationProvider((roomId: roomId, chunkId: chunkId)),
    );

    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;

    return Dialog(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: min(700, size.width * 0.9),
          maxHeight: min(600, size.height * 0.85),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(SoliplexSpacing.s4),
              child: Row(
                children: [
                  const Icon(Icons.picture_as_pdf, size: 24),
                  const SizedBox(width: SoliplexSpacing.s2),
                  Expanded(
                    child: Text(
                      documentTitle,
                      style: theme.textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: 'Close',
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // Content
            Flexible(
              child: asyncValue.when(
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(SoliplexSpacing.s6),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (error, _) => _buildError(context, ref, error),
                data: (visualization) => _buildContent(context, visualization),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError(BuildContext context, WidgetRef ref, Object error) {
    final theme = Theme.of(context);
    final message = switch (error) {
      NotFoundException() => 'Page images not available for this citation.',
      NetworkException() => 'Could not connect to server.',
      _ => 'Failed to load page images.',
    };

    return Padding(
      padding: const EdgeInsets.all(SoliplexSpacing.s6),
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

  Widget _buildContent(BuildContext context, ChunkVisualization visualization) {
    final theme = Theme.of(context);

    if (!visualization.hasImages) {
      return Padding(
        padding: const EdgeInsets.all(SoliplexSpacing.s6),
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

    return SingleChildScrollView(
      padding: const EdgeInsets.all(SoliplexSpacing.s4),
      child: Center(
        child: Wrap(
          spacing: SoliplexSpacing.s4,
          runSpacing: SoliplexSpacing.s4,
          alignment: WrapAlignment.center,
          children: [
            for (var i = 0; i < visualization.imageCount; i++)
              _PageImage(
                imageBase64: visualization.imagesBase64[i],
                pageNumber: i + 1,
                totalPages: visualization.imageCount,
              ),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final soliplexTheme = SoliplexTheme.of(context);

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
          child: Image.memory(
            base64Decode(imageBase64),
            fit: BoxFit.contain,
            errorBuilder: (context, error, stack) => Container(
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
            ),
          ),
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
}
