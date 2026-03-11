import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soliplex_frontend/shared/widgets/fullscreen_image_viewer.dart';

import '../../helpers/test_helpers.dart';

void main() {
  group('FullscreenImageViewer', () {
    Widget buildViewer({String? caption}) {
      return createTestApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => FullscreenImageViewer(
                  caption: caption,
                  child: const Icon(Icons.image, size: 100),
                ),
              ),
            ),
            child: const Text('Open'),
          ),
        ),
      );
    }

    testWidgets('wraps child in InteractiveViewer for zoom/pan', (
      tester,
    ) async {
      await tester.pumpWidget(buildViewer());

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.byType(InteractiveViewer), findsOneWidget);
    });

    testWidgets('close button pops the route', (tester) async {
      await tester.pumpWidget(buildViewer());

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();

      // Back on the original page
      expect(find.text('Open'), findsOneWidget);
      expect(find.byType(FullscreenImageViewer), findsNothing);
    });

    testWidgets('displays caption when provided', (tester) async {
      await tester.pumpWidget(
        buildViewer(caption: 'A beautiful sunset'),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('A beautiful sunset'), findsOneWidget);
    });

    testWidgets('rotate button rotates by 90 degrees', (tester) async {
      await tester.pumpWidget(buildViewer());

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Initially no rotation
      var rotated = tester.widget<RotatedBox>(find.byType(RotatedBox));
      expect(rotated.quarterTurns, 0);

      // Tap rotate button
      await tester.tap(find.byTooltip('Rotate'));
      await tester.pumpAndSettle();

      // After one tap, rotated 90 degrees
      rotated = tester.widget<RotatedBox>(find.byType(RotatedBox));
      expect(rotated.quarterTurns, 1);
    });

    testWidgets('has dark background for image viewing', (tester) async {
      await tester.pumpWidget(buildViewer());

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).last);
      expect(scaffold.backgroundColor, Colors.black);
    });
  });
}
