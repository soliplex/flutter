import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soliplex_frontend/shared/widgets/async_value_handler.dart';
import 'package:soliplex_frontend/shared/widgets/error_display.dart';
import 'package:soliplex_frontend/shared/widgets/loading_indicator.dart';

import '../../helpers/test_helpers.dart';

void main() {
  group('AsyncValueHandler', () {
    testWidgets('shows LoadingIndicator when loading and no custom widget',
        (tester) async {
      await tester.pumpWidget(
        createTestApp(
          home: AsyncValueHandler<String>(
            value: const AsyncValue.loading(),
            data: (text) => Text(text, key: ValueKey(text)),
          ),
        ),
      );

      expect(find.byType(LoadingIndicator), findsOneWidget);
    });

    testWidgets('shows custom loading widget when provided', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          home: AsyncValueHandler<String>(
            value: const AsyncValue.loading(),
            data: (text) => Text(text, key: ValueKey(text)),
            loading: const Text('Custom Loading'),
          ),
        ),
      );

      expect(find.text('Custom Loading'), findsOneWidget);
      expect(find.byType(LoadingIndicator), findsNothing);
    });

    testWidgets('shows data widget when data is available', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          home: AsyncValueHandler<String>(
            value: const AsyncValue.data('Hello World'),
            data: (text) => Text(text, key: ValueKey(text)),
          ),
        ),
      );

      expect(find.text('Hello World'), findsOneWidget);
    });

    testWidgets('shows ErrorDisplay when error occurs', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          home: AsyncValueHandler<String>(
            value: AsyncValue.error(Exception('Test error'), StackTrace.empty),
            data: (text) => Text(text, key: ValueKey(text)),
          ),
        ),
      );

      expect(find.byType(ErrorDisplay), findsOneWidget);
    });

    testWidgets('ErrorDisplay shows retry button when onRetry provided',
        (tester) async {
      var retried = false;

      await tester.pumpWidget(
        createTestApp(
          home: AsyncValueHandler<String>(
            value: AsyncValue.error(Exception('Test error'), StackTrace.empty),
            data: (text) => Text(text, key: ValueKey(text)),
            onRetry: () => retried = true,
          ),
        ),
      );

      expect(find.text('Retry'), findsOneWidget);
      await tester.tap(find.text('Retry'));
      await tester.pump();

      expect(retried, isTrue);
    });
  });
}
