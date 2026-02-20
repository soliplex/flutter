import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
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
}
