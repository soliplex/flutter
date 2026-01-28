import 'package:flutter/material.dart';
import 'package:soliplex_client/soliplex_client.dart'
    show
        AwaitingText,
        ProcessingActivity,
        RespondingActivity,
        StreamingState,
        TextStreaming,
        ThinkingActivity,
        ToolCallActivity;

/// Status indicator showing what the assistant is currently doing.
///
/// Uses the current activity from streaming state which persists until the
/// next activity starts, ensuring rapid events (like tool calls) are visible.
class StatusIndicator extends StatelessWidget {
  /// Creates a status indicator.
  const StatusIndicator({
    required this.streaming,
    super.key,
  });

  /// The streaming state containing current activity.
  final StreamingState streaming;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Get current activity from streaming state
    final activity = switch (streaming) {
      AwaitingText(:final currentActivity) => currentActivity,
      TextStreaming(:final currentActivity) => currentActivity,
    };

    // Map activity to status text
    final statusText = switch (activity) {
      ThinkingActivity() => 'Thinking',
      ToolCallActivity() => 'Calling: ${activity.allToolNames.join(', ')}',
      RespondingActivity() => 'Responding',
      ProcessingActivity() => 'Processing',
    };

    return Semantics(
      label: statusText,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  theme.colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                statusText,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
