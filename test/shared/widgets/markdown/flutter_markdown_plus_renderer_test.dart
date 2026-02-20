import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soliplex_frontend/shared/widgets/markdown/flutter_markdown_plus_renderer.dart';
import 'package:soliplex_frontend/shared/widgets/markdown/markdown_renderer.dart';
import 'package:soliplex_frontend/shared/widgets/markdown/markdown_theme_extension.dart';

import '../../../helpers/test_helpers.dart';

void main() {
  group('FlutterMarkdownPlusRenderer', () {
    testWidgets('is a MarkdownRenderer', (tester) async {
      const renderer = FlutterMarkdownPlusRenderer(data: 'hello');

      expect(renderer, isA<MarkdownRenderer>());
    });

    testWidgets('renders markdown text', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          home: const FlutterMarkdownPlusRenderer(
            data: 'Hello **world**',
          ),
        ),
      );

      expect(find.byType(MarkdownBody), findsOneWidget);
    });

    testWidgets('passes data to MarkdownBody', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          home: const FlutterMarkdownPlusRenderer(
            data: 'Simple text',
          ),
        ),
      );

      final markdownBody = tester.widget<MarkdownBody>(
        find.byType(MarkdownBody),
      );
      expect(markdownBody.data, 'Simple text');
    });

    testWidgets('renders code blocks with syntax highlighting', (
      tester,
    ) async {
      await tester.pumpWidget(
        createTestApp(
          home: const FlutterMarkdownPlusRenderer(
            data: '```dart\nvoid main() {}\n```',
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byType(MarkdownBody), findsOneWidget);
    });

    testWidgets('sanitizes <br> tags to newlines', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          home: const FlutterMarkdownPlusRenderer(
            data: 'line one<br>line two',
          ),
        ),
      );

      final body = tester.widget<MarkdownBody>(find.byType(MarkdownBody));
      expect(body.data, 'line one\nline two');
    });

    testWidgets('sanitizes <br /> tags to newlines', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          home: const FlutterMarkdownPlusRenderer(
            data: 'line one<br />line two',
          ),
        ),
      );

      final body = tester.widget<MarkdownBody>(find.byType(MarkdownBody));
      expect(body.data, 'line one\nline two');
    });

    testWidgets('sanitizes <br/> tags to newlines', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          home: const FlutterMarkdownPlusRenderer(
            data: 'line one<br/>line two',
          ),
        ),
      );

      final body = tester.widget<MarkdownBody>(find.byType(MarkdownBody));
      expect(body.data, 'line one\nline two');
    });

    testWidgets('passes through content without HTML unchanged', (
      tester,
    ) async {
      await tester.pumpWidget(
        createTestApp(
          home: const FlutterMarkdownPlusRenderer(
            data: 'no html here',
          ),
        ),
      );

      final body = tester.widget<MarkdownBody>(find.byType(MarkdownBody));
      expect(body.data, 'no html here');
    });

    testWidgets('wires onLinkTap to MarkdownBody.onTapLink', (
      tester,
    ) async {
      String? tappedHref;
      String? tappedTitle;

      await tester.pumpWidget(
        createTestApp(
          home: FlutterMarkdownPlusRenderer(
            data: '[example](https://example.com)',
            onLinkTap: (href, title) {
              tappedHref = href;
              tappedTitle = title;
            },
          ),
        ),
      );

      final body = tester.widget<MarkdownBody>(find.byType(MarkdownBody));
      expect(body.onTapLink, isNotNull);

      // Simulate the package callback to verify bridging
      body.onTapLink!('example', 'https://example.com', '');
      expect(tappedHref, 'https://example.com');
      expect(tappedTitle, '');
    });

    testWidgets('does not set onTapLink when onLinkTap is null', (
      tester,
    ) async {
      await tester.pumpWidget(
        createTestApp(
          home: const FlutterMarkdownPlusRenderer(
            data: '[example](https://example.com)',
          ),
        ),
      );

      final body = tester.widget<MarkdownBody>(find.byType(MarkdownBody));
      expect(body.onTapLink, isNull);
    });

    testWidgets('onLinkTap ignores links with null href', (tester) async {
      String? tappedHref;

      await tester.pumpWidget(
        createTestApp(
          home: FlutterMarkdownPlusRenderer(
            data: '[example](https://example.com)',
            onLinkTap: (href, title) {
              tappedHref = href;
            },
          ),
        ),
      );

      final body = tester.widget<MarkdownBody>(find.byType(MarkdownBody));

      // Simulate the package calling with null href
      body.onTapLink!('example', null, '');
      expect(tappedHref, isNull);
    });

    testWidgets('sets imageBuilder on MarkdownBody when onImageTap is provided',
        (tester) async {
      await tester.pumpWidget(
        createTestApp(
          home: FlutterMarkdownPlusRenderer(
            data: '![alt](https://example.com/img.png)',
            onImageTap: (_, __) {},
          ),
        ),
      );

      final body = tester.widget<MarkdownBody>(find.byType(MarkdownBody));
      expect(body.imageBuilder, isNotNull);
    });

    testWidgets('does not set imageBuilder when onImageTap is null', (
      tester,
    ) async {
      await tester.pumpWidget(
        createTestApp(
          home: const FlutterMarkdownPlusRenderer(
            data: '![alt](https://example.com/img.png)',
          ),
        ),
      );

      final body = tester.widget<MarkdownBody>(find.byType(MarkdownBody));
      expect(body.imageBuilder, isNull);
    });

    testWidgets('imageBuilder constrains image size', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          home: FlutterMarkdownPlusRenderer(
            data: '![photo](https://example.com/img.png)',
            onImageTap: (_, __) {},
          ),
        ),
      );

      final body = tester.widget<MarkdownBody>(find.byType(MarkdownBody));
      final widget = body.imageBuilder!(
        Uri.parse('https://example.com/img.png'),
        null,
        'photo',
      );

      // Build the widget tree to inspect constraints
      await tester.pumpWidget(createTestApp(home: widget));

      final finder = find.descendant(
        of: find.byType(GestureDetector),
        matching: find.byType(ConstrainedBox),
      );
      final box = tester.widget<ConstrainedBox>(finder);
      expect(box.constraints.maxHeight, 400);
    });

    testWidgets('imageBuilder forwards tap to onImageTap', (tester) async {
      String? tappedSrc;
      String? tappedAlt;

      await tester.pumpWidget(
        createTestApp(
          home: FlutterMarkdownPlusRenderer(
            data: '![photo](https://example.com/img.png)',
            onImageTap: (src, alt) {
              tappedSrc = src;
              tappedAlt = alt;
            },
          ),
        ),
      );

      final body = tester.widget<MarkdownBody>(find.byType(MarkdownBody));
      final widget = body.imageBuilder!(
        Uri.parse('https://example.com/img.png'),
        null,
        'photo',
      );

      await tester.pumpWidget(createTestApp(home: widget));

      // Invoke onTap directly — network images don't load in test env so
      // the widget may have zero size and fail hit testing.
      final detector = tester.widget<GestureDetector>(
        find.byType(GestureDetector).first,
      );
      detector.onTap!();
      expect(tappedSrc, 'https://example.com/img.png');
      expect(tappedAlt, 'photo');
    });

    testWidgets('uses styles from MarkdownThemeExtension', (
      tester,
    ) async {
      final theme = testThemeData.copyWith(
        extensions: [
          ...testThemeData.extensions.values,
          const MarkdownThemeExtension(
            code: TextStyle(backgroundColor: Colors.red),
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: const Scaffold(
            body: FlutterMarkdownPlusRenderer(data: 'Hello'),
          ),
        ),
      );

      final body = tester.widget<MarkdownBody>(
        find.byType(MarkdownBody),
      );
      expect(body.styleSheet?.code?.backgroundColor, Colors.red);
    });
  });
}
