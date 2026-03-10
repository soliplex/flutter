import 'package:nocterm/nocterm.dart';

import 'package:soliplex_tui/src/chat_session_view.dart';

/// Horizontal tab bar showing active sessions.
class SessionTabBar extends StatelessComponent {
  const SessionTabBar({
    required this.tabs,
    required this.activeIndex,
    required this.onSelect,
    super.key,
  });

  final List<ChatSessionView> tabs;
  final int activeIndex;
  final void Function(int index) onSelect;

  @override
  Component build(BuildContext context) {
    final theme = TuiTheme.of(context);

    return Container(
      color: theme.surface,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 1),
        child: Row(
          children: [
            for (var i = 0; i < tabs.length; i++) ...[
              if (i > 0) const Text(' '),
              _TabChip(
                label: '${i + 1}:${tabs[i].label}',
                isActive: i == activeIndex,
                onTap: () => onSelect(i),
              ),
            ],
            Expanded(child: const SizedBox()),
            Text(
              'Ctrl+T New  Ctrl+W Close  Ctrl+←/→ Switch',
              style: TextStyle(color: theme.onSurface.withOpacity(0.4)),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabChip extends StatelessComponent {
  const _TabChip({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Component build(BuildContext context) {
    final theme = TuiTheme.of(context);

    if (isActive) {
      return Text('[$label]', style: TextStyle(color: theme.primary));
    }

    return GestureDetector(
      onTap: onTap,
      child: Text(
        ' $label ',
        style: TextStyle(color: theme.onSurface.withOpacity(0.6)),
      ),
    );
  }
}
