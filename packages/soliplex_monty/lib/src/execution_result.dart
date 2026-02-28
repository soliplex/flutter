import 'package:dart_monty_platform_interface/dart_monty_platform_interface.dart';
import 'package:meta/meta.dart';

/// The result of a completed Python execution.
@immutable
class ExecutionResult {
  const ExecutionResult({
    required this.usage,
    required this.output,
    this.value,
  });

  /// The return value of the Python expression, if any.
  final String? value;

  /// Resource usage during execution.
  final MontyResourceUsage usage;

  /// Collected console output from `print()` calls.
  final String output;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExecutionResult &&
          runtimeType == other.runtimeType &&
          value == other.value &&
          usage == other.usage &&
          output == other.output;

  @override
  int get hashCode => Object.hash(value, usage, output);

  @override
  String toString() =>
      'ExecutionResult(value: $value, output: $output, usage: $usage)';
}
