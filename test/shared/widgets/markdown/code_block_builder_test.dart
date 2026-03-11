import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soliplex_frontend/shared/widgets/fullscreen_image_viewer.dart';
import 'package:soliplex_frontend/shared/widgets/markdown/flutter_markdown_plus_renderer.dart';

import '../../../helpers/test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (message) async {
      if (message.method == 'Clipboard.setData') {
        return null;
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  group('inline code', () {
    testWidgets('does not render copy button for inline code', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          home: const FlutterMarkdownPlusRenderer(
            data: 'Use the `foo` command',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.copy), findsNothing);
    });

    // Tests visual styling — intentionally coupled to InlineCodeBuilder's
    // widget structure (DecoratedBox with color + borderRadius). Will need
    // updating if the builder's widget tree changes.
    testWidgets('wraps inline code in a decorated container', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          home: const FlutterMarkdownPlusRenderer(
            data: 'Use the `foo` command',
          ),
        ),
      );
      await tester.pumpAndSettle();

      final decoratedBoxes = find.ancestor(
        of: find.text('foo'),
        matching: find.byType(DecoratedBox),
      );

      final hasCodePill = decoratedBoxes.evaluate().any((element) {
        final box = element.widget as DecoratedBox;
        final decoration = box.decoration;
        return decoration is BoxDecoration &&
            decoration.color != null &&
            decoration.borderRadius != null;
      });
      expect(hasCodePill, isTrue);
    });
  });

  group('CodeBlockBuilder', () {
    testWidgets('renders copy button on code blocks', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          home: const FlutterMarkdownPlusRenderer(
            data: '```\nsome code\n```',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.copy), findsOneWidget);
    });

    testWidgets('shows language label when language is detected', (
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

      expect(find.text('dart'), findsOneWidget);
    });

    testWidgets('does not show language label for plaintext', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          home: const FlutterMarkdownPlusRenderer(
            data: '```\nsome code\n```',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('plaintext'), findsNothing);
    });

    testWidgets('copies code to clipboard on tap', (tester) async {
      String? copiedText;

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (message) async {
        if (message.method == 'Clipboard.setData') {
          final args = message.arguments as Map;
          copiedText = args['text'] as String?;
        }
        return null;
      });

      await tester.pumpWidget(
        createTestApp(
          home: const FlutterMarkdownPlusRenderer(
            data: '```\nhello world\n```',
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.copy));
      await tester.pump();

      expect(copiedText, contains('hello world'));
    });

    testWidgets('shows snackbar after copying', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          home: const FlutterMarkdownPlusRenderer(
            data: '```\ncode\n```',
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.copy));
      await tester.pump();
      await tester.pump();

      expect(find.text('Copied to clipboard'), findsOneWidget);
    });
  });

  group('SVG code block', () {
    const validSvg = '```svg\n'
        '<svg xmlns="http://www.w3.org/2000/svg" width="100" height="100">\n'
        '<circle cx="50" cy="50" r="40" fill="red"/>\n'
        '</svg>\n'
        '```';

    testWidgets('renders SVG preview', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          home: const FlutterMarkdownPlusRenderer(data: validSvg),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SvgPicture), findsOneWidget);
    });

    testWidgets('shows "svg" language label', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          home: const FlutterMarkdownPlusRenderer(data: validSvg),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('svg'), findsOneWidget);
    });

    testWidgets('has copy and toggle buttons', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          home: const FlutterMarkdownPlusRenderer(data: validSvg),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.copy), findsOneWidget);
      expect(find.byIcon(Icons.code), findsOneWidget);
    });

    testWidgets('copies SVG source to clipboard', (tester) async {
      String? copiedText;

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (message) async {
        if (message.method == 'Clipboard.setData') {
          final args = message.arguments as Map;
          copiedText = args['text'] as String?;
        }
        return null;
      });

      await tester.pumpWidget(
        createTestApp(
          home: const FlutterMarkdownPlusRenderer(data: validSvg),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.copy));
      await tester.pump();

      expect(copiedText, contains('<svg'));
    });

    testWidgets('toggles to source view', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          home: const FlutterMarkdownPlusRenderer(data: validSvg),
        ),
      );
      await tester.pumpAndSettle();

      // Initially shows preview, not source.
      expect(find.byType(SvgPicture), findsOneWidget);
      expect(find.byType(HighlightView), findsNothing);

      // Tap the toggle button (Icons.code in preview mode).
      await tester.tap(find.byIcon(Icons.code));
      await tester.pumpAndSettle();

      // Now shows source, not preview.
      expect(find.byType(SvgPicture), findsNothing);
      expect(find.byType(HighlightView), findsOneWidget);
    });

    testWidgets('shows broken image for malformed SVG', (tester) async {
      const malformedSvg = '```svg\nnot valid svg at all\n```';

      await tester.pumpWidget(
        createTestApp(
          home: const FlutterMarkdownPlusRenderer(
            data: malformedSvg,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.broken_image), findsOneWidget);
    });

    testWidgets('has accessibility semantics', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          home: const FlutterMarkdownPlusRenderer(data: validSvg),
        ),
      );
      await tester.pumpAndSettle();

      final semantics = find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.label == 'SVG image',
      );
      expect(semantics, findsOneWidget);
    });

    testWidgets('tapping preview opens fullscreen viewer', (
      tester,
    ) async {
      await tester.pumpWidget(
        createTestApp(
          home: const FlutterMarkdownPlusRenderer(data: validSvg),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(SvgPicture));
      await tester.pumpAndSettle();

      expect(find.byType(FullscreenImageViewer), findsOneWidget);
    });
  });
}
