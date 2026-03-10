import 'package:soliplex_scripting/soliplex_scripting.dart';
import 'package:test/test.dart';

import '../helpers.dart';

void main() {
  group('McpPlugin', () {
    late _FakeMcpExecutor executor;
    late _FakeMcpToolLister toolLister;
    late _FakeMcpServerLister serverLister;
    late McpPlugin plugin;

    setUp(() {
      executor = _FakeMcpExecutor();
      toolLister = _FakeMcpToolLister();
      serverLister = _FakeMcpServerLister();
      plugin = McpPlugin(
        executor: executor.call,
        toolLister: toolLister.call,
        serverLister: serverLister.call,
      );
    });

    test('namespace is mcp', () {
      expect(plugin.namespace, 'mcp');
    });

    test('provides 3 functions', () {
      expect(plugin.functions, hasLength(3));
      final names = plugin.functions.map((f) => f.schema.name).toSet();
      expect(
        names,
        containsAll(['mcp_call_tool', 'mcp_list_tools', 'mcp_list_servers']),
      );
    });

    test('is NOT a LegacyUnprefixedPlugin', () {
      expect(plugin, isNot(isA<LegacyUnprefixedPlugin>()));
    });

    test('has systemPromptContext', () {
      expect(plugin.systemPromptContext, isNotNull);
      expect(plugin.systemPromptContext, contains('mcp_call_tool'));
    });

    test('registers onto bridge via PluginRegistry', () async {
      final bridge = RecordingBridge();
      final registry = PluginRegistry()..register(plugin);
      await registry.attachTo(bridge);

      final names = bridge.registered.map((f) => f.schema.name).toSet();
      expect(
        names,
        containsAll([
          'mcp_call_tool',
          'mcp_list_tools',
          'mcp_list_servers',
        ]),
      );
    });

    group('mcp_call_tool', () {
      late HostFunction fn;

      setUp(() {
        fn = plugin.functions.firstWhere(
          (f) => f.schema.name == 'mcp_call_tool',
        );
      });

      test('delegates to executor', () async {
        final result = await fn.handler({
          'server': 'fs-server',
          'tool': 'read_file',
          'args': <String, Object?>{'path': '/tmp/test.txt'},
        });

        expect(result, isA<Map<String, Object?>>());
        final map = result! as Map<String, Object?>;
        expect(map['isError'], isFalse);
        expect(executor.lastServer, 'fs-server');
        expect(executor.lastTool, 'read_file');
        expect(executor.lastArgs!['path'], '/tmp/test.txt');
      });

      test('passes empty args when none provided', () async {
        await fn.handler({
          'server': 'fs-server',
          'tool': 'list_files',
          'args': null,
        });

        expect(executor.lastArgs, isEmpty);
      });

      test('schema has server, tool, optional args', () {
        expect(fn.schema.params, hasLength(3));
        expect(fn.schema.params[0].name, 'server');
        expect(fn.schema.params[0].isRequired, isTrue);
        expect(fn.schema.params[1].name, 'tool');
        expect(fn.schema.params[1].isRequired, isTrue);
        expect(fn.schema.params[2].name, 'args');
        expect(fn.schema.params[2].isRequired, isFalse);
      });
    });

    group('mcp_list_tools', () {
      late HostFunction fn;

      setUp(() {
        fn = plugin.functions.firstWhere(
          (f) => f.schema.name == 'mcp_list_tools',
        );
      });

      test('delegates to toolLister', () async {
        final result = await fn.handler({});

        expect(result, isA<List<Map<String, Object?>>>());
        final list = result! as List<Map<String, Object?>>;
        expect(list, hasLength(1));
        expect(list.first['name'], 'read_file');
        expect(toolLister.lastServerId, isNull);
      });

      test('passes server filter when provided', () async {
        await fn.handler({'server': 'fs-server'});

        expect(toolLister.lastServerId, 'fs-server');
      });

      test('schema has optional server param', () {
        expect(fn.schema.params, hasLength(1));
        expect(fn.schema.params[0].name, 'server');
        expect(fn.schema.params[0].isRequired, isFalse);
      });
    });

    group('mcp_list_servers', () {
      late HostFunction fn;

      setUp(() {
        fn = plugin.functions.firstWhere(
          (f) => f.schema.name == 'mcp_list_servers',
        );
      });

      test('delegates to serverLister', () async {
        final result = await fn.handler({});

        expect(result, isA<List<Map<String, Object?>>>());
        final list = result! as List<Map<String, Object?>>;
        expect(list, hasLength(1));
        expect(list.first['id'], 'fs-server');
        expect(serverLister.called, isTrue);
      });

      test('schema has no params', () {
        expect(fn.schema.params, isEmpty);
      });
    });
  });
}

class _FakeMcpExecutor {
  String? lastServer;
  String? lastTool;
  Map<String, Object?>? lastArgs;

  Future<Map<String, Object?>> call(
    String serverId,
    String toolName,
    Map<String, Object?> args,
  ) async {
    lastServer = serverId;
    lastTool = toolName;
    lastArgs = args;
    return <String, Object?>{
      'isError': false,
      'content': ['file contents here'],
    };
  }
}

class _FakeMcpToolLister {
  String? lastServerId;

  Future<List<Map<String, Object?>>> call({String? serverId}) async {
    lastServerId = serverId;
    return [
      <String, Object?>{
        'server': 'fs-server',
        'name': 'read_file',
        'description': 'Read a file',
      },
    ];
  }
}

class _FakeMcpServerLister {
  bool called = false;

  Future<List<Map<String, Object?>>> call() async {
    called = true;
    return [
      <String, Object?>{
        'id': 'fs-server',
        'kind': 'stdio',
        'status': 'connected',
      },
    ];
  }
}
