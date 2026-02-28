import 'package:meta/meta.dart';
import 'package:soliplex_interpreter_monty/src/bridge/host_param_type.dart';

/// Describes a single parameter of a host function.
@immutable
class HostParam {
  const HostParam({
    required this.name,
    required this.type,
    this.isRequired = true,
    this.description,
    this.defaultValue,
  });

  /// Parameter name (used as the key in the validated args map).
  final String name;

  /// Expected type.
  final HostParamType type;

  /// Whether the caller must supply a value.
  final bool isRequired;

  /// Human-readable description for ag-ui tool export.
  final String? description;

  /// Default value when the argument is absent and not required.
  final Object? defaultValue;

  /// Validates and optionally coerces [value].
  ///
  /// Returns the validated (possibly coerced) value.
  /// Throws [FormatException] if validation fails.
  Object? validate(Object? value) {
    if (value == null) {
      if (isRequired) {
        throw FormatException(
          'Required parameter "$name" is null',
          value,
        );
      }

      return defaultValue;
    }

    return switch (type) {
      HostParamType.string => _expectType<String>(value),
      HostParamType.integer => _expectType<int>(value),
      HostParamType.number => _coerceNumber(value),
      HostParamType.boolean => _expectType<bool>(value),
      HostParamType.list => _expectType<List<Object?>>(value),
      HostParamType.map => _expectType<Map<String, Object?>>(value),
    };
  }

  T _expectType<T>(Object? value) {
    if (value is T) return value;
    throw FormatException(
      'Parameter "$name": expected $T, got ${value.runtimeType}',
      value,
    );
  }

  /// Accept both int and double for number params.
  num _coerceNumber(Object? value) {
    if (value is num) return value;
    throw FormatException(
      'Parameter "$name": expected num, got ${value.runtimeType}',
      value,
    );
  }
}
