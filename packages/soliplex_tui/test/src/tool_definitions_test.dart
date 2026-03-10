import 'package:mocktail/mocktail.dart';
import 'package:soliplex_agent/soliplex_agent.dart';
import 'package:soliplex_tui/src/tool_definitions.dart';
import 'package:test/test.dart';

class _MockToolExecutionContext extends Mock
    implements ToolExecutionContext {}

void main() {
  group('buildDemoToolRegistry', () {
    test('registers all demo tools when no filter', () {
      final registry = buildDemoToolRegistry();
      expect(registry.length, 2);
      expect(registry.contains('secret_number'), isTrue);
      expect(registry.contains('echo'), isTrue);
    });

    test('filters to only requested tools', () {
      final registry = buildDemoToolRegistry(
        enabledTools: {'echo'},
      );
      expect(registry.length, 1);
      expect(registry.contains('echo'), isTrue);
      expect(registry.contains('secret_number'), isFalse);
    });

    test('returns empty registry for unknown tool names', () {
      final registry = buildDemoToolRegistry(
        enabledTools: {'nonexistent'},
      );
      expect(registry.isEmpty, isTrue);
    });
  });

  group('availableDemoToolNames', () {
    test('returns expected tool names', () {
      expect(
        availableDemoToolNames,
        containsAll(['secret_number', 'echo']),
      );
    });
  });

  group('tool executors via registry', () {
    late ToolRegistry registry;
    late _MockToolExecutionContext ctx;

    setUp(() {
      registry = buildDemoToolRegistry();
      ctx = _MockToolExecutionContext();
    });

    test('secret_number returns 42', () async {
      final result = await registry.execute(
        const ToolCallInfo(
          id: 'tc_1',
          name: 'secret_number',
        ),
        ctx,
      );
      expect(result, '42');
    });

    test('echo returns text argument', () async {
      final result = await registry.execute(
        const ToolCallInfo(
          id: 'tc_2',
          name: 'echo',
          arguments: '{"text": "hello world"}',
        ),
        ctx,
      );
      expect(result, 'hello world');
    });

    test('echo returns empty string with no arguments', () async {
      final result = await registry.execute(
        const ToolCallInfo(id: 'tc_3', name: 'echo'),
        ctx,
      );
      expect(result, '');
    });

    test('echo returns empty string when text key missing', () async {
      final result = await registry.execute(
        const ToolCallInfo(
          id: 'tc_4',
          name: 'echo',
          arguments: '{"other": "value"}',
        ),
        ctx,
      );
      expect(result, '');
    });
  });
}
