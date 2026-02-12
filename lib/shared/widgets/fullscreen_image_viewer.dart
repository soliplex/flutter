import 'package:flutter/material.dart';

/// Fullscreen overlay for viewing images with zoom, pan, and rotation.
class FullscreenImageViewer extends StatefulWidget {
  const FullscreenImageViewer({
    required this.imageUrl,
    this.altText,
    super.key,
  });

  final String imageUrl;
  final String? altText;

  @override
  State<FullscreenImageViewer> createState() => _FullscreenImageViewerState();
}

class _FullscreenImageViewerState extends State<FullscreenImageViewer> {
  int _quarterTurns = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Close',
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.rotate_right),
            tooltip: 'Rotate',
            onPressed: () => setState(() => _quarterTurns++),
          ),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: Column(
        children: [
          Expanded(
            child: InteractiveViewer(
              minScale: 1,
              maxScale: 5,
              child: Center(
                child: RotatedBox(
                  quarterTurns: _quarterTurns,
                  child: Image.network(
                    widget.imageUrl,
                    errorBuilder: (_, __, ___) => const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.broken_image,
                          color: Colors.white54,
                          size: 64,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Failed to load image',
                          style: TextStyle(color: Colors.white54),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (widget.altText != null && widget.altText!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                widget.altText!,
                style: const TextStyle(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }
}
