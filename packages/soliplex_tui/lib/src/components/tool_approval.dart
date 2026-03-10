import 'package:nocterm/nocterm.dart';

import 'package:soliplex_tui/src/services/tui_ui_delegate.dart';

/// Modal overlay for tool approval prompts.
///
/// Captures Y (approve), N (deny), A (always allow) keypresses.
/// Rendered as a centered box over the chat body when a
/// [ToolApprovalRequest] is pending.
class ToolApprovalModal extends StatelessComponent {
  const ToolApprovalModal({
    required this.request,
    required this.onResolve,
    super.key,
  });

  final ToolApprovalRequest request;

  /// Called with `(approved, always)`.
  final void Function({required bool approved, bool always}) onResolve;

  @override
  Component build(BuildContext context) {
    final theme = TuiTheme.of(context);

    return Focusable(
      focused: true,
      onKeyEvent: (event) {
        if (event.matches(LogicalKey.keyY)) {
          onResolve(approved: true);
          return true;
        }
        if (event.matches(LogicalKey.keyN) ||
            event.matches(LogicalKey.escape)) {
          onResolve(approved: false);
          return true;
        }
        if (event.matches(LogicalKey.keyA)) {
          onResolve(approved: true, always: true);
          return true;
        }
        return false;
      },
      child: Center(
        child: SizedBox(
          width: 60,
          child: Padding(
            padding: const EdgeInsets.all(1),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ' Tool Approval Required ',
                  style: TextStyle(
                    color: theme.onPrimary,
                    backgroundColor: theme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  'Tool: ${request.toolName}',
                  style: TextStyle(color: theme.onSurface),
                ),
                Text(
                  request.rationale,
                  style: TextStyle(color: theme.onSurface.withOpacity(0.8)),
                ),
                const SizedBox(height: 1),
                Text(
                  '[Y] Approve  [N] Deny  [A] Always Allow',
                  style: TextStyle(color: theme.primary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
