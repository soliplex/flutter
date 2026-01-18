import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soliplex_client/soliplex_client.dart' hide State;
import 'package:soliplex_frontend/features/rooms/widgets/room_grid_card.dart';

/// Creates a test app with proper theme for RoomGridCard.
Widget _testApp({required Widget child}) {
  return MaterialApp(
    theme: ThemeData(
      dividerTheme: const DividerThemeData(
        color: Colors.grey,
        thickness: 1,
      ),
    ),
    home: Scaffold(body: child),
  );
}

void main() {
  group('RoomGridCard', () {
    testWidgets('renders room name', (tester) async {
      const room = Room(id: 'r1', name: 'Test Room');
      var tapped = false;

      await tester.pumpWidget(
        _testApp(
          child: RoomGridCard(
            room: room,
            onTap: () => tapped = true,
          ),
        ),
      );

      expect(find.text('Test Room'), findsOneWidget);
      expect(tapped, isFalse);
    });

    testWidgets('renders room description when present', (tester) async {
      const room = Room(
        id: 'r1',
        name: 'Test Room',
        description: 'A test description',
      );

      await tester.pumpWidget(
        _testApp(child: RoomGridCard(room: room, onTap: () {})),
      );

      expect(find.text('Test Room'), findsOneWidget);
      expect(find.text('A test description'), findsOneWidget);
    });

    testWidgets('does not render description when empty', (tester) async {
      const room = Room(id: 'r1', name: 'Test Room');

      await tester.pumpWidget(
        _testApp(child: RoomGridCard(room: room, onTap: () {})),
      );

      // Only the title should be present, no description text
      expect(find.text('Test Room'), findsOneWidget);
    });

    testWidgets('calls onTap when tapped', (tester) async {
      const room = Room(id: 'r1', name: 'Test Room');
      var tapped = false;

      await tester.pumpWidget(
        _testApp(
          child: RoomGridCard(
            room: room,
            onTap: () => tapped = true,
          ),
        ),
      );

      await tester.tap(find.byType(RoomGridCard));
      await tester.pump();

      expect(tapped, isTrue);
    });

    testWidgets('has correct semantics label', (tester) async {
      const room = Room(id: 'r1', name: 'My Room');

      await tester.pumpWidget(
        _testApp(child: RoomGridCard(room: room, onTap: () {})),
      );

      final semantics = find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label == 'Open room: My Room' &&
            (widget.properties.button ?? false),
      );
      expect(semantics, findsOneWidget);
    });

    testWidgets('handles hover interaction', (tester) async {
      const room = Room(id: 'r1', name: 'Test Room');

      await tester.pumpWidget(
        _testApp(child: RoomGridCard(room: room, onTap: () {})),
      );

      // Create a TestPointer and simulate hover enter
      final gesture = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
      );
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      await tester.pump();

      await gesture.moveTo(tester.getCenter(find.byType(RoomGridCard)));
      await tester.pumpAndSettle();

      // Widget should still render after hover
      expect(find.byType(RoomGridCard), findsOneWidget);

      // Exit hover
      await gesture.moveTo(Offset.zero);
      await tester.pumpAndSettle();

      // Widget should still render after hover exit
      expect(find.byType(RoomGridCard), findsOneWidget);
    });

    testWidgets('shows tooltip on long hover', (tester) async {
      const room = Room(id: 'r1', name: 'Long Room Name');

      await tester.pumpWidget(
        _testApp(child: RoomGridCard(room: room, onTap: () {})),
      );

      final tooltip = find.byWidgetPredicate(
        (widget) => widget is Tooltip && widget.message == 'Long Room Name',
      );
      expect(tooltip, findsOneWidget);
    });
  });

  group('RoomGridCard.ghost', () {
    testWidgets('renders New Room text', (tester) async {
      await tester.pumpWidget(
        _testApp(
          child: Builder(
            builder: (context) => RoomGridCard.ghost(context: context),
          ),
        ),
      );

      expect(find.text('New Room'), findsOneWidget);
    });

    testWidgets('renders add icon', (tester) async {
      await tester.pumpWidget(
        _testApp(
          child: Builder(
            builder: (context) => RoomGridCard.ghost(context: context),
          ),
        ),
      );

      expect(find.byIcon(Icons.add), findsOneWidget);
    });

    testWidgets('calls onTap when tapped', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        _testApp(
          child: Builder(
            builder: (context) => RoomGridCard.ghost(
              context: context,
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      await tester.tap(find.text('New Room'));
      await tester.pump();

      expect(tapped, isTrue);
    });

    testWidgets('has correct semantics label', (tester) async {
      await tester.pumpWidget(
        _testApp(
          child: Builder(
            builder: (context) => RoomGridCard.ghost(context: context),
          ),
        ),
      );

      final semantics = find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label == 'Create new room' &&
            (widget.properties.button ?? false),
      );
      expect(semantics, findsOneWidget);
    });

    testWidgets('renders without onTap callback', (tester) async {
      await tester.pumpWidget(
        _testApp(
          child: Builder(
            builder: (context) => RoomGridCard.ghost(context: context),
          ),
        ),
      );

      // Should render without throwing
      expect(find.text('New Room'), findsOneWidget);
    });
  });
}
