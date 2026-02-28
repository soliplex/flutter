import 'package:dart_monty_platform_interface/dart_monty_platform_interface.dart';
import 'package:dart_monty_platform_interface/dart_monty_testing.dart';
import 'package:soliplex_interpreter_monty/soliplex_interpreter_monty.dart';
import 'package:test/test.dart';

const _usage = MontyResourceUsage(
  memoryBytesUsed: 1024,
  timeElapsedMs: 10,
  stackDepthUsed: 5,
);

void main() {
  late MockMontyPlatform mock;
  late MontyExecutionService service;

  setUp(() {
    mock = MockMontyPlatform();
    service = MontyExecutionService(platform: mock);
  });

  tearDown(() {
    service.dispose();
  });

  group('MontyExecutionService', () {
    test('emits ConsoleOutput then ConsoleComplete for print + return',
        () async {
      mock
        ..enqueueProgress(
          const MontyPending(
            functionName: '__console_write__',
            arguments: ['hello\n'],
          ),
        )
        ..enqueueProgress(
          const MontyComplete(
            result: MontyResult(value: 42, usage: _usage),
          ),
        );

      final events = await service.execute(r'print("hello")\n42').toList();

      expect(events, hasLength(2));

      final output = events.first;
      expect(output, isA<ConsoleOutput>());
      expect((output as ConsoleOutput).text, 'hello\n');

      final complete = events.last;
      expect(complete, isA<ConsoleComplete>());

      final result = (complete as ConsoleComplete).result;
      expect(result.value, '42');
      expect(result.output, 'hello\n');
      expect(result.usage, _usage);
    });

    test('emits ConsoleError on MontyComplete with error', () async {
      mock.enqueueProgress(
        const MontyComplete(
          result: MontyResult(
            error: MontyException(
              message: 'NameError: x is not defined',
              lineNumber: 1,
            ),
            usage: _usage,
          ),
        ),
      );

      final events = await service.execute('x').toList();

      expect(events, hasLength(1));

      final error = events.first;
      expect(error, isA<ConsoleError>());
      expect(
        (error as ConsoleError).error.message,
        'NameError: x is not defined',
      );
    });

    test('emits ConsoleComplete with null value for None return', () async {
      mock.enqueueProgress(
        const MontyComplete(result: MontyResult(usage: _usage)),
      );

      final events = await service.execute('pass').toList();

      expect(events, hasLength(1));

      final complete = events.first;
      expect(complete, isA<ConsoleComplete>());
      expect((complete as ConsoleComplete).result.value, isNull);
    });

    test('handles multiple print calls', () async {
      mock
        ..enqueueProgress(
          const MontyPending(
            functionName: '__console_write__',
            arguments: ['line 1\n'],
          ),
        )
        ..enqueueProgress(
          const MontyPending(
            functionName: '__console_write__',
            arguments: ['line 2\n'],
          ),
        )
        ..enqueueProgress(
          const MontyComplete(result: MontyResult(usage: _usage)),
        );

      final events = await service.execute('code').toList();

      expect(events, hasLength(3));
      expect(events.first, isA<ConsoleOutput>());
      expect(events[1], isA<ConsoleOutput>());

      final complete = events.last;
      expect(complete, isA<ConsoleComplete>());
      expect(
        (complete as ConsoleComplete).result.output,
        'line 1\nline 2\n',
      );
    });

    test('throws StateError if already executing', () async {
      mock.enqueueProgress(
        const MontyComplete(result: MontyResult(usage: _usage)),
      );

      // Start first execution but don't await
      final stream = service.execute('code');

      // Second call should throw
      expect(
        () => service.execute('more code'),
        throwsStateError,
      );

      // Drain first stream to clean up
      await stream.toList();
    });

    test('throws StateError after dispose', () {
      service.dispose();

      expect(
        () => service.execute('code'),
        throwsStateError,
      );
    });

    test('sets isExecuting during execution', () async {
      mock.enqueueProgress(
        const MontyComplete(result: MontyResult(usage: _usage)),
      );

      expect(service.isExecuting, isFalse);

      final stream = service.execute('code');
      expect(service.isExecuting, isTrue);

      await stream.toList();
      expect(service.isExecuting, isFalse);
    });

    test('wraps code with print preamble', () async {
      mock.enqueueProgress(
        const MontyComplete(result: MontyResult(usage: _usage)),
      );

      await service.execute('x = 1').toList();

      expect(mock.lastStartCode, contains('__console_write__'));
      expect(mock.lastStartCode, contains('x = 1'));
    });

    test('passes __console_write__ as external function', () async {
      mock.enqueueProgress(
        const MontyComplete(result: MontyResult(usage: _usage)),
      );

      await service.execute('pass').toList();

      expect(
        mock.lastStartExternalFunctions,
        contains('__console_write__'),
      );
    });

    test('ignores pending calls for unknown functions', () async {
      mock
        ..enqueueProgress(
          const MontyPending(
            functionName: 'unknown_fn',
            arguments: ['ignored'],
          ),
        )
        ..enqueueProgress(
          const MontyComplete(result: MontyResult(usage: _usage)),
        );

      final events = await service.execute('code').toList();

      expect(events, hasLength(1));
      expect(events.first, isA<ConsoleComplete>());
    });

    test('can execute again after previous completes', () async {
      mock.enqueueProgress(
        const MontyComplete(result: MontyResult(usage: _usage)),
      );
      await service.execute('first').toList();

      mock.enqueueProgress(
        const MontyComplete(
          result: MontyResult(value: 'second', usage: _usage),
        ),
      );
      final events = await service.execute('second').toList();

      expect(events, hasLength(1));
      expect(
        (events.first as ConsoleComplete).result.value,
        'second',
      );
    });
  });
}
