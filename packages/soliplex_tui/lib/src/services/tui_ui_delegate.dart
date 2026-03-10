import 'dart:async';
import 'dart:collection';

import 'package:signals_core/signals_core.dart';
import 'package:soliplex_agent/soliplex_agent.dart';

/// A pending approval request surfaced to the UI.
class ToolApprovalRequest {
  ToolApprovalRequest({
    required this.toolName,
    required this.arguments,
    required this.rationale,
    required this.completer,
  });

  final String toolName;
  final Map<String, dynamic> arguments;
  final String rationale;
  final Completer<bool> completer;
}

/// [AgentUiDelegate] implementation for the nocterm TUI.
///
/// Serializes concurrent approval requests with a simple FIFO queue
/// (Dart is single-threaded, so no mutex needed). Routes each request
/// to the correct tab via per-session signals.
class TuiUiDelegate implements AgentUiDelegate {
  final Set<String> _alwaysAllow = {};
  final Map<String, Signal<ToolApprovalRequest?>> _sessionSignals = {};
  final Queue<_QueueEntry> _queue = Queue();
  bool _processing = false;

  /// Tools the user has chosen "Always allow" for this runtime lifetime.
  Set<String> get alwaysAllowed => UnmodifiableSetView(_alwaysAllow);

  /// Get or create the approval signal for a specific session/tab.
  Signal<ToolApprovalRequest?> signalFor(String sessionId) {
    return _sessionSignals.putIfAbsent(sessionId, () => signal(null));
  }

  /// Clean up when a session/tab is disposed. Prevents signal leaks.
  void cleanup(String sessionId) {
    _sessionSignals.remove(sessionId)?.dispose();
  }

  @override
  Future<bool> requestToolApproval({
    required AgentSession session,
    required String toolName,
    required Map<String, dynamic> arguments,
    required String rationale,
  }) async {
    if (_alwaysAllow.contains(toolName)) return true;

    final completer = Completer<bool>();
    _queue.add(
      _QueueEntry(
        session: session,
        toolName: toolName,
        arguments: arguments,
        rationale: rationale,
        completer: completer,
      ),
    );
    _processQueue();
    return completer.future;
  }

  /// Resolve an approval: [approved] = true/false, [always] = remember.
  void resolve({required bool approved, bool always = false}) {
    final sig =
        _sessionSignals.values.where((s) => s.value != null).firstOrNull;
    if (sig == null) return;

    final request = sig.value!;
    if (always && approved) {
      _alwaysAllow.add(request.toolName);
    }
    request.completer.complete(approved);
    sig.value = null;
    _processing = false;
    _processQueue();
  }

  void _processQueue() {
    if (_processing || _queue.isEmpty) return;
    _processing = true;

    final entry = _queue.removeFirst();
    final request = ToolApprovalRequest(
      toolName: entry.toolName,
      arguments: entry.arguments,
      rationale: entry.rationale,
      completer: entry.completer,
    );

    signalFor(entry.session.id).value = request;
  }

  /// Dispose all session signals.
  void dispose() {
    // Reject any dispatched (signal-visible) approvals.
    for (final sig in _sessionSignals.values) {
      final request = sig.value;
      if (request != null && !request.completer.isCompleted) {
        request.completer.complete(false);
      }
      sig.dispose();
    }
    _sessionSignals.clear();
    // Reject any queued approvals.
    for (final entry in _queue) {
      if (!entry.completer.isCompleted) {
        entry.completer.complete(false);
      }
    }
    _queue.clear();
    _processing = false;
  }
}

class _QueueEntry {
  _QueueEntry({
    required this.session,
    required this.toolName,
    required this.arguments,
    required this.rationale,
    required this.completer,
  });

  final AgentSession session;
  final String toolName;
  final Map<String, dynamic> arguments;
  final String rationale;
  final Completer<bool> completer;
}
