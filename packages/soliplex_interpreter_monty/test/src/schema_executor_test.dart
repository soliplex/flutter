import 'package:dart_monty_platform_interface/dart_monty_platform_interface.dart';
import 'package:dart_monty_platform_interface/dart_monty_testing.dart';
import 'package:soliplex_interpreter_monty/src/schema_executor.dart';
import 'package:test/test.dart';

const _usage = MontyResourceUsage(
  memoryBytesUsed: 1024,
  timeElapsedMs: 10,
  stackDepthUsed: 5,
);

const _toolValidatorCode = '''
def validate_tool(raw):
    result = {}
    result['kind'] = str(raw.get('kind', ''))
    result['tool_name'] = str(raw.get('tool_name', ''))
    result['allow_mcp'] = bool(raw.get('allow_mcp', False))
    return result
''';

void main() {
  late MockMontyPlatform mock;
  late SchemaExecutor executor;

  setUp(() {
    mock = MockMontyPlatform();
    executor = SchemaExecutor(platform: mock);
  });

  group('loadSchemas', () {
    test('makes schema names available', () {
      executor.loadSchemas({'tool': _toolValidatorCode});

      expect(executor.schemaNames, contains('tool'));
      expect(executor.hasSchemas, isTrue);
    });

    test('hasSchemas is false when empty', () {
      expect(executor.hasSchemas, isFalse);
    });

    test('merges multiple loads', () {
      executor
        ..loadSchemas({'tool': _toolValidatorCode})
        ..loadSchemas({'room': 'def validate_room(raw):\n    return raw\n'});

      expect(executor.schemaNames, containsAll(['tool', 'room']));
    });
  });

  group('validate', () {
    test('returns validated dict from Python function', () async {
      executor.loadSchemas({'tool': _toolValidatorCode});

      mock.runResult = const MontyResult(
        value: {
          'kind': 'search',
          'tool_name': 'tools.search',
          'allow_mcp': false,
        },
        usage: _usage,
      );

      final result = await executor.validate('tool', {
        'kind': 'search',
        'tool_name': 'tools.search',
        'allow_mcp': false,
      });

      expect(result['kind'], 'search');
      expect(result['tool_name'], 'tools.search');
      expect(result['allow_mcp'], false);
    });

    test('composes correct Python code', () async {
      executor.loadSchemas({'tool': _toolValidatorCode});

      mock.runResult = const MontyResult(
        value: <String, Object?>{},
        usage: _usage,
      );

      await executor.validate('tool', <String, Object?>{});

      expect(mock.lastRunCode, contains('raw = __input__'));
      expect(mock.lastRunCode, contains('def validate_tool(raw):'));
      expect(mock.lastRunCode, contains('validate_tool(raw)'));
    });

    test('passes raw JSON as __input__', () async {
      executor.loadSchemas({'tool': _toolValidatorCode});

      mock.runResult = const MontyResult(
        value: <String, Object?>{},
        usage: _usage,
      );

      final input = <String, Object?>{'kind': 'test'};
      await executor.validate('tool', input);

      expect(
        mock.lastRunInputs,
        containsPair('__input__', input),
      );
    });

    test('throws ArgumentError for unknown schema', () async {
      expect(
        () => executor.validate('unknown', <String, Object?>{}),
        throwsArgumentError,
      );
    });

    test('throws MontyException when Python code fails', () async {
      executor.loadSchemas({'tool': _toolValidatorCode});

      mock.runResult = const MontyResult(
        error: MontyException(message: 'NameError: raw is not defined'),
        usage: _usage,
      );

      expect(
        () => executor.validate('tool', <String, Object?>{}),
        throwsA(isA<MontyException>()),
      );
    });
  });

  group('multiple schemas', () {
    test('validates different schemas independently', () async {
      executor.loadSchemas({
        'tool': _toolValidatorCode,
        'room': '''
def validate_room(raw):
    result = {}
    result['name'] = str(raw.get('name', ''))
    return result
''',
      });

      mock.runResult = const MontyResult(
        value: {'name': 'general'},
        usage: _usage,
      );

      final result = await executor.validate('room', {'name': 'general'});
      expect(result['name'], 'general');

      // Verify the room schema code was used, not tool
      expect(mock.lastRunCode, contains('validate_room(raw)'));
      expect(mock.lastRunCode, isNot(contains('validate_tool')));
    });
  });
}
