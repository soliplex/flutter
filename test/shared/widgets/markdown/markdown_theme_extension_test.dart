import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soliplex_frontend/shared/widgets/markdown/markdown_theme_extension.dart';

void main() {
  group('MarkdownThemeExtension', () {
    test('toMarkdownStyleSheet maps all fields', () {
      const h1 = TextStyle(fontSize: 32);
      const h2 = TextStyle(fontSize: 28);
      const h3 = TextStyle(fontSize: 24);
      const body = TextStyle(fontSize: 16);
      const code = TextStyle(fontFamily: 'monospace');
      const link = TextStyle(color: Colors.blue);
      final codeBlockDecoration = BoxDecoration(color: Colors.grey[200]);
      final blockquoteDecoration = BoxDecoration(color: Colors.grey[100]);

      final extension = MarkdownThemeExtension(
        h1: h1,
        h2: h2,
        h3: h3,
        body: body,
        code: code,
        link: link,
        codeBlockDecoration: codeBlockDecoration,
        blockquoteDecoration: blockquoteDecoration,
      );

      final styleSheet = extension.toMarkdownStyleSheet();

      expect(styleSheet.h1, h1);
      expect(styleSheet.h2, h2);
      expect(styleSheet.h3, h3);
      expect(styleSheet.p, body);
      expect(styleSheet.code, code);
      expect(styleSheet.a, link);
      expect(styleSheet.codeblockDecoration, codeBlockDecoration);
      expect(styleSheet.blockquoteDecoration, blockquoteDecoration);
    });

    test('copyWith overrides specified fields only', () {
      const original = MarkdownThemeExtension(
        body: TextStyle(fontSize: 16),
        code: TextStyle(fontFamily: 'monospace'),
        h1: TextStyle(fontSize: 32),
      );

      final modified = original.copyWith(
        body: const TextStyle(fontSize: 18),
      );

      expect(modified.body, const TextStyle(fontSize: 18));
      expect(modified.code, original.code);
      expect(modified.h1, original.h1);
      expect(modified.h2, isNull);
    });

    test('lerp interpolates TextStyle fields', () {
      const a = MarkdownThemeExtension(
        body: TextStyle(fontSize: 14),
      );
      const b = MarkdownThemeExtension(
        body: TextStyle(fontSize: 18),
      );

      final result = a.lerp(b, 0.5);

      expect(result.body?.fontSize, 16);
    });

    test('toMarkdownStyleSheet merges codeFontStyle with code', () {
      const ext = MarkdownThemeExtension(
        code: TextStyle(backgroundColor: Colors.grey),
      );
      const monoFont = TextStyle(
        fontFamily: 'SF Mono',
        fontFamilyFallback: ['monospace'],
      );

      final styleSheet = ext.toMarkdownStyleSheet(
        codeFontStyle: monoFont,
      );

      expect(styleSheet.code?.fontFamily, 'SF Mono');
      expect(styleSheet.code?.backgroundColor, Colors.grey);
    });

    test('toMarkdownStyleSheet uses code as-is without codeFontStyle', () {
      const ext = MarkdownThemeExtension(
        code: TextStyle(backgroundColor: Colors.grey),
      );

      final styleSheet = ext.toMarkdownStyleSheet();

      expect(styleSheet.code?.backgroundColor, Colors.grey);
      expect(styleSheet.code?.fontFamily, isNull);
    });

    test('lerp returns this when other is null', () {
      const ext = MarkdownThemeExtension(
        body: TextStyle(fontSize: 14),
      );

      final result = ext.lerp(null, 0.5);

      expect(result.body, ext.body);
    });
  });
}
