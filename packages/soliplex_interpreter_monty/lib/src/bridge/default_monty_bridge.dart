import 'dart:async';
import 'dart:convert';

import 'package:dart_monty_platform_interface/dart_monty_platform_interface.dart';
import 'package:soliplex_interpreter_monty/src/bridge/bridge_event.dart';
import 'package:soliplex_interpreter_monty/src/bridge/host_function.dart';
import 'package:soliplex_interpreter_monty/src/bridge/host_function_schema.dart';
import 'package:soliplex_interpreter_monty/src/bridge/monty_bridge.dart';

/// Print-override preamble injected before user code.
///
/// Routes Python `print()` calls through `__console_write__` so the bridge
/// can capture output and emit it as text events.
const _printPreamble = r'''
def _cw(*a, sep=' ', end='\n', **k):
    __console_write__(sep.join(str(x) for x in a) + end)
print = _cw
''';

const _consoleWriteFn = '__console_write__';

/// Default [MontyBridge] implementation.
///
/// Orchestrates the Monty start/resume loop, dispatching external function
/// calls to registered [HostFunction] handlers and emitting [BridgeEvent]s.
class DefaultMontyBridge implements MontyBridge {
  DefaultMontyBridge({MontyPlatform? platform, MontyLimits? limits})
      : _explicitPlatform = platform,
        _limits = limits;

  final MontyPlatform? _explicitPlatform;
  final MontyLimits? _limits;
  final Map<String, HostFunction> _functions = {};
  int _idCounter = 0;
  bool _isExecuting = false;
  bool _isDisposed = false;

  MontyPlatform get _platform => _explicitPlatform ?? MontyPlatform.instance;

  String get _nextId => '${_idCounter++}';

  @override
  List<HostFunctionSchema> get schemas =>
      _functions.values.map((f) => f.schema).toList(growable: false);

  @override
  void register(HostFunction function) {
    if (_isDisposed) throw StateError('Bridge has been disposed');
    _functions[function.schema.name] = function;
  }

  @override
  void unregister(String name) {
    if (_isDisposed) throw StateError('Bridge has been disposed');
    _functions.remove(name);
  }

  @override
  Stream<BridgeEvent> execute(String code) {
    if (_isDisposed) throw StateError('Bridge has been disposed');
    if (_isExecuting) {
      throw StateError('Bridge is already executing');
    }

    final controller = StreamController<BridgeEvent>();
    _isExecuting = true;
    unawaited(
      _run(code, controller).whenComplete(() {
        _isExecuting = false;
        unawaited(controller.close());
      }),
    );

    return controller.stream;
  }

  @override
  void dispose() {
    _isDisposed = true;
  }

  Future<void> _run(
    String code,
    StreamController<BridgeEvent> controller,
  ) async {
    final threadId = _nextId;
    final runId = _nextId;

    controller.add(BridgeRunStarted(threadId: threadId, runId: runId));

    final printBuffer = StringBuffer();
    final wrappedCode = '$_printPreamble\n$code';
    final externalFunctions = [_consoleWriteFn, ..._functions.keys];

    try {
      var progress = await _platform.start(
        wrappedCode,
        externalFunctions: externalFunctions,
        limits: _limits,
      );

      while (true) {
        switch (progress) {
          case final MontyPending pending:
            progress = await _handlePending(pending, printBuffer, controller);

          case MontyResolveFutures():
            // TODO(M13): Implement async/futures support.
            progress = await _platform.resume(null);

          case MontyComplete(:final result):
            _flushPrintBuffer(printBuffer, controller);

            if (result.isError) {
              controller.add(BridgeRunError(message: result.error!.message));
            } else {
              controller.add(
                BridgeRunFinished(threadId: threadId, runId: runId),
              );
            }
            return;
        }
      }
    } on MontyException catch (e) {
      controller.add(BridgeRunError(message: e.message));
    } on Exception catch (e) {
      controller.addError(e);
    }
  }

  Future<MontyProgress> _handlePending(
    MontyPending pending,
    StringBuffer printBuffer,
    StreamController<BridgeEvent> controller,
  ) async {
    final name = pending.functionName;

    // Console write — always intercept, buffer for text flush.
    if (name == _consoleWriteFn) {
      if (pending.arguments.isNotEmpty) {
        printBuffer.write(pending.arguments.first.toString());
      }

      return _platform.resume(null);
    }

    // Registered host function — emit tool call events.
    final fn = _functions[name];
    if (fn != null) {
      return _dispatchToolCall(fn, pending, controller);
    }

    // Unknown function — raise error in Python.
    return _platform.resumeWithError('Unknown function: $name');
  }

  Future<MontyProgress> _dispatchToolCall(
    HostFunction fn,
    MontyPending pending,
    StreamController<BridgeEvent> controller,
  ) async {
    final callId = _nextId;
    final stepName = pending.functionName;

    controller
      ..add(BridgeStepStarted(stepId: stepName))
      ..add(BridgeToolCallStart(callId: callId, name: stepName));

    // Map and validate arguments.
    final Map<String, Object?> args;
    try {
      args = fn.schema.mapAndValidate(pending);
    } on FormatException catch (e) {
      controller
        ..add(BridgeToolCallResult(callId: callId, result: 'Error: $e'))
        ..add(BridgeStepFinished(stepId: stepName));

      return _platform.resumeWithError(e.toString());
    }
    controller
      ..add(BridgeToolCallArgs(callId: callId, delta: jsonEncode(args)))
      ..add(BridgeToolCallEnd(callId: callId));

    // Execute handler.
    try {
      final result = await fn.handler(args);
      controller
        ..add(
          BridgeToolCallResult(
            callId: callId,
            result: result?.toString() ?? '',
          ),
        )
        ..add(BridgeStepFinished(stepId: stepName));

      return _platform.resume(result);
    } on Exception catch (e) {
      controller
        ..add(BridgeToolCallResult(callId: callId, result: 'Error: $e'))
        ..add(BridgeStepFinished(stepId: stepName));

      return _platform.resumeWithError(e.toString());
    }
  }

  void _flushPrintBuffer(
    StringBuffer buffer,
    StreamController<BridgeEvent> controller,
  ) {
    if (buffer.isEmpty) return;
    final messageId = _nextId;
    controller
      ..add(BridgeTextStart(messageId: messageId))
      ..add(
        BridgeTextContent(messageId: messageId, delta: buffer.toString()),
      )
      ..add(BridgeTextEnd(messageId: messageId));
  }
}
