import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:soliplex_client/soliplex_client.dart';
import 'package:soliplex_client/soliplex_client.dart' as domain
    show Conversation, Running;
import 'package:soliplex_frontend/core/models/active_run_state.dart';
import 'package:soliplex_frontend/core/providers/api_provider.dart';
import 'package:soliplex_frontend/core/providers/rooms_provider.dart';
import 'package:soliplex_frontend/core/providers/threads_provider.dart';
import 'package:soliplex_frontend/features/chat/widgets/chat_input.dart';

import '../../../helpers/test_helpers.dart';

void main() {
  group('ChatInput', () {
    group('Send Button', () {
      testWidgets('is enabled when canSendMessage is true', (tester) async {
        // Arrange
        final mockRoom = TestData.createRoom();
        final mockThread = TestData.createThread();

        // Act
        await tester.pumpWidget(
          createTestApp(
            home: Scaffold(body: ChatInput(onSend: (_) {})),
            overrides: [
              currentRoomProvider.overrideWith((ref) => mockRoom),
              currentThreadProvider.overrideWith((ref) => mockThread),
              activeRunNotifierOverride(const IdleState()),
            ],
          ),
        );

        // Type some text
        await tester.enterText(find.byType(TextField), 'Hello');
        await tester.pump();

        // Assert
        final sendButton = tester.widget<IconButton>(
          find.widgetWithIcon(IconButton, Icons.send),
        );
        expect(sendButton.onPressed, isNotNull);
      });

      testWidgets('is disabled when canSendMessage is false', (tester) async {
        // Arrange - no room selected
        await tester.pumpWidget(
          createTestApp(
            home: Scaffold(body: ChatInput(onSend: (_) {})),
            overrides: [currentRoomProvider.overrideWith((ref) => null)],
          ),
        );

        // Act
        await tester.enterText(find.byType(TextField), 'Hello');
        await tester.pump();

        // Assert
        final sendButton = tester.widget<IconButton>(
          find.widgetWithIcon(IconButton, Icons.send),
        );
        expect(sendButton.onPressed, isNull);
      });

      testWidgets('is disabled when text is empty', (tester) async {
        // Arrange
        final mockRoom = TestData.createRoom();
        final mockThread = TestData.createThread();

        // Act
        await tester.pumpWidget(
          createTestApp(
            home: Scaffold(body: ChatInput(onSend: (_) {})),
            overrides: [
              currentRoomProvider.overrideWith((ref) => mockRoom),
              currentThreadProvider.overrideWith((ref) => mockThread),
              activeRunNotifierOverride(const IdleState()),
            ],
          ),
        );

        // Assert - empty text field
        final sendButton = tester.widget<IconButton>(
          find.widgetWithIcon(IconButton, Icons.send),
        );
        expect(sendButton.onPressed, isNull);
      });

      testWidgets('shows stop button during active run', (tester) async {
        // Arrange
        final mockRoom = TestData.createRoom();
        final mockThread = TestData.createThread();
        const conversation = domain.Conversation(
          threadId: 'test-thread',
          status: domain.Running(runId: 'test-run'),
        );

        // Act
        await tester.pumpWidget(
          createTestApp(
            home: Scaffold(body: ChatInput(onSend: (_) {})),
            overrides: [
              currentRoomProvider.overrideWith((ref) => mockRoom),
              currentThreadProvider.overrideWith((ref) => mockThread),
              activeRunNotifierOverride(
                const RunningState(conversation: conversation),
              ),
            ],
          ),
        );

        await tester.pump();

        // Assert - stop button shown instead of send button during active run
        expect(find.byIcon(Icons.stop), findsOneWidget);
        expect(find.byIcon(Icons.send), findsNothing);
      });

      testWidgets('tapping stop button calls cancelRun', (tester) async {
        // Arrange
        final mockRoom = TestData.createRoom();
        final mockThread = TestData.createThread();
        const conversation = domain.Conversation(
          threadId: 'test-thread',
          status: domain.Running(runId: 'test-run'),
        );
        final (override, mockNotifier) = activeRunNotifierOverrideWithMock(
          const RunningState(conversation: conversation),
        );

        // Act
        await tester.pumpWidget(
          createTestApp(
            home: Scaffold(body: ChatInput(onSend: (_) {})),
            overrides: [
              currentRoomProvider.overrideWith((ref) => mockRoom),
              currentThreadProvider.overrideWith((ref) => mockThread),
              override,
            ],
          ),
        );

        await tester.pump();

        // Tap stop button
        await tester.tap(find.byIcon(Icons.stop));
        await tester.pump();

        // Assert
        expect(mockNotifier.cancelRunCalled, isTrue);
      });
    });

    group('Text Input', () {
      testWidgets('displays placeholder when can send', (tester) async {
        // Arrange
        final mockRoom = TestData.createRoom();
        final mockThread = TestData.createThread();

        // Act
        await tester.pumpWidget(
          createTestApp(
            home: Scaffold(body: ChatInput(onSend: (_) {})),
            overrides: [
              currentRoomProvider.overrideWith((ref) => mockRoom),
              currentThreadProvider.overrideWith((ref) => mockThread),
              activeRunNotifierOverride(const IdleState()),
            ],
          ),
        );

        // Assert
        final textField = tester.widget<TextField>(find.byType(TextField));
        expect(textField.decoration?.hintText, 'Type a message...');
      });

      testWidgets('displays disabled placeholder when cannot send', (
        tester,
      ) async {
        // Arrange - no room selected
        await tester.pumpWidget(
          createTestApp(
            home: Scaffold(body: ChatInput(onSend: (_) {})),
            overrides: [currentRoomProvider.overrideWith((ref) => null)],
          ),
        );

        // Assert
        final textField = tester.widget<TextField>(find.byType(TextField));
        expect(
          textField.decoration?.hintText,
          'Select a room to start chatting',
        );
      });

      testWidgets('allows text entry', (tester) async {
        // Arrange
        final mockRoom = TestData.createRoom();
        final mockThread = TestData.createThread();

        // Act
        await tester.pumpWidget(
          createTestApp(
            home: Scaffold(body: ChatInput(onSend: (_) {})),
            overrides: [
              currentRoomProvider.overrideWith((ref) => mockRoom),
              currentThreadProvider.overrideWith((ref) => mockThread),
              activeRunNotifierOverride(const IdleState()),
            ],
          ),
        );

        await tester.enterText(find.byType(TextField), 'Hello, world!');
        await tester.pump();

        // Assert
        expect(find.text('Hello, world!'), findsOneWidget);
      });

      testWidgets('is disabled when cannot send', (tester) async {
        // Arrange - no room selected
        await tester.pumpWidget(
          createTestApp(
            home: Scaffold(body: ChatInput(onSend: (_) {})),
            overrides: [currentRoomProvider.overrideWith((ref) => null)],
          ),
        );

        // Assert
        final textField = tester.widget<TextField>(find.byType(TextField));
        expect(textField.enabled, isFalse);
      });
    });

    group('Send Action', () {
      testWidgets('calls onSend callback with text', (tester) async {
        // Arrange
        final mockRoom = TestData.createRoom();
        final mockThread = TestData.createThread();
        String? sentText;

        // Act
        await tester.pumpWidget(
          createTestApp(
            home: Scaffold(body: ChatInput(onSend: (text) => sentText = text)),
            overrides: [
              currentRoomProvider.overrideWith((ref) => mockRoom),
              currentThreadProvider.overrideWith((ref) => mockThread),
              activeRunNotifierOverride(const IdleState()),
            ],
          ),
        );

        await tester.enterText(find.byType(TextField), 'Test message');
        await tester.pump();

        await tester.tap(find.widgetWithIcon(IconButton, Icons.send));
        await tester.pump();

        // Assert
        expect(sentText, 'Test message');
      });

      testWidgets('clears input after send', (tester) async {
        // Arrange
        final mockRoom = TestData.createRoom();
        final mockThread = TestData.createThread();

        // Act
        await tester.pumpWidget(
          createTestApp(
            home: Scaffold(body: ChatInput(onSend: (_) {})),
            overrides: [
              currentRoomProvider.overrideWith((ref) => mockRoom),
              currentThreadProvider.overrideWith((ref) => mockThread),
              activeRunNotifierOverride(const IdleState()),
            ],
          ),
        );

        await tester.enterText(find.byType(TextField), 'Test message');
        await tester.pump();

        await tester.tap(find.widgetWithIcon(IconButton, Icons.send));
        await tester.pump();

        // Assert
        final textField = tester.widget<TextField>(find.byType(TextField));
        expect(textField.controller?.text, isEmpty);
      });

      testWidgets('trims whitespace before sending', (tester) async {
        // Arrange
        final mockRoom = TestData.createRoom();
        final mockThread = TestData.createThread();
        String? sentText;

        // Act
        await tester.pumpWidget(
          createTestApp(
            home: Scaffold(body: ChatInput(onSend: (text) => sentText = text)),
            overrides: [
              currentRoomProvider.overrideWith((ref) => mockRoom),
              currentThreadProvider.overrideWith((ref) => mockThread),
              activeRunNotifierOverride(const IdleState()),
            ],
          ),
        );

        await tester.enterText(find.byType(TextField), '  Test message  ');
        await tester.pump();

        await tester.tap(find.widgetWithIcon(IconButton, Icons.send));
        await tester.pump();

        // Assert
        expect(sentText, 'Test message');
      });

      testWidgets('does not send empty message', (tester) async {
        // Arrange
        final mockRoom = TestData.createRoom();
        final mockThread = TestData.createThread();
        var sendCalled = false;

        // Act
        await tester.pumpWidget(
          createTestApp(
            home: Scaffold(body: ChatInput(onSend: (_) => sendCalled = true)),
            overrides: [
              currentRoomProvider.overrideWith((ref) => mockRoom),
              currentThreadProvider.overrideWith((ref) => mockThread),
              activeRunNotifierOverride(const IdleState()),
            ],
          ),
        );

        await tester.enterText(find.byType(TextField), '   ');
        await tester.pump();

        // Try to tap send button (should be disabled)
        final sendButton = tester.widget<IconButton>(
          find.widgetWithIcon(IconButton, Icons.send),
        );

        // Assert
        expect(sendButton.onPressed, isNull);
        expect(sendCalled, isFalse);
      });

      testWidgets('can send by pressing enter', (tester) async {
        // Arrange
        final mockRoom = TestData.createRoom();
        final mockThread = TestData.createThread();
        String? sentText;

        // Act
        await tester.pumpWidget(
          createTestApp(
            home: Scaffold(body: ChatInput(onSend: (text) => sentText = text)),
            overrides: [
              currentRoomProvider.overrideWith((ref) => mockRoom),
              currentThreadProvider.overrideWith((ref) => mockThread),
              activeRunNotifierOverride(const IdleState()),
            ],
          ),
        );

        // Focus the text field
        await tester.tap(find.byType(TextField));
        await tester.pump();

        await tester.enterText(find.byType(TextField), 'Test message');
        await tester.pump();

        // Send Enter key event
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();

        // Assert
        expect(sentText, 'Test message');
      });
    });

    group('Keyboard Shortcuts', () {
      testWidgets('Shift+Enter adds newline without sending', (tester) async {
        // Arrange
        final mockRoom = TestData.createRoom();
        final mockThread = TestData.createThread();
        var sendCalled = false;

        // Act
        await tester.pumpWidget(
          createTestApp(
            home: Scaffold(body: ChatInput(onSend: (_) => sendCalled = true)),
            overrides: [
              currentRoomProvider.overrideWith((ref) => mockRoom),
              currentThreadProvider.overrideWith((ref) => mockThread),
              activeRunNotifierOverride(const IdleState()),
            ],
          ),
        );

        // Focus the text field
        await tester.tap(find.byType(TextField));
        await tester.pump();

        // Type some text
        await tester.enterText(find.byType(TextField), 'Line 1');
        await tester.pump();

        // Simulate Shift+Enter
        await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);
        await tester.pump();

        // Assert - message should not be sent
        expect(sendCalled, isFalse);
      });

      testWidgets('Escape clears focus from input', (tester) async {
        // Arrange
        final mockRoom = TestData.createRoom();
        final mockThread = TestData.createThread();

        // Act
        await tester.pumpWidget(
          createTestApp(
            home: Scaffold(body: ChatInput(onSend: (_) {})),
            overrides: [
              currentRoomProvider.overrideWith((ref) => mockRoom),
              currentThreadProvider.overrideWith((ref) => mockThread),
              activeRunNotifierOverride(const IdleState()),
            ],
          ),
        );

        // Focus the text field
        await tester.tap(find.byType(TextField));
        await tester.pump();

        final textField = tester.widget<TextField>(find.byType(TextField));
        expect(textField.focusNode?.hasFocus, isTrue);

        // Simulate Escape key
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pump();

        // Assert - focus should be cleared
        expect(textField.focusNode?.hasFocus, isFalse);
      });
    });

    group('Visual Styling', () {
      testWidgets('send button has primary color when enabled', (tester) async {
        // Arrange
        final mockRoom = TestData.createRoom();
        final mockThread = TestData.createThread();

        // Act
        await tester.pumpWidget(
          createTestApp(
            home: Scaffold(body: ChatInput(onSend: (_) {})),
            overrides: [
              currentRoomProvider.overrideWith((ref) => mockRoom),
              currentThreadProvider.overrideWith((ref) => mockThread),
              activeRunNotifierOverride(const IdleState()),
            ],
          ),
        );

        await tester.enterText(find.byType(TextField), 'Test');
        await tester.pump();

        // Assert - send button should be styled
        final sendButton = tester.widget<IconButton>(
          find.widgetWithIcon(IconButton, Icons.send),
        );
        expect(sendButton.onPressed, isNotNull);
      });
    });

    group('Document Picker', () {
      testWidgets('shows attach file button when room is set', (tester) async {
        // Arrange
        final mockRoom = TestData.createRoom();
        final mockThread = TestData.createThread();

        // Act
        await tester.pumpWidget(
          createTestApp(
            home: Scaffold(
              body: ChatInput(onSend: (_) {}, roomId: mockRoom.id),
            ),
            overrides: [
              currentRoomProvider.overrideWith((ref) => mockRoom),
              currentThreadProvider.overrideWith((ref) => mockThread),
              activeRunNotifierOverride(const IdleState()),
            ],
          ),
        );

        // Assert
        expect(
          find.widgetWithIcon(IconButton, Icons.attach_file),
          findsOneWidget,
        );
      });

      testWidgets('hides attach file button when room is not set', (
        tester,
      ) async {
        // Act
        await tester.pumpWidget(
          createTestApp(
            home: Scaffold(
              body: ChatInput(
                onSend: (_) {},
                // roomId: null (not set)
              ),
            ),
            overrides: [
              currentRoomProvider.overrideWith((ref) => null),
              activeRunNotifierOverride(const IdleState()),
            ],
          ),
        );

        // Assert
        expect(
          find.widgetWithIcon(IconButton, Icons.attach_file),
          findsNothing,
        );
      });

      testWidgets('displays selected document above input', (tester) async {
        // Arrange
        final mockRoom = TestData.createRoom();
        final mockThread = TestData.createThread();
        final selectedDoc = TestData.createDocument(
          id: 'doc-1',
          title: 'Manual.pdf',
        );

        // Act
        await tester.pumpWidget(
          createTestApp(
            home: Scaffold(
              body: ChatInput(
                onSend: (_) {},
                roomId: mockRoom.id,
                selectedDocument: selectedDoc,
              ),
            ),
            overrides: [
              currentRoomProvider.overrideWith((ref) => mockRoom),
              currentThreadProvider.overrideWith((ref) => mockThread),
              activeRunNotifierOverride(const IdleState()),
            ],
          ),
        );

        // Assert
        expect(find.text('Manual.pdf'), findsOneWidget);
        expect(find.byIcon(Icons.description_outlined), findsOneWidget);
      });

      testWidgets('displays selected document as styled chip', (tester) async {
        // Arrange
        final mockRoom = TestData.createRoom();
        final mockThread = TestData.createThread();
        final selectedDoc = TestData.createDocument(
          id: 'doc-1',
          title: 'Manual.pdf',
        );

        // Act
        await tester.pumpWidget(
          createTestApp(
            home: Scaffold(
              body: ChatInput(
                onSend: (_) {},
                roomId: mockRoom.id,
                selectedDocument: selectedDoc,
              ),
            ),
            overrides: [
              currentRoomProvider.overrideWith((ref) => mockRoom),
              currentThreadProvider.overrideWith((ref) => mockThread),
              activeRunNotifierOverride(const IdleState()),
            ],
          ),
        );

        // Assert - chip shows document name and icon
        expect(find.text('Manual.pdf'), findsOneWidget);
        expect(find.byIcon(Icons.description_outlined), findsOneWidget);
        expect(find.byIcon(Icons.close), findsOneWidget);
      });

      testWidgets('chip truncates long paths to filename + 2 parents', (
        tester,
      ) async {
        // Arrange
        final mockRoom = TestData.createRoom();
        final mockThread = TestData.createThread();
        final selectedDoc = TestData.createDocument(
          id: 'doc-1',
          title: 'file:///Users/svarlet/Code/soliplex/docs/rag.md',
        );

        // Act
        await tester.pumpWidget(
          createTestApp(
            home: Scaffold(
              body: ChatInput(
                onSend: (_) {},
                roomId: mockRoom.id,
                selectedDocument: selectedDoc,
              ),
            ),
            overrides: [
              currentRoomProvider.overrideWith((ref) => mockRoom),
              currentThreadProvider.overrideWith((ref) => mockThread),
              activeRunNotifierOverride(const IdleState()),
            ],
          ),
        );

        // Assert - should show only last 3 path segments
        expect(find.text('soliplex/docs/rag.md'), findsOneWidget);
      });

      testWidgets('chip delete button removes selection', (tester) async {
        // Arrange
        final mockRoom = TestData.createRoom();
        final mockThread = TestData.createThread();
        final selectedDoc = TestData.createDocument(
          id: 'doc-1',
          title: 'Manual.pdf',
        );
        RagDocument? resultDoc = selectedDoc;

        // Act
        await tester.pumpWidget(
          createTestApp(
            home: Scaffold(
              body: ChatInput(
                onSend: (_) {},
                roomId: mockRoom.id,
                selectedDocument: selectedDoc,
                onDocumentSelected: (doc) => resultDoc = doc,
              ),
            ),
            overrides: [
              currentRoomProvider.overrideWith((ref) => mockRoom),
              currentThreadProvider.overrideWith((ref) => mockThread),
              activeRunNotifierOverride(const IdleState()),
            ],
          ),
        );

        // Tap the chip delete button via tooltip
        await tester.tap(find.byTooltip('Remove document filter'));
        await tester.pump();

        // Assert
        expect(resultDoc, isNull);
      });

      testWidgets('opens document picker dialog when attach button tapped', (
        tester,
      ) async {
        // Arrange
        final mockRoom = TestData.createRoom();
        final mockThread = TestData.createThread();
        final mockApi = MockSoliplexApi();
        final documents = [
          TestData.createDocument(id: 'doc-1', title: 'Document 1.pdf'),
          TestData.createDocument(id: 'doc-2', title: 'Document 2.pdf'),
        ];

        when(
          () => mockApi.getDocuments(mockRoom.id),
        ).thenAnswer((_) async => documents);

        // Act
        await tester.pumpWidget(
          createTestApp(
            home: Scaffold(
              body: ChatInput(onSend: (_) {}, roomId: mockRoom.id),
            ),
            overrides: [
              currentRoomProvider.overrideWith((ref) => mockRoom),
              currentThreadProvider.overrideWith((ref) => mockThread),
              activeRunNotifierOverride(const IdleState()),
              apiProvider.overrideWithValue(mockApi),
            ],
          ),
        );

        // Tap the attach button
        await tester.tap(find.widgetWithIcon(IconButton, Icons.attach_file));
        await tester.pumpAndSettle();

        // Assert - dialog should be open
        expect(find.text('Select a document'), findsOneWidget);
        expect(find.text('Document 1.pdf'), findsOneWidget);
        expect(find.text('Document 2.pdf'), findsOneWidget);
      });

      testWidgets('selects document when list tile tapped in picker', (
        tester,
      ) async {
        // Arrange
        final mockRoom = TestData.createRoom();
        final mockThread = TestData.createThread();
        final mockApi = MockSoliplexApi();
        final documents = [
          TestData.createDocument(id: 'doc-1', title: 'Document 1.pdf'),
          TestData.createDocument(id: 'doc-2', title: 'Document 2.pdf'),
        ];
        RagDocument? selectedDoc;

        when(
          () => mockApi.getDocuments(mockRoom.id),
        ).thenAnswer((_) async => documents);

        // Act
        await tester.pumpWidget(
          createTestApp(
            home: Scaffold(
              body: ChatInput(
                onSend: (_) {},
                roomId: mockRoom.id,
                onDocumentSelected: (doc) => selectedDoc = doc,
              ),
            ),
            overrides: [
              currentRoomProvider.overrideWith((ref) => mockRoom),
              currentThreadProvider.overrideWith((ref) => mockThread),
              activeRunNotifierOverride(const IdleState()),
              apiProvider.overrideWithValue(mockApi),
            ],
          ),
        );

        // Open picker
        await tester.tap(find.widgetWithIcon(IconButton, Icons.attach_file));
        await tester.pumpAndSettle();

        // Tap on the first document
        await tester.tap(find.text('Document 1.pdf'));
        await tester.pumpAndSettle();

        // Assert
        expect(selectedDoc?.id, equals('doc-1'));
        expect(selectedDoc?.title, equals('Document 1.pdf'));
      });

      testWidgets('shows empty state when no documents in room', (
        tester,
      ) async {
        // Arrange
        final mockRoom = TestData.createRoom();
        final mockThread = TestData.createThread();
        final mockApi = MockSoliplexApi();

        when(
          () => mockApi.getDocuments(mockRoom.id),
        ).thenAnswer((_) async => <RagDocument>[]);

        // Act
        await tester.pumpWidget(
          createTestApp(
            home: Scaffold(
              body: ChatInput(onSend: (_) {}, roomId: mockRoom.id),
            ),
            overrides: [
              currentRoomProvider.overrideWith((ref) => mockRoom),
              currentThreadProvider.overrideWith((ref) => mockThread),
              activeRunNotifierOverride(const IdleState()),
              apiProvider.overrideWithValue(mockApi),
            ],
          ),
        );

        // Open picker
        await tester.tap(find.widgetWithIcon(IconButton, Icons.attach_file));
        await tester.pumpAndSettle();

        // Assert
        expect(find.text('No documents in this room.'), findsOneWidget);
      });
    });
  });
}
