import 'package:soliplex_agent/src/runtime/agent_session.dart';

/// Callback interface for UI-side tool approval decisions.
///
/// Both Flutter and TUI implement this interface to control how tool
/// execution approval is presented to the user. When no delegate is
/// provided to `AgentRuntime`, tools are auto-approved (headless mode).
///
/// ```dart
/// class MyUiDelegate implements AgentUiDelegate {
///   @override
///   Future<bool> requestToolApproval({
///     required AgentSession session,
///     required String toolName,
///     required Map<String, dynamic> arguments,
///     required String rationale,
///   }) async {
///     // Show dialog, return user's decision
///     return showApprovalDialog(toolName, rationale);
///   }
/// }
/// ```
abstract interface class AgentUiDelegate {
  /// Suspends the tool loop until the user approves or rejects.
  ///
  /// [session] identifies which session is requesting approval, allowing
  /// multi-tab UIs to route the prompt to the correct view.
  ///
  /// Returns `true` to proceed with tool execution, `false` to deny.
  /// When denied, the tool receives a "User denied permission" error
  /// that is fed back to the LLM.
  Future<bool> requestToolApproval({
    required AgentSession session,
    required String toolName,
    required Map<String, dynamic> arguments,
    required String rationale,
  });
}
