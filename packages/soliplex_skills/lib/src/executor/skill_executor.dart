import 'package:meta/meta.dart';

/// Role for an injected message.
enum MessageRole {
  /// Injected as a system message.
  system,

  /// Injected as a user message.
  user,
}

/// Result of executing a skill.
@immutable
sealed class SkillResult {
  const SkillResult();
}

/// A chat message to inject from a Markdown skill.
@immutable
final class MessageInjection extends SkillResult {
  const MessageInjection({required this.role, required this.content});

  /// The role the message should be injected as.
  final MessageRole role;

  /// The message content.
  final String content;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MessageInjection &&
          runtimeType == other.runtimeType &&
          role == other.role &&
          content == other.content;

  @override
  int get hashCode => Object.hash(runtimeType, role, content);

  @override
  String toString() => 'MessageInjection(role: $role)';
}

/// Output from executing a Python skill.
@immutable
final class ExecutionOutput extends SkillResult {
  const ExecutionOutput({required this.output, this.error});

  /// Standard output from the execution.
  final String output;

  /// Error message, if execution failed.
  final String? error;

  /// Whether execution completed without errors.
  bool get isSuccess => error == null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExecutionOutput &&
          runtimeType == other.runtimeType &&
          output == other.output &&
          error == other.error;

  @override
  int get hashCode => Object.hash(runtimeType, output, error);

  @override
  String toString() => 'ExecutionOutput(success: $isSuccess)';
}

/// Signature for a function that executes Python code and returns output.
///
/// Injected by the host (Flutter app or TUI) to decouple from Monty.
typedef PythonRunner = Future<String> Function(String code);
