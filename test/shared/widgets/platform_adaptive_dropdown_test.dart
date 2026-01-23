import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soliplex_frontend/shared/widgets/platform_adaptive_dropdown.dart';

void main() {
  group('PlatformAdaptiveDropdown', () {
    final items = [
      const PlatformAdaptiveDropdownItem(text: 'Option A', value: 'a'),
      const PlatformAdaptiveDropdownItem(text: 'Option B', value: 'b'),
      const PlatformAdaptiveDropdownItem(text: 'Option C', value: 'c'),
    ];

    group('Material platform', () {
      testWidgets('shows DropdownMenu', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(platform: TargetPlatform.android),
            home: Scaffold(
              body: PlatformAdaptiveDropdown<String>(
                items: items,
                onSelected: (_) {},
              ),
            ),
          ),
        );

        expect(find.byType(DropdownMenu<String>), findsOneWidget);
      });

      testWidgets('shows hint text when no selection', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(platform: TargetPlatform.android),
            home: Scaffold(
              body: PlatformAdaptiveDropdown<String>(
                items: items,
                onSelected: (_) {},
                hint: 'Choose one',
              ),
            ),
          ),
        );

        expect(find.text('Choose one'), findsOneWidget);
      });

      testWidgets('calls onSelected when item is chosen', (tester) async {
        String? selected;

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(platform: TargetPlatform.android),
            home: Scaffold(
              body: PlatformAdaptiveDropdown<String>(
                items: items,
                onSelected: (value) => selected = value,
              ),
            ),
          ),
        );

        // Tap to open dropdown
        await tester.tap(find.byType(DropdownMenu<String>));
        await tester.pumpAndSettle();

        // Tap an option
        await tester.tap(find.text('Option B').last);
        await tester.pumpAndSettle();

        expect(selected, 'b');
      });
    });

    group('Cupertino platform', () {
      testWidgets('shows tappable text with chevron', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(platform: TargetPlatform.iOS),
            home: Scaffold(
              body: PlatformAdaptiveDropdown<String>(
                items: items,
                onSelected: (_) {},
                initialSelection: 'a',
              ),
            ),
          ),
        );

        expect(find.text('Option A'), findsOneWidget);
        expect(find.byIcon(CupertinoIcons.chevron_down), findsOneWidget);
      });

      testWidgets('shows hint when no selection', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(platform: TargetPlatform.iOS),
            home: Scaffold(
              body: PlatformAdaptiveDropdown<String>(
                items: items,
                onSelected: (_) {},
                hint: 'Pick one',
              ),
            ),
          ),
        );

        expect(find.text('Pick one'), findsOneWidget);
      });

      testWidgets('opens CupertinoPicker modal on tap', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(platform: TargetPlatform.iOS),
            home: Scaffold(
              body: PlatformAdaptiveDropdown<String>(
                items: items,
                onSelected: (_) {},
                initialSelection: 'a',
              ),
            ),
          ),
        );

        // Tap to open picker
        await tester.tap(find.text('Option A'));
        await tester.pumpAndSettle();

        // Verify picker is shown
        expect(find.byType(CupertinoPicker), findsOneWidget);
        expect(find.text('Done'), findsOneWidget);
      });

      testWidgets('calls onSelected only when Done is tapped', (tester) async {
        String? selected;

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(platform: TargetPlatform.iOS),
            home: Scaffold(
              body: PlatformAdaptiveDropdown<String>(
                items: items,
                onSelected: (value) => selected = value,
                initialSelection: 'a',
              ),
            ),
          ),
        );

        // Open picker
        await tester.tap(find.text('Option A'));
        await tester.pumpAndSettle();

        // Scroll to different option (simulate picker scroll)
        await tester.drag(find.byType(CupertinoPicker), const Offset(0, -64));
        await tester.pump();

        // Selection should NOT be called yet (just scrolling)
        expect(selected, isNull);

        // Tap Done
        await tester.tap(find.text('Done'));
        await tester.pumpAndSettle();

        // Now onSelected should be called
        expect(selected, isNotNull);
      });
    });
  });
}
