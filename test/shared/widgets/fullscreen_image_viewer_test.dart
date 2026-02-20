import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soliplex_frontend/shared/widgets/fullscreen_image_viewer.dart';

import '../../helpers/test_helpers.dart';

void main() {
  group('FullscreenImageViewer', () {
    testWidgets('wraps image in InteractiveViewer for zoom/pan', (
      tester,
    ) async {
      await tester.pumpWidget(
        createTestApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const FullscreenImageViewer(
                    imageUrl: 'https://example.com/photo.png',
                  ),
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.byType(InteractiveViewer), findsOneWidget);
    });

    testWidgets('close button pops the route', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const FullscreenImageViewer(
                    imageUrl: 'https://example.com/photo.png',
                  ),
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();

      // Back on the original page
      expect(find.text('Open'), findsOneWidget);
      expect(find.byType(FullscreenImageViewer), findsNothing);
    });

    testWidgets('shows error state when image fails to load', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const FullscreenImageViewer(
                    imageUrl: 'https://broken.example.com/missing.png',
                  ),
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Network images fail in test environment, triggering the error state
      expect(find.byIcon(Icons.broken_image), findsOneWidget);
    });

    testWidgets('displays alt text when provided', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const FullscreenImageViewer(
                    imageUrl: 'https://example.com/photo.png',
                    altText: 'A beautiful sunset',
                  ),
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('A beautiful sunset'), findsOneWidget);
    });

    testWidgets('rotate button rotates image by 90 degrees', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const FullscreenImageViewer(
                    imageUrl: 'https://example.com/photo.png',
                  ),
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      );

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
      await tester.pumpWidget(
        createTestApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const FullscreenImageViewer(
                    imageUrl: 'https://example.com/photo.png',
                  ),
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).last);
      expect(scaffold.backgroundColor, Colors.black);
    });
  });
}
