import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soliplex_client/soliplex_client.dart';
import 'package:soliplex_frontend/core/providers/rooms_provider.dart';
import 'package:soliplex_frontend/features/room/widgets/room_info_screen.dart';

import '../../../helpers/test_helpers.dart';

Room _createRoomWithAgent() {
  return const Room(
    id: 'room-1',
    name: 'Test Room',
    description: 'A test room for testing',
    welcomeMessage: 'Welcome!',
    enableAttachments: true,
    allowMcp: true,
    agent: DefaultRoomAgent(
      id: 'agent-1',
      modelName: 'gpt-4o',
      retries: 3,
      systemPrompt: 'You are a helpful assistant.',
      providerType: 'openai',
    ),
    tools: {
      'rag_search': RoomTool(
        name: 'rag_search',
        description: 'Search knowledge base',
        kind: 'search',
        toolRequires: 'tool_config',
        allowMcp: true,
      ),
    },
    mcpClientToolsets: {
      'my_toolset': McpClientToolset(
        kind: 'http',
        allowedTools: ['tool1'],
        toolsetParams: {'url': 'http://localhost:3000'},
      ),
    },
    aguiFeatureNames: ['feature1'],
  );
}

void main() {
  group('RoomInfoScreen', () {
    testWidgets('shows room name and description', (tester) async {
      final room = _createRoomWithAgent();

      await tester.pumpWidget(
        createTestApp(
          home: const RoomInfoScreen(roomId: 'room-1'),
          overrides: [
            roomsProvider.overrideWith((ref) async => [room]),
            documentsProviderOverride('room-1'),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Room Information'), findsOneWidget);
      expect(find.text('A test room for testing'), findsOneWidget);
    });

    testWidgets('shows agent configuration', (tester) async {
      final room = _createRoomWithAgent();

      await tester.pumpWidget(
        createTestApp(
          home: const RoomInfoScreen(roomId: 'room-1'),
          overrides: [
            roomsProvider.overrideWith((ref) async => [room]),
            documentsProviderOverride('room-1'),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('gpt-4o'), findsOneWidget);
      expect(find.text('openai'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('shows tools section', (tester) async {
      final room = _createRoomWithAgent();

      await tester.pumpWidget(
        createTestApp(
          home: const RoomInfoScreen(roomId: 'room-1'),
          overrides: [
            roomsProvider.overrideWith((ref) async => [room]),
            documentsProviderOverride('room-1'),
          ],
        ),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('rag_search'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(find.text('rag_search'), findsOneWidget);
      expect(find.text('Search knowledge base'), findsOneWidget);
    });

    testWidgets('shows documents with count', (tester) async {
      final room = _createRoomWithAgent();
      const docs = [
        RagDocument(id: 'doc-1', title: 'Document 1.pdf'),
        RagDocument(id: 'doc-2', title: 'Document 2.pdf'),
      ];

      await tester.pumpWidget(
        createTestApp(
          home: const RoomInfoScreen(roomId: 'room-1'),
          overrides: [
            roomsProvider.overrideWith((ref) async => [room]),
            documentsProviderOverride('room-1', docs),
          ],
        ),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('DOCUMENTS (2)'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(find.text('DOCUMENTS (2)'), findsOneWidget);
      expect(find.text('Document 1.pdf'), findsOneWidget);
      expect(find.text('Document 2.pdf'), findsOneWidget);
    });

    testWidgets('shows features section', (tester) async {
      final room = _createRoomWithAgent();

      await tester.pumpWidget(
        createTestApp(
          home: const RoomInfoScreen(roomId: 'room-1'),
          overrides: [
            roomsProvider.overrideWith((ref) async => [room]),
            documentsProviderOverride('room-1'),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Enabled'), findsWidgets);
      expect(find.text('Yes'), findsWidgets);
    });

    testWidgets('handles room without agent', (tester) async {
      const room = Room(id: 'room-2', name: 'Simple Room');

      await tester.pumpWidget(
        createTestApp(
          home: const RoomInfoScreen(roomId: 'room-2'),
          overrides: [
            roomsProvider.overrideWith((ref) async => [room]),
            documentsProviderOverride('room-2'),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Room Information'), findsOneWidget);
      expect(find.text('AGENT'), findsNothing);
    });
  });
}
