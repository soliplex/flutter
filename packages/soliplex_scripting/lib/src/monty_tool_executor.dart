import 'dart:convert';

import 'package:soliplex_agent/soliplex_agent.dart' show ThreadKey;
import 'package:soliplex_client/soliplex_client.dart' show ToolCallInfo;
import 'package:soliplex_interpreter_monty/soliplex_interpreter_monty.dart';
import 'package:soliplex_scripting/src/bridge_cache.dart';
import 'package:soliplex_scripting/src/host_function_wiring.dart';

/// Executes `execute_python` tool calls against a cached [MontyBridge].
///
/// One executor is created per session/thread. The [threadKey] determines
/// which bridge is acquired from the [BridgeCache].
///
/// Execution flow:
/// 1. Extract `code` from the [ToolCallInfo] arguments.
/// 2. Acquire a bridge from the cache for this thread.
/// 3. Register host functions via [HostFunctionWiring].
/// 4. Execute the code and collect text output.
/// 5. Release the bridge back to the cache (even on error).
class MontyToolExecutor {
  MontyToolExecutor({
    required this.threadKey,
    required BridgeCache bridgeCache,
    required HostFunctionWiring hostWiring,
  })  : _cache = bridgeCache,
        _wiring = hostWiring;

  /// Thread identity for bridge acquisition.
  final ThreadKey threadKey;
  final BridgeCache _cache;
  final HostFunctionWiring _wiring;

  /// Executes the Python code in [toolCall] and returns the text result.
  ///
  /// The [ToolCallInfo.arguments] must be a JSON object with a `code` key
  /// containing the Python source to execute.
  ///
  /// Throws [ArgumentError] if the code argument is missing or not a string.
  /// Throws [StateError] if the bridge emits a [BridgeRunError].
  Future<String> execute(ToolCallInfo toolCall) async {
    final code = _extractCode(toolCall);
    final bridge = _cache.acquire(threadKey);
    _wiring.registerOnto(bridge);
    try {
      final events = bridge.execute(code);
      return await _collectTextResult(events);
    } finally {
      _cache.release(threadKey);
    }
  }

  /// Decodes the JSON arguments and extracts the `code` field.
  static String _extractCode(ToolCallInfo toolCall) {
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
      throw ArgumentError.value(
        code,
        'code',
        'Expected a non-empty string.',
      );
    }

    return code;
  }

  /// Listens to the bridge event stream and accumulates text deltas.
  ///
  /// Throws [StateError] if a [BridgeRunError] is encountered.
  static Future<String> _collectTextResult(Stream<BridgeEvent> events) async {
    final buffer = StringBuffer();
    await for (final event in events) {
      switch (event) {
        case BridgeTextContent(:final delta):
          buffer.write(delta);
        case BridgeRunError(:final message):
          throw StateError(message);
        default:
          break;
      }
    }
    return buffer.toString();
  }
}
