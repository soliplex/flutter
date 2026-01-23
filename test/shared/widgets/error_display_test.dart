import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soliplex_client/soliplex_client.dart' hide State;
import 'package:soliplex_frontend/core/providers/thread_message_cache.dart';
import 'package:soliplex_frontend/shared/widgets/error_display.dart';

import '../../helpers/test_helpers.dart';

void main() {
  group('ErrorDisplay', () {
    testWidgets('displays network error message', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          home: const ErrorDisplay(
            error: NetworkException(message: 'Connection failed'),
          ),
        ),
      );

      expect(find.textContaining('Network error'), findsOneWidget);
      expect(find.textContaining('Connection failed'), findsOneWidget);
      expect(find.byIcon(Icons.wifi_off), findsOneWidget);
    });

    testWidgets('displays session expired for 401 auth error', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          home: const ErrorDisplay(
            error: AuthException(message: 'Unauthorized', statusCode: 401),
          ),
        ),
      );

      expect(
        find.text('Session expired. Please log in again.'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    });

    testWidgets('displays permission denied for 403 auth error', (
      tester,
    ) async {
      await tester.pumpWidget(
        createTestApp(
          home: const ErrorDisplay(
            error: AuthException(message: 'Forbidden', statusCode: 403),
          ),
        ),
      );

      expect(
        find.text("You don't have permission to access this resource."),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    });

    testWidgets('displays not found error with resource', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          home: const ErrorDisplay(
            error: NotFoundException(
              message: 'does not exist',
              resource: 'Thread',
            ),
          ),
        ),
      );

      expect(find.textContaining('Thread not found'), findsOneWidget);
      expect(find.textContaining('does not exist'), findsOneWidget);
    });

    testWidgets('displays not found error without resource', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          home: const ErrorDisplay(
            error: NotFoundException(message: 'Resource not found'),
          ),
        ),
      );

      expect(find.text('Resource not found'), findsOneWidget);
    });

    testWidgets('displays API error message with status text', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          home: const ErrorDisplay(
            error: ApiException(statusCode: 500, message: 'Database error'),
          ),
        ),
      );

      expect(
        find.textContaining('Server error (Internal Server Error)'),
        findsOneWidget,
      );
      expect(find.textContaining('Database error'), findsOneWidget);
    });

    testWidgets('displays generic error message', (tester) async {
      await tester.pumpWidget(
        createTestApp(home: ErrorDisplay(error: Exception('Unknown error'))),
      );

      expect(find.text('An unexpected error occurred.'), findsOneWidget);
    });

    testWidgets('shows retry button when callback provided', (tester) async {
      var retryPressed = false;

      await tester.pumpWidget(
        createTestApp(
          home: ErrorDisplay(
            error: const NetworkException(message: 'Failed'),
            onRetry: () => retryPressed = true,
          ),
        ),
      );

      expect(find.text('Retry'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      await tester.pump();

      expect(retryPressed, true);
    });

    testWidgets('hides retry button when callback not provided', (
      tester,
    ) async {
      await tester.pumpWidget(
        createTestApp(
          home: const ErrorDisplay(error: NetworkException(message: 'Failed')),
        ),
      );

      expect(find.text('Retry'), findsNothing);
    });

    group('collapsible details', () {
      testWidgets('shows "Show details" toggle', (tester) async {
        await tester.pumpWidget(
          createTestApp(
            home: const ErrorDisplay(
              error: NetworkException(message: 'Connection failed'),
            ),
          ),
        );

        expect(find.text('Show details'), findsOneWidget);
        expect(find.text('Hide details'), findsNothing);
      });

      testWidgets('expands details on tap', (tester) async {
        await tester.pumpWidget(
          createTestApp(
            home: const ErrorDisplay(
              error: ApiException(
                statusCode: 500,
                message: 'Server error',
                body: '{"error": "internal"}',
              ),
            ),
          ),
        );

        await tester.tap(find.text('Show details'));
        await tester.pumpAndSettle();

        expect(find.text('Hide details'), findsOneWidget);
        expect(find.textContaining('Type:'), findsOneWidget);
        expect(find.textContaining('ApiException'), findsOneWidget);
        expect(find.textContaining('Response Body:'), findsOneWidget);
        expect(find.text('Copy details'), findsOneWidget);
      });

      testWidgets('collapses details on second tap', (tester) async {
        await tester.pumpWidget(
          createTestApp(
            home: const ErrorDisplay(
              error: NetworkException(message: 'Failed'),
            ),
          ),
        );

        // Expand
        await tester.tap(find.text('Show details'));
        await tester.pumpAndSettle();
        expect(find.text('Hide details'), findsOneWidget);

        // Collapse
        await tester.tap(find.text('Hide details'));
        await tester.pumpAndSettle();
        expect(find.text('Show details'), findsOneWidget);
        expect(find.text('Copy details'), findsNothing);
      });
    });

    group('MessageFetchException unwrapping', () {
      testWidgets('unwraps NetworkException from MessageFetchException', (
        tester,
      ) async {
        await tester.pumpWidget(
          createTestApp(
            home: ErrorDisplay(
              error: MessageFetchException(
                threadId: 'thread-123',
                cause: const NetworkException(message: 'Connection failed'),
              ),
            ),
          ),
        );

        expect(find.textContaining('Network error'), findsOneWidget);
        expect(find.byIcon(Icons.wifi_off), findsOneWidget);
      });

      testWidgets('unwraps ApiException from MessageFetchException', (
        tester,
      ) async {
        await tester.pumpWidget(
          createTestApp(
            home: ErrorDisplay(
              error: MessageFetchException(
                threadId: 'thread-123',
                cause: const ApiException(
                  statusCode: 500,
                  message: 'Internal Server Error',
                ),
              ),
            ),
          ),
        );

        expect(
          find.textContaining('Server error (Internal Server Error)'),
          findsOneWidget,
        );
      });

      testWidgets('shows thread ID in expanded details', (tester) async {
        await tester.pumpWidget(
          createTestApp(
            home: ErrorDisplay(
              error: MessageFetchException(
                threadId: 'thread-123',
                cause: const NetworkException(message: 'Failed'),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Show details'));
        await tester.pumpAndSettle();

        expect(find.textContaining('Thread ID:'), findsOneWidget);
        expect(find.textContaining('thread-123'), findsOneWidget);
      });

      testWidgets('shows retry button for wrapped NetworkException', (
        tester,
      ) async {
        var retryPressed = false;

        await tester.pumpWidget(
          createTestApp(
            home: ErrorDisplay(
              error: MessageFetchException(
                threadId: 'thread-123',
                cause: const NetworkException(message: 'Failed'),
              ),
              onRetry: () => retryPressed = true,
            ),
          ),
        );

        expect(find.text('Retry'), findsOneWidget);

        await tester.tap(find.text('Retry'));
        await tester.pump();

        expect(retryPressed, true);
      });

      testWidgets('hides retry button for wrapped AuthException', (
        tester,
      ) async {
        await tester.pumpWidget(
          createTestApp(
            home: ErrorDisplay(
              error: MessageFetchException(
                threadId: 'thread-123',
                cause: const AuthException(message: 'Unauthorized'),
              ),
              onRetry: () {},
            ),
          ),
        );

        expect(find.text('Retry'), findsNothing);
      });
    });
  });
}
