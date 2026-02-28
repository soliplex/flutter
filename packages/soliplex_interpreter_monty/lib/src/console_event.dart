import 'package:dart_monty_platform_interface/dart_monty_platform_interface.dart';
import 'package:meta/meta.dart';
import 'package:soliplex_interpreter_monty/src/execution_result.dart';

/// Events emitted during Python code execution.
@immutable
sealed class ConsoleEvent {
  const ConsoleEvent();
}

/// A line of console output from a `print()` call.
final class ConsoleOutput extends ConsoleEvent {
  const ConsoleOutput(this.text);

  final String text;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConsoleOutput &&
          runtimeType == other.runtimeType &&
          text == other.text;

  @override
  int get hashCode => text.hashCode;

  @override
  String toString() => 'ConsoleOutput($text)';
}

/// Execution completed successfully.
final class ConsoleComplete extends ConsoleEvent {
  const ConsoleComplete(this.result);

  final ExecutionResult result;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConsoleComplete &&
          runtimeType == other.runtimeType &&
          result == other.result;

  @override
  int get hashCode => result.hashCode;

  @override
  String toString() => 'ConsoleComplete($result)';
}

/// Execution failed with a Python exception.
final class ConsoleError extends ConsoleEvent {
  const ConsoleError(this.error);

  final MontyException error;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConsoleError &&
          runtimeType == other.runtimeType &&
          error == other.error;

  @override
  int get hashCode => error.hashCode;

  @override
  String toString() => 'ConsoleError($error)';
}
