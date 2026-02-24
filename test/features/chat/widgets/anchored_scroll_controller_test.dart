import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soliplex_frontend/features/chat/widgets/anchored_scroll_controller.dart';

void main() {
  late AnchoredScrollController controller;

  setUp(() {
    controller = AnchoredScrollController();
  });

  tearDown(() {
    controller.dispose();
  });

  group('realMaxScrollExtent', () {
    test('returns null when no clients are attached', () {
      expect(controller.realMaxScrollExtent, isNull);
    });
  });

  group('anchor inflation', () {
    testWidgets(
      'maxScrollExtent stays at anchor when content shrinks below it',
      (tester) async {
        await tester.pumpWidget(
          _TestScaffold(controller: controller, childHeight: 1000),
        );
        await tester.pumpAndSettle();

        // Scroll to 500 and set anchor there.
        controller
          ..jumpTo(500)
          ..anchorOffset = 500;
        await tester.pump();

        // Shrink content so real maxScrollExtent drops below 500.
        await tester.pumpWidget(
          _TestScaffold(controller: controller, childHeight: 400),
        );
        await tester.pump();

        // Inflated maxScrollExtent should be >= anchor.
        expect(controller.position.maxScrollExtent, greaterThanOrEqualTo(500));
        // Real max should reflect actual content.
        expect(controller.realMaxScrollExtent, lessThan(500));
      },
    );

    testWidgets(
      'no inflation when anchorOffset is null',
      (tester) async {
        await tester.pumpWidget(
          _TestScaffold(controller: controller, childHeight: 1000),
        );
        await tester.pumpAndSettle();

        final maxBefore = controller.position.maxScrollExtent;

        // Shrink content without setting anchor.
        await tester.pumpWidget(
          _TestScaffold(controller: controller, childHeight: 400),
        );
        await tester.pump();

        // maxScrollExtent should reflect actual content (no inflation).
        expect(controller.position.maxScrollExtent, lessThan(maxBefore));
        expect(
          controller.realMaxScrollExtent,
          equals(controller.position.maxScrollExtent),
        );
      },
    );

    testWidgets(
      'no inflation when content is larger than anchor',
      (tester) async {
        await tester.pumpWidget(
          _TestScaffold(controller: controller, childHeight: 1000),
        );
        await tester.pumpAndSettle();

        controller.anchorOffset = 100;
        await tester.pump();

        // Content is large, maxScrollExtent already above anchor.
        expect(controller.position.maxScrollExtent, greaterThan(100));
        expect(
          controller.realMaxScrollExtent,
          equals(controller.position.maxScrollExtent),
        );
      },
    );

    testWidgets(
      'realMaxScrollExtent tracks uninflated value during inflation',
      (tester) async {
        await tester.pumpWidget(
          _TestScaffold(controller: controller, childHeight: 1000),
        );
        await tester.pumpAndSettle();

        controller
          ..jumpTo(500)
          ..anchorOffset = 500;
        await tester.pump();

        // Shrink content.
        await tester.pumpWidget(
          _TestScaffold(controller: controller, childHeight: 400),
        );
        await tester.pump();

        final realMax = controller.realMaxScrollExtent!;
        final inflatedMax = controller.position.maxScrollExtent;

        expect(inflatedMax, greaterThan(realMax));
        expect(inflatedMax, greaterThanOrEqualTo(500));
      },
    );
  });
}

/// Minimal scaffold that puts a [SingleChildScrollView] around a colored box
/// of the given [childHeight], using the provided [controller].
class _TestScaffold extends StatelessWidget {
  const _TestScaffold({required this.controller, required this.childHeight});

  final ScrollController controller;
  final double childHeight;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: SizedBox(
          height: 600,
          child: SingleChildScrollView(
            controller: controller,
            child: SizedBox(height: childHeight),
          ),
        ),
      ),
    );
  }
}
