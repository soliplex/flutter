@Tags(['integration'])
library;

import 'dart:io';

import 'package:soliplex_completions/soliplex_completions.dart';
import 'package:soliplex_mcp/soliplex_mcp.dart';
import 'package:test/test.dart';

/// End-to-end integration test wiring MCP (Brave Search) → LLM (Ollama).
///
/// Flow: Brave Search MCP returns web results → Ollama summarizes them.
/// This validates the full pipeline that a Monty script would exercise
/// via McpPlugin + LlmPlugin.fromCallbacks().
///
/// Prerequisites:
///   - Ollama running on localhost:11434 with `qwen3:0.6b`
///   - `BRAVE_API_KEY` env var set
///
/// Run:
///   cd packages/soliplex_mcp
///   BRAVE_API_KEY=`<key>` dart test --tags=integration --run-skipped
void main() {
  final apiKey = Platform.environment['BRAVE_API_KEY'];

  late McpConnectionManager mcp;
  late OllamaLlmProvider llm;

  setUpAll(() {
    if (apiKey == null || apiKey.isEmpty) {
      fail('BRAVE_API_KEY env var is required for integration tests');
    }

    mcp = McpConnectionManager(
      serverConfigs: {
        'brave': McpServerConfig.stdio(
          command: 'npx',
          args: const ['-y', '@brave/brave-search-mcp-server'],
          environment: {
            ...Platform.environment,
            'BRAVE_API_KEY': apiKey,
          },
        ),
      },
    );

    llm = OllamaLlmProvider(model: 'qwen3:0.6b');
  });

  tearDownAll(() async {
    await mcp.dispose();
  });

  group('MCP + LLM end-to-end', () {
    test(
      'search via MCP, summarize via LLM',
      () async {
        // Step 1: Use MCP to search
        final searchResult = await mcp.executeTool(
          'brave',
          'brave_web_search',
          {'query': 'Dart programming language features'},
        );

        expect(searchResult['isError'], isFalse);
        final content = searchResult['content']! as List;
        expect(content, isNotEmpty);

        // Step 2: Feed search results to LLM for summarization
        final searchText = content.take(3).join('\n\n');
        final summary = await llm.complete(
          'Summarize these search results in one sentence:\n\n$searchText',
          systemPrompt: 'You are a concise summarizer. Reply in one sentence.',
          maxTokens: 4096,
        );

        expect(summary, isNotEmpty);
        // The summary should be a coherent sentence, not empty garbage.
        expect(summary.length, greaterThan(10));
      },
      timeout: const Timeout(
        Duration(seconds: 60),
      ),
    );

    test(
      'chat with MCP context injection',
      () async {
        // Step 1: Discover available tools
        final tools = await mcp.listTools(serverId: 'brave');
        final toolNames = tools.map((t) => t['name']).toList();

        // Step 2: Ask LLM about the tools (simulates agent reasoning)
        final response = await llm.chat(
          [
            (
              role: 'user',
              content: 'I have these MCP tools available: $toolNames. '
                  'Which one would I use to search the web?',
            ),
          ],
          maxTokens: 4096,
        );

        expect(response, isNotEmpty);
        expect(
          response.toLowerCase(),
          contains('brave_web_search'),
          reason: 'LLM should identify brave_web_search as the web search tool',
        );
      },
      timeout: const Timeout(
        Duration(seconds: 60),
      ),
    );
  });
}
