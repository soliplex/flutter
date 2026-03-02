import 'package:nocterm/nocterm.dart';
import 'package:nocterm_bloc/nocterm_bloc.dart';

import 'package:soliplex_tui/src/components/chat_body.dart';
import 'package:soliplex_tui/src/components/footer_bar.dart';
import 'package:soliplex_tui/src/components/header_bar.dart';
import 'package:soliplex_tui/src/components/input_row.dart';
import 'package:soliplex_tui/src/components/reasoning_pane.dart';
import 'package:soliplex_tui/src/components/tool_status_bar.dart';
import 'package:soliplex_tui/src/loggers.dart';
import 'package:soliplex_tui/src/state/tui_chat_cubit.dart';
import 'package:soliplex_tui/src/state/tui_chat_state.dart';

/// Main chat page with header, message body, input, and footer.
class ChatPage extends StatefulComponent {
  const ChatPage({
    required this.roomId,
    required this.threadId,
    super.key,
  });

  final String roomId;
  final String threadId;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  late final TextEditingController _inputController;
  late final ScrollController _scrollController;

  /// User toggle for the reasoning pane (Ctrl+R).
  bool _showReasoningToggle = true;

  /// Latched reasoning pane state — avoids flashing when reasoning text
  /// toggles between empty and non-empty during streaming transitions.
  bool _reasoningPaneActive = false;
  String _lastReasoningText = '';

  /// Tracks when the last Ctrl+C was pressed for double-tap quit.
  DateTime? _lastCtrlC;

  @override
  void initState() {
    super.initState();
    _inputController = TextEditingController();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit(String text) async {
    Loggers.chat.debug('Submit: ${text.length} chars');
    await BlocProvider.of<TuiChatCubit>(context).sendMessage(text);
  }

  bool _handleKeyEvent(KeyboardEvent event) {
    if (event.matches(LogicalKey.keyQ, ctrl: true)) {
      Loggers.chat.info('Ctrl+Q — shutting down');
      shutdownApp();
      return true;
    }
    if (event.matches(LogicalKey.keyC, ctrl: true)) {
      final now = DateTime.now();
      final prev = _lastCtrlC;
      _lastCtrlC = now;

      // Double-tap Ctrl+C within 1 second → quit.
      if (prev != null && now.difference(prev).inMilliseconds < 1000) {
        Loggers.chat.info('Ctrl+C x2 — shutting down');
        shutdownApp();
        return true;
      }

      // Single Ctrl+C → cancel active run.
      Loggers.chat.info('Ctrl+C — cancelling run');
      BlocProvider.of<TuiChatCubit>(context).cancelRun();
      return true;
    }
    if (event.matches(LogicalKey.keyR, ctrl: true)) {
      Loggers.chat.debug('Toggled reasoning pane');
      setState(() {
        _showReasoningToggle = !_showReasoningToggle;
      });
      return true;
    }
    return false;
  }

  @override
  Component build(BuildContext context) {
    return BlocBuilder<TuiChatCubit, TuiChatState>(
      builder: (context, state) {
        final isInputEnabled = state is TuiIdleState || state is TuiErrorState;

        // Latch reasoning text so the pane persists after the run ends.
        // Only clears when the user toggles off via Ctrl+R.
        if (state is TuiStreamingState) {
          final text = state.reasoningText;
          if (text != null && text.isNotEmpty) {
            _lastReasoningText = text;
          }
        }
        _reasoningPaneActive =
            _showReasoningToggle && _lastReasoningText.isNotEmpty;

        // Parent Focusable catches shortcuts when TextField is disabled
        // (during streaming/tool execution). When TextField is enabled,
        // shortcuts go through TextField.onKeyEvent instead.
        return Focusable(
          focused: !isInputEnabled,
          onKeyEvent: _handleKeyEvent,
          child: Column(
            children: [
              HeaderBar(
                roomId: component.roomId,
                threadId: component.threadId,
                isConnected: state is! TuiErrorState,
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final chatBody = ChatBody(
                      scrollController: _scrollController,
                    );

                    if (_reasoningPaneActive && constraints.maxWidth >= 80) {
                      return Row(
                        children: [
                          Expanded(child: chatBody),
                          VerticalDivider(
                            color: TuiTheme.of(context).outlineVariant,
                          ),
                          SizedBox(
                            width:
                                (constraints.maxWidth / 3).floor().toDouble(),
                            child: ReasoningPane(
                              reasoningText: _lastReasoningText,
                            ),
                          ),
                        ],
                      );
                    }

                    return chatBody;
                  },
                ),
              ),
              if (state is TuiExecutingToolsState)
                ToolStatusBar(pendingTools: state.pendingTools),
              InputRow(
                controller: _inputController,
                onSubmitted: _handleSubmit,
                onKeyEvent: _handleKeyEvent,
                enabled: isInputEnabled,
              ),
              const FooterBar(),
            ],
          ),
        );
      },
    );
  }
}
