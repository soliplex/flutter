import 'dart:async';

import 'package:flutter/material.dart';
import 'package:soliplex_monty/src/console_event.dart';

/// Renders a stream of [ConsoleEvent]s as monospace console output.
///
/// Auto-scrolls to the bottom as new output arrives. Shows return value
/// and resource usage after [ConsoleComplete], or an error message after
/// [ConsoleError].
class ConsoleOutputView extends StatefulWidget {
  const ConsoleOutputView({
    required this.eventStream,
    this.style,
    this.maxHeight = 300,
    super.key,
  });

  /// The stream of console events to render.
  final Stream<ConsoleEvent> eventStream;

  /// Optional text style override. Defaults to monospace.
  final TextStyle? style;

  /// Maximum height before scrolling.
  final double maxHeight;

  @override
  State<ConsoleOutputView> createState() => _ConsoleOutputViewState();
}

class _ConsoleOutputViewState extends State<ConsoleOutputView> {
  final _scrollController = ScrollController();
  final _lines = <_ConsoleLine>[];
  StreamSubscription<ConsoleEvent>? _subscription;
  bool _isComplete = false;

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  @override
  void didUpdateWidget(ConsoleOutputView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.eventStream != oldWidget.eventStream) {
      unawaited(_subscription?.cancel());
      _lines.clear();
      _isComplete = false;
      _subscribe();
    }
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    _scrollController.dispose();
    super.dispose();
  }

  void _subscribe() {
    _subscription = widget.eventStream.listen(_onEvent);
  }

  void _onEvent(ConsoleEvent event) {
    if (!mounted) return;
    setState(() {
      switch (event) {
        case ConsoleOutput(:final text):
          _lines.add(_ConsoleLine(text: text));
        case ConsoleComplete(:final result):
          _isComplete = true;
          if (result.value != null) {
            _lines.add(
              _ConsoleLine(
                text: '=> ${result.value}\n',
                style: _LineStyle.result,
              ),
            );
          }
          final u = result.usage;
          _lines.add(
            _ConsoleLine(
              text: '[${u.timeElapsedMs}ms | '
                  '${(u.memoryBytesUsed / 1024).toStringAsFixed(1)}KB | '
                  'depth ${u.stackDepthUsed}]\n',
              style: _LineStyle.meta,
            ),
          );
        case ConsoleError(:final error):
          _isComplete = true;
          final location =
              error.lineNumber != null ? 'line ${error.lineNumber}: ' : '';
          _lines.add(
            _ConsoleLine(
              text: '$location${error.message}\n',
              style: _LineStyle.error,
            ),
          );
      }
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        unawaited(
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 100),
            curve: Curves.easeOut,
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final baseStyle =
        widget.style ?? const TextStyle(fontFamily: 'monospace', fontSize: 13);
    final theme = Theme.of(context);

    return Container(
      constraints: BoxConstraints(maxHeight: widget.maxHeight),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(8),
      child: _lines.isEmpty && !_isComplete
          ? Center(
              child: Text(
                'No output',
                style: baseStyle.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            )
          : SelectionArea(
              child: ListView.builder(
                controller: _scrollController,
                itemCount: _lines.length,
                shrinkWrap: true,
                itemBuilder: (context, index) {
                  final line = _lines[index];

                  return Text(
                    line.text,
                    style: baseStyle.copyWith(
                      color: switch (line.style) {
                        _LineStyle.normal => theme.colorScheme.onSurface,
                        _LineStyle.result => Colors.green,
                        _LineStyle.error => theme.colorScheme.error,
                        _LineStyle.meta => theme.colorScheme.onSurfaceVariant,
                      },
                    ),
                  );
                },
              ),
            ),
    );
  }
}

enum _LineStyle { normal, result, error, meta }

class _ConsoleLine {
  const _ConsoleLine({required this.text, this.style = _LineStyle.normal});
  final String text;
  final _LineStyle style;
}
