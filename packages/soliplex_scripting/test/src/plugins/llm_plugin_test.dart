import 'dart:async';

import 'package:soliplex_agent/soliplex_agent.dart' show FakeAgentApi;
import 'package:soliplex_scripting/soliplex_scripting.dart';
import 'package:test/test.dart';

import '../helpers.dart';

void main() {
  group('LlmPlugin', () {
    late FakeAgentApi agentApi;
    late LlmPlugin plugin;

    setUp(() {
      agentApi = FakeAgentApi(
        spawnResult: 10,
        getResultResult: 'LLM says hello',
      );
      plugin = LlmPlugin(agentApi: agentApi);
    });

    test('namespace is llm', () {
      expect(plugin.namespace, 'llm');
    });

    test('provides 2 functions', () {
      expect(plugin.functions, hasLength(2));
      final names = plugin.functions.map((f) => f.schema.name).toSet();
      expect(names, containsAll(['llm_complete', 'llm_chat']));
    });

    test('is NOT a LegacyUnprefixedPlugin', () {
      expect(plugin, isNot(isA<LegacyUnprefixedPlugin>()));
    });

    test('has systemPromptContext', () {
      expect(plugin.systemPromptContext, isNotNull);
      expect(plugin.systemPromptContext, contains('llm_complete'));
    });

    test('registers onto bridge via PluginRegistry', () async {
      final bridge = RecordingBridge();
      final registry = PluginRegistry()..register(plugin);
      await registry.attachTo(bridge);

      final names = bridge.registered.map((f) => f.schema.name).toSet();
      expect(names, containsAll(['llm_complete', 'llm_chat']));
    });

    group('llm_complete', () {
      late HostFunction fn;

      setUp(() {
        fn = plugin.functions.firstWhere(
          (f) => f.schema.name == 'llm_complete',
        );
      });

      test('sends prompt via AgentApi and returns result', () async {
        final result = await fn.handler({'prompt': 'What is 2+2?'});

        expect(result, 'LLM says hello');
        expect(agentApi.calls['spawnAgent']![0], 'general');
        expect(agentApi.calls['spawnAgent']![1], 'What is 2+2?');
      });

      test('prepends system prompt when provided', () async {
        await fn.handler({
          'prompt': 'What is 2+2?',
          'system_prompt': 'You are a math tutor.',
        });

        final sentPrompt = agentApi.calls['spawnAgent']![1]! as String;
        expect(sentPrompt, contains('System: You are a math tutor.'));
        expect(sentPrompt, contains('What is 2+2?'));
      });

      test('uses custom room when provided', () async {
        await fn.handler({'prompt': 'Hello', 'room': 'math'});

        expect(agentApi.calls['spawnAgent']![0], 'math');
      });

      test('uses defaultRoom when room not provided', () async {
        final p = LlmPlugin(agentApi: agentApi, defaultRoom: 'custom-room');
        final f = p.functions.firstWhere(
          (f) => f.schema.name == 'llm_complete',
        );

        await f.handler({'prompt': 'Hi'});

        expect(agentApi.calls['spawnAgent']![0], 'custom-room');
      });

      test('schema has prompt, system_prompt, room', () {
        expect(fn.schema.params, hasLength(3));
        expect(fn.schema.params[0].name, 'prompt');
        expect(fn.schema.params[0].isRequired, isTrue);
        expect(fn.schema.params[1].name, 'system_prompt');
        expect(fn.schema.params[1].isRequired, isFalse);
        expect(fn.schema.params[2].name, 'room');
        expect(fn.schema.params[2].isRequired, isFalse);
      });

      test('times out with configured agentTimeout', () async {
        final slowApi = _NeverResolvingAgentApi();
        final p = LlmPlugin(
          agentApi: slowApi,
          agentTimeout: const Duration(milliseconds: 50),
        );
        final f = p.functions.firstWhere(
          (f) => f.schema.name == 'llm_complete',
        );

        await expectLater(
          f.handler({'prompt': 'slow'}),
          throwsA(isA<TimeoutException>()),
        );
      });
    });

    group('llm_chat', () {
      late HostFunction fn;

      setUp(() {
        fn = plugin.functions.firstWhere((f) => f.schema.name == 'llm_chat');
      });

      test('sends messages via AgentApi and returns result', () async {
        final result = await fn.handler({
          'messages': <Object?>[
            <String, Object?>{'role': 'user', 'content': 'Hello'},
            <String, Object?>{'role': 'assistant', 'content': 'Hi there!'},
            <String, Object?>{'role': 'user', 'content': 'How are you?'},
          ],
        });

        expect(result, isA<Map<String, Object?>>());
        final map = result! as Map<String, Object?>;
        expect(map['text'], 'LLM says hello');
        expect(map['thread_id'], 'fake-thread-id');

        final sentPrompt = agentApi.calls['spawnAgent']![1]! as String;
        expect(sentPrompt, contains('user: Hello'));
        expect(sentPrompt, contains('assistant: Hi there!'));
        expect(sentPrompt, contains('user: How are you?'));
      });

      test('prepends system prompt to messages', () async {
        await fn.handler({
          'messages': <Object?>[
            <String, Object?>{'role': 'user', 'content': 'Hello'},
          ],
          'system_prompt': 'Be helpful.',
        });

        final sentPrompt = agentApi.calls['spawnAgent']![1]! as String;
        expect(sentPrompt, startsWith('System: Be helpful.'));
      });

      test('passes thread_id for continuation', () async {
        await fn.handler({
          'messages': <Object?>[
            <String, Object?>{'role': 'user', 'content': 'Continue'},
          ],
          'thread_id': 'tid-abc',
        });

        expect(agentApi.calls['spawnAgent']![2], 'tid-abc');
      });

      test('schema has messages, system_prompt, room, thread_id', () {
        expect(fn.schema.params, hasLength(4));
        expect(fn.schema.params[0].name, 'messages');
        expect(fn.schema.params[0].type, HostParamType.list);
        expect(fn.schema.params[1].name, 'system_prompt');
        expect(fn.schema.params[1].isRequired, isFalse);
        expect(fn.schema.params[2].name, 'room');
        expect(fn.schema.params[2].isRequired, isFalse);
        expect(fn.schema.params[3].name, 'thread_id');
        expect(fn.schema.params[3].isRequired, isFalse);
      });
    });
  });

  group('LlmPlugin.fromCallbacks', () {
    late List<String> completeCalls;
    late List<List<Map<String, String>>> chatCalls;
    late LlmPlugin plugin;

    setUp(() {
      completeCalls = [];
      chatCalls = [];
      plugin = LlmPlugin.fromCallbacks(
        complete: (prompt, {String? systemPrompt, int? maxTokens}) async {
          completeCalls.add(prompt);
          return 'callback response';
        },
        chat: (messages, {String? systemPrompt, int? maxTokens}) async {
          chatCalls.add(messages);
          return 'chat callback response';
        },
      );
    });

    test('namespace is llm', () {
      expect(plugin.namespace, 'llm');
    });

    test('provides 2 functions', () {
      expect(plugin.functions, hasLength(2));
    });

    test('llm_complete delegates to completer callback', () async {
      final fn = plugin.functions.firstWhere(
        (f) => f.schema.name == 'llm_complete',
      );

      final result = await fn.handler({'prompt': 'Hello'});

      expect(result, 'callback response');
      expect(completeCalls, ['Hello']);
    });

    test('llm_chat delegates to chatCompleter callback', () async {
      final fn = plugin.functions.firstWhere(
        (f) => f.schema.name == 'llm_chat',
      );

      final result = await fn.handler({
        'messages': <Object?>[
          <String, Object?>{'role': 'user', 'content': 'Hi'},
        ],
      });

      expect(result, isA<Map<String, Object?>>());
      final map = result! as Map<String, Object?>;
      expect(map['text'], 'chat callback response');
      expect(map.containsKey('thread_id'), isTrue);
      expect(map['thread_id'], isNull);
      expect(chatCalls, hasLength(1));
      expect(chatCalls.first.first['role'], 'user');
      expect(chatCalls.first.first['content'], 'Hi');
    });

    test('registers onto bridge via PluginRegistry', () async {
      final bridge = RecordingBridge();
      final registry = PluginRegistry()..register(plugin);
      await registry.attachTo(bridge);

      final names = bridge.registered.map((f) => f.schema.name).toSet();
      expect(names, containsAll(['llm_complete', 'llm_chat']));
    });
  });
}

class _NeverResolvingAgentApi implements FakeAgentApi {
  @override
  Future<int> spawnAgent(
    String roomId,
    String prompt, {
    String? threadId,
    Duration? timeout,
  }) =>
      Completer<int>().future;

  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError();
}
