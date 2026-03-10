import 'package:openai_dart/openai_dart.dart';
import 'package:soliplex_completions/src/llm_provider.dart';

/// LLM provider backed by the OpenAI Chat Completions API.
///
/// Also works with OpenAI-compatible endpoints by setting `baseUrl`
/// in the constructor.
class OpenAiLlmProvider implements LlmProvider {
  OpenAiLlmProvider({
    required String apiKey,
    this.model = 'gpt-4o',
    this.defaultMaxTokens = 1024,
    String? baseUrl,
  }) : _client = OpenAIClient(
          config: OpenAIConfig(
            authProvider: ApiKeyProvider(apiKey),
            baseUrl: baseUrl ?? 'https://api.openai.com/v1',
          ),
        );

  final OpenAIClient _client;

  /// OpenAI model identifier.
  final String model;

  /// Default max tokens when not specified per-call.
  final int defaultMaxTokens;

  @override
  Future<String> complete(
    String prompt, {
    String? systemPrompt,
    int? maxTokens,
  }) async {
    final messages = <ChatMessage>[
      if (systemPrompt != null) ChatMessage.system(systemPrompt),
      ChatMessage.user(prompt),
    ];
    return _send(messages, maxTokens: maxTokens);
  }

  @override
  Future<String> chat(
    List<LlmMessage> messages, {
    String? systemPrompt,
    int? maxTokens,
  }) async {
    final mapped = <ChatMessage>[
      if (systemPrompt != null) ChatMessage.system(systemPrompt),
      ...messages.map(_toMessage),
    ];
    return _send(mapped, maxTokens: maxTokens);
  }

  Future<String> _send(List<ChatMessage> messages, {int? maxTokens}) async {
    final response = await _client.chat.completions.create(
      ChatCompletionCreateRequest(
        model: model,
        messages: messages,
        maxTokens: maxTokens ?? defaultMaxTokens,
      ),
    );
    return response.text ?? '';
  }

  static ChatMessage _toMessage(LlmMessage msg) {
    return switch (msg.role) {
      'system' => ChatMessage.system(msg.content),
      'assistant' => ChatMessage.assistant(content: msg.content),
      _ => ChatMessage.user(msg.content),
    };
  }
}
