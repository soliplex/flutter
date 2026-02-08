import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soliplex_frontend/features/log_viewer/widgets/log_level_badge.dart';
import 'package:soliplex_logging/soliplex_logging.dart';

import '../../../helpers/test_helpers.dart';

void main() {
  group('LogLevelBadge', () {
    for (final level in LogLevel.values) {
      testWidgets('renders label for ${level.name}', (tester) async {
        await tester.pumpWidget(
          createTestApp(home: LogLevelBadge(level: level)),
        );

        expect(find.text(level.label), findsOneWidget);
      });
    }

    testWidgets('renders different text for error vs info', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          home: const Column(
            children: [
              LogLevelBadge(level: LogLevel.error),
              LogLevelBadge(level: LogLevel.info),
            ],
          ),
        ),
      );

      expect(find.text('ERROR'), findsOneWidget);
      expect(find.text('INFO'), findsOneWidget);
    });
  });
}
