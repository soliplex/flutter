import 'dart:async';

import 'package:dart_monty_platform_interface/dart_monty_platform_interface.dart';
import 'package:soliplex_interpreter_monty/src/console_event.dart';
import 'package:soliplex_interpreter_monty/src/execution_result.dart';

/// Python print-override preamble injected before user code.
///
/// Reassigns the built-in `print` via variable assignment so that calls
/// to `print()` in user code route through the `__console_write__`
/// external function, which the service intercepts to stream output.
///
/// Monty does not allow `def print(...)` to shadow the built-in, so
/// we use direct variable assignment instead.
const _printPreamble = r'''
def _cw(*a, sep=' ', end='\n', **k):
    __console_write__(sep.join(str(x) for x in a) + end)
print = _cw
''';

const _consoleWriteFn = '__console_write__';

/// Executes Python code via [MontyPlatform] and streams console output.
///
/// Only one execution may run at a time. Attempting to call [execute]
/// while another execution is in progress throws a [StateError].
class MontyExecutionService {
  MontyExecutionService({MontyPlatform? platform, MontyLimits? limits})
      : _explicitPlatform = platform,
        _limits = limits;

  final MontyPlatform? _explicitPlatform;
  final MontyLimits? _limits;
  bool _isExecuting = false;
  bool _isDisposed = false;

  MontyPlatform get _platform => _explicitPlatform ?? MontyPlatform.instance;

  /// Whether an execution is currently in progress.
  bool get isExecuting => _isExecuting;

  /// Executes [code] and returns a stream of [ConsoleEvent]s.
  ///
  /// The stream emits [ConsoleOutput] for each `print()` call,
  /// then either [ConsoleComplete] or [ConsoleError] before closing.
  ///
  /// Throws [StateError] if already executing or disposed.
  Stream<ConsoleEvent> execute(String code) {
    if (_isDisposed) {
      throw StateError('MontyExecutionService has been disposed');
    }
    if (_isExecuting) {
      throw StateError(
        'MontyExecutionService is already executing. '
        'Only one execution may run at a time.',
      );
    }

    final controller = StreamController<ConsoleEvent>();
    _isExecuting = true;
    unawaited(
      _run(code, controller).whenComplete(() {
        _isExecuting = false;
        unawaited(controller.close());
      }),
    );

    return controller.stream;
  }

  /// Releases resources held by this service.
  void dispose() {
    _isDisposed = true;
  }

  Future<void> _run(
    String code,
    StreamController<ConsoleEvent> controller,
  ) async {
    final wrappedCode = '$_printPreamble\n$code';
    final output = StringBuffer();

    try {
      var progress = await _platform.start(
        wrappedCode,
        externalFunctions: const [_consoleWriteFn],
        limits: _limits,
      );

      while (true) {
        switch (progress) {
          case MontyPending(:final functionName, :final arguments):
            if (functionName == _consoleWriteFn && arguments.isNotEmpty) {
              final text = arguments.first.toString();
              output.write(text);
              controller.add(ConsoleOutput(text));
            }
            progress = await _platform.resume(null);

          case MontyResolveFutures():
            progress = await _platform.resume(null);

          case MontyComplete(:final result):
            final error = result.error;
            if (error != null) {
              controller.add(ConsoleError(error));
            } else {
              final value = result.value;
              controller.add(
                ConsoleComplete(
                  ExecutionResult(
                    value: value?.toString(),
                    usage: result.usage,
                    output: output.toString(),
                  ),
                ),
              );
            }

            return;
        }
      }
    } on MontyException catch (e) {
      controller.add(ConsoleError(e));
    } on Exception catch (e) {
      controller.addError(e);
    }
  }
}
