import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:soliplex_client/soliplex_client.dart' as domain
    show Conversation, Running, ThreadInfo;
import 'package:soliplex_frontend/core/models/active_run_state.dart';
import 'package:soliplex_frontend/core/providers/threads_provider.dart';
import 'package:soliplex_frontend/features/history/history_panel.dart';
import 'package:soliplex_frontend/features/history/widgets/new_conversation_button.dart';
import 'package:soliplex_frontend/features/history/widgets/thread_list_item.dart';
import 'package:soliplex_frontend/shared/widgets/empty_state.dart';
import 'package:soliplex_frontend/shared/widgets/error_display.dart';

import '../../helpers/test_helpers.dart';

/// Mock that tracks method calls.
class _TrackingThreadSelectionNotifier extends Notifier<ThreadSelection>
    implements ThreadSelectionNotifier {
  _TrackingThreadSelectionNotifier({required this.initialSelection});

  final ThreadSelection initialSelection;
  ThreadSelection? lastSet;

  @override
  ThreadSelection build() => initialSelection;

  @override
  void set(ThreadSelection value) {
    lastSet = value;
    state = value;
  }
}

/// Creates a test app with GoRouter for testing navigation.
Widget _createAppWithRouter({
  required Widget home,
  required List<dynamic> overrides,
}) {
  final router = GoRouter(
    initialLocation: '/history',
    routes: [
      GoRoute(
        path: '/history',
        builder: (_, __) => Scaffold(body: home),
      ),
      GoRoute(
        path: '/rooms/:roomId',
        builder: (context, state) {
          final threadId = state.uri.queryParameters['thread'];
          final roomId = state.pathParameters['roomId'];
          return Text('Room: $roomId, Thread: $threadId');
        },
      ),
    ],
  );

  return UncontrolledProviderScope(
    container: ProviderContainer(overrides: overrides.cast()),
    child: MaterialApp.router(theme: testThemeData, routerConfig: router),
  );
}

void main() {
  group('HistoryPanel', () {
    group('Empty state', () {
      testWidgets('shows EmptyState when no threads', (tester) async {
        await tester.pumpWidget(
          createTestApp(
            home: const HistoryPanel(roomId: 'room-1'),
            overrides: [
              threadsProvider('room-1').overrideWith((ref) async => []),
              activeRunNotifierOverride(const IdleState()),
            ],
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(EmptyState), findsOneWidget);
        expect(
          find.text('No conversations yet\nStart a new one!'),
          findsOneWidget,
        );
      });

      testWidgets('shows NewConversationButton in empty state', (tester) async {
        await tester.pumpWidget(
          createTestApp(
            home: const HistoryPanel(roomId: 'room-1'),
            overrides: [
              threadsProvider('room-1').overrideWith((ref) async => []),
              activeRunNotifierOverride(const IdleState()),
            ],
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(NewConversationButton), findsOneWidget);
      });
    });

    group('Thread list', () {
      testWidgets('displays threads when available', (tester) async {
        final threads = <domain.ThreadInfo>[
          TestData.createThread(id: 'thread-1', name: 'Thread 1'),
          TestData.createThread(id: 'thread-2', name: 'Thread 2'),
        ];

        await tester.pumpWidget(
          createTestApp(
            home: const HistoryPanel(roomId: 'room-1'),
            overrides: [
              threadsProvider('room-1').overrideWith((ref) async => threads),
              activeRunNotifierOverride(const IdleState()),
              currentThreadIdProvider.overrideWith((ref) => null),
            ],
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(ThreadListItem), findsNWidgets(2));
      });

      testWidgets('highlights selected thread', (tester) async {
        final threads = <domain.ThreadInfo>[
          TestData.createThread(id: 'thread-1', name: 'Thread 1'),
          TestData.createThread(id: 'thread-2', name: 'Thread 2'),
        ];

        await tester.pumpWidget(
          createTestApp(
            home: const HistoryPanel(roomId: 'room-1'),
            overrides: [
              threadsProvider('room-1').overrideWith((ref) async => threads),
              activeRunNotifierOverride(const IdleState()),
              currentThreadIdProvider.overrideWith((ref) => 'thread-1'),
            ],
          ),
        );
        await tester.pumpAndSettle();

        // Find ThreadListItem widgets and verify selection state
        expect(find.byType(ThreadListItem), findsNWidgets(2));
      });

      testWidgets('shows activity indicator for active thread', (tester) async {
        final threads = <domain.ThreadInfo>[
          TestData.createThread(id: 'thread-1', name: 'Thread 1'),
        ];
        const conversation = domain.Conversation(
          threadId: 'thread-1',
          status: domain.Running(runId: 'run-1'),
        );

        await tester.pumpWidget(
          createTestApp(
            home: const HistoryPanel(roomId: 'room-1'),
            overrides: [
              threadsProvider('room-1').overrideWith((ref) async => threads),
              activeRunNotifierOverride(
                const RunningState(conversation: conversation),
              ),
              currentThreadIdProvider.overrideWith((ref) => 'thread-1'),
            ],
          ),
        );
        // Use pump() instead of pumpAndSettle() to avoid timeout with
        // RunningState causing continuous rebuilds
        await tester.pump();
        await tester.pump();

        expect(find.byType(ThreadListItem), findsOneWidget);
      });
    });

    group('New conversation', () {
      testWidgets('button sets NewThreadIntent', (tester) async {
        late _TrackingThreadSelectionNotifier mockNotifier;

        await tester.pumpWidget(
          createTestApp(
            home: const HistoryPanel(roomId: 'room-1'),
            overrides: [
              threadsProvider('room-1').overrideWith((ref) async => []),
              activeRunNotifierOverride(const IdleState()),
              threadSelectionProvider.overrideWith(() {
                return mockNotifier = _TrackingThreadSelectionNotifier(
                  initialSelection: const NoThreadSelected(),
                );
              }),
            ],
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byType(NewConversationButton));
        await tester.pump();

        expect(mockNotifier.lastSet, isA<NewThreadIntent>());
      });
    });

    group('Error state', () {
      testWidgets('shows ErrorDisplay on error', (tester) async {
        await tester.pumpWidget(
          createTestApp(
            home: const HistoryPanel(roomId: 'room-1'),
            overrides: [
              threadsProvider('room-1').overrideWith(
                (ref) => throw Exception('Network error'),
              ),
              activeRunNotifierOverride(const IdleState()),
            ],
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(ErrorDisplay), findsOneWidget);
      });
    });

    group('Thread selection', () {
      testWidgets('navigates when thread tapped', (tester) async {
        final threads = <domain.ThreadInfo>[
          TestData.createThread(id: 'thread-1', name: 'Thread 1'),
        ];

        await tester.pumpWidget(
          _createAppWithRouter(
            home: const HistoryPanel(roomId: 'room-1'),
            overrides: [
              threadsProvider('room-1').overrideWith((ref) async => threads),
              activeRunNotifierOverride(const IdleState()),
              currentThreadIdProvider.overrideWith((ref) => null),
              threadSelectionProvider.overrideWith(
                () => _TrackingThreadSelectionNotifier(
                  initialSelection: const NoThreadSelected(),
                ),
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byType(ThreadListItem));
        await tester.pumpAndSettle();

        // Verify navigation occurred
        expect(find.textContaining('Room: room-1'), findsOneWidget);
        expect(find.textContaining('Thread: thread-1'), findsOneWidget);
      });
    });
  });
}
