import 'dart:async';

import 'package:dart_monty_platform_interface/dart_monty_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:soliplex_monty/src/console_event.dart';
import 'package:soliplex_monty/src/execution_result.dart';
import 'package:soliplex_monty/src/input_variable.dart';
import 'package:soliplex_monty/src/monty_execution_service.dart';
import 'package:soliplex_monty/src/monty_limits_defaults.dart';

enum _ButtonState { idle, executing, completed, error }

/// A play/stop button that executes Python code via [MontyExecutionService].
///
/// If [inputVariables] is non-empty, shows a form dialog to collect and
/// validate input values before execution. Validated inputs are injected
/// as Python variable assignments before the user code.
class PythonRunButton extends StatefulWidget {
  const PythonRunButton({
    required this.code,
    this.inputVariables = const {},
    this.service,
    this.limits,
    this.onResult,
    this.onError,
    this.onConsoleEvent,
    super.key,
  });

  /// The Python source code to execute.
  final String code;

  /// Input variables to collect via form before execution.
  /// Keys are Python variable names, values describe the input field.
  final Map<String, InputVariable> inputVariables;

  /// Optional service instance. Creates one internally if not provided.
  final MontyExecutionService? service;

  /// Resource limits for execution.
  final MontyLimits? limits;

  /// Called when execution completes successfully.
  final ValueChanged<ExecutionResult>? onResult;

  /// Called when execution fails with an exception.
  final ValueChanged<MontyException>? onError;

  /// Called for each console event during execution.
  final ValueChanged<ConsoleEvent>? onConsoleEvent;

  @override
  State<PythonRunButton> createState() => _PythonRunButtonState();
}

class _PythonRunButtonState extends State<PythonRunButton> {
  MontyExecutionService? _ownedService;
  _ButtonState _state = _ButtonState.idle;
  StreamSubscription<ConsoleEvent>? _subscription;

  MontyExecutionService get _service {
    final provided = widget.service;
    if (provided != null) return provided;

    return _ownedService ??= MontyExecutionService(
      limits: widget.limits ?? MontyLimitsDefaults.playButton,
    );
  }

  @override
  void didUpdateWidget(PythonRunButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.service != oldWidget.service) {
      _ownedService?.dispose();
      _ownedService = null;
    }
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    _ownedService?.dispose();
    super.dispose();
  }

  void _handlePressed() {
    if (_state == _ButtonState.executing) return;

    if (widget.inputVariables.isNotEmpty) {
      unawaited(_collectInputsThenExecute());
    } else {
      _executeWithInputs(const {});
    }
  }

  Future<void> _collectInputsThenExecute() async {
    final inputs = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => _InputDialog(variables: widget.inputVariables),
    );
    if (inputs == null || !mounted) return;
    _executeWithInputs(inputs);
  }

  void _executeWithInputs(Map<String, String> inputs) {
    final preamble = _buildInputPreamble(inputs);
    final code = preamble.isEmpty ? widget.code : '$preamble\n${widget.code}';

    setState(() => _state = _ButtonState.executing);

    _subscription = _service.execute(code).listen(
      (event) {
        widget.onConsoleEvent?.call(event);
        switch (event) {
          case ConsoleComplete(:final result):
            widget.onResult?.call(result);
            if (mounted) setState(() => _state = _ButtonState.completed);
          case ConsoleError(:final error):
            widget.onError?.call(error);
            if (mounted) setState(() => _state = _ButtonState.error);
          case ConsoleOutput():
            break;
        }
      },
      onError: (_) {
        if (mounted) setState(() => _state = _ButtonState.error);
      },
    );
  }

  String _buildInputPreamble(Map<String, String> inputs) {
    if (inputs.isEmpty) return '';
    final lines = <String>[];
    for (final entry in inputs.entries) {
      final name = entry.key;
      final raw = entry.value;
      final variable = widget.inputVariables[name];
      if (variable == null) continue;
      lines.add('$name = ${_toPythonLiteral(raw, variable.type)}');
    }

    return lines.join('\n');
  }

  String _toPythonLiteral(String raw, InputVariableType type) {
    return switch (type) {
      InputVariableType.string => _escapePythonString(raw),
      InputVariableType.int => raw.trim(),
      InputVariableType.float => raw.trim(),
      InputVariableType.bool =>
        raw.trim().toLowerCase() == 'true' ? 'True' : 'False',
    };
  }

  String _escapePythonString(String raw) {
    final escaped = raw
        .replaceAll(r'\', r'\\')
        .replaceAll("'", r"\'")
        .replaceAll('\n', r'\n')
        .replaceAll('\r', r'\r')
        .replaceAll('\t', r'\t');

    return "'$escaped'";
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: _state == _ButtonState.executing ? null : _handlePressed,
      icon: switch (_state) {
        _ButtonState.idle => const Icon(Icons.play_arrow),
        _ButtonState.executing => const SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        _ButtonState.completed => const Icon(Icons.check, color: Colors.green),
        _ButtonState.error =>
          const Icon(Icons.error_outline, color: Colors.red),
      },
      tooltip: switch (_state) {
        _ButtonState.idle => 'Run Python',
        _ButtonState.executing => 'Executing...',
        _ButtonState.completed => 'Completed',
        _ButtonState.error => 'Error',
      },
    );
  }
}

class _InputDialog extends StatefulWidget {
  const _InputDialog({required this.variables});

  final Map<String, InputVariable> variables;

  @override
  State<_InputDialog> createState() => _InputDialogState();
}

class _InputDialogState extends State<_InputDialog> {
  final _formKey = GlobalKey<FormState>();
  final _controllers = <String, TextEditingController>{};

  @override
  void initState() {
    super.initState();
    for (final entry in widget.variables.entries) {
      _controllers[entry.key] =
          TextEditingController(text: entry.value.defaultValue ?? '');
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  String? _validate(String? value, InputVariable variable) {
    if (variable.validator != null) {
      return variable.validator?.call(value);
    }
    if (value == null || value.trim().isEmpty) {
      return '${variable.label} is required';
    }
    final trimmed = value.trim();

    return switch (variable.type) {
      InputVariableType.int when int.tryParse(trimmed) == null =>
        'Must be an integer',
      InputVariableType.float when double.tryParse(trimmed) == null =>
        'Must be a number',
      InputVariableType.bool
          when trimmed.toLowerCase() != 'true' &&
              trimmed.toLowerCase() != 'false' =>
        'Must be true or false',
      _ => null,
    };
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      Navigator.of(context).pop({
        for (final entry in _controllers.entries) entry.key: entry.value.text,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Input Variables'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final entry in widget.variables.entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: TextFormField(
                    controller: _controllers[entry.key],
                    decoration: InputDecoration(
                      labelText: entry.value.label,
                      hintText: entry.value.type.name,
                    ),
                    validator: (value) => _validate(value, entry.value),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Run'),
        ),
      ],
    );
  }
}
