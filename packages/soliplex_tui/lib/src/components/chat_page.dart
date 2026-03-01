import 'dart:io';

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
    final cubit = BlocProvider.of<TuiChatCubit>(context);

    if (event.matches(LogicalKey.keyQ, ctrl: true)) {
      exit(0);
    }
    if (event.matches(LogicalKey.keyC, ctrl: true)) {
      Loggers.chat.info('User pressed Ctrl+C');
      cubit.cancelRun();
      return true;
    }
    if (event.matches(LogicalKey.keyR, ctrl: true)) {
      Loggers.chat.debug('Toggled reasoning pane');
      cubit.toggleReasoning();
      return true;
    }
    return false;
  }

  @override
  Component build(BuildContext context) {
    return BlocBuilder<TuiChatCubit, TuiChatState>(
      builder: (context, state) {
        final isInputEnabled = state is TuiIdleState || state is TuiErrorState;

        // Extract reasoning text for the side pane.
        final reasoningText =
            state is TuiStreamingState ? state.reasoningText : null;
        final showReasoning = state is TuiStreamingState &&
            state.showReasoning &&
            reasoningText != null &&
            reasoningText.isNotEmpty;

        return Focusable(
          focused: true,
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

                    if (showReasoning && constraints.maxWidth >= 80) {
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
                              reasoningText: reasoningText,
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
