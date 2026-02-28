import 'package:dart_monty_platform_interface/dart_monty_platform_interface.dart';
import 'package:soliplex_interpreter_monty/soliplex_interpreter_monty.dart';
import 'package:test/test.dart';

const _usage = MontyResourceUsage(
  memoryBytesUsed: 1024,
  timeElapsedMs: 10,
  stackDepthUsed: 5,
);

void main() {
  group('ConsoleOutput', () {
    test('equality', () {
      const a = ConsoleOutput('hello');
      const b = ConsoleOutput('hello');
      const c = ConsoleOutput('world');

      expect(a, equals(b));
      expect(a, isNot(equals(c)));
      expect(a.hashCode, b.hashCode);
    });

    test('not equal to different type', () {
      const output = ConsoleOutput('text');
      expect(output, isNot(equals('text')));
    });

    test('toString', () {
      const output = ConsoleOutput('hello');
      expect(output.toString(), 'ConsoleOutput(hello)');
    });
  });

  group('ConsoleComplete', () {
    test('equality', () {
      const a = ConsoleComplete(
        ExecutionResult(value: '42', usage: _usage, output: 'out'),
      );
      const b = ConsoleComplete(
        ExecutionResult(value: '42', usage: _usage, output: 'out'),
      );
      const c = ConsoleComplete(
        ExecutionResult(value: '99', usage: _usage, output: 'out'),
      );

      expect(a, equals(b));
      expect(a, isNot(equals(c)));
      expect(a.hashCode, b.hashCode);
    });

    test('not equal to different type', () {
      const complete = ConsoleComplete(
        ExecutionResult(usage: _usage, output: ''),
      );
      expect(complete, isNot(equals(42)));
    });

    test('toString', () {
      const complete = ConsoleComplete(
        ExecutionResult(value: '42', usage: _usage, output: 'x'),
      );
      expect(complete.toString(), contains('ConsoleComplete'));
      expect(complete.toString(), contains('42'));
    });
  });

  group('ConsoleError', () {
    test('equality', () {
      const a = ConsoleError(MontyException(message: 'err'));
      const b = ConsoleError(MontyException(message: 'err'));
      const c = ConsoleError(MontyException(message: 'other'));

      expect(a, equals(b));
      expect(a, isNot(equals(c)));
      expect(a.hashCode, b.hashCode);
    });

    test('not equal to different type', () {
      const error = ConsoleError(MontyException(message: 'err'));
      expect(error, isNot(equals('err')));
    });

    test('toString', () {
      const error = ConsoleError(MontyException(message: 'boom'));
      expect(error.toString(), contains('ConsoleError'));
    });
  });
}
