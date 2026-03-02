import 'package:nocterm/nocterm.dart';

/// Scrollable pane displaying the model's reasoning/thinking text.
class ReasoningPane extends StatelessComponent {
  const ReasoningPane({required this.reasoningText, super.key});

  final String reasoningText;

  @override
  Component build(BuildContext context) {
    final theme = TuiTheme.of(context);

    return Container(
      color: theme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1),
            child: Text(
              'Reasoning',
              style: TextStyle(color: theme.warning),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1),
              child: SingleChildScrollView(
                child: MarkdownText(reasoningText),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
