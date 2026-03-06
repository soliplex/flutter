import 'dart:async';
import 'dart:convert';

import 'package:soliplex_agent/soliplex_agent.dart'
    show ClientTool, ScriptEnvironment;
import 'package:soliplex_client/soliplex_client.dart' show ToolCallInfo;
import 'package:soliplex_dataframe/soliplex_dataframe.dart';
import 'package:soliplex_interpreter_monty/soliplex_interpreter_monty.dart';
import 'package:soliplex_scripting/src/python_executor_tool.dart';
import 'package:soliplex_scripting/src/stream_registry.dart';

/// Session-scoped [ScriptEnvironment] backed by a [MontyBridge].
///
/// Owns the bridge, [DfRegistry], and [StreamRegistry]. Host functions are
/// registered once at construction (via factory). The [dispose] method
/// releases all resources — called automatically by `AgentSession.dispose()`.
///
/// The bridge lives for exactly one session — no acquire/release cycle or
/// LRU eviction.
class MontyScriptEnvironment implements ScriptEnvironment {
  /// Creates an environment with pre-configured resources.
  ///
  /// Host functions should already be registered onto [bridge] before
  /// constructing this environment (done by the factory function).
  MontyScriptEnvironment({
    required MontyBridge bridge,
    required DfRegistry dfRegistry,
    required StreamRegistry streamRegistry,
    Duration executionTimeout = const Duration(seconds: 30),
    IsolatePlugin? isolatePlugin,
  })  : _bridge = bridge,
        _dfRegistry = dfRegistry,
        _streamRegistry = streamRegistry,
        _executionTimeout = executionTimeout,
        _isolatePlugin = isolatePlugin;

  final MontyBridge _bridge;
  final DfRegistry _dfRegistry;
  final StreamRegistry _streamRegistry;
  final Duration _executionTimeout;
  final IsolatePlugin? _isolatePlugin;
  bool _disposed = false;

  @override
  List<ClientTool> get tools => [
        ClientTool(
          definition: PythonExecutorTool.definition,
          executor: _executePython,
        ),
      ];

  Future<String> _executePython(ToolCallInfo toolCall, _) async {
    final code = extractCode(toolCall);
    final events = _bridge.execute(code);
    final result = await collectTextResult(events).timeout(_executionTimeout);
    return result.isEmpty ? '(ok)' : result;
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    if (_isolatePlugin != null) unawaited(_isolatePlugin.onDispose());
    _bridge.dispose();
    _dfRegistry.disposeAll();
    unawaited(_streamRegistry.dispose());
  }

  /// Decodes the JSON arguments and extracts the `code` field.
  static String extractCode(ToolCallInfo toolCall) {
    final Object? decoded;
    try {
      decoded = jsonDecode(toolCall.arguments);
    } on FormatException {
      throw ArgumentError.value(
        toolCall.arguments,
        'toolCall.arguments',
        'Expected valid JSON.',
      );
    }

    if (decoded is! Map<String, Object?>) {
      throw ArgumentError.value(
        decoded,
        'toolCall.arguments',
        'Expected a JSON object.',
      );
    }

    final code = decoded['code'];
    if (code is! String || code.isEmpty) {
      throw ArgumentError.value(code, 'code', 'Expected a non-empty string.');
    }

    return code;
  }

  /// Listens to the bridge event stream and accumulates text deltas
  /// and host-function results.
  ///
  /// Throws [StateError] if a [BridgeRunError] is encountered.
  static Future<String> collectTextResult(Stream<BridgeEvent> events) async {
    final buffer = StringBuffer();
    await for (final event in events) {
      switch (event) {
        case BridgeTextContent(:final delta):
          buffer.write(delta);
        case BridgeToolCallResult(:final result) when result.isNotEmpty:
          if (buffer.isNotEmpty) buffer.write('\n');
          buffer.writeln(result);
        case BridgeRunError(:final message):
          throw StateError(message);
        default:
          break;
      }
    }
    return buffer.toString();
  }
}
