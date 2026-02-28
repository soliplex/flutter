import 'dart:async';

import 'package:dart_monty_platform_interface/dart_monty_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soliplex_monty/soliplex_monty.dart';

const _usage = MontyResourceUsage(
  memoryBytesUsed: 2048,
  timeElapsedMs: 15,
  stackDepthUsed: 3,
);

void main() {
  Widget buildApp({required Stream<ConsoleEvent> stream}) {
    return MaterialApp(
      home: Scaffold(
        body: ConsoleOutputView(eventStream: stream),
      ),
    );
  }

  group('ConsoleOutputView', () {
    testWidgets('shows "No output" when stream is empty', (tester) async {
      final controller = StreamController<ConsoleEvent>();

      await tester.pumpWidget(buildApp(stream: controller.stream));

      expect(find.text('No output'), findsOneWidget);

      await controller.close();
    });

    testWidgets('renders console output text', (tester) async {
      final controller = StreamController<ConsoleEvent>();

      await tester.pumpWidget(buildApp(stream: controller.stream));

      controller.add(const ConsoleOutput('hello world\n'));
      await tester.pumpAndSettle();

      expect(find.text('hello world\n'), findsOneWidget);

      await controller.close();
    });

    testWidgets('renders multiple output lines', (tester) async {
      final controller = StreamController<ConsoleEvent>();

      await tester.pumpWidget(buildApp(stream: controller.stream));

      controller
        ..add(const ConsoleOutput('line 1\n'))
        ..add(const ConsoleOutput('line 2\n'));
      await tester.pumpAndSettle();

      expect(find.text('line 1\n'), findsOneWidget);
      expect(find.text('line 2\n'), findsOneWidget);

      await controller.close();
    });

    testWidgets('shows return value on completion', (tester) async {
      final controller = StreamController<ConsoleEvent>();

      await tester.pumpWidget(buildApp(stream: controller.stream));

      controller.add(
        const ConsoleComplete(
          ExecutionResult(value: '42', usage: _usage, output: ''),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('=> 42\n'), findsOneWidget);

      await controller.close();
    });

    testWidgets('shows resource usage on completion', (tester) async {
      final controller = StreamController<ConsoleEvent>();

      await tester.pumpWidget(buildApp(stream: controller.stream));

      controller.add(
        const ConsoleComplete(
          ExecutionResult(usage: _usage, output: ''),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('15ms'), findsOneWidget);
      expect(find.textContaining('2.0KB'), findsOneWidget);
      expect(find.textContaining('depth 3'), findsOneWidget);

      await controller.close();
    });

    testWidgets('shows error message in red', (tester) async {
      final controller = StreamController<ConsoleEvent>();

      await tester.pumpWidget(buildApp(stream: controller.stream));

      controller.add(
        const ConsoleError(
          MontyException(message: 'NameError: x', lineNumber: 5),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('line 5: NameError: x\n'), findsOneWidget);

      await controller.close();
    });

    testWidgets('does not show return value when null', (tester) async {
      final controller = StreamController<ConsoleEvent>();

      await tester.pumpWidget(buildApp(stream: controller.stream));

      controller.add(
        const ConsoleComplete(
          ExecutionResult(usage: _usage, output: 'hello\n'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('=>'), findsNothing);

      await controller.close();
    });
  });
}
