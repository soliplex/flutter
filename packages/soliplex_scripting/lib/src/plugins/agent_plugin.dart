import 'package:soliplex_agent/soliplex_agent.dart'
    show AgentApi, AgentFailure, AgentSuccess, AgentTimedOut;
import 'package:soliplex_interpreter_monty/soliplex_interpreter_monty.dart';
import 'package:soliplex_scripting/src/plugin_registry.dart';

/// Plugin exposing agent orchestration (spawn, wait, cancel, ask_llm) to
/// Monty scripts.
///
/// Uses [LegacyUnprefixedPlugin] because `wait_all`, `get_result`, and
/// `ask_llm` predate the `namespace_` prefix convention.
class AgentPlugin extends MontyPlugin with LegacyUnprefixedPlugin {
  AgentPlugin({
    required AgentApi agentApi,
    Duration agentTimeout = const Duration(seconds: 30),
  })  : _agentApi = agentApi,
        _agentTimeout = agentTimeout;

  final AgentApi _agentApi;
  final Duration _agentTimeout;

  @override
  String get namespace => 'agent';

  @override
  Set<String> get legacyNames => const {
        'spawn_agent',
        'wait_all',
        'get_result',
        'cancel_agent',
        'ask_llm',
      };

  @override
  List<HostFunction> get functions => [
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
            return _agentApi.spawnAgent(
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
            return _agentApi.waitAll(handles).timeout(_agentTimeout);
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
            return _agentApi.getResult(handle).timeout(_agentTimeout);
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
            final result = await _agentApi.watchAgent(handle).timeout(timeout);
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
            return _agentApi.cancelAgent(handle);
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
            return _agentApi.agentStatus(handle);
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
            final handle = await _agentApi
                .spawnAgent(room, prompt, threadId: threadId)
                .timeout(_agentTimeout);
            final tid = _agentApi.getThreadId(handle);
            final result =
                await _agentApi.getResult(handle).timeout(_agentTimeout);
            return <String, Object?>{'text': result, 'thread_id': tid};
          },
        ),
      ];
}
