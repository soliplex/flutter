import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soliplex_client/soliplex_client.dart' hide State;
import 'package:soliplex_frontend/core/logging/loggers.dart';
import 'package:soliplex_frontend/core/providers/chunk_visualization_provider.dart';
import 'package:soliplex_frontend/design/design.dart';

/// Full-screen page for viewing PDF chunk page images with rotation and zoom.
///
/// Displays images in a horizontal [PageView] carousel with per-image rotation
/// via the AppBar rotate button, pinch-to-zoom via [InteractiveViewer], and
/// double-tap to reset zoom.
class ChunkVisualizationPage extends ConsumerStatefulWidget {
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
  ConsumerState<ChunkVisualizationPage> createState() =>
      _ChunkVisualizationPageState();
}

class _ChunkVisualizationPageState
    extends ConsumerState<ChunkVisualizationPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  Map<int, int> _quarterTurns = {};
  bool _isScaled = false;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asyncValue = ref.watch(
      chunkVisualizationProvider(
        (roomId: widget.roomId, chunkId: widget.chunkId),
      ),
    );

    final theme = Theme.of(context);
    final hasData = asyncValue.asData?.value.hasImages ?? false;

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
                widget.documentTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          if (hasData)
            IconButton(
              icon: const Icon(Icons.rotate_right),
              tooltip: 'Rotate',
              onPressed: () => setState(() {
                _quarterTurns = Map.of(_quarterTurns)
                  ..[_currentPage] =
                      ((_quarterTurns[_currentPage] ?? 0) + 1) % 4;
              }),
            ),
        ],
      ),
      body: asyncValue.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) =>
            _buildError(context, error, stackTrace, theme),
        data: (visualization) => _buildContent(context, visualization, theme),
      ),
    );
  }

  Widget _buildError(
    BuildContext context,
    Object error,
    StackTrace? stackTrace,
    ThemeData theme,
  ) {
    Loggers.chat.error(
      'ChunkVisualization error for chunk ${widget.chunkId}',
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
          Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
          const SizedBox(height: SoliplexSpacing.s4),
          Text(
            message,
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: SoliplexSpacing.s4),
          FilledButton.icon(
            onPressed: () => ref.invalidate(
              chunkVisualizationProvider(
                (roomId: widget.roomId, chunkId: widget.chunkId),
              ),
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

    // Clamp current page if data refreshed with fewer images.
    if (_currentPage >= visualization.imageCount) {
      _currentPage = visualization.imageCount - 1;
    }

    return Stack(
      children: [
        PageView.builder(
          controller: _pageController,
          onPageChanged: (i) => setState(() {
            _currentPage = i;
            _isScaled = false;
          }),
          physics: _isScaled ? const NeverScrollableScrollPhysics() : null,
          itemCount: visualization.imageCount,
          itemBuilder: (context, i) => _PageImage(
            imageBase64: visualization.imagesBase64[i],
            quarterTurns: _quarterTurns[i] ?? 0,
            onScaleChanged: (scaled) => setState(() => _isScaled = scaled),
          ),
        ),
        if (visualization.imageCount > 1)
          Positioned(
            bottom: SoliplexSpacing.s4,
            left: 0,
            right: 0,
            child: Center(
              child: _DotIndicator(
                count: visualization.imageCount,
                current: _currentPage,
              ),
            ),
          ),
      ],
    );
  }
}

class _PageImage extends StatefulWidget {
  const _PageImage({
    required this.imageBase64,
    required this.quarterTurns,
    required this.onScaleChanged,
  });

  final String imageBase64;
  final int quarterTurns;
  final ValueChanged<bool> onScaleChanged;

  @override
  State<_PageImage> createState() => _PageImageState();
}

class _PageImageState extends State<_PageImage> {
  Uint8List? _imageBytes;
  late final TransformationController _transformController;
  bool _wasScaled = false;

  @override
  void initState() {
    super.initState();
    _imageBytes = _decodeImage(widget.imageBase64);
    _transformController = TransformationController();
    _transformController.addListener(_onTransformChanged);
  }

  @override
  void didUpdateWidget(_PageImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.imageBase64 != oldWidget.imageBase64) {
      _imageBytes = _decodeImage(widget.imageBase64);
    }
  }

  @override
  void dispose() {
    _transformController
      ..removeListener(_onTransformChanged)
      ..dispose();
    super.dispose();
  }

  void _onTransformChanged() {
    final isScaled = _transformController.value.getMaxScaleOnAxis() > 1.01;
    if (isScaled != _wasScaled) {
      _wasScaled = isScaled;
      widget.onScaleChanged(isScaled);
    }
  }

  Uint8List? _decodeImage(String base64Data) {
    try {
      return base64Decode(base64Data);
    } on FormatException catch (e, s) {
      Loggers.chat.error(
        'Failed to decode base64 image',
        error: e,
        stackTrace: s,
      );
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onDoubleTap: () {
        _transformController.value = Matrix4.identity();
      },
      child: InteractiveViewer(
        transformationController: _transformController,
        panEnabled: _wasScaled,
        minScale: 1,
        maxScale: 4,
        child: Center(
          child: RotatedBox(
            quarterTurns: widget.quarterTurns,
            child: _imageBytes != null
                ? Image.memory(
                    _imageBytes!,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stack) {
                      Loggers.chat.error(
                        'Image decode error',
                        error: error,
                        stackTrace: stack,
                      );
                      return _buildBrokenImage(theme);
                    },
                  )
                : _buildBrokenImage(theme),
          ),
        ),
      ),
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

class _DotIndicator extends StatelessWidget {
  const _DotIndicator({required this.count, required this.current});

  final int count;
  final int current;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: 'Page ${current + 1} of $count',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(
          count,
          (i) => Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i == current
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
            ),
          ),
        ),
      ),
    );
  }
}
