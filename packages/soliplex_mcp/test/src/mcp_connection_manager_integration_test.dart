@Tags(['integration'])
library;

import 'dart:io';

import 'package:soliplex_mcp/soliplex_mcp.dart';
import 'package:test/test.dart';

/// Integration tests for [McpConnectionManager] against a live Brave Search
/// MCP server.
///
/// Prerequisites:
///   - `npx @brave/brave-search-mcp-server` must be runnable
///   - `BRAVE_API_KEY` env var set
///
/// Run:
///   cd packages/soliplex_mcp
///   BRAVE_API_KEY=`<key>` dart test --tags=integration --run-skipped
void main() {
  final apiKey = Platform.environment['BRAVE_API_KEY'];

  late McpConnectionManager manager;

  setUpAll(() {
    if (apiKey == null || apiKey.isEmpty) {
      fail('BRAVE_API_KEY env var is required for integration tests');
    }

    manager = McpConnectionManager(
      serverConfigs: {
        'brave': McpServerConfig.stdio(
          command: 'npx',
          args: const ['-y', '@brave/brave-search-mcp-server'],
          environment: {...Platform.environment, 'BRAVE_API_KEY': apiKey},
        ),
      },
    );
  });

  tearDownAll(() async {
    await manager.dispose();
  });

  group('McpConnectionManager + Brave Search integration', () {
    test(
      'listServers returns brave as disconnected before first use',
      () async {
        // Re-create a fresh manager to test initial state.
        final fresh = McpConnectionManager(
          serverConfigs: {
            'brave': McpServerConfig.stdio(
              command: 'npx',
              args: const ['-y', '@brave/brave-search-mcp-server'],
              environment: {...Platform.environment, 'BRAVE_API_KEY': apiKey!},
            ),
          },
        );

        final servers = await fresh.listServers();
        expect(servers, hasLength(1));
        expect(servers.first['id'], 'brave');
        expect(servers.first['kind'], 'stdio');
        expect(servers.first['status'], 'disconnected');
        await fresh.dispose();
      },
    );

    test(
      'listTools discovers brave_web_search tool',
      () async {
        final tools = await manager.listTools(serverId: 'brave');

        expect(tools, isNotEmpty);
        final names = tools.map((t) => t['name']).toSet();
        expect(
          names,
          contains('brave_web_search'),
          reason: 'Brave MCP should expose brave_web_search tool',
        );

        // Each tool entry should have required fields.
        for (final tool in tools) {
          expect(tool['server'], 'brave');
          expect(tool['name'], isA<String>());
          expect(tool['description'], isA<String>());
        }
      },
      timeout: const Timeout(Duration(seconds: 60)),
    );

    test('listServers shows brave as connected after listTools', () async {
      // listTools above triggered the lazy connection.
      final servers = await manager.listServers();
      final brave = servers.firstWhere((s) => s['id'] == 'brave');
      expect(brave['status'], 'connected');
    });

    test(
      'executeTool brave_web_search returns results',
      () async {
        final result = await manager.executeTool('brave', 'brave_web_search', {
          'query': 'Flutter MCP integration',
        });

        expect(result['isError'], isFalse);
        expect(result['content'], isA<List<Object?>>());
        final content = result['content']! as List;
        expect(content, isNotEmpty, reason: 'Search should return results');

        // Content items should be text strings.
        final firstItem = content.first as String;
        expect(firstItem, isNotEmpty);
      },
      timeout: const Timeout(Duration(seconds: 30)),
    );

    test(
      'executeTool with unknown tool returns error',
      () async {
        // MCP spec: calling a nonexistent tool should produce an error result
        // (not throw).
        try {
          final result = await manager.executeTool(
            'brave',
            'nonexistent_tool_xyz',
            {},
          );
          // If it returns rather than throws, isError should be true.
          expect(result['isError'], isTrue);
        } on Exception {
          // Some servers may throw — that's acceptable too.
        }
      },
      timeout: const Timeout(Duration(seconds: 15)),
    );

    test('unknown server throws ArgumentError', () async {
      await expectLater(
        manager.executeTool('no-such-server', 'tool', {}),
        throwsA(isA<ArgumentError>()),
      );
    });

    test(
      'dispose closes connection without error',
      () async {
        // Create a separate manager, connect it, then dispose.
        final disposable = McpConnectionManager(
          serverConfigs: {
            'brave': McpServerConfig.stdio(
              command: 'npx',
              args: const ['-y', '@brave/brave-search-mcp-server'],
              environment: {...Platform.environment, 'BRAVE_API_KEY': apiKey!},
            ),
          },
        );

        // Force connection.
        await disposable.listTools(serverId: 'brave');
        // Dispose should not throw.
        await disposable.dispose();
      },
      timeout: const Timeout(Duration(seconds: 60)),
    );
  });
}
