import 'package:dart_monty_platform_interface/dart_monty_platform_interface.dart';
import 'package:soliplex_interpreter_monty/soliplex_interpreter_monty.dart';
import 'package:test/test.dart';

const _usage = MontyResourceUsage(
  memoryBytesUsed: 1024,
  timeElapsedMs: 10,
  stackDepthUsed: 5,
);

const _usage2 = MontyResourceUsage(
  memoryBytesUsed: 2048,
  timeElapsedMs: 20,
  stackDepthUsed: 10,
);

void main() {
  group('ExecutionResult', () {
    test('equality with same fields', () {
      const a = ExecutionResult(value: '42', usage: _usage, output: 'hi\n');
      const b = ExecutionResult(value: '42', usage: _usage, output: 'hi\n');

      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    test('not equal with different value', () {
      const a = ExecutionResult(value: '42', usage: _usage, output: '');
      const b = ExecutionResult(value: '99', usage: _usage, output: '');

      expect(a, isNot(equals(b)));
    });

    test('not equal with different usage', () {
      const a = ExecutionResult(value: '42', usage: _usage, output: '');
      const b = ExecutionResult(value: '42', usage: _usage2, output: '');

      expect(a, isNot(equals(b)));
    });

    test('not equal with different output', () {
      const a = ExecutionResult(value: '42', usage: _usage, output: 'a');
      const b = ExecutionResult(value: '42', usage: _usage, output: 'b');

      expect(a, isNot(equals(b)));
    });

    test('not equal to different type', () {
      const result = ExecutionResult(usage: _usage, output: '');
      expect(result, isNot(equals(42)));
    });

    test('equality with null value', () {
      const a = ExecutionResult(usage: _usage, output: '');
      const b = ExecutionResult(usage: _usage, output: '');

      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    test('toString', () {
      const result = ExecutionResult(value: '42', usage: _usage, output: 'x');

      expect(result.toString(), contains('ExecutionResult'));
      expect(result.toString(), contains('42'));
      expect(result.toString(), contains('x'));
    });
  });
}
