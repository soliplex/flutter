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
