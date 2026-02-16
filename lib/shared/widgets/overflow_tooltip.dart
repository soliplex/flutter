import 'package:flutter/material.dart';

/// A widget that displays text with a tooltip only when the text is truncated.
///
/// Uses [LayoutBuilder] to get available width and [TextPainter] to measure
/// if text would overflow. The tooltip only appears when text is actually
/// truncated due to overflow constraints.
class OverflowTooltip extends StatelessWidget {
  /// Creates an [OverflowTooltip] widget.
  const OverflowTooltip({
    required this.text,
    this.style,
    this.maxLines = 1,
    this.tooltipMessage,
    super.key,
  });

  /// The text to display.
  final String text;

  /// The style to apply to the text.
  final TextStyle? style;

  /// Maximum number of lines before truncation. Defaults to 1.
  final int maxLines;

  /// The tooltip message to display. Falls back to [text] if null.
  final String? tooltipMessage;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final effectiveStyle = style ?? DefaultTextStyle.of(context).style;
        final isOverflowing = _isTextOverflowing(
          text,
          effectiveStyle,
          constraints.maxWidth,
          maxLines,
        );

        final textWidget = Text(
          text,
          style: style,
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
        );

        if (isOverflowing) {
          return Tooltip(
            message: tooltipMessage ?? text,
            child: textWidget,
          );
        }
        return textWidget;
      },
    );
  }

  static bool _isTextOverflowing(
    String text,
    TextStyle style,
    double maxWidth,
    int maxLines,
  ) {
    final textPainter = TextPainter(
      text: TextSpan(text: text, style: style),
      maxLines: maxLines,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: maxWidth);

    return textPainter.didExceedMaxLines;
  }
}
