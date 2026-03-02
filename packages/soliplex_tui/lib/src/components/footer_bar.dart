import 'package:nocterm/nocterm.dart';

/// Footer bar with keyboard shortcut hints.
class FooterBar extends StatelessComponent {
  const FooterBar({super.key});

  @override
  Component build(BuildContext context) {
    final theme = TuiTheme.of(context);
    final hintStyle = TextStyle(color: theme.onSurface.withOpacity(0.6));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 1),
      child: Text(
        'Ctrl+C Cancel  Ctrl+R Reasoning  Ctrl+Q Quit',
        style: hintStyle,
      ),
    );
  }
}
