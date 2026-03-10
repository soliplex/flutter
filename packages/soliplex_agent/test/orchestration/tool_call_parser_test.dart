import 'package:soliplex_agent/src/orchestration/tool_call_parser.dart';
import 'package:test/test.dart';

void main() {
  group('parseToolCallResponse', () {
    test('pure text returns TextResponse', () {
      final result = parseToolCallResponse('Hello, how can I help?');
      expect(result, isA<TextResponse>());
      expect((result as TextResponse).text, 'Hello, how can I help?');
    });

    test('valid tool call returns ToolCallResponse', () {
      const response = '''
```tool_call
{"name": "get_weather", "arguments": {"city": "NYC"}}
```''';
      final result = parseToolCallResponse(response);
      expect(result, isA<ToolCallResponse>());
      final tc = result as ToolCallResponse;
      expect(tc.name, 'get_weather');
      expect(tc.arguments, {'city': 'NYC'});
      expect(tc.prefixText, isEmpty);
    });

    test('tool call with prefix text preserves prefix', () {
      const response = '''
Let me check that for you.

```tool_call
{"name": "get_weather", "arguments": {"city": "NYC"}}
```''';
      final result = parseToolCallResponse(response);
      expect(result, isA<ToolCallResponse>());
      final tc = result as ToolCallResponse;
      expect(tc.name, 'get_weather');
      expect(tc.prefixText, 'Let me check that for you.');
    });

    test('invalid JSON falls back to TextResponse', () {
      const response = '''
```tool_call
{not valid json}
```''';
      final result = parseToolCallResponse(response);
      expect(result, isA<TextResponse>());
    });

    test('missing name falls back to TextResponse', () {
      const response = '''
```tool_call
{"arguments": {"city": "NYC"}}
```''';
      final result = parseToolCallResponse(response);
      expect(result, isA<TextResponse>());
    });

    test('empty name falls back to TextResponse', () {
      const response = '''
```tool_call
{"name": "", "arguments": {"city": "NYC"}}
```''';
      final result = parseToolCallResponse(response);
      expect(result, isA<TextResponse>());
    });

    test('missing arguments defaults to empty map', () {
      const response = '''
```tool_call
{"name": "list_files"}
```''';
      final result = parseToolCallResponse(response);
      expect(result, isA<ToolCallResponse>());
      final tc = result as ToolCallResponse;
      expect(tc.name, 'list_files');
      expect(tc.arguments, isEmpty);
    });

    test('array wrapping extracts first element', () {
      const response = '''
```tool_call
[{"name": "get_weather", "arguments": {"city": "NYC"}}]
```''';
      final result = parseToolCallResponse(response);
      expect(result, isA<ToolCallResponse>());
      expect((result as ToolCallResponse).name, 'get_weather');
    });

    test('empty array falls back to TextResponse', () {
      const response = '''
```tool_call
[]
```''';
      final result = parseToolCallResponse(response);
      expect(result, isA<TextResponse>());
    });

    test('nested arguments are preserved', () {
      const response = '''
```tool_call
{"name": "query", "arguments": {"filter": {"age": {"gt": 18}}, "limit": 10}}
```''';
      final result = parseToolCallResponse(response);
      expect(result, isA<ToolCallResponse>());
      final tc = result as ToolCallResponse;
      expect(tc.arguments['filter'], {
        'age': {'gt': 18},
      });
      expect(tc.arguments['limit'], 10);
    });

    test('extra whitespace in block is handled', () {
      const response = '''
```tool_call

  {"name": "echo", "arguments": {"text": "hi"}}

```''';
      final result = parseToolCallResponse(response);
      expect(result, isA<ToolCallResponse>());
      expect((result as ToolCallResponse).name, 'echo');
    });

    test('no fenced block returns TextResponse', () {
      const response = '{"name": "echo", "arguments": {"text": "hi"}}';
      final result = parseToolCallResponse(response);
      expect(result, isA<TextResponse>());
    });

    test('wrong language tag returns TextResponse', () {
      const response = '''
```json
{"name": "echo", "arguments": {"text": "hi"}}
```''';
      final result = parseToolCallResponse(response);
      expect(result, isA<TextResponse>());
    });

    test('closing backticks on same line as JSON', () {
      const response = '```tool_call\n{"name": "execute_python", "arguments": '
          '{"code": "x = 1"}}```';
      final result = parseToolCallResponse(response);
      expect(result, isA<ToolCallResponse>());
      final tc = result as ToolCallResponse;
      expect(tc.name, 'execute_python');
      expect(tc.arguments, {'code': 'x = 1'});
    });

    test('closing backticks on same line with trailing newline', () {
      const response =
          '```tool_call\n{"name": "echo", "arguments": {"text": "hi"}}```\n';
      final result = parseToolCallResponse(response);
      expect(result, isA<ToolCallResponse>());
      expect((result as ToolCallResponse).name, 'echo');
    });
  });
}
