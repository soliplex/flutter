import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:soliplex_client/soliplex_client.dart';
import 'package:soliplex_frontend/core/providers/api_provider.dart';
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

    testWidgets('shows tool names collapsed by default', (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

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

      // Tool name visible
      expect(find.text('rag_search'), findsOneWidget);
      // Details hidden when collapsed
      expect(find.text('Search knowledge base'), findsNothing);
    });

    testWidgets('expands tool to show details on tap', (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

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

      // Tap to expand
      await tester.tap(find.text('rag_search'));
      await tester.pumpAndSettle();

      expect(find.text('Search knowledge base'), findsOneWidget);
      expect(find.text('search'), findsOneWidget);
      expect(find.text('tool_config'), findsOneWidget);
    });

    testWidgets('collapses expanded tool on second tap', (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

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

      // Expand
      await tester.tap(find.text('rag_search'));
      await tester.pumpAndSettle();
      expect(find.text('Search knowledge base'), findsOneWidget);

      // Collapse
      await tester.tap(find.text('rag_search'));
      await tester.pumpAndSettle();
      expect(find.text('Search knowledge base'), findsNothing);
    });

    testWidgets('shows MCP detail line for MCP-enabled tools when expanded',
        (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

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

      // Expand the tool
      await tester.tap(find.text('rag_search'));
      await tester.pumpAndSettle();

      // MCP info visible when expanded
      expect(find.text('Allow MCP'), findsWidgets);
      expect(find.text('Yes'), findsWidgets);
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

    testWidgets('shows MCP token with copy button when allowMcp is true',
        (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const room = Room(
        id: 'room-1',
        name: 'MCP Room',
        allowMcp: true,
      );

      final mockApi = MockSoliplexApi();
      when(() => mockApi.getMcpToken('room-1'))
          .thenAnswer((_) async => 'test-token-abc123');

      await tester.pumpWidget(
        createTestApp(
          home: const RoomInfoScreen(roomId: 'room-1'),
          overrides: [
            roomsProvider.overrideWith((ref) async => [room]),
            documentsProviderOverride('room-1'),
            apiProvider.overrideWithValue(mockApi),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Token value is NOT displayed
      expect(find.textContaining('test-token-abc123'), findsNothing);
      // "Copy Token" button exists with copy icon
      expect(find.text('Copy Token'), findsOneWidget);
      expect(find.byIcon(Icons.copy), findsOneWidget);
    });

    testWidgets('copy button shows checkmark then reverts', (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const room = Room(
        id: 'room-1',
        name: 'MCP Room',
        allowMcp: true,
      );

      final mockApi = MockSoliplexApi();
      when(() => mockApi.getMcpToken('room-1'))
          .thenAnswer((_) async => 'test-token-abc123');

      await tester.pumpWidget(
        createTestApp(
          home: const RoomInfoScreen(roomId: 'room-1'),
          overrides: [
            roomsProvider.overrideWith((ref) async => [room]),
            documentsProviderOverride('room-1'),
            apiProvider.overrideWithValue(mockApi),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Starts with "Copy Token" button and copy icon
      expect(find.text('Copy Token'), findsOneWidget);
      expect(find.byIcon(Icons.copy), findsOneWidget);
      expect(find.byIcon(Icons.check), findsNothing);

      // Tap copy
      await tester.tap(find.text('Copy Token'));
      await tester.pump();

      // Shows checkmark and "Copied" text
      expect(find.byIcon(Icons.check), findsOneWidget);
      expect(find.text('Copied'), findsOneWidget);
      expect(find.byIcon(Icons.copy), findsNothing);

      // After 2 seconds, reverts to copy icon
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('Copy Token'), findsOneWidget);
      expect(find.byIcon(Icons.copy), findsOneWidget);
      expect(find.byIcon(Icons.check), findsNothing);
    });

    testWidgets('does not show MCP token when allowMcp is false',
        (tester) async {
      const room = Room(
        id: 'room-1',
        name: 'No MCP Room',
      );

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

      expect(find.text('Copy Token'), findsNothing);
      expect(find.byIcon(Icons.copy), findsNothing);
    });

    testWidgets('tapping a document expands to show metadata', (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final room = _createRoomWithAgent();
      final docs = [
        RagDocument(
          id: 'doc-1',
          title: 'Document 1.pdf',
          uri: 'file:///docs/document1.pdf',
          metadata: const {
            'source': 'upload',
            'content-type': 'application/pdf',
          },
          createdAt: DateTime.utc(2025, 1, 15),
          updatedAt: DateTime.utc(2025, 2, 20),
        ),
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
        find.text('Document 1.pdf'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      // Metadata not visible before tap
      expect(find.text('file:///docs/document1.pdf'), findsNothing);

      // Tap to expand
      await tester.tap(find.text('Document 1.pdf'));
      await tester.pumpAndSettle();

      // ID, URI, and dates visible; metadata behind button
      expect(find.text('doc-1'), findsOneWidget);
      expect(find.text('file:///docs/document1.pdf'), findsOneWidget);
      expect(find.text('Show metadata'), findsOneWidget);
    });

    testWidgets('tapping an expanded document collapses it', (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final room = _createRoomWithAgent();
      final docs = [
        RagDocument(
          id: 'doc-1',
          title: 'Document 1.pdf',
          uri: 'file:///docs/document1.pdf',
          createdAt: DateTime.utc(2025, 1, 15),
        ),
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
        find.text('Document 1.pdf'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      // Tap to expand
      await tester.tap(find.text('Document 1.pdf'));
      await tester.pumpAndSettle();
      expect(find.text('file:///docs/document1.pdf'), findsOneWidget);

      // Tap again to collapse
      await tester.tap(find.text('Document 1.pdf'));
      await tester.pumpAndSettle();
      expect(find.text('file:///docs/document1.pdf'), findsNothing);
    });

    testWidgets('does not show metadata entries inline', (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final room = _createRoomWithAgent();
      final docs = [
        RagDocument(
          id: 'doc-1',
          title: 'Document 1.pdf',
          uri: 'file:///docs/document1.pdf',
          metadata: const {
            'source': 'upload',
            'content-type': 'application/pdf',
          },
          createdAt: DateTime.utc(2025, 1, 15),
        ),
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
        find.text('Document 1.pdf'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Document 1.pdf'));
      await tester.pumpAndSettle();

      // URI and dates still visible
      expect(find.text('file:///docs/document1.pdf'), findsOneWidget);
      expect(find.textContaining('2025-01-15'), findsOneWidget);

      // Metadata entries NOT shown inline
      expect(find.text('upload'), findsNothing);
      expect(find.text('application/pdf'), findsNothing);

      // "Show metadata" button visible
      expect(find.text('Show metadata'), findsOneWidget);
    });

    testWidgets('hides "Show metadata" button when metadata is empty',
        (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final room = _createRoomWithAgent();
      const docs = [
        RagDocument(id: 'doc-1', title: 'Document 1.pdf'),
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
        find.text('Document 1.pdf'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Document 1.pdf'));
      await tester.pumpAndSettle();

      expect(find.text('Show metadata'), findsNothing);
    });

    testWidgets('"Show metadata" opens dialog with all metadata',
        (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final room = _createRoomWithAgent();
      const docs = [
        RagDocument(
          id: 'doc-1',
          title: 'Document 1.pdf',
          metadata: {
            'source': 'upload',
            'content-type': 'application/pdf',
            'batch_id': 'batch-123',
            'md5': 'abc123hash',
          },
        ),
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
        find.text('Document 1.pdf'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Document 1.pdf'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Show metadata'));
      await tester.pumpAndSettle();

      // Dialog shows all metadata entries
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('upload'), findsOneWidget);
      expect(find.text('application/pdf'), findsOneWidget);
      expect(find.text('batch-123'), findsOneWidget);
      expect(find.text('abc123hash'), findsOneWidget);

      // Close button works
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
    });

    group('document search', () {
      testWidgets('shows search field when more than one document',
          (tester) async {
        tester.view.physicalSize = const Size(800, 2000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        const room = Room(id: 'room-1', name: 'Test Room');
        const docs = [
          RagDocument(id: 'doc-1', title: 'Alpha.pdf'),
          RagDocument(id: 'doc-2', title: 'Beta.pdf'),
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

        expect(
          find.widgetWithText(TextField, 'Search documents...'),
          findsOneWidget,
        );
      });

      testWidgets('hides search field when only one document', (tester) async {
        tester.view.physicalSize = const Size(800, 2000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        const room = Room(id: 'room-1', name: 'Test Room');
        const docs = [
          RagDocument(id: 'doc-1', title: 'Alpha.pdf'),
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
          find.text('DOCUMENTS (1)'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();

        expect(
          find.widgetWithText(TextField, 'Search documents...'),
          findsNothing,
        );
      });

      testWidgets('filters documents by title', (tester) async {
        tester.view.physicalSize = const Size(800, 2000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        const room = Room(id: 'room-1', name: 'Test Room');
        const docs = [
          RagDocument(id: 'doc-1', title: 'Alpha.pdf'),
          RagDocument(id: 'doc-2', title: 'Beta.pdf'),
          RagDocument(id: 'doc-3', title: 'Gamma.pdf'),
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
          find.widgetWithText(TextField, 'Search documents...'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();

        await tester.enterText(
          find.widgetWithText(TextField, 'Search documents...'),
          'alpha',
        );
        await tester.pumpAndSettle();

        expect(find.text('Alpha.pdf'), findsOneWidget);
        expect(find.text('Beta.pdf'), findsNothing);
        expect(find.text('Gamma.pdf'), findsNothing);
      });

      testWidgets('filters documents by URI', (tester) async {
        tester.view.physicalSize = const Size(800, 2000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        const room = Room(id: 'room-1', name: 'Test Room');
        const docs = [
          RagDocument(
            id: 'doc-1',
            title: 'Alpha.pdf',
            uri: 'file:///unique/path',
          ),
          RagDocument(id: 'doc-2', title: 'Beta.pdf', uri: 'file:///other'),
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
          find.widgetWithText(TextField, 'Search documents...'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();

        await tester.enterText(
          find.widgetWithText(TextField, 'Search documents...'),
          'unique',
        );
        await tester.pumpAndSettle();

        expect(find.text('Alpha.pdf'), findsOneWidget);
        expect(find.text('Beta.pdf'), findsNothing);
      });

      testWidgets('shows filtered count in title when searching',
          (tester) async {
        tester.view.physicalSize = const Size(800, 2000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        const room = Room(id: 'room-1', name: 'Test Room');
        const docs = [
          RagDocument(id: 'doc-1', title: 'Alpha.pdf'),
          RagDocument(id: 'doc-2', title: 'Beta.pdf'),
          RagDocument(id: 'doc-3', title: 'Another Alpha.pdf'),
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
          find.widgetWithText(TextField, 'Search documents...'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();

        await tester.enterText(
          find.widgetWithText(TextField, 'Search documents...'),
          'alpha',
        );
        await tester.pumpAndSettle();

        expect(find.text('DOCUMENTS (2 / 3)'), findsOneWidget);
      });
    });

    group('system prompt', () {
      testWidgets('renders system prompt text', (tester) async {
        tester.view.physicalSize = const Size(800, 2000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

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

        expect(find.text('System Prompt'), findsOneWidget);
        expect(
          find.text('You are a helpful assistant.'),
          findsOneWidget,
        );
      });

      testWidgets('expands and collapses on tap', (tester) async {
        tester.view.physicalSize = const Size(800, 2000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        const longPrompt = 'Line 1\nLine 2\nLine 3\nLine 4\nLine 5';
        const room = Room(
          id: 'room-1',
          name: 'Test Room',
          agent: DefaultRoomAgent(
            id: 'agent-1',
            modelName: 'gpt-4o',
            retries: 0,
            systemPrompt: longPrompt,
            providerType: 'openai',
          ),
        );

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

        // "Show more" appears because prompt has >3 lines
        expect(find.text('Show more'), findsOneWidget);

        // Tap "Show more" to expand
        await tester.tap(find.text('Show more'));
        await tester.pumpAndSettle();

        // "Show more" disappears once expanded
        expect(find.text('Show more'), findsNothing);
      });

      testWidgets('shows "Show more" for long single-line prompt that wraps',
          (tester) async {
        tester.view.physicalSize = const Size(800, 2000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        // Single line, no newlines, but long enough to wrap past 3 lines
        final longSingleLine = 'a' * 500;
        final room = Room(
          id: 'room-1',
          name: 'Test Room',
          agent: DefaultRoomAgent(
            id: 'agent-1',
            modelName: 'gpt-4o',
            retries: 0,
            systemPrompt: longSingleLine,
            providerType: 'openai',
          ),
        );

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

        expect(find.text('Show more'), findsOneWidget);
      });

      testWidgets('hides "Show more" when prompt has 3 or fewer lines',
          (tester) async {
        tester.view.physicalSize = const Size(800, 2000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        const room = Room(
          id: 'room-1',
          name: 'Test Room',
          agent: DefaultRoomAgent(
            id: 'agent-1',
            modelName: 'gpt-4o',
            retries: 0,
            systemPrompt: 'Short prompt',
            providerType: 'openai',
          ),
        );

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

        expect(find.text('Short prompt'), findsOneWidget);
        expect(find.text('Show more'), findsNothing);
      });

      testWidgets('copy button shows checkmark after copying', (tester) async {
        tester.view.physicalSize = const Size(800, 2000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

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

        expect(find.byIcon(Icons.copy), findsOneWidget);
        expect(find.byIcon(Icons.check), findsNothing);

        await tester.tap(find.byTooltip('Copy system prompt'));
        await tester.pump();

        expect(find.byIcon(Icons.check), findsOneWidget);
        expect(find.byIcon(Icons.copy), findsNothing);

        await tester.pump(const Duration(seconds: 2));

        expect(find.byIcon(Icons.copy), findsOneWidget);
        expect(find.byIcon(Icons.check), findsNothing);
      });
    });

    group('MCP client toolsets', () {
      testWidgets('shows toolset names collapsed by default', (tester) async {
        tester.view.physicalSize = const Size(800, 2000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

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
          find.text('my_toolset'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();

        expect(find.text('MCP CLIENT TOOLSETS (1)'), findsOneWidget);
        expect(find.text('my_toolset'), findsOneWidget);
        // Details hidden when collapsed
        expect(find.text('http'), findsNothing);
        expect(find.text('tool1'), findsNothing);
      });

      testWidgets('expands toolset to show details on tap', (tester) async {
        tester.view.physicalSize = const Size(800, 2000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

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
          find.text('my_toolset'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();

        // Tap to expand
        await tester.tap(find.text('my_toolset'));
        await tester.pumpAndSettle();

        expect(find.text('http'), findsOneWidget);
        expect(find.text('tool1'), findsOneWidget);
      });
    });

    group('MCP token error handling', () {
      testWidgets('shows retry button when getMcpToken fails', (tester) async {
        tester.view.physicalSize = const Size(800, 2000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        const room = Room(
          id: 'room-1',
          name: 'MCP Room',
          allowMcp: true,
        );

        final mockApi = MockSoliplexApi();
        when(() => mockApi.getMcpToken('room-1'))
            .thenAnswer((_) async => throw Exception('token fetch failed'));

        await tester.pumpWidget(
          createTestApp(
            home: const RoomInfoScreen(roomId: 'room-1'),
            overrides: [
              roomsProvider.overrideWith((ref) async => [room]),
              documentsProviderOverride('room-1'),
              apiProvider.overrideWithValue(mockApi),
            ],
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Copy Token'), findsNothing);
        expect(find.text('Retry token'), findsOneWidget);
      });

      testWidgets('tapping retry re-fetches MCP token', (tester) async {
        tester.view.physicalSize = const Size(800, 2000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        const room = Room(
          id: 'room-1',
          name: 'MCP Room',
          allowMcp: true,
        );

        final mockApi = MockSoliplexApi();
        // First call fails, second succeeds
        var callCount = 0;
        when(() => mockApi.getMcpToken('room-1')).thenAnswer((_) async {
          callCount++;
          if (callCount == 1) throw Exception('token fetch failed');
          return 'test-token-abc123';
        });

        await tester.pumpWidget(
          createTestApp(
            home: const RoomInfoScreen(roomId: 'room-1'),
            overrides: [
              roomsProvider.overrideWith((ref) async => [room]),
              documentsProviderOverride('room-1'),
              apiProvider.overrideWithValue(mockApi),
            ],
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Retry token'), findsOneWidget);

        await tester.tap(find.text('Retry token'));
        await tester.pumpAndSettle();

        expect(find.text('Copy Token'), findsOneWidget);
        expect(find.text('Retry token'), findsNothing);
        expect(callCount, equals(2));
      });
    });

    group('documents states', () {
      testWidgets('shows error with retry button when loading fails',
          (tester) async {
        const room = Room(id: 'room-1', name: 'Test Room');
        final (docsOverride, notifier) = documentsErrorOverride('room-1');

        await tester.pumpWidget(
          createTestApp(
            home: const RoomInfoScreen(roomId: 'room-1'),
            overrides: [
              roomsProvider.overrideWith((ref) async => [room]),
              docsOverride,
            ],
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Failed to load documents'), findsOneWidget);
        expect(find.text('Retry'), findsOneWidget);

        await tester.tap(find.text('Retry'));
        await tester.pumpAndSettle();

        expect(notifier.retryCalled, isTrue);
      });

      testWidgets('shows empty message when room has no documents',
          (tester) async {
        tester.view.physicalSize = const Size(800, 2000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        const room = Room(id: 'room-1', name: 'Test Room');

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
          find.text('No documents in this room.'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();

        expect(find.text('No documents in this room.'), findsOneWidget);
      });
    });

    testWidgets('shows formatted dates in document metadata', (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const room = Room(id: 'room-1', name: 'Test Room');
      final docs = [
        RagDocument(
          id: 'doc-1',
          title: 'Dated Doc.pdf',
          createdAt: DateTime.utc(2025, 1, 15, 9, 30),
          updatedAt: DateTime.utc(2025, 2, 20, 14, 45),
        ),
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
        find.text('Dated Doc.pdf'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Dated Doc.pdf'));
      await tester.pumpAndSettle();

      expect(find.text('2025-01-15 09:30'), findsOneWidget);
      expect(find.text('2025-02-20 14:45'), findsOneWidget);
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

    group('client tools', () {
      ToolRegistry registryWithTools() {
        return const ToolRegistry()
            .register(
              const ClientTool(
                definition: Tool(
                  name: 'gps_lookup',
                  description: 'Look up GPS coordinates',
                ),
                executor: _noOpExecutor,
              ),
            )
            .register(
              const ClientTool(
                definition: Tool(
                  name: 'db_query',
                  description: 'Query the database',
                ),
                executor: _noOpExecutor,
              ),
            );
      }

      testWidgets('shows client tools collapsed by default', (tester) async {
        tester.view.physicalSize = const Size(800, 2000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        const room = Room(id: 'room-1', name: 'Test Room');

        await tester.pumpWidget(
          createTestApp(
            home: const RoomInfoScreen(roomId: 'room-1'),
            overrides: [
              roomsProvider.overrideWith((ref) async => [room]),
              documentsProviderOverride('room-1'),
              toolRegistryProvider.overrideWithValue(registryWithTools()),
            ],
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('CLIENT TOOLS (2)'), findsOneWidget);
        expect(find.text('gps_lookup'), findsOneWidget);
        expect(find.text('db_query'), findsOneWidget);
        // Descriptions hidden when collapsed
        expect(find.text('Look up GPS coordinates'), findsNothing);
        expect(find.text('Query the database'), findsNothing);
      });

      testWidgets('expands client tool to show description on tap',
          (tester) async {
        tester.view.physicalSize = const Size(800, 2000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        const room = Room(id: 'room-1', name: 'Test Room');

        await tester.pumpWidget(
          createTestApp(
            home: const RoomInfoScreen(roomId: 'room-1'),
            overrides: [
              roomsProvider.overrideWith((ref) async => [room]),
              documentsProviderOverride('room-1'),
              toolRegistryProvider.overrideWithValue(registryWithTools()),
            ],
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('gps_lookup'));
        await tester.pumpAndSettle();

        expect(find.text('Look up GPS coordinates'), findsOneWidget);
        // Other tool still collapsed
        expect(find.text('Query the database'), findsNothing);
      });

      testWidgets('not shown when registry is empty', (tester) async {
        tester.view.physicalSize = const Size(800, 2000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        const room = Room(id: 'room-1', name: 'Test Room');

        await tester.pumpWidget(
          createTestApp(
            home: const RoomInfoScreen(roomId: 'room-1'),
            overrides: [
              roomsProvider.overrideWith((ref) async => [room]),
              documentsProviderOverride('room-1'),
              toolRegistryProvider.overrideWithValue(const ToolRegistry()),
            ],
          ),
        );
        await tester.pumpAndSettle();

        expect(find.textContaining('CLIENT TOOLS'), findsNothing);
      });
    });

    testWidgets('shows AG-UI features in features card', (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

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
        find.text('FEATURES'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(find.text('feature1'), findsWidgets);
    });

    testWidgets('shows AG-UI features in agent card', (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const room = Room(
        id: 'room-1',
        name: 'Test Room',
        agent: DefaultRoomAgent(
          id: 'agent-1',
          modelName: 'gpt-4o',
          retries: 0,
          providerType: 'openai',
          aguiFeatureNames: ['streaming'],
        ),
      );

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

      expect(find.text('streaming'), findsOneWidget);
    });

    testWidgets('shows factory agent configuration', (tester) async {
      const room = Room(
        id: 'room-1',
        name: 'Factory Room',
        agent: FactoryRoomAgent(
          id: 'agent-f',
          factoryName: 'my.custom.agent',
          extraConfig: {'key': 'value'},
        ),
      );

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

      expect(find.text('Factory: my.custom.agent'), findsOneWidget);
      expect(find.text('{key: value}'), findsOneWidget);
    });

    testWidgets('shows other agent configuration', (tester) async {
      const room = Room(
        id: 'room-1',
        name: 'Other Room',
        agent: OtherRoomAgent(id: 'agent-o', kind: 'custom_kind'),
      );

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

      expect(find.text('custom_kind'), findsOneWidget);
    });

    testWidgets('shows error when rooms fail to load', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          home: const RoomInfoScreen(roomId: 'room-1'),
          overrides: [
            roomsProvider.overrideWith(
              (ref) async => throw Exception('network error'),
            ),
            documentsProviderOverride('room-1'),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Failed to load room'), findsOneWidget);
    });

    testWidgets('shows not-found when room ID does not exist', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          home: const RoomInfoScreen(roomId: 'nonexistent'),
          overrides: [
            roomsProvider.overrideWith(
              (ref) async => [
                const Room(id: 'room-1', name: 'Other Room'),
              ],
            ),
            documentsProviderOverride('nonexistent'),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Room not found'), findsOneWidget);
    });

    testWidgets('hides description when room has none', (tester) async {
      const room = Room(id: 'room-1', name: 'No Description Room');

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
      // Default empty description should not be rendered
      expect(find.text(''), findsNothing);
    });
  });
}

Future<String> _noOpExecutor(ToolCallInfo toolCall) async => '';
