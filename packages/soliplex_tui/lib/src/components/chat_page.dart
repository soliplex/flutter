import 'package:nocterm/nocterm.dart';
import 'package:soliplex_agent/soliplex_agent.dart' hide State;

import 'package:soliplex_tui/src/chat_session_view.dart';
import 'package:soliplex_tui/src/components/chat_body.dart';
import 'package:soliplex_tui/src/components/footer_bar.dart';
import 'package:soliplex_tui/src/components/header_bar.dart';
import 'package:soliplex_tui/src/components/input_row.dart';
import 'package:soliplex_tui/src/components/reasoning_pane.dart';
import 'package:soliplex_tui/src/components/tab_bar.dart';
import 'package:soliplex_tui/src/components/tool_approval.dart';
import 'package:soliplex_tui/src/components/tool_status_bar.dart';
import 'package:soliplex_tui/src/loggers.dart';
import 'package:soliplex_tui/src/services/tui_ui_delegate.dart';
import 'package:soliplex_tui/src/signal_builder.dart';

/// Main chat page with tabs, header, message body, input, and footer.
class ChatPage extends StatefulComponent {
  const ChatPage({
    required this.runtime,
    required this.roomId,
    this.uiDelegate,
    super.key,
  });

  final AgentRuntime runtime;
  final String roomId;
  final TuiUiDelegate? uiDelegate;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  late final TextEditingController _inputController;
  late final ScrollController _scrollController;

  final List<ChatSessionView> _tabs = [];
  int _activeIndex = -1;

  /// User toggle for the reasoning pane (Ctrl+R).
  bool _showReasoningToggle = true;

  /// Latched reasoning text — persists after run ends until toggled off.
  String _lastReasoningText = '';

  /// Tracks when the last Ctrl+C was pressed for double-tap quit.
  DateTime? _lastCtrlC;

  ChatSessionView? get _activeTab =>
      _activeIndex >= 0 && _activeIndex < _tabs.length
          ? _tabs[_activeIndex]
          : null;

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

  Future<void> _spawnTab(String prompt) async {
    Loggers.app.info('Spawning new tab (${prompt.length} chars)');
    try {
      final session = await component.runtime.spawn(
        roomId: component.roomId,
        prompt: prompt,
        autoDispose: false,
      );
      Loggers.app.info(
        'Session spawned: thread=${session.threadKey.threadId}',
      );
      final view = ChatSessionView(
        roomId: component.roomId,
        threadId: session.threadKey.threadId,
        uiDelegate: component.uiDelegate,
      )..attachSession(session);
      setState(() {
        _tabs.add(view);
        _activeIndex = _tabs.length - 1;
        _lastReasoningText = '';
      });
    } on Exception catch (e, s) {
      Loggers.app.error('Failed to spawn tab', error: e, stackTrace: s);
    }
  }

  Future<void> _handleSubmit(String text) async {
    Loggers.chat.debug('Submit: ${text.length} chars');

    final tab = _activeTab;
    if (tab != null && !tab.isInputEnabled.value) {
      Loggers.chat.debug(
        'Ignoring submit — input disabled '
        '(runState=${tab.runState.value.runtimeType})',
      );
      return;
    }

    if (tab == null) {
      // First message — spawn a new tab.
      await _spawnTab(text);
      return;
    }

    // Existing tab — spawn a new session on the same thread.
    Loggers.app.info(
      'Spawning follow-up on thread=${tab.threadId} '
      '(${text.length} chars)',
    );
    try {
      final session = await component.runtime.spawn(
        roomId: tab.roomId,
        prompt: text,
        threadId: tab.threadId,
        autoDispose: false,
      );
      Loggers.app.info(
        'Follow-up session spawned: id=${session.id}',
      );
      // Reuse the same view — attachSession wires new signals.
      tab.attachSession(session);
      setState(() {
        _lastReasoningText = '';
      });
    } on Exception catch (e, s) {
      Loggers.app.error(
        'Failed to spawn follow-up',
        error: e,
        stackTrace: s,
      );
    }
  }

  void _closeTab(int index) {
    if (index < 0 || index >= _tabs.length) return;
    _tabs[index]
      ..cancel()
      ..dispose();
    setState(() {
      _tabs.removeAt(index);
      if (_tabs.isEmpty) {
        _activeIndex = -1;
      } else if (_activeIndex >= _tabs.length) {
        _activeIndex = _tabs.length - 1;
      }
      _lastReasoningText = '';
    });
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

      if (prev != null && now.difference(prev).inMilliseconds < 1000) {
        Loggers.chat.info('Ctrl+C x2 — shutting down');
        shutdownApp();
        return true;
      }

      Loggers.chat.info('Ctrl+C — cancelling session');
      _activeTab?.cancel();
      return true;
    }
    if (event.matches(LogicalKey.keyR, ctrl: true)) {
      Loggers.chat.debug('Toggled reasoning pane');
      setState(() {
        _showReasoningToggle = !_showReasoningToggle;
      });
      return true;
    }
    if (event.matches(LogicalKey.keyT, ctrl: true)) {
      Loggers.chat.debug('Ctrl+T — new tab');
      // Set index past end — _activeTab returns null, showing empty state.
      // When the user submits a message, _handleSubmit creates the tab.
      setState(() {
        _activeIndex = _tabs.length;
        _lastReasoningText = '';
      });
      return true;
    }
    if (event.matches(LogicalKey.keyW, ctrl: true)) {
      Loggers.chat.debug('Ctrl+W — close tab');
      _closeTab(_activeIndex);
      return true;
    }
    if (event.matches(LogicalKey.arrowLeft, ctrl: true)) {
      if (_tabs.length > 1) {
        setState(() {
          _activeIndex = (_activeIndex - 1 + _tabs.length) % _tabs.length;
          _lastReasoningText = '';
        });
      }
      return true;
    }
    if (event.matches(LogicalKey.arrowRight, ctrl: true)) {
      if (_tabs.length > 1) {
        setState(() {
          _activeIndex = (_activeIndex + 1) % _tabs.length;
          _lastReasoningText = '';
        });
      }
      return true;
    }
    return false;
  }

  @override
  Component build(BuildContext context) {
    final tab = _activeTab;
    final hasMultipleTabs = _tabs.length > 1;

    // No tab yet — show empty idle state.
    if (tab == null) {
      return _buildShell(
        context,
        tabBar: hasMultipleTabs ? _buildTabBar(context) : null,
        body: const Center(child: Text('Type a message to begin.')),
        isInputEnabled: true,
        toolBar: null,
      );
    }

    return SignalBuilder<RunState>(
      signal: tab.runState,
      builder: (context, runState) {
        // Latch reasoning text.
        final reasoning = tab.reasoningText.value;
        if (reasoning != null && reasoning.isNotEmpty) {
          _lastReasoningText = reasoning;
        }

        final showReasoning =
            _showReasoningToggle && _lastReasoningText.isNotEmpty;

        final approvalSignal = tab.approvalRequest;
        final approval = approvalSignal?.value;

        var body = _buildBody(context, tab, showReasoning);
        if (approval != null) {
          body = Stack(
            children: [
              body,
              ToolApprovalModal(
                request: approval,
                onResolve: ({required approved, always = false}) {
                  component.uiDelegate?.resolve(
                    approved: approved,
                    always: always,
                  );
                },
              ),
            ],
          );
        }

        return _buildShell(
          context,
          tabBar: hasMultipleTabs ? _buildTabBar(context) : null,
          body: body,
          isInputEnabled: tab.isInputEnabled.value,
          toolBar: tab.pendingTools.value != null
              ? ToolStatusBar(pendingTools: tab.pendingTools.value!)
              : null,
          isConnected: tab.isConnected.value,
        );
      },
    );
  }

  Component _buildShell(
    BuildContext context, {
    required Component? tabBar,
    required Component body,
    required bool isInputEnabled,
    required Component? toolBar,
    bool isConnected = true,
  }) {
    final tab = _activeTab;
    return Focusable(
      focused: !isInputEnabled,
      onKeyEvent: _handleKeyEvent,
      child: Column(
        children: [
          if (tabBar != null) tabBar,
          HeaderBar(
            roomId: tab?.roomId ?? component.roomId,
            threadId: tab?.threadId ?? '(new)',
            isConnected: isConnected,
          ),
          Expanded(child: body),
          if (toolBar != null) toolBar,
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
  }

  Component _buildBody(
    BuildContext context,
    ChatSessionView tab,
    bool showReasoning,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final chatBody = ChatBody(
          scrollController: _scrollController,
          messages: tab.messages,
          streaming: tab.streaming,
        );

        if (showReasoning && constraints.maxWidth >= 80) {
          return Row(
            children: [
              Expanded(child: chatBody),
              VerticalDivider(
                color: TuiTheme.of(context).outlineVariant,
              ),
              SizedBox(
                width: (constraints.maxWidth / 3).floor().toDouble(),
                child: ReasoningPane(
                  reasoningText: _lastReasoningText,
                ),
              ),
            ],
          );
        }

        return chatBody;
      },
    );
  }

  Component _buildTabBar(BuildContext context) {
    return SessionTabBar(
      tabs: _tabs,
      activeIndex: _activeIndex,
      onSelect: (index) {
        setState(() {
          _activeIndex = index;
          _lastReasoningText = '';
        });
      },
    );
  }
}
