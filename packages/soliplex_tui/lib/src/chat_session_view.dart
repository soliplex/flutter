import 'package:signals_core/signals_core.dart';
import 'package:soliplex_agent/soliplex_agent.dart';
import 'package:soliplex_tui/src/loggers.dart';
import 'package:soliplex_tui/src/services/tui_ui_delegate.dart';

/// View model for a chat tab, owning its own signals that survive
/// session disposal.
///
/// The runtime auto-disposes sessions on completion, which kills the
/// session's `runState` signal. This class copies state into owned
/// signals via [effect], so the UI keeps working after completion.
class ChatSessionView {
  ChatSessionView({
    required this.roomId,
    required this.threadId,
    this.uiDelegate,
  });

  final String roomId;
  final String threadId;
  final TuiUiDelegate? uiDelegate;

  final Signal<List<ChatMessage>> _messages = signal(const []);
  final Signal<StreamingState?> _streaming = signal(null);
  final Signal<String?> _reasoningText = signal(null);
  final Signal<List<ToolCallInfo>?> _pendingTools = signal(null);
  final Signal<bool> _isInputEnabled = signal(true);
  final Signal<bool> _isConnected = signal(true);
  final Signal<RunState> _runState = signal(const IdleState());

  EffectCleanup? _cleanup;
  AgentSession? _session;

  ReadonlySignal<List<ChatMessage>> get messages => _messages.readonly();
  ReadonlySignal<StreamingState?> get streaming => _streaming.readonly();
  ReadonlySignal<String?> get reasoningText => _reasoningText.readonly();
  ReadonlySignal<List<ToolCallInfo>?> get pendingTools =>
      _pendingTools.readonly();
  ReadonlySignal<bool> get isInputEnabled => _isInputEnabled.readonly();
  ReadonlySignal<bool> get isConnected => _isConnected.readonly();
  ReadonlySignal<RunState> get runState => _runState.readonly();

  /// Short label for the tab bar.
  String get label => roomId;

  /// The pending approval signal for this tab, or `null` if no delegate.
  ReadonlySignal<ToolApprovalRequest?>? get approvalRequest =>
      _session != null && uiDelegate != null
      ? uiDelegate!.signalFor(_session!.id).readonly()
      : null;

  /// Attach a new session to this view, syncing its run state into
  /// our owned signals.
  void attachSession(AgentSession session) {
    // Detach previous if any.
    _cleanup?.call();
    _session = session;

    _cleanup = effect(() {
      final state = session.runState.value;
      Loggers.chat.trace('RunState: ${state.runtimeType}');
      _runState.value = state;
      _messages.value = _extractMessages(state);
      _streaming.value = _extractStreaming(state);
      _reasoningText.value = _extractReasoningText(state);
      _pendingTools.value = _extractPendingTools(state);
      _isInputEnabled.value = _checkInputEnabled(state);
      _isConnected.value = state is! FailedState;
    });
  }

  void cancel() => _session?.cancel();

  void dispose() {
    _cleanup?.call();
    if (_session != null && uiDelegate != null) {
      uiDelegate!.cleanup(_session!.id);
    }
    _messages.dispose();
    _streaming.dispose();
    _reasoningText.dispose();
    _pendingTools.dispose();
    _isInputEnabled.dispose();
    _isConnected.dispose();
    _runState.dispose();
  }

  static List<ChatMessage> _extractMessages(RunState state) {
    return switch (state) {
      RunningState(:final conversation) => conversation.messages,
      CompletedState(:final conversation) => conversation.messages,
      ToolYieldingState(:final conversation) => conversation.messages,
      FailedState(:final conversation) => conversation?.messages ?? const [],
      CancelledState(:final conversation) => conversation?.messages ?? const [],
      IdleState() => const [],
    };
  }

  static StreamingState? _extractStreaming(RunState state) {
    return switch (state) {
      RunningState(:final streaming) => streaming,
      _ => null,
    };
  }

  static String? _extractReasoningText(RunState state) {
    return switch (state) {
      RunningState(:final streaming) => switch (streaming) {
        AwaitingText(:final bufferedThinkingText)
            when bufferedThinkingText.isNotEmpty =>
          bufferedThinkingText,
        TextStreaming(:final thinkingText) when thinkingText.isNotEmpty =>
          thinkingText,
        _ => null,
      },
      _ => null,
    };
  }

  static List<ToolCallInfo>? _extractPendingTools(RunState state) {
    return switch (state) {
      ToolYieldingState(:final pendingToolCalls) => pendingToolCalls,
      _ => null,
    };
  }

  static bool _checkInputEnabled(RunState state) {
    return state is IdleState ||
        state is FailedState ||
        state is CompletedState;
  }
}
