import 'package:soliplex_mcp/soliplex_mcp.dart';
import 'package:test/test.dart';

void main() {
  group('McpServerConfig', () {
    test('stdio constructor sets correct fields', () {
      const config = McpServerConfig.stdio(
        command: 'npx',
        args: ['-y', '@modelcontextprotocol/server-filesystem', '/tmp'],
        workingDirectory: '/home/user',
        environment: {'DEBUG': 'true'},
      );

      expect(config.kind, McpTransportKind.stdio);
      expect(config.command, 'npx');
      expect(config.args, [
        '-y',
        '@modelcontextprotocol/server-filesystem',
        '/tmp',
      ]);
      expect(config.workingDirectory, '/home/user');
      expect(config.environment, {'DEBUG': 'true'});
      expect(config.url, isNull);
    });

    test('http constructor sets correct fields', () {
      const config = McpServerConfig.http(url: 'http://localhost:3000/mcp');

      expect(config.kind, McpTransportKind.http);
      expect(config.url, 'http://localhost:3000/mcp');
      expect(config.command, isNull);
      expect(config.args, isEmpty);
      expect(config.workingDirectory, isNull);
      expect(config.environment, isNull);
    });

    test('stdio defaults args to empty list', () {
      const config = McpServerConfig.stdio(command: 'node');
      expect(config.args, isEmpty);
    });
  });

  group('McpTransportKind', () {
    test('has stdio and http values', () {
      expect(McpTransportKind.values, hasLength(2));
      expect(McpTransportKind.stdio.name, 'stdio');
      expect(McpTransportKind.http.name, 'http');
    });
  });
}
