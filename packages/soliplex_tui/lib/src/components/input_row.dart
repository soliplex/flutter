import 'package:nocterm/nocterm.dart';

/// Input row with `> ` prompt and text field.
class InputRow extends StatelessComponent {
  const InputRow({
    required this.controller,
    required this.onSubmitted,
    required this.enabled,
    super.key,
  });

  final TextEditingController controller;
  final void Function(String text) onSubmitted;
  final bool enabled;

  @override
  Component build(BuildContext context) {
    final theme = TuiTheme.of(context);

    return Row(
      children: [
        Text(
          '> ',
          style: TextStyle(color: theme.primary),
        ),
        Expanded(
          child: TextField(
            controller: controller,
            enabled: enabled,
            focused: enabled,
            placeholder: enabled ? 'Type a message...' : 'Waiting...',
            placeholderStyle:
                TextStyle(color: theme.onSurface.withOpacity(0.5)),
            style: TextStyle(color: theme.onSurface),
            onSubmitted: (text) {
              if (text.trim().isEmpty) return;
              onSubmitted(text.trim());
              controller.clear();
            },
          ),
        ),
      ],
    );
  }
}
