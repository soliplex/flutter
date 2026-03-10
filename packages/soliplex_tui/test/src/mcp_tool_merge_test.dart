import 'dart:convert';

import 'package:mocktail/mocktail.dart';
import 'package:soliplex_agent/soliplex_agent.dart';
import 'package:soliplex_mcp/soliplex_mcp.dart';
import 'package:soliplex_tui/src/app.dart' show mergeWithMcpTools;
import 'package:test/test.dart';

class MockMcpConnectionManager extends Mock implements McpConnectionManager {}

class FakeToolExecutionContext extends Fake implements ToolExecutionContext {}

void main() {
  late MockMcpConnectionManager mockMcp;

  setUp(() {
    mockMcp = MockMcpConnectionManager();
  });

  setUpAll(() {
    registerFallbackValue(<String, Object?>{});
  });

  group('mergeWithMcpTools', () {
    test('returns base registry when mcpManager is null', () async {
      const base = ToolRegistry();
      final result = await mergeWithMcpTools(base, null);
      expect(result.length, base.length);
    });

    test('registers MCP tools into registry', () async {
      when(() => mockMcp.listTools()).thenAnswer(
        (_) async => [
          {
            'server': 'brave',
            'name': 'web_search',
            'description': 'Search the web',
          },
          {
            'server': 'brave',
            'name': 'local_search',
            'description': 'Search locally',
          },
        ],
      );

      final result = await mergeWithMcpTools(const ToolRegistry(), mockMcp);

      expect(result.length, 2);
      expect(result.contains('web_search'), isTrue);
      expect(result.contains('local_search'), isTrue);
    });

    test('preserves existing tools from base registry', () async {
      when(() => mockMcp.listTools()).thenAnswer(
        (_) async => [
          {'server': 's1', 'name': 'mcp_tool', 'description': 'MCP'},
        ],
      );

      var base = const ToolRegistry();
      base = base.register(
        ClientTool.simple(
          name: 'demo',
          description: 'Demo tool',
          executor: (_, __) async => 'ok',
        ),
      );

      final result = await mergeWithMcpTools(base, mockMcp);

      expect(result.length, 2);
      expect(result.contains('demo'), isTrue);
      expect(result.contains('mcp_tool'), isTrue);
    });

    test('MCP tool executor delegates to mcpManager.executeTool', () async {
      when(() => mockMcp.listTools()).thenAnswer(
        (_) async => [
          {'server': 'brave', 'name': 'web_search', 'description': 'Search'},
        ],
      );
      when(() => mockMcp.executeTool('brave', 'web_search', any())).thenAnswer(
        (_) async => {
          'isError': false,
          'content': ['result text'],
        },
      );

      final registry = await mergeWithMcpTools(const ToolRegistry(), mockMcp);
      final tool = registry.lookup('web_search');

      const tc = ToolCallInfo(
        id: 'tc-1',
        name: 'web_search',
        arguments: '{"query": "dart"}',
      );

      final output = await tool.executor(tc, FakeToolExecutionContext());
      final decoded = jsonDecode(output) as Map<String, dynamic>;

      expect(decoded['isError'], isFalse);
      expect(decoded['content'], contains('result text'));
      verify(
        () => mockMcp.executeTool('brave', 'web_search', {'query': 'dart'}),
      ).called(1);
    });

    test('MCP tool executor handles missing arguments', () async {
      when(() => mockMcp.listTools()).thenAnswer(
        (_) async => [
          {'server': 's1', 'name': 'no_args_tool', 'description': 'No args'},
        ],
      );
      when(() => mockMcp.executeTool('s1', 'no_args_tool', any())).thenAnswer(
        (_) async => {
          'isError': false,
          'content': ['done'],
        },
      );

      final registry = await mergeWithMcpTools(const ToolRegistry(), mockMcp);
      final tool = registry.lookup('no_args_tool');

      const tc = ToolCallInfo(id: 'tc-2', name: 'no_args_tool');

      final output = await tool.executor(tc, FakeToolExecutionContext());
      final decoded = jsonDecode(output) as Map<String, dynamic>;

      expect(decoded['isError'], isFalse);
      verify(
        () => mockMcp.executeTool('s1', 'no_args_tool', <String, Object?>{}),
      ).called(1);
    });

    test('MCP tool executor returns error for malformed JSON args', () async {
      when(() => mockMcp.listTools()).thenAnswer(
        (_) async => [
          {'server': 's1', 'name': 'bad_tool', 'description': 'Bad'},
        ],
      );

      final registry = await mergeWithMcpTools(const ToolRegistry(), mockMcp);
      final tool = registry.lookup('bad_tool');

      const tc = ToolCallInfo(
        id: 'tc-3',
        name: 'bad_tool',
        arguments: 'not valid json{{{',
      );

      final output = await tool.executor(tc, FakeToolExecutionContext());
      final decoded = jsonDecode(output) as Map<String, dynamic>;

      expect(decoded, contains('error'));
      expect(decoded['error'], contains('Invalid tool arguments'));
      verifyNever(() => mockMcp.executeTool(any(), any(), any()));
    });

    test('handles empty description gracefully', () async {
      when(() => mockMcp.listTools()).thenAnswer(
        (_) async => [
          {'server': 's1', 'name': 'no_desc', 'description': null},
        ],
      );

      final registry = await mergeWithMcpTools(const ToolRegistry(), mockMcp);

      expect(registry.contains('no_desc'), isTrue);
      final tool = registry.lookup('no_desc');
      expect(tool.definition.description, isEmpty);
    });
  });
}
