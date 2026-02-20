import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soliplex_frontend/features/history/widgets/thread_list_item.dart';

import '../../../helpers/test_helpers.dart';

void main() {
  group('ThreadListItem', () {
    group('unread indicator', () {
      testWidgets('shows unread dot when hasUnreadRun is true', (
        tester,
      ) async {
        await tester.pumpWidget(
          createTestApp(
            home: ThreadListItem(
              thread: TestData.createThread(id: 'thread-1', name: 'Thread 1'),
              isSelected: false,
              hasActiveRun: false,
              hasUnreadRun: true,
              onTap: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Find the 8x8 circular dot container
        final dotFinder = find.byWidgetPredicate(
          (widget) =>
              widget is Container &&
              widget.constraints?.maxWidth == 8 &&
              widget.constraints?.maxHeight == 8,
        );
        expect(dotFinder, findsOneWidget);
      });

      testWidgets('hides unread dot when hasUnreadRun is false', (
        tester,
      ) async {
        await tester.pumpWidget(
          createTestApp(
            home: ThreadListItem(
              thread: TestData.createThread(id: 'thread-1', name: 'Thread 1'),
              isSelected: false,
              hasActiveRun: false,
              onTap: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        final dotFinder = find.byWidgetPredicate(
          (widget) =>
              widget is Container &&
              widget.constraints?.maxWidth == 8 &&
              widget.constraints?.maxHeight == 8,
        );
        expect(dotFinder, findsNothing);
      });

      testWidgets('hides unread dot when selected even if hasUnreadRun', (
        tester,
      ) async {
        await tester.pumpWidget(
          createTestApp(
            home: ThreadListItem(
              thread: TestData.createThread(id: 'thread-1', name: 'Thread 1'),
              isSelected: true,
              hasActiveRun: false,
              hasUnreadRun: true,
              onTap: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        final dotFinder = find.byWidgetPredicate(
          (widget) =>
              widget is Container &&
              widget.constraints?.maxWidth == 8 &&
              widget.constraints?.maxHeight == 8,
        );
        expect(dotFinder, findsNothing);
      });
    });
  });
}
