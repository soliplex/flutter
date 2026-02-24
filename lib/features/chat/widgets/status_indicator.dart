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
import 'package:soliplex_frontend/core/models/active_run_state.dart';

/// Status indicator showing what the assistant is currently doing.
///
/// Uses the current activity from streaming state which persists until the
/// next activity starts, ensuring rapid events (like tool calls) are visible.
/// Also shows client-side tool execution status via [ExecutingToolsState].
class StatusIndicator extends StatelessWidget {
  /// Creates a status indicator.
  const StatusIndicator({
    required this.runState,
    super.key,
  });

  /// The active run state containing current activity information.
  final ActiveRunState runState;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final statusText = switch (runState) {
      ExecutingToolsState(:final pendingTools) =>
        'Executing: ${pendingTools.map((t) => t.name).join(', ')}',
      _ => _streamingStatusText(runState.streaming),
    };

    return Semantics(
      label: statusText,
      excludeSemantics: true,
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

  /// Maps streaming state activity to status text.
  static String _streamingStatusText(StreamingState streaming) {
    final activity = switch (streaming) {
      AwaitingText(:final currentActivity) => currentActivity,
      TextStreaming(:final currentActivity) => currentActivity,
    };

    return switch (activity) {
      ThinkingActivity() => 'Thinking',
      ToolCallActivity() => 'Calling: ${activity.allToolNames.join(', ')}',
      RespondingActivity() => 'Responding',
      ProcessingActivity() => 'Processing',
    };
  }
}
