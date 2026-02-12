import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soliplex_frontend/shared/widgets/markdown/flutter_markdown_plus_renderer.dart';
import 'package:soliplex_frontend/shared/widgets/markdown/markdown_block_extension.dart';

import '../../../helpers/test_helpers.dart';

void main() {
  group('MarkdownBlockExtension', () {
    testWidgets('registered block renders custom widget', (tester) async {
      final extension = MarkdownBlockExtension(
        pattern: RegExp(r'^\[\[note:\s*(.+)\]\]$'),
        tag: 'note',
        builder: (content, attributes) => Container(
          key: const Key('custom-note'),
          child: Text('NOTE: $content'),
        ),
      );

      await tester.pumpWidget(
        createTestApp(
          home: FlutterMarkdownPlusRenderer(
            data: '[[note: This is important]]',
            blockExtensions: {'note': extension},
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byKey(const Key('custom-note')), findsOneWidget);
      expect(find.text('NOTE: This is important'), findsOneWidget);
    });

    testWidgets('multiple extensions work simultaneously', (tester) async {
      final noteExtension = MarkdownBlockExtension(
        pattern: RegExp(r'^\[\[note:\s*(.+)\]\]$'),
        tag: 'note',
        builder: (content, attributes) => Text(
          'NOTE: $content',
          key: const Key('note-widget'),
        ),
      );

      final warnExtension = MarkdownBlockExtension(
        pattern: RegExp(r'^\[\[warn:\s*(.+)\]\]$'),
        tag: 'warn',
        builder: (content, attributes) => Text(
          'WARN: $content',
          key: const Key('warn-widget'),
        ),
      );

      await tester.pumpWidget(
        createTestApp(
          home: FlutterMarkdownPlusRenderer(
            data: '[[note: Info here]]\n\n[[warn: Be careful]]',
            blockExtensions: {
              'note': noteExtension,
              'warn': warnExtension,
            },
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byKey(const Key('note-widget')), findsOneWidget);
      expect(find.byKey(const Key('warn-widget')), findsOneWidget);
    });

    testWidgets('passes matched content to builder', (tester) async {
      String? capturedContent;

      final extension = MarkdownBlockExtension(
        pattern: RegExp(r'^\[\[color:\s*(.+)\]\]$'),
        tag: 'color',
        builder: (content, attributes) {
          capturedContent = content;
          return Text('Color: $content');
        },
      );

      await tester.pumpWidget(
        createTestApp(
          home: FlutterMarkdownPlusRenderer(
            data: '[[color: red]]',
            blockExtensions: {'color': extension},
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(capturedContent, contains('red'));
    });

    testWidgets('multi-line block collects content between fences', (
      tester,
    ) async {
      String? capturedContent;

      final extension = MarkdownBlockExtension(
        pattern: RegExp(r'^```special\s*$'),
        endPattern: RegExp(r'^```\s*$'),
        tag: 'special',
        builder: (content, attributes) {
          capturedContent = content;
          return Text('SPECIAL: $content', key: const Key('special'));
        },
      );

      await tester.pumpWidget(
        createTestApp(
          home: FlutterMarkdownPlusRenderer(
            data: '```special\nline one\nline two\n```',
            blockExtensions: {'special': extension},
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byKey(const Key('special')), findsOneWidget);
      expect(capturedContent, 'line one\nline two');
    });

    testWidgets('single-line and multi-line extensions coexist', (
      tester,
    ) async {
      final singleLine = MarkdownBlockExtension(
        pattern: RegExp(r'^\[\[note:\s*(.+)\]\]$'),
        tag: 'note',
        builder: (content, attributes) => Text(
          'NOTE: $content',
          key: const Key('note-widget'),
        ),
      );

      final multiLine = MarkdownBlockExtension(
        pattern: RegExp(r'^```special\s*$'),
        endPattern: RegExp(r'^```\s*$'),
        tag: 'special',
        builder: (content, attributes) => Text(
          'SPECIAL: $content',
          key: const Key('special-widget'),
        ),
      );

      await tester.pumpWidget(
        createTestApp(
          home: FlutterMarkdownPlusRenderer(
            data: '[[note: Hello]]\n\n```special\nfoo\nbar\n```',
            blockExtensions: {
              'note': singleLine,
              'special': multiLine,
            },
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byKey(const Key('note-widget')), findsOneWidget);
      expect(find.byKey(const Key('special-widget')), findsOneWidget);
    });

    testWidgets('does not interfere with standard markdown', (tester) async {
      final extension = MarkdownBlockExtension(
        pattern: RegExp(r'^\[\[note:\s*(.+)\]\]$'),
        tag: 'note',
        builder: (content, attributes) => Text(
          'NOTE: $content',
          key: const Key('note-widget'),
        ),
      );

      await tester.pumpWidget(
        createTestApp(
          home: FlutterMarkdownPlusRenderer(
            data: '# Heading\n\n[[note: Important]]\n\nRegular text',
            blockExtensions: {'note': extension},
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byKey(const Key('note-widget')), findsOneWidget);
      expect(find.text('Heading'), findsOneWidget);
      expect(find.text('Regular text'), findsOneWidget);
    });
  });
}
