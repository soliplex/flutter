import 'package:dart_monty_platform_interface/dart_monty_platform_interface.dart';
import 'package:dart_monty_platform_interface/dart_monty_testing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soliplex_monty/soliplex_monty.dart';

const _usage = MontyResourceUsage(
  memoryBytesUsed: 1024,
  timeElapsedMs: 10,
  stackDepthUsed: 5,
);

void main() {
  late MockMontyPlatform mock;

  setUp(() {
    mock = MockMontyPlatform();
  });

  Widget buildApp({required Widget child}) {
    return MaterialApp(home: Scaffold(body: child));
  }

  MontyExecutionService serviceFor(MockMontyPlatform m) =>
      MontyExecutionService(platform: m);

  group('PythonRunButton', () {
    testWidgets('shows play icon in idle state', (tester) async {
      mock.enqueueProgress(
        const MontyComplete(result: MontyResult(usage: _usage)),
      );

      await tester.pumpWidget(
        buildApp(
          child: PythonRunButton(
            code: 'pass',
            service: serviceFor(mock),
          ),
        ),
      );

      expect(find.byIcon(Icons.play_arrow), findsOneWidget);
    });

    testWidgets('shows check icon after successful execution', (tester) async {
      mock.enqueueProgress(
        const MontyComplete(
          result: MontyResult(value: 42, usage: _usage),
        ),
      );

      final playFinder = find.byIcon(Icons.play_arrow);

      await tester.pumpWidget(
        buildApp(
          child: PythonRunButton(
            code: '42',
            service: serviceFor(mock),
          ),
        ),
      );

      await tester.tap(playFinder);
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.check), findsOneWidget);
    });

    testWidgets('shows error icon after failed execution', (tester) async {
      mock.enqueueProgress(
        const MontyComplete(
          result: MontyResult(
            error: MontyException(message: 'fail'),
            usage: _usage,
          ),
        ),
      );

      final playFinder = find.byIcon(Icons.play_arrow);

      await tester.pumpWidget(
        buildApp(
          child: PythonRunButton(
            code: 'x',
            service: serviceFor(mock),
          ),
        ),
      );

      await tester.tap(playFinder);
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('calls onResult callback on success', (tester) async {
      mock.enqueueProgress(
        const MontyComplete(
          result: MontyResult(value: 42, usage: _usage),
        ),
      );

      ExecutionResult? captured;
      final playFinder = find.byIcon(Icons.play_arrow);

      await tester.pumpWidget(
        buildApp(
          child: PythonRunButton(
            code: '42',
            service: serviceFor(mock),
            onResult: (result) => captured = result,
          ),
        ),
      );

      await tester.tap(playFinder);
      await tester.pumpAndSettle();

      expect(captured, isNotNull);
      expect(captured?.value, '42');
    });

    testWidgets('calls onError callback on failure', (tester) async {
      mock.enqueueProgress(
        const MontyComplete(
          result: MontyResult(
            error: MontyException(message: 'boom'),
            usage: _usage,
          ),
        ),
      );

      MontyException? captured;
      final playFinder = find.byIcon(Icons.play_arrow);

      await tester.pumpWidget(
        buildApp(
          child: PythonRunButton(
            code: 'x',
            service: serviceFor(mock),
            onError: (error) => captured = error,
          ),
        ),
      );

      await tester.tap(playFinder);
      await tester.pumpAndSettle();

      expect(captured, isNotNull);
      expect(captured?.message, 'boom');
    });

    group('input variables', () {
      testWidgets('shows dialog when inputVariables provided', (tester) async {
        mock.enqueueProgress(
          const MontyComplete(result: MontyResult(usage: _usage)),
        );

        final playFinder = find.byIcon(Icons.play_arrow);

        await tester.pumpWidget(
          buildApp(
            child: PythonRunButton(
              code: 'print(x)',
              service: serviceFor(mock),
              inputVariables: const {
                'x': InputVariable(
                  label: 'X value',
                  type: InputVariableType.int,
                ),
              },
            ),
          ),
        );

        await tester.tap(playFinder);
        await tester.pumpAndSettle();

        expect(find.text('Input Variables'), findsOneWidget);
        expect(find.text('X value'), findsOneWidget);
      });

      testWidgets('validates int input', (tester) async {
        mock.enqueueProgress(
          const MontyComplete(result: MontyResult(usage: _usage)),
        );

        final playFinder = find.byIcon(Icons.play_arrow);
        final runFinder = find.text('Run');

        await tester.pumpWidget(
          buildApp(
            child: PythonRunButton(
              code: 'print(x)',
              service: serviceFor(mock),
              inputVariables: const {
                'x': InputVariable(
                  label: 'X',
                  type: InputVariableType.int,
                ),
              },
            ),
          ),
        );

        await tester.tap(playFinder);
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextFormField), 'abc');
        await tester.tap(runFinder);
        await tester.pumpAndSettle();

        expect(find.text('Must be an integer'), findsOneWidget);
      });

      testWidgets('accepts trimmed int input', (tester) async {
        mock.enqueueProgress(
          const MontyComplete(result: MontyResult(usage: _usage)),
        );

        final playFinder = find.byIcon(Icons.play_arrow);
        final runFinder = find.text('Run');

        await tester.pumpWidget(
          buildApp(
            child: PythonRunButton(
              code: 'print(x)',
              service: serviceFor(mock),
              inputVariables: const {
                'x': InputVariable(
                  label: 'X',
                  type: InputVariableType.int,
                  defaultValue: '  42  ',
                ),
              },
            ),
          ),
        );

        await tester.tap(playFinder);
        await tester.pumpAndSettle();

        await tester.tap(runFinder);
        await tester.pumpAndSettle();

        expect(mock.startCodes, hasLength(1));
        expect(mock.lastStartCode, contains('x = 42'));
      });

      testWidgets('injects variables as Python assignments', (tester) async {
        mock.enqueueProgress(
          const MontyComplete(result: MontyResult(usage: _usage)),
        );

        final playFinder = find.byIcon(Icons.play_arrow);
        final runFinder = find.text('Run');

        await tester.pumpWidget(
          buildApp(
            child: PythonRunButton(
              code: 'print(x)',
              service: serviceFor(mock),
              inputVariables: const {
                'x': InputVariable(
                  label: 'X',
                  type: InputVariableType.int,
                  defaultValue: '42',
                ),
              },
            ),
          ),
        );

        await tester.tap(playFinder);
        await tester.pumpAndSettle();

        await tester.tap(runFinder);
        await tester.pumpAndSettle();

        final code = mock.lastStartCode;
        expect(code, contains('x = 42'));
        expect(code, contains('print(x)'));
      });

      testWidgets('escapes string input as Python literal', (tester) async {
        mock.enqueueProgress(
          const MontyComplete(result: MontyResult(usage: _usage)),
        );

        final playFinder = find.byIcon(Icons.play_arrow);
        final runFinder = find.text('Run');

        await tester.pumpWidget(
          buildApp(
            child: PythonRunButton(
              code: 'print(s)',
              service: serviceFor(mock),
              inputVariables: const {
                's': InputVariable(
                  label: 'Text',
                  defaultValue: r"it's a\test",
                ),
              },
            ),
          ),
        );

        await tester.tap(playFinder);
        await tester.pumpAndSettle();

        await tester.tap(runFinder);
        await tester.pumpAndSettle();

        final code = mock.lastStartCode;
        expect(code, contains("s = 'it"));
        expect(code, contains('print(s)'));
      });

      testWidgets('validates float input', (tester) async {
        mock.enqueueProgress(
          const MontyComplete(result: MontyResult(usage: _usage)),
        );

        final playFinder = find.byIcon(Icons.play_arrow);
        final runFinder = find.text('Run');

        await tester.pumpWidget(
          buildApp(
            child: PythonRunButton(
              code: 'print(f)',
              service: serviceFor(mock),
              inputVariables: const {
                'f': InputVariable(
                  label: 'Float',
                  type: InputVariableType.float,
                ),
              },
            ),
          ),
        );

        await tester.tap(playFinder);
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextFormField), 'abc');
        await tester.tap(runFinder);
        await tester.pumpAndSettle();

        expect(find.text('Must be a number'), findsOneWidget);
      });

      testWidgets('accepts valid float input', (tester) async {
        mock.enqueueProgress(
          const MontyComplete(result: MontyResult(usage: _usage)),
        );

        final playFinder = find.byIcon(Icons.play_arrow);
        final runFinder = find.text('Run');

        await tester.pumpWidget(
          buildApp(
            child: PythonRunButton(
              code: 'print(f)',
              service: serviceFor(mock),
              inputVariables: const {
                'f': InputVariable(
                  label: 'Float',
                  type: InputVariableType.float,
                  defaultValue: '3.14',
                ),
              },
            ),
          ),
        );

        await tester.tap(playFinder);
        await tester.pumpAndSettle();

        await tester.tap(runFinder);
        await tester.pumpAndSettle();

        expect(mock.lastStartCode, contains('f = 3.14'));
      });

      testWidgets('validates bool input', (tester) async {
        mock.enqueueProgress(
          const MontyComplete(result: MontyResult(usage: _usage)),
        );

        final playFinder = find.byIcon(Icons.play_arrow);
        final runFinder = find.text('Run');

        await tester.pumpWidget(
          buildApp(
            child: PythonRunButton(
              code: 'print(b)',
              service: serviceFor(mock),
              inputVariables: const {
                'b': InputVariable(
                  label: 'Flag',
                  type: InputVariableType.bool,
                ),
              },
            ),
          ),
        );

        await tester.tap(playFinder);
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextFormField), 'maybe');
        await tester.tap(runFinder);
        await tester.pumpAndSettle();

        expect(find.text('Must be true or false'), findsOneWidget);
      });

      testWidgets('converts bool true to Python True', (tester) async {
        mock.enqueueProgress(
          const MontyComplete(result: MontyResult(usage: _usage)),
        );

        final playFinder = find.byIcon(Icons.play_arrow);
        final runFinder = find.text('Run');

        await tester.pumpWidget(
          buildApp(
            child: PythonRunButton(
              code: 'print(b)',
              service: serviceFor(mock),
              inputVariables: const {
                'b': InputVariable(
                  label: 'Flag',
                  type: InputVariableType.bool,
                  defaultValue: 'true',
                ),
              },
            ),
          ),
        );

        await tester.tap(playFinder);
        await tester.pumpAndSettle();

        await tester.tap(runFinder);
        await tester.pumpAndSettle();

        expect(mock.lastStartCode, contains('b = True'));
      });

      testWidgets('converts bool false to Python False', (tester) async {
        mock.enqueueProgress(
          const MontyComplete(result: MontyResult(usage: _usage)),
        );

        final playFinder = find.byIcon(Icons.play_arrow);
        final runFinder = find.text('Run');

        await tester.pumpWidget(
          buildApp(
            child: PythonRunButton(
              code: 'print(b)',
              service: serviceFor(mock),
              inputVariables: const {
                'b': InputVariable(
                  label: 'Flag',
                  type: InputVariableType.bool,
                  defaultValue: 'false',
                ),
              },
            ),
          ),
        );

        await tester.tap(playFinder);
        await tester.pumpAndSettle();

        await tester.tap(runFinder);
        await tester.pumpAndSettle();

        expect(mock.lastStartCode, contains('b = False'));
      });

      testWidgets('cancelling dialog does not execute', (tester) async {
        final playFinder = find.byIcon(Icons.play_arrow);
        final cancelFinder = find.text('Cancel');

        await tester.pumpWidget(
          buildApp(
            child: PythonRunButton(
              code: 'print(x)',
              service: serviceFor(mock),
              inputVariables: const {
                'x': InputVariable(
                  label: 'X',
                  type: InputVariableType.int,
                ),
              },
            ),
          ),
        );

        await tester.tap(playFinder);
        await tester.pumpAndSettle();

        await tester.tap(cancelFinder);
        await tester.pumpAndSettle();

        expect(playFinder, findsOneWidget);
        expect(mock.startCodes, isEmpty);
      });
    });

    testWidgets('didUpdateWidget disposes owned service on swap',
        (tester) async {
      final mock1 = MockMontyPlatform();
      final mock2 = MockMontyPlatform();

      mock1.enqueueProgress(
        const MontyComplete(result: MontyResult(usage: _usage)),
      );
      mock2.enqueueProgress(
        const MontyComplete(result: MontyResult(usage: _usage)),
      );

      final service1 = serviceFor(mock1);
      final service2 = serviceFor(mock2);

      await tester.pumpWidget(
        buildApp(
          child: PythonRunButton(
            code: 'pass',
            service: service1,
          ),
        ),
      );

      await tester.pumpWidget(
        buildApp(
          child: PythonRunButton(
            code: 'pass',
            service: service2,
          ),
        ),
      );

      // After swapping, tapping should use service2
      await tester.tap(find.byIcon(Icons.play_arrow));
      await tester.pumpAndSettle();

      expect(mock2.startCodes, hasLength(1));
      expect(mock1.startCodes, isEmpty);
    });
  });
}
