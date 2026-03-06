import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:soliplex_agent/soliplex_agent.dart'
    show
        AgentApi,
        AgentFailure,
        AgentSuccess,
        AgentTimedOut,
        BlackboardApi,
        FormApi,
        HostApi;
import 'package:soliplex_dataframe/soliplex_dataframe.dart';
import 'package:soliplex_interpreter_monty/soliplex_interpreter_monty.dart';
import 'package:soliplex_scripting/src/df_functions.dart';
import 'package:soliplex_scripting/src/stream_registry.dart';

/// Wires [HostApi] methods to [HostFunction]s and registers them onto a
/// [MontyBridge] via a [HostFunctionRegistry].
///
/// Each category maps Python-callable function names to the corresponding
/// [HostApi] method:
///
/// | Category | Python name    | HostApi method       |
/// |----------|---------------|----------------------|
/// | df       | `df_*` (37)   | via DfRegistry       |
/// | chart    | `chart_create`| `registerChart`      |
/// | platform | `host_invoke` | `invoke`             |
class HostFunctionWiring {
  HostFunctionWiring({
    required HostApi hostApi,
    AgentApi? agentApi,
    BlackboardApi? blackboardApi,
    DfRegistry? dfRegistry,
    StreamRegistry? streamRegistry,
    FormApi? formApi,
    List<HostFunction>? extraFunctions,
    Duration agentTimeout = const Duration(seconds: 30),
  })  : _hostApi = hostApi,
        _agentApi = agentApi,
        _blackboardApi = blackboardApi,
        _dfRegistry = dfRegistry ?? DfRegistry(),
        _streamRegistry = streamRegistry,
        _formApi = formApi,
        _extraFunctions = extraFunctions,
        _agentTimeout = agentTimeout;

  final HostApi _hostApi;
  final AgentApi? _agentApi;
  final BlackboardApi? _blackboardApi;
  final DfRegistry _dfRegistry;
  final StreamRegistry? _streamRegistry;
  final FormApi? _formApi;
  final List<HostFunction>? _extraFunctions;
  final Duration _agentTimeout;

  /// Registers all host function categories (plus introspection builtins)
  /// onto [bridge].
  void registerOnto(MontyBridge bridge) {
    final registry = HostFunctionRegistry()
      ..addCategory('df', buildDfFunctions(_dfRegistry))
      ..addCategory('chart', _chartFunctions())
      ..addCategory('platform', _platformFunctions());
    if (_streamRegistry != null) {
      registry.addCategory('stream', _streamFunctions());
    }
    if (_formApi != null) {
      registry.addCategory('form', _formFunctions());
    }
    if (_agentApi != null) {
      registry.addCategory('agent', _agentFunctions());
    }
    if (_blackboardApi != null) {
      registry.addCategory('blackboard', _blackboardFunctions());
    }
    if (_extraFunctions != null && _extraFunctions.isNotEmpty) {
      registry.addCategory('extra', _extraFunctions);
    }
    registry.registerAllOnto(bridge);
  }

  List<HostFunction> _chartFunctions() => [
        HostFunction(
          schema: const HostFunctionSchema(
            name: 'chart_create',
            description: 'Create a chart from a configuration map.',
            params: [
              HostParam(
                name: 'config',
                type: HostParamType.map,
                description: 'Chart configuration.',
              ),
            ],
          ),
          handler: (args) async {
            final raw = args['config'];
            if (raw is! Map) {
              throw ArgumentError.value(raw, 'config', 'Expected a map.');
            }
            return _hostApi.registerChart(Map<String, Object?>.from(raw));
          },
        ),
        HostFunction(
          schema: const HostFunctionSchema(
            name: 'chart_update',
            description: 'Update an existing chart with a new configuration.',
            params: [
              HostParam(
                name: 'chart_id',
                type: HostParamType.integer,
                description: 'Chart handle returned by chart_create.',
              ),
              HostParam(
                name: 'config',
                type: HostParamType.map,
                description: 'New chart configuration.',
              ),
            ],
          ),
          handler: (args) async {
            final chartId = (args['chart_id']! as num).toInt();
            final raw = args['config'];
            if (raw is! Map) {
              throw ArgumentError.value(raw, 'config', 'Expected a map.');
            }
            return _hostApi.updateChart(
              chartId,
              Map<String, Object?>.from(raw),
            );
          },
        ),
      ];

  List<HostFunction> _platformFunctions() => [
        HostFunction(
          schema: const HostFunctionSchema(
            name: 'host_invoke',
            description: 'Invoke a named host operation.',
            params: [
              HostParam(
                name: 'name',
                type: HostParamType.string,
                description: 'Namespaced operation name.',
              ),
              HostParam(
                name: 'args',
                type: HostParamType.map,
                description: 'Arguments for the operation.',
              ),
            ],
          ),
          handler: (args) async {
            final name = args['name'];
            if (name is! String) {
              throw ArgumentError.value(name, 'name', 'Expected a string.');
            }
            final rawArgs = args['args'];
            if (rawArgs is! Map) {
              throw ArgumentError.value(rawArgs, 'args', 'Expected a map.');
            }
            return _hostApi.invoke(name, Map<String, Object?>.from(rawArgs));
          },
        ),
        HostFunction(
          schema: const HostFunctionSchema(
            name: 'sleep',
            description: 'Pause execution for a number of milliseconds.',
            params: [
              HostParam(
                name: 'ms',
                type: HostParamType.integer,
                description: 'Duration in milliseconds.',
              ),
            ],
          ),
          handler: (args) async {
            final ms = (args['ms']! as num).toInt();
            await Future<void>.delayed(Duration(milliseconds: ms));
            return null;
          },
        ),
        HostFunction(
          schema: const HostFunctionSchema(
            name: 'fetch',
            description: 'Make an HTTP request and return the response. '
                'Returns a dict with status, body, and headers.',
            params: [
              HostParam(
                name: 'url',
                type: HostParamType.string,
                description: 'Request URL.',
              ),
              HostParam(
                name: 'method',
                type: HostParamType.string,
                isRequired: false,
                defaultValue: 'GET',
                description: 'HTTP method (GET, POST, PUT, DELETE).',
              ),
              HostParam(
                name: 'headers',
                type: HostParamType.map,
                isRequired: false,
                description: 'Request headers.',
              ),
              HostParam(
                name: 'body',
                type: HostParamType.string,
                isRequired: false,
                description: 'Request body (for POST/PUT).',
              ),
            ],
          ),
          handler: (args) async {
            final url = Uri.parse(args['url']! as String);
            final method = (args['method']! as String).toUpperCase();
            final rawHeaders = args['headers'] as Map?;
            final headers = rawHeaders != null
                ? Map<String, String>.from(rawHeaders)
                : <String, String>{};
            final body = args['body'] as String?;

            final http.Response response;
            switch (method) {
              case 'POST':
                response = await http.post(url, headers: headers, body: body);
              case 'PUT':
                response = await http.put(url, headers: headers, body: body);
              case 'DELETE':
                response = await http.delete(url, headers: headers);
              default:
                response = await http.get(url, headers: headers);
            }

            return <String, Object?>{
              'status': response.statusCode,
              'body': response.body,
              'headers': response.headers,
            };
          },
        ),
        HostFunction(
          schema: const HostFunctionSchema(
            name: 'log',
            description: 'Log a message at the specified level. '
                'Visible in host debug output.',
            params: [
              HostParam(
                name: 'message',
                type: HostParamType.string,
                description: 'Log message.',
              ),
              HostParam(
                name: 'level',
                type: HostParamType.string,
                isRequired: false,
                defaultValue: 'info',
                description:
                    "Log level: 'debug', 'info', 'warning', or 'error'.",
              ),
            ],
          ),
          handler: (args) async {
            final level = args['level']! as String;
            final message = args['message']! as String;
            return _hostApi.invoke(
              'log',
              <String, Object?>{'level': level, 'message': message},
            );
          },
        ),
      ];

  List<HostFunction> _formFunctions() => [
        HostFunction(
          schema: const HostFunctionSchema(
            name: 'form_create',
            description: 'Create a dynamic form with field definitions.',
            params: [
              HostParam(
                name: 'fields',
                type: HostParamType.list,
                description: 'List of field definition maps.',
              ),
            ],
          ),
          handler: (args) async {
            final raw = args['fields']! as List<Object?>;
            final fields = <Map<String, Object?>>[];
            for (final item in raw) {
              fields.add(Map<String, Object?>.from(item! as Map));
            }
            return _formApi!.createForm(fields);
          },
        ),
        HostFunction(
          schema: const HostFunctionSchema(
            name: 'form_set_errors',
            description: 'Set validation errors on a form.',
            params: [
              HostParam(
                name: 'handle',
                type: HostParamType.integer,
                description: 'Form handle.',
              ),
              HostParam(
                name: 'errors',
                type: HostParamType.map,
                description: 'Map of field name to error message.',
              ),
            ],
          ),
          handler: (args) async {
            final handle = (args['handle']! as num).toInt();
            final raw = args['errors'];
            if (raw is! Map) {
              throw ArgumentError.value(raw, 'errors', 'Expected a map.');
            }
            return _formApi!
                .setFormErrors(handle, Map<String, String>.from(raw));
          },
        ),
      ];

  List<HostFunction> _streamFunctions() => [
        HostFunction(
          schema: const HostFunctionSchema(
            name: 'stream_subscribe',
            description: 'Subscribe to a named data stream.',
            params: [
              HostParam(
                name: 'name',
                type: HostParamType.string,
                description: 'Stream name.',
              ),
            ],
          ),
          handler: (args) async {
            final name = args['name']! as String;
            return _streamRegistry!.subscribe(name);
          },
        ),
        HostFunction(
          schema: const HostFunctionSchema(
            name: 'stream_next',
            description: 'Pull the next value from a stream subscription.',
            params: [
              HostParam(
                name: 'handle',
                type: HostParamType.integer,
                description: 'Subscription handle.',
              ),
            ],
          ),
          handler: (args) async {
            final handle = (args['handle']! as num).toInt();
            return _streamRegistry!.next(handle);
          },
        ),
        HostFunction(
          schema: const HostFunctionSchema(
            name: 'stream_close',
            description: 'Close a stream subscription early.',
            params: [
              HostParam(
                name: 'handle',
                type: HostParamType.integer,
                description: 'Subscription handle.',
              ),
            ],
          ),
          handler: (args) async {
            final handle = (args['handle']! as num).toInt();
            return _streamRegistry!.close(handle);
          },
        ),
      ];

  List<HostFunction> _blackboardFunctions() => [
        HostFunction(
          schema: const HostFunctionSchema(
            name: 'blackboard_write',
            description: 'Write a value to the shared blackboard.',
            params: [
              HostParam(
                name: 'key',
                type: HostParamType.string,
                description: 'Key to write.',
              ),
              HostParam(
                name: 'value',
                type: HostParamType.any,
                isRequired: false,
                description: 'JSON-compatible value (string, number, '
                    'bool, list, map, or null).',
              ),
            ],
          ),
          handler: (args) async {
            final key = args['key']! as String;
            final value = args['value'];
            await _blackboardApi!.write(key, value);
            return null;
          },
        ),
        HostFunction(
          schema: const HostFunctionSchema(
            name: 'blackboard_read',
            description: 'Read a value from the shared blackboard.',
            params: [
              HostParam(
                name: 'key',
                type: HostParamType.string,
                description: 'Key to read.',
              ),
            ],
          ),
          handler: (args) async {
            final key = args['key']! as String;
            return _blackboardApi!.read(key);
          },
        ),
        HostFunction(
          schema: const HostFunctionSchema(
            name: 'blackboard_keys',
            description: 'List all keys on the shared blackboard.',
          ),
          handler: (args) async {
            return _blackboardApi!.keys();
          },
        ),
      ];

  List<HostFunction> _agentFunctions() => [
        HostFunction(
          schema: const HostFunctionSchema(
            name: 'spawn_agent',
            description: 'Spawn an L2 sub-agent in a room.',
            params: [
              HostParam(
                name: 'room',
                type: HostParamType.string,
                description: 'Room ID to spawn the agent in.',
              ),
              HostParam(
                name: 'prompt',
                type: HostParamType.string,
                description: 'Prompt for the agent.',
              ),
              HostParam(
                name: 'thread_id',
                type: HostParamType.string,
                isRequired: false,
                description: 'Thread ID to continue an existing conversation.',
              ),
            ],
          ),
          handler: (args) async {
            final room = args['room']! as String;
            final prompt = args['prompt']! as String;
            final threadId = args['thread_id'] as String?;
            return _agentApi!.spawnAgent(
              room,
              prompt,
              threadId: threadId,
            );
          },
        ),
        HostFunction(
          schema: const HostFunctionSchema(
            name: 'wait_all',
            description: 'Wait for all agents to complete.',
            params: [
              HostParam(
                name: 'handles',
                type: HostParamType.list,
                description: 'List of agent handles.',
              ),
            ],
          ),
          handler: (args) async {
            final raw = args['handles']! as List<Object?>;
            final handles = raw.cast<num>().map((n) => n.toInt()).toList();
            return _agentApi!.waitAll(handles).timeout(_agentTimeout);
          },
        ),
        HostFunction(
          schema: const HostFunctionSchema(
            name: 'get_result',
            description: 'Get the result of a completed agent.',
            params: [
              HostParam(
                name: 'handle',
                type: HostParamType.integer,
                description: 'Agent handle.',
              ),
            ],
          ),
          handler: (args) async {
            final handle = (args['handle']! as num).toInt();
            return _agentApi!.getResult(handle).timeout(_agentTimeout);
          },
        ),
        HostFunction(
          schema: const HostFunctionSchema(
            name: 'agent_watch',
            description: 'Watch a spawned agent and return its result status '
                'without evicting the handle. Returns a dict with '
                "'status' ('success', 'failed', 'timed_out') and details.",
            params: [
              HostParam(
                name: 'handle',
                type: HostParamType.integer,
                description: 'Agent handle from spawn_agent.',
              ),
              HostParam(
                name: 'timeout_seconds',
                type: HostParamType.number,
                isRequired: false,
                description: 'Timeout in seconds (uses agentTimeout default).',
              ),
            ],
          ),
          handler: (args) async {
            final handle = (args['handle']! as num).toInt();
            final timeoutSec = args['timeout_seconds'] as num?;
            final timeout = timeoutSec != null
                ? Duration(seconds: timeoutSec.toInt())
                : _agentTimeout;
            final result = await _agentApi!.watchAgent(handle).timeout(timeout);
            return switch (result) {
              AgentSuccess(:final output) => <String, Object?>{
                  'status': 'success',
                  'output': output,
                },
              AgentFailure(:final reason, :final error, :final partialOutput) =>
                <String, Object?>{
                  'status': 'failed',
                  'reason': reason.name,
                  'error': error,
                  if (partialOutput != null) 'partial_output': partialOutput,
                },
              AgentTimedOut(:final elapsed) => <String, Object?>{
                  'status': 'timed_out',
                  'elapsed_seconds': elapsed.inSeconds,
                },
            };
          },
        ),
        HostFunction(
          schema: const HostFunctionSchema(
            name: 'cancel_agent',
            description: 'Cancel a spawned agent. Evicts the handle.',
            params: [
              HostParam(
                name: 'handle',
                type: HostParamType.integer,
                description: 'Agent handle from spawn_agent.',
              ),
            ],
          ),
          handler: (args) async {
            final handle = (args['handle']! as num).toInt();
            return _agentApi!.cancelAgent(handle);
          },
        ),
        HostFunction(
          schema: const HostFunctionSchema(
            name: 'agent_status',
            description: 'Non-blocking poll of agent lifecycle state. '
                "Returns 'spawning', 'running', 'completed', 'failed', "
                "or 'cancelled'.",
            params: [
              HostParam(
                name: 'handle',
                type: HostParamType.integer,
                description: 'Agent handle from spawn_agent.',
              ),
            ],
          ),
          handler: (args) async {
            final handle = (args['handle']! as num).toInt();
            return _agentApi!.agentStatus(handle);
          },
        ),
        HostFunction(
          schema: const HostFunctionSchema(
            name: 'ask_llm',
            description: 'Send a prompt to an LLM and return the response text '
                'and thread ID. Pass thread_id to continue a conversation.',
            params: [
              HostParam(
                name: 'prompt',
                type: HostParamType.string,
                description: 'Prompt for the agent.',
              ),
              HostParam(
                name: 'room',
                type: HostParamType.string,
                isRequired: false,
                defaultValue: 'general',
                description: 'Room ID (defaults to "general").',
              ),
              HostParam(
                name: 'thread_id',
                type: HostParamType.string,
                isRequired: false,
                description: 'Thread ID to continue an existing conversation.',
              ),
            ],
          ),
          handler: (args) async {
            final prompt = args['prompt']! as String;
            final room = args['room']! as String;
            final threadId = args['thread_id'] as String?;
            final api = _agentApi!;
            final handle = await api
                .spawnAgent(room, prompt, threadId: threadId)
                .timeout(_agentTimeout);
            final tid = api.getThreadId(handle);
            final result = await api.getResult(handle).timeout(_agentTimeout);
            return <String, Object?>{'text': result, 'thread_id': tid};
          },
        ),
      ];
}
