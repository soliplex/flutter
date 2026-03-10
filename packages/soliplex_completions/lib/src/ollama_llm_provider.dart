import 'package:ollama_dart/ollama_dart.dart';
import 'package:soliplex_completions/src/llm_provider.dart';

/// LLM provider backed by a local Ollama instance.
class OllamaLlmProvider implements LlmProvider {
  OllamaLlmProvider({
    this.model = 'llama3.2',
    String baseUrl = 'http://localhost:11434/api',
  }) : _client = OllamaClient(baseUrl: baseUrl);

  final OllamaClient _client;

  /// Ollama model name.
  final String model;

  @override
  Future<String> complete(
    String prompt, {
    String? systemPrompt,
    int? maxTokens,
  }) async {
    final messages = <Message>[
      if (systemPrompt != null)
        Message(role: MessageRole.system, content: systemPrompt),
      Message(role: MessageRole.user, content: prompt),
    ];
    return _send(messages, maxTokens: maxTokens);
  }

  @override
  Future<String> chat(
    List<LlmMessage> messages, {
    String? systemPrompt,
    int? maxTokens,
  }) async {
    final mapped = <Message>[
      if (systemPrompt != null)
        Message(role: MessageRole.system, content: systemPrompt),
      ...messages.map(_toMessage),
    ];
    return _send(mapped, maxTokens: maxTokens);
  }

  Future<String> _send(List<Message> messages, {int? maxTokens}) async {
    final response = await _client.generateChatCompletion(
      request: GenerateChatCompletionRequest(
        model: model,
        messages: messages,
        options:
            maxTokens != null ? RequestOptions(numPredict: maxTokens) : null,
      ),
    );
    return response.message.content;
  }

  static Message _toMessage(LlmMessage msg) {
    final role = switch (msg.role) {
      'system' => MessageRole.system,
      'assistant' => MessageRole.assistant,
      _ => MessageRole.user,
    };
    return Message(role: role, content: msg.content);
  }
}
