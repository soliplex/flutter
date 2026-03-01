import 'package:nocterm/nocterm.dart';
import 'package:soliplex_client/soliplex_client.dart';

/// Status bar shown while client-side tools are executing.
class ToolStatusBar extends StatelessComponent {
  const ToolStatusBar({required this.pendingTools, super.key});

  final List<ToolCallInfo> pendingTools;

  @override
  Component build(BuildContext context) {
    final theme = TuiTheme.of(context);
    final names = pendingTools.map((t) => t.name).join(', ');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 1),
      child: Text(
        'Executing: $names [${pendingTools.length} tool(s)]',
        style: TextStyle(color: theme.warning),
      ),
    );
  }
}
