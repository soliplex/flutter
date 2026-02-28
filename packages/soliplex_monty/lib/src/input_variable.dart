import 'package:meta/meta.dart';

/// Describes an input variable for Python code execution.
@immutable
class InputVariable {
  const InputVariable({
    required this.label,
    this.type = InputVariableType.string,
    this.defaultValue,
    this.validator,
  });

  /// Display label for the input field.
  final String label;

  /// Expected Python type for this variable.
  final InputVariableType type;

  /// Default value pre-filled in the form.
  final String? defaultValue;

  /// Custom validator. Return an error string or null if valid.
  final String? Function(String?)? validator;
}

/// Supported Python variable types for form validation.
enum InputVariableType {
  string,
  int,
  float,
  bool,
}
