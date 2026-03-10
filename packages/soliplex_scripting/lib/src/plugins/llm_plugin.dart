import 'package:soliplex_agent/soliplex_agent.dart' show AgentApi;
import 'package:soliplex_interpreter_monty/soliplex_interpreter_monty.dart';

/// Callback for single-shot LLM completions.
typedef LlmCompleter = Future<String> Function(
  String prompt, {
  String? systemPrompt,
  int? maxTokens,
});

/// Callback for multi-turn LLM chat completions.
typedef LlmChatCompleter = Future<String> Function(
  List<Map<String, String>> messages, {
  String? systemPrompt,
  int? maxTokens,
});

/// Plugin exposing LLM completion functions to Monty scripts.
///
/// Two construction paths:
/// - [LlmPlugin.new] — delegates to [AgentApi] (backend-routed, Phase 1)
/// - [LlmPlugin.fromCallbacks] — delegates to injected functions (direct
///   SDK calls via `soliplex_completions`, Phase 2)
class LlmPlugin extends MontyPlugin {
  LlmPlugin({
    required AgentApi agentApi,
    this.defaultRoom = 'general',
    Duration agentTimeout = const Duration(seconds: 30),
  })  : _agentApi = agentApi,
        _agentTimeout = agentTimeout,
        _completer = null,
        _chatCompleter = null;

  /// Direct callback constructor — bypasses [AgentApi] entirely.
  LlmPlugin.fromCallbacks({
    required LlmCompleter complete,
    required LlmChatCompleter chat,
  })  : _completer = complete,
        _chatCompleter = chat,
        _agentApi = null,
        _agentTimeout = Duration.zero,
        defaultRoom = '';

  final AgentApi? _agentApi;
  final Duration _agentTimeout;
  final LlmCompleter? _completer;
  final LlmChatCompleter? _chatCompleter;

  /// Default room for LLM calls when none specified (AgentApi path only).
  final String defaultRoom;

  @override
  String get namespace => 'llm';

  @override
  String? get systemPromptContext =>
      'LLM completion functions. Use llm_complete() for single prompts, '
      'llm_chat() for multi-turn conversations.';

  @override
  List<HostFunction> get functions => [
        HostFunction(
          schema: const HostFunctionSchema(
            name: 'llm_complete',
            description: 'Send a prompt to an LLM and return the response '
                'text. For single-shot completions.',
            params: [
              HostParam(
                name: 'prompt',
                type: HostParamType.string,
                description: 'The prompt to send.',
              ),
              HostParam(
                name: 'system_prompt',
                type: HostParamType.string,
                isRequired: false,
                description: 'Optional system prompt.',
              ),
              HostParam(
                name: 'room',
                type: HostParamType.string,
                isRequired: false,
                description: 'Room ID (defaults to plugin defaultRoom).',
              ),
            ],
          ),
          handler: (args) async {
            final prompt = args['prompt']! as String;
            final systemPrompt = args['system_prompt'] as String?;

            if (_completer != null) {
              return _completer(prompt, systemPrompt: systemPrompt);
            }

            final room = args['room'] as String? ?? defaultRoom;
            final fullPrompt = systemPrompt != null
                ? 'System: $systemPrompt\n\n$prompt'
                : prompt;

            final handle = await _agentApi!
                .spawnAgent(room, fullPrompt)
                .timeout(_agentTimeout);
            return _agentApi.getResult(handle).timeout(_agentTimeout);
          },
        ),
        HostFunction(
          schema: const HostFunctionSchema(
            name: 'llm_chat',
            description: 'Send a multi-turn conversation to an LLM. '
                'Messages alternate between user and assistant roles. '
                'Returns the assistant response text and a thread_id '
                'for continuation.',
            params: [
              HostParam(
                name: 'messages',
                type: HostParamType.list,
                description: 'List of message dicts with "role" and '
                    '"content" keys.',
              ),
              HostParam(
                name: 'system_prompt',
                type: HostParamType.string,
                isRequired: false,
                description: 'Optional system prompt.',
              ),
              HostParam(
                name: 'room',
                type: HostParamType.string,
                isRequired: false,
                description: 'Room ID (defaults to plugin defaultRoom).',
              ),
              HostParam(
                name: 'thread_id',
                type: HostParamType.string,
                isRequired: false,
                description: 'Thread ID to continue a conversation.',
              ),
            ],
          ),
          handler: (args) async {
            final messages = args['messages']! as List<Object?>;
            final systemPrompt = args['system_prompt'] as String?;

            final mapped = <Map<String, String>>[
              for (final msg in messages)
                {
                  'role': (msg! as Map)['role']! as String,
                  'content': (msg as Map)['content']! as String,
                },
            ];

            if (_chatCompleter != null) {
              final text =
                  await _chatCompleter(mapped, systemPrompt: systemPrompt);
              return <String, Object?>{'text': text, 'thread_id': null};
            }

            final room = args['room'] as String? ?? defaultRoom;
            final threadId = args['thread_id'] as String?;

            final buffer = StringBuffer();
            if (systemPrompt != null) {
              buffer
                ..writeln('System: $systemPrompt')
                ..writeln();
            }
            for (final m in mapped) {
              buffer.writeln('${m['role']}: ${m['content']}');
            }

            final handle = await _agentApi!
                .spawnAgent(
                  room,
                  buffer.toString().trimRight(),
                  threadId: threadId,
                )
                .timeout(_agentTimeout);
            final tid = _agentApi.getThreadId(handle);
            final result =
                await _agentApi.getResult(handle).timeout(_agentTimeout);
            return <String, Object?>{'text': result, 'thread_id': tid};
          },
        ),
      ];
}
