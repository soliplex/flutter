import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soliplex_frontend/features/home/home_screen.dart';

import '../../helpers/test_helpers.dart';

void main() {
  group('HomeScreen', () {
    testWidgets('displays header and URL input', (tester) async {
      await tester.pumpWidget(
        createTestApp(home: const HomeScreen()),
      );

      expect(find.text('Soliplex'), findsOneWidget);
      expect(find.text('Enter the URL of your backend server'), findsOneWidget);
      expect(find.text('Backend URL'), findsOneWidget);
      expect(find.text('Connect'), findsOneWidget);
    });

    testWidgets('validates URL format', (tester) async {
      await tester.pumpWidget(
        createTestApp(home: const HomeScreen()),
      );

      // Clear the URL field and enter invalid URL
      final urlField = find.byType(TextFormField);
      await tester.enterText(urlField, 'invalid-url');
      await tester.tap(find.text('Connect'));
      await tester.pump();

      expect(
        find.text('URL must start with http:// or https://'),
        findsOneWidget,
      );
    });

    testWidgets('validates empty URL', (tester) async {
      await tester.pumpWidget(
        createTestApp(home: const HomeScreen()),
      );

      // Clear the URL field
      final urlField = find.byType(TextFormField);
      await tester.enterText(urlField, '');
      await tester.tap(find.text('Connect'));
      await tester.pump();

      expect(find.text('Please enter a server URL'), findsOneWidget);
    });

  });
}
