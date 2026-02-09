import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soliplex_frontend/core/logging/logging_provider.dart';
import 'package:soliplex_frontend/core/providers/shell_config_provider.dart';
import 'package:soliplex_frontend/design/theme/theme.dart';
import 'package:soliplex_frontend/features/log_viewer/log_viewer_screen.dart';
import 'package:soliplex_frontend/features/log_viewer/widgets/log_level_badge.dart';
import 'package:soliplex_frontend/features/log_viewer/widgets/log_record_tile.dart';
import 'package:soliplex_logging/soliplex_logging.dart';

import '../../helpers/test_helpers.dart';

/// Duration that exceeds the flush timer so pending records reach the UI.
const _flushDuration = Duration(milliseconds: 150);

LogRecord _makeRecord({
  LogLevel level = LogLevel.info,
  String message = 'Test message',
  String loggerName = 'Test',
  DateTime? timestamp,
  Object? error,
  StackTrace? stackTrace,
}) {
  return LogRecord(
    level: level,
    message: message,
    loggerName: loggerName,
    timestamp: timestamp ?? DateTime(2024, 1, 15, 10, 30, 45, 123),
    error: error,
    stackTrace: stackTrace,
  );
}

Widget _buildScreen({required MemorySink sink}) {
  return ProviderScope(
    overrides: [
      memorySinkProvider.overrideWithValue(sink),
      shellConfigProvider.overrideWithValue(testSoliplexConfig),
    ],
    child: MaterialApp(
      theme: soliplexLightTheme(),
      home: const LogViewerScreen(),
    ),
  );
}

void main() {
  group('LogViewerScreen', () {
    group('Empty state', () {
      testWidgets('shows empty message when no logs', (tester) async {
        final sink = MemorySink();
        await tester.pumpWidget(_buildScreen(sink: sink));

        expect(find.text('No log entries'), findsOneWidget);
        expect(
          find.text('Log entries will appear here as you use the app'),
          findsOneWidget,
        );
      });

      testWidgets('clear button is disabled when empty', (tester) async {
        final sink = MemorySink();
        await tester.pumpWidget(_buildScreen(sink: sink));

        final clearButton = tester.widget<IconButton>(
          find.ancestor(
            of: find.byIcon(Icons.delete_outline),
            matching: find.byType(IconButton),
          ),
        );
        expect(clearButton.onPressed, isNull);
      });

      testWidgets('shows Logs (0) in title', (tester) async {
        final sink = MemorySink();
        await tester.pumpWidget(_buildScreen(sink: sink));

        expect(find.text('Logs (0)'), findsOneWidget);
      });
    });

    group('With records', () {
      testWidgets('displays log record tiles', (tester) async {
        final sink = MemorySink()
          ..write(_makeRecord(message: 'First'))
          ..write(_makeRecord(message: 'Second'));

        await tester.pumpWidget(_buildScreen(sink: sink));

        expect(find.byType(LogRecordTile), findsNWidgets(2));
      });

      testWidgets('shows count in title', (tester) async {
        final sink = MemorySink()
          ..write(_makeRecord(message: 'One'))
          ..write(_makeRecord(message: 'Two'))
          ..write(_makeRecord(message: 'Three'));

        await tester.pumpWidget(_buildScreen(sink: sink));

        expect(find.text('Logs (3)'), findsOneWidget);
      });

      testWidgets('shows newest record first in the list', (tester) async {
        final sink = MemorySink()
          ..write(
            _makeRecord(
              message: 'Old message',
              timestamp: DateTime(2024, 1, 15, 10),
            ),
          )
          ..write(
            _makeRecord(
              message: 'New message',
              timestamp: DateTime(2024, 1, 15, 11),
            ),
          );

        await tester.pumpWidget(_buildScreen(sink: sink));

        // Both records are displayed.
        expect(find.text('Old message'), findsOneWidget);
        expect(find.text('New message'), findsOneWidget);

        // The first LogRecordTile on screen should be the newest record.
        final tiles = tester.widgetList<LogRecordTile>(
          find.byType(LogRecordTile),
        );
        expect(tiles.first.record.message, 'New message');
        expect(tiles.last.record.message, 'Old message');
      });

      testWidgets('newest record stays first after live update',
          (tester) async {
        final sink = MemorySink()
          ..write(
            _makeRecord(
              message: 'Initial',
              timestamp: DateTime(2024, 1, 15, 10),
            ),
          );

        await tester.pumpWidget(_buildScreen(sink: sink));

        // Write a newer record while the screen is open.
        sink.write(
          _makeRecord(
            message: 'Live update',
            timestamp: DateTime(2024, 1, 15, 11),
          ),
        );
        await tester.pump(_flushDuration);

        final tiles = tester.widgetList<LogRecordTile>(
          find.byType(LogRecordTile),
        );
        expect(tiles.first.record.message, 'Live update');
        expect(tiles.last.record.message, 'Initial');
      });

      testWidgets('ordering preserved after filter change', (tester) async {
        final sink = MemorySink()
          ..write(
            _makeRecord(
              message: 'Info old',
              timestamp: DateTime(2024, 1, 15, 9),
            ),
          )
          ..write(
            _makeRecord(
              level: LogLevel.error,
              message: 'Error',
              timestamp: DateTime(2024, 1, 15, 10),
            ),
          )
          ..write(
            _makeRecord(
              message: 'Info new',
              timestamp: DateTime(2024, 1, 15, 11),
            ),
          );

        await tester.pumpWidget(_buildScreen(sink: sink));

        // Filter to INFO only.
        await tester.tap(find.widgetWithText(FilterChip, 'INFO'));
        await tester.pump();

        final tiles = tester.widgetList<LogRecordTile>(
          find.byType(LogRecordTile),
        );
        expect(tiles.first.record.message, 'Info new');
        expect(tiles.last.record.message, 'Info old');
      });

      testWidgets('clear button is enabled with records', (tester) async {
        final sink = MemorySink()..write(_makeRecord());

        await tester.pumpWidget(_buildScreen(sink: sink));

        final clearButton = tester.widget<IconButton>(
          find.ancestor(
            of: find.byIcon(Icons.delete_outline),
            matching: find.byType(IconButton),
          ),
        );
        expect(clearButton.onPressed, isNotNull);
      });
    });

    group('Level filter', () {
      testWidgets('tapping level chip filters records', (tester) async {
        final sink = MemorySink()
          ..write(_makeRecord(message: 'Info msg'))
          ..write(_makeRecord(level: LogLevel.error, message: 'Error msg'));

        await tester.pumpWidget(_buildScreen(sink: sink));
        expect(find.byType(LogRecordTile), findsNWidgets(2));

        // Tap the ERROR chip
        await tester.tap(find.widgetWithText(FilterChip, 'ERROR'));
        await tester.pump();

        expect(find.byType(LogRecordTile), findsOneWidget);
        expect(find.text('Error msg'), findsOneWidget);
        expect(find.text('Info msg'), findsNothing);
      });

      testWidgets('multi-select level chips', (tester) async {
        final sink = MemorySink()
          ..write(_makeRecord(message: 'Info msg'))
          ..write(_makeRecord(level: LogLevel.error, message: 'Error msg'))
          ..write(_makeRecord(level: LogLevel.debug, message: 'Debug msg'));

        await tester.pumpWidget(_buildScreen(sink: sink));
        expect(find.byType(LogRecordTile), findsNWidgets(3));

        // Select ERROR and INFO
        await tester.tap(find.widgetWithText(FilterChip, 'ERROR'));
        await tester.pump();
        await tester.tap(find.widgetWithText(FilterChip, 'INFO'));
        await tester.pump();

        expect(find.byType(LogRecordTile), findsNWidgets(2));
        expect(find.text('Debug msg'), findsNothing);
      });

      testWidgets('deselecting chip removes filter', (tester) async {
        final sink = MemorySink()
          ..write(_makeRecord(message: 'Info msg'))
          ..write(_makeRecord(level: LogLevel.error, message: 'Error msg'));

        await tester.pumpWidget(_buildScreen(sink: sink));

        // Select then deselect ERROR
        await tester.tap(find.widgetWithText(FilterChip, 'ERROR'));
        await tester.pump();
        expect(find.byType(LogRecordTile), findsOneWidget);

        await tester.tap(find.widgetWithText(FilterChip, 'ERROR'));
        await tester.pump();
        expect(find.byType(LogRecordTile), findsNWidgets(2));
      });

      testWidgets('All chip clears level selection', (tester) async {
        final sink = MemorySink()
          ..write(_makeRecord(message: 'Info msg'))
          ..write(_makeRecord(level: LogLevel.error, message: 'Error msg'));

        await tester.pumpWidget(_buildScreen(sink: sink));

        // Select ERROR only
        await tester.tap(find.widgetWithText(FilterChip, 'ERROR'));
        await tester.pump();
        expect(find.byType(LogRecordTile), findsOneWidget);

        // Tap "All" to clear selection (first "All" chip = levels row)
        await tester.tap(find.widgetWithText(FilterChip, 'All').first);
        await tester.pump();
        expect(find.byType(LogRecordTile), findsNWidgets(2));
      });
    });

    group('Logger filter', () {
      testWidgets('HTTP is excluded by default', (tester) async {
        final sink = MemorySink()
          ..write(_makeRecord(loggerName: 'Auth', message: 'Auth msg'))
          ..write(_makeRecord(loggerName: 'HTTP', message: 'HTTP msg'));

        await tester.pumpWidget(_buildScreen(sink: sink));

        expect(find.byType(LogRecordTile), findsOneWidget);
        expect(find.text('Auth msg'), findsOneWidget);
        expect(find.text('HTTP msg'), findsNothing);
      });

      testWidgets('deselecting logger chip excludes it', (tester) async {
        final sink = MemorySink()
          ..write(_makeRecord(loggerName: 'Auth', message: 'Auth msg'))
          ..write(_makeRecord(loggerName: 'Chat', message: 'Chat msg'));

        await tester.pumpWidget(_buildScreen(sink: sink));
        expect(find.byType(LogRecordTile), findsNWidgets(2));

        // Tap Auth chip to deselect (exclude) it
        await tester.tap(find.widgetWithText(FilterChip, 'Auth'));
        await tester.pump();

        expect(find.byType(LogRecordTile), findsOneWidget);
        expect(find.text('Chat msg'), findsOneWidget);
      });

      testWidgets('re-selecting excluded logger shows it again',
          (tester) async {
        final sink = MemorySink()
          ..write(_makeRecord(loggerName: 'Auth', message: 'Auth msg'))
          ..write(_makeRecord(loggerName: 'Chat', message: 'Chat msg'));

        await tester.pumpWidget(_buildScreen(sink: sink));

        // Exclude Auth
        await tester.tap(find.widgetWithText(FilterChip, 'Auth'));
        await tester.pump();
        expect(find.byType(LogRecordTile), findsOneWidget);

        // Re-include Auth
        await tester.tap(find.widgetWithText(FilterChip, 'Auth'));
        await tester.pump();
        expect(find.byType(LogRecordTile), findsNWidgets(2));
      });

      testWidgets('multi-select loggers works', (tester) async {
        final sink = MemorySink()
          ..write(_makeRecord(loggerName: 'Auth', message: 'Auth msg'))
          ..write(_makeRecord(loggerName: 'Chat', message: 'Chat msg'))
          ..write(_makeRecord(loggerName: 'Room', message: 'Room msg'));

        await tester.pumpWidget(_buildScreen(sink: sink));
        expect(find.byType(LogRecordTile), findsNWidgets(3));

        // Exclude Auth and Chat
        await tester.tap(find.widgetWithText(FilterChip, 'Auth'));
        await tester.pump();
        await tester.tap(find.widgetWithText(FilterChip, 'Chat'));
        await tester.pump();

        expect(find.byType(LogRecordTile), findsOneWidget);
        expect(find.text('Room msg'), findsOneWidget);
      });

      testWidgets('All chip on loggers re-includes everything', (tester) async {
        final sink = MemorySink()
          ..write(_makeRecord(loggerName: 'Auth', message: 'Auth msg'))
          ..write(_makeRecord(loggerName: 'HTTP', message: 'HTTP msg'));

        await tester.pumpWidget(_buildScreen(sink: sink));
        // HTTP excluded by default
        expect(find.byType(LogRecordTile), findsOneWidget);

        // Find the logger row's "All" chip (second one, after levels "All")
        final allChips = find.widgetWithText(FilterChip, 'All');
        // Tap the second "All" (logger row)
        await tester.tap(allChips.last);
        await tester.pump();

        expect(find.byType(LogRecordTile), findsNWidgets(2));
      });
    });

    group('Search', () {
      testWidgets('search filters by message text', (tester) async {
        final sink = MemorySink()
          ..write(_makeRecord(message: 'User logged in'))
          ..write(_makeRecord(message: 'HTTP request'));

        await tester.pumpWidget(_buildScreen(sink: sink));
        expect(find.byType(LogRecordTile), findsNWidgets(2));

        await tester.enterText(find.byType(TextField), 'logged');
        await tester.pump();

        expect(find.byType(LogRecordTile), findsOneWidget);
        expect(find.text('User logged in'), findsOneWidget);
      });

      testWidgets('search is case-insensitive', (tester) async {
        final sink = MemorySink()
          ..write(_makeRecord(message: 'User Logged In'));

        await tester.pumpWidget(_buildScreen(sink: sink));

        await tester.enterText(find.byType(TextField), 'user logged');
        await tester.pump();

        expect(find.byType(LogRecordTile), findsOneWidget);
      });
    });

    group('Live updates', () {
      testWidgets('new record appears after flush timer', (tester) async {
        final sink = MemorySink();
        await tester.pumpWidget(_buildScreen(sink: sink));
        expect(find.byType(LogRecordTile), findsNothing);

        sink.write(_makeRecord(message: 'Live update'));
        // Advance past the flush interval so batched records reach the UI.
        await tester.pump(_flushDuration);

        expect(find.byType(LogRecordTile), findsOneWidget);
        expect(find.text('Live update'), findsOneWidget);
      });

      testWidgets('filtered record does not appear after flush',
          (tester) async {
        final sink = MemorySink();
        await tester.pumpWidget(_buildScreen(sink: sink));

        // Set filter to ERROR only
        await tester.tap(find.widgetWithText(FilterChip, 'ERROR'));
        await tester.pump();

        // Write an INFO record (should be filtered out even after flush)
        sink.write(_makeRecord(message: 'Filtered'));
        await tester.pump(_flushDuration);

        expect(find.text('Filtered'), findsNothing);
      });

      testWidgets('burst of records batched into single rebuild',
          (tester) async {
        final sink = MemorySink();
        await tester.pumpWidget(_buildScreen(sink: sink));

        // Write multiple records rapidly (simulating a log burst)
        for (var i = 0; i < 50; i++) {
          sink.write(_makeRecord(message: 'Burst $i'));
        }
        // Single flush processes all 50
        await tester.pump(_flushDuration);

        // Use title count since ListView only renders visible items.
        expect(find.text('Logs (50)'), findsOneWidget);
      });
    });

    group('Clear', () {
      testWidgets('tap clear empties list', (tester) async {
        final sink = MemorySink()
          ..write(_makeRecord(message: 'First'))
          ..write(_makeRecord(message: 'Second'));

        await tester.pumpWidget(_buildScreen(sink: sink));
        expect(find.byType(LogRecordTile), findsNWidgets(2));

        await tester.tap(find.byIcon(Icons.delete_outline));
        await tester.pump();

        expect(find.byType(LogRecordTile), findsNothing);
        expect(find.text('No log entries'), findsOneWidget);
      });
    });

    group('Expandable error/stackTrace', () {
      testWidgets('record with error has ExpansionTile', (tester) async {
        final sink = MemorySink()
          ..write(
            _makeRecord(
              message: 'Failed',
              error: Exception('test error'),
              stackTrace: StackTrace.current,
            ),
          );

        await tester.pumpWidget(_buildScreen(sink: sink));

        expect(find.byType(ExpansionTile), findsOneWidget);
      });

      testWidgets('expanding shows error details', (tester) async {
        final sink = MemorySink()
          ..write(
            _makeRecord(message: 'Failed', error: Exception('test error')),
          );

        await tester.pumpWidget(_buildScreen(sink: sink));

        // Error text is hidden initially
        expect(find.text('Error'), findsNothing);

        // Tap to expand
        await tester.tap(find.byType(ExpansionTile));
        await tester.pumpAndSettle();

        expect(find.text('Error'), findsOneWidget);
        expect(find.textContaining('test error'), findsAtLeast(1));
      });

      testWidgets('record without error has no ExpansionTile', (tester) async {
        final sink = MemorySink()..write(_makeRecord(message: 'Normal'));

        await tester.pumpWidget(_buildScreen(sink: sink));

        expect(find.byType(ExpansionTile), findsNothing);
      });
    });

    group('Combined filters', () {
      testWidgets('level + logger exclusion + search filters together',
          (tester) async {
        final sink = MemorySink()
          ..write(
            _makeRecord(
              level: LogLevel.error,
              loggerName: 'Auth',
              message: 'Auth failed',
            ),
          )
          ..write(
            _makeRecord(
              level: LogLevel.error,
              loggerName: 'Chat',
              message: 'Chat failed',
            ),
          )
          ..write(
            _makeRecord(loggerName: 'Auth', message: 'Auth success'),
          )
          ..write(
            _makeRecord(
              level: LogLevel.error,
              loggerName: 'Auth',
              message: 'Auth timeout',
            ),
          );

        await tester.pumpWidget(_buildScreen(sink: sink));
        // All 4 visible (none are HTTP)
        expect(find.byType(LogRecordTile), findsNWidgets(4));

        // Filter to ERROR level
        await tester.tap(find.widgetWithText(FilterChip, 'ERROR'));
        await tester.pump();
        expect(find.byType(LogRecordTile), findsNWidgets(3));

        // Exclude Chat logger
        await tester.tap(find.widgetWithText(FilterChip, 'Chat'));
        await tester.pump();
        expect(find.byType(LogRecordTile), findsNWidgets(2));

        // Search for "failed"
        await tester.enterText(find.byType(TextField), 'failed');
        await tester.pump();
        expect(find.byType(LogRecordTile), findsOneWidget);
        expect(find.text('Auth failed'), findsOneWidget);
      });
    });

    group('LogRecordTile', () {
      testWidgets('shows timestamp formatted as HH:mm:ss.SSS', (tester) async {
        final sink = MemorySink()
          ..write(
            _makeRecord(timestamp: DateTime(2024, 1, 15, 10, 30, 45, 123)),
          );

        await tester.pumpWidget(_buildScreen(sink: sink));

        expect(find.text('10:30:45.123'), findsOneWidget);
      });

      testWidgets('shows logger name', (tester) async {
        final sink = MemorySink()..write(_makeRecord(loggerName: 'Auth'));

        await tester.pumpWidget(_buildScreen(sink: sink));

        expect(find.text('Auth'), findsAtLeast(1));
      });

      testWidgets('shows LogLevelBadge', (tester) async {
        final sink = MemorySink()..write(_makeRecord(level: LogLevel.warning));

        await tester.pumpWidget(_buildScreen(sink: sink));

        expect(find.byType(LogLevelBadge), findsOneWidget);
      });
    });

    group('Ring buffer resync', () {
      testWidgets('sheds stale records when sink wraps', (tester) async {
        // Small capacity so the ring buffer wraps quickly.
        final sink = MemorySink(maxRecords: 10);
        await tester.pumpWidget(_buildScreen(sink: sink));

        // Write 10 records to fill the buffer.
        for (var i = 0; i < 10; i++) {
          sink.write(_makeRecord(message: 'Msg $i'));
        }
        await tester.pump(_flushDuration);
        // Use title count since ListView only renders visible items.
        expect(find.text('Logs (10)'), findsOneWidget);

        // Write 5 more to trigger wrap (oldest 5 dropped from sink).
        for (var i = 10; i < 15; i++) {
          sink.write(_makeRecord(message: 'Msg $i'));
        }
        await tester.pump(_flushDuration);

        // After resync, the UI should only show the 10 records still in
        // the sink, not all 15 we ever wrote.
        expect(find.text('Logs (10)'), findsOneWidget);
      });

      testWidgets('prunes stale logger names after wrap', (tester) async {
        final sink = MemorySink(maxRecords: 5);

        // Write records from 'OldLogger' to fill the buffer.
        for (var i = 0; i < 5; i++) {
          sink.write(_makeRecord(loggerName: 'OldLogger', message: 'Old $i'));
        }

        await tester.pumpWidget(_buildScreen(sink: sink));
        // OldLogger chip should be visible.
        expect(find.widgetWithText(FilterChip, 'OldLogger'), findsOneWidget);

        // Overwrite entire buffer with records from 'NewLogger'.
        for (var i = 0; i < 6; i++) {
          sink.write(_makeRecord(loggerName: 'NewLogger', message: 'New $i'));
        }
        await tester.pump(_flushDuration);

        // OldLogger should be pruned, NewLogger should appear.
        expect(find.widgetWithText(FilterChip, 'OldLogger'), findsNothing);
        expect(find.widgetWithText(FilterChip, 'NewLogger'), findsOneWidget);
      });
    });
  });
}
