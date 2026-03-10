import 'dart:async';
import 'dart:convert';

import 'package:ag_ui/ag_ui.dart' show Tool;
import 'package:dart_monty_platform_interface/dart_monty_platform_interface.dart'
    show MontyPlatform;
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
  ///
  /// When [hostFunctionSchemas] is provided, the `execute_python` tool
  /// description includes a listing of all available host functions and
  /// their signatures so the LLM knows what it can call.
  MontyScriptEnvironment({
    required MontyBridge bridge,
    required DfRegistry dfRegistry,
    required StreamRegistry streamRegistry,
    MontyPlatform? ownedPlatform,
    Duration executionTimeout = const Duration(seconds: 30),
    IsolatePlugin? isolatePlugin,
    List<HostFunctionSchema>? hostFunctionSchemas,
  })  : _bridge = bridge,
        _ownedPlatform = ownedPlatform,
        _dfRegistry = dfRegistry,
        _streamRegistry = streamRegistry,
        _executionTimeout = executionTimeout,
        _isolatePlugin = isolatePlugin,
        _hostFunctionSchemas = hostFunctionSchemas;

  final MontyBridge _bridge;
  final MontyPlatform? _ownedPlatform;
  final DfRegistry _dfRegistry;
  final StreamRegistry _streamRegistry;
  final Duration _executionTimeout;
  final IsolatePlugin? _isolatePlugin;
  final List<HostFunctionSchema>? _hostFunctionSchemas;
  bool _disposed = false;

  @override
  List<ClientTool> get tools => [
        ClientTool(
          definition: _buildToolDefinition(),
          executor: _executePython,
        ),
      ];

  Tool _buildToolDefinition() {
    final schemas = _hostFunctionSchemas;
    if (schemas == null || schemas.isEmpty) {
      return PythonExecutorTool.definition;
    }

    final buffer = StringBuffer(
      'Execute Python code in a sandboxed interpreter. '
      'No imports available. All functions are pre-loaded globals '
      'using keyword arguments. Fresh scope per call.\n\n'
      'Functions:\n',
    );
    for (final schema in schemas) {
      final params = schema.params.map((p) {
        final typeName = p.type.jsonSchemaType;
        final req = p.isRequired ? '' : '?';
        return '${p.name}: $typeName$req';
      }).join(', ');
      buffer.writeln('- ${schema.name}($params)');
    }

    return Tool(
      name: PythonExecutorTool.toolName,
      description: buffer.toString(),
      parameters: PythonExecutorTool.definition.parameters,
    );
  }

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
    if (_ownedPlatform != null) unawaited(_ownedPlatform.dispose());
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
