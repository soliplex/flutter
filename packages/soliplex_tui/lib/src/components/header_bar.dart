import 'package:nocterm/nocterm.dart';

/// Header bar showing room name, thread ID, and connection status.
class HeaderBar extends StatelessComponent {
  const HeaderBar({
    required this.roomId,
    required this.threadId,
    required this.isConnected,
    super.key,
  });

  final String roomId;
  final String threadId;
  final bool isConnected;

  @override
  Component build(BuildContext context) {
    final theme = TuiTheme.of(context);
    final dot = isConnected ? '●' : '○';

    return Container(
      color: theme.surface,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 1),
        child: Row(
          children: [
            Text(
              'Room: $roomId',
              style: TextStyle(color: theme.onSurface),
            ),
            const Text('  '),
            Text(
              'Thread: $threadId',
              style: TextStyle(color: theme.onSurface),
            ),
            Expanded(child: const SizedBox()),
            Text(
              dot,
              style: TextStyle(
                color: isConnected ? theme.primary : theme.error,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
