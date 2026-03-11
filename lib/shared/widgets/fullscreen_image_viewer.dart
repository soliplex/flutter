import 'package:flutter/material.dart';

/// Fullscreen overlay for viewing images with zoom, pan, and rotation.
class FullscreenImageViewer extends StatefulWidget {
  const FullscreenImageViewer({
    required this.child,
    this.caption,
    super.key,
  });

  final Widget child;
  final String? caption;

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
                  child: widget.child,
                ),
              ),
            ),
          ),
          if (widget.caption != null && widget.caption!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                widget.caption!,
                style: const TextStyle(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }
}
