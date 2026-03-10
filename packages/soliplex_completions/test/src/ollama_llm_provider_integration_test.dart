@Tags(['integration'])
library;

import 'package:soliplex_completions/soliplex_completions.dart';
import 'package:test/test.dart';

/// Integration tests for [OllamaLlmProvider] against a live Ollama instance.
///
/// Prerequisites:
///   - Ollama running on localhost:11434
///   - Model `qwen3:0.6b` pulled (`ollama pull qwen3:0.6b`)
///
/// Run:
///   cd packages/soliplex_completions
///   dart test --tags=integration --run-skipped
///
/// Note: Qwen3 models use "thinking mode" by default — internal reasoning
/// tokens count against num_predict. Use a high maxTokens to leave room
/// for both thinking and the actual response.
void main() {
  const model = 'qwen3:0.6b';
  // High enough for thinking-mode models where thinking eats token budget.
  const defaultMaxTokens = 4096;

  late OllamaLlmProvider provider;

  setUpAll(() {
    provider = OllamaLlmProvider(model: model);
  });

  group('OllamaLlmProvider integration', () {
    test(
      'complete returns non-empty response',
      () async {
        final result = await provider.complete(
          'Reply with exactly one word: hello',
          maxTokens: defaultMaxTokens,
        );

        expect(result, isNotEmpty, reason: 'Ollama returned empty content');
      },
      timeout: const Timeout(Duration(seconds: 30)),
    );

    test(
      'complete with system prompt',
      () async {
        final result = await provider.complete(
          'What is 2 + 2?',
          systemPrompt: 'You are a calculator. Reply with only the number.',
          maxTokens: defaultMaxTokens,
        );

        expect(result, isNotEmpty);
        expect(result, contains('4'));
      },
      timeout: const Timeout(Duration(seconds: 30)),
    );

    test(
      'chat single turn',
      () async {
        final result = await provider.chat(
          [
            (role: 'user', content: 'Say "pong" and nothing else.'),
          ],
          maxTokens: defaultMaxTokens,
        );

        expect(result, isNotEmpty);
        expect(result.toLowerCase(), contains('pong'));
      },
      timeout: const Timeout(Duration(seconds: 30)),
    );

    test(
      'chat multi-turn',
      () async {
        final result = await provider.chat(
          [
            (role: 'user', content: 'Remember the number 42.'),
            (role: 'assistant', content: 'I will remember 42.'),
            (role: 'user', content: 'What number did I ask you to remember?'),
          ],
          systemPrompt: 'Reply with only the number, no explanation.',
          maxTokens: defaultMaxTokens,
        );

        expect(result, isNotEmpty);
        expect(result, contains('42'));
      },
      timeout: const Timeout(Duration(seconds: 30)),
    );

    test(
      'complete without maxTokens returns response',
      () async {
        final result = await provider.complete('Say the word "test".');

        expect(result, isNotEmpty);
      },
      timeout: const Timeout(Duration(seconds: 30)),
    );

    test(
      'LlmProvider contract — complete and chat return strings',
      () async {
        final LlmProvider contract = provider;

        final completeResult = await contract.complete(
          'Say hi',
          maxTokens: defaultMaxTokens,
        );
        expect(completeResult, isA<String>());
        expect(completeResult, isNotEmpty);

        final chatResult = await contract.chat(
          [
            (role: 'user', content: 'Say hi'),
          ],
          maxTokens: defaultMaxTokens,
        );
        expect(chatResult, isA<String>());
        expect(chatResult, isNotEmpty);
      },
      timeout: const Timeout(Duration(seconds: 30)),
    );
  });
}
