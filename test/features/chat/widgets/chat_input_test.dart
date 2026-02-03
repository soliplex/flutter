import 'dart:async';

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
  group('formatDocumentTitle', () {
    test('removes file:// prefix and shows up to 2 parent folders', () {
      expect(
        formatDocumentTitle('file:///path/to/my/favorite/document.txt'),
        equals('my/favorite/document.txt'),
      );
    });

    test('handles paths without file:// prefix', () {
      expect(
        formatDocumentTitle('/path/to/file.pdf'),
        equals('path/to/file.pdf'),
      );
    });

    test('handles deep paths', () {
      expect(formatDocumentTitle('/a/b/c/d/e/f.txt'), equals('d/e/f.txt'));
    });

    test('handles short paths', () {
      expect(
        formatDocumentTitle('/parent/file.txt'),
        equals('parent/file.txt'),
      );
    });

    test('handles filename only', () {
      expect(formatDocumentTitle('document.txt'), equals('document.txt'));
    });

    test('handles paths with exactly 3 segments', () {
      expect(formatDocumentTitle('/a/b/c.txt'), equals('a/b/c.txt'));
    });
  });

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
        final mockApi = MockSoliplexApi();
        final documents = [
          TestData.createDocument(id: 'doc-1', title: 'Document 1.pdf'),
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

        // Assert
        expect(
          find.widgetWithIcon(IconButton, Icons.filter_alt),
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
          find.widgetWithIcon(IconButton, Icons.filter_alt),
          findsNothing,
        );
      });

      testWidgets('displays selected document above input', (tester) async {
        // Arrange
        final mockRoom = TestData.createRoom();
        final mockThread = TestData.createThread();
        final mockApi = MockSoliplexApi();
        final selectedDoc = TestData.createDocument(
          id: 'doc-1',
          title: 'Manual.pdf',
        );

        when(
          () => mockApi.getDocuments(mockRoom.id),
        ).thenAnswer((_) async => [selectedDoc]);

        // Act
        await tester.pumpWidget(
          createTestApp(
            home: Scaffold(
              body: ChatInput(
                onSend: (_) {},
                roomId: mockRoom.id,
                selectedDocuments: {selectedDoc},
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

        // Assert
        expect(find.text('Manual.pdf'), findsOneWidget);
        expect(find.byIcon(Icons.description), findsOneWidget);
      });

      testWidgets('removes document when close button tapped', (tester) async {
        // Arrange
        final mockRoom = TestData.createRoom();
        final mockThread = TestData.createThread();
        final mockApi = MockSoliplexApi();
        final selectedDoc = TestData.createDocument(
          id: 'doc-1',
          title: 'Manual.pdf',
        );
        var resultDocs = <RagDocument>{selectedDoc};

        when(
          () => mockApi.getDocuments(mockRoom.id),
        ).thenAnswer((_) async => [selectedDoc]);

        // Act
        await tester.pumpWidget(
          createTestApp(
            home: Scaffold(
              body: ChatInput(
                onSend: (_) {},
                roomId: mockRoom.id,
                selectedDocuments: {selectedDoc},
                onDocumentsChanged: (docs) => resultDocs = docs,
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

        // Tap the chip delete button via tooltip
        await tester.tap(find.byTooltip('Remove document filter'));
        await tester.pump();

        // Assert
        expect(resultDocs, isEmpty);
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
        await tester.tap(find.widgetWithIcon(IconButton, Icons.filter_alt));
        await tester.pumpAndSettle();

        // Assert - dialog should be open with checkboxes
        expect(find.text('Select documents'), findsOneWidget);
        expect(find.text('Document 1.pdf'), findsOneWidget);
        expect(find.text('Document 2.pdf'), findsOneWidget);
        expect(find.byType(CheckboxListTile), findsNWidgets(2));
      });

      testWidgets('selects document when checkbox tapped and Done pressed', (
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
        var selectedDocs = <RagDocument>{};

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
                onDocumentsChanged: (docs) => selectedDocs = docs,
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
        await tester.tap(find.widgetWithIcon(IconButton, Icons.filter_alt));
        await tester.pumpAndSettle();

        // Tap on the first document checkbox
        await tester.tap(find.text('Document 1.pdf'));
        await tester.pump();

        // Tap Done
        await tester.tap(find.text('Done'));
        await tester.pumpAndSettle();

        // Assert
        expect(selectedDocs.length, equals(1));
        expect(selectedDocs.first.id, equals('doc-1'));
        expect(selectedDocs.first.title, equals('Document 1.pdf'));
      });

      testWidgets('picker button is disabled when room has no documents', (
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
        await tester.pumpAndSettle();

        // Assert - button should be disabled
        final attachButton = tester.widget<IconButton>(
          find.widgetWithIcon(IconButton, Icons.filter_alt),
        );
        expect(attachButton.onPressed, isNull);
      });

      testWidgets('picker button is enabled when room has documents', (
        tester,
      ) async {
        // Arrange
        final mockRoom = TestData.createRoom();
        final mockThread = TestData.createThread();
        final mockApi = MockSoliplexApi();
        final documents = [
          TestData.createDocument(id: 'doc-1', title: 'Document 1.pdf'),
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
        await tester.pumpAndSettle();

        // Assert - button should be enabled
        final attachButton = tester.widget<IconButton>(
          find.widgetWithIcon(IconButton, Icons.filter_alt),
        );
        expect(attachButton.onPressed, isNotNull);
      });

      testWidgets('picker button tooltip explains disabled state', (
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
        await tester.pumpAndSettle();

        // Assert - tooltip should explain why disabled
        final attachButton = tester.widget<IconButton>(
          find.widgetWithIcon(IconButton, Icons.filter_alt),
        );
        expect(attachButton.tooltip, 'No documents in this room');
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
        await tester.tap(find.widgetWithIcon(IconButton, Icons.filter_alt));
        await tester.pumpAndSettle();

        // Assert
        expect(find.text('No documents in this room.'), findsOneWidget);
      });

      testWidgets('can select multiple documents', (tester) async {
        // Arrange
        final mockRoom = TestData.createRoom();
        final mockThread = TestData.createThread();
        final mockApi = MockSoliplexApi();
        final documents = [
          TestData.createDocument(id: 'doc-1', title: 'Document 1.pdf'),
          TestData.createDocument(id: 'doc-2', title: 'Document 2.pdf'),
          TestData.createDocument(id: 'doc-3', title: 'Document 3.pdf'),
        ];
        var selectedDocs = <RagDocument>{};

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
                onDocumentsChanged: (docs) => selectedDocs = docs,
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
        await tester.tap(find.widgetWithIcon(IconButton, Icons.filter_alt));
        await tester.pumpAndSettle();

        // Select first and third documents
        await tester.tap(find.text('Document 1.pdf'));
        await tester.pump();
        await tester.tap(find.text('Document 3.pdf'));
        await tester.pump();

        // Tap Done
        await tester.tap(find.text('Done'));
        await tester.pumpAndSettle();

        // Assert
        expect(selectedDocs.length, equals(2));
        expect(
          selectedDocs.map((d) => d.id).toSet(),
          equals({'doc-1', 'doc-3'}),
        );
      });

      testWidgets('checkboxes toggle correctly', (tester) async {
        // Arrange
        final mockRoom = TestData.createRoom();
        final mockThread = TestData.createThread();
        final mockApi = MockSoliplexApi();
        final documents = [
          TestData.createDocument(id: 'doc-1', title: 'Document 1.pdf'),
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

        // Open picker
        await tester.tap(find.widgetWithIcon(IconButton, Icons.filter_alt));
        await tester.pumpAndSettle();

        // Checkbox should start unchecked
        var checkbox = tester.widget<CheckboxListTile>(
          find.byType(CheckboxListTile),
        );
        expect(checkbox.value, isFalse);

        // Tap to check
        await tester.tap(find.text('Document 1.pdf'));
        await tester.pump();

        checkbox = tester.widget<CheckboxListTile>(
          find.byType(CheckboxListTile),
        );
        expect(checkbox.value, isTrue);

        // Tap again to uncheck
        await tester.tap(find.text('Document 1.pdf'));
        await tester.pump();

        checkbox = tester.widget<CheckboxListTile>(
          find.byType(CheckboxListTile),
        );
        expect(checkbox.value, isFalse);
      });

      testWidgets('displays multiple selected documents', (tester) async {
        // Arrange
        final mockRoom = TestData.createRoom();
        final mockThread = TestData.createThread();
        final mockApi = MockSoliplexApi();
        final doc1 = TestData.createDocument(id: 'doc-1', title: 'Doc1.pdf');
        final doc2 = TestData.createDocument(id: 'doc-2', title: 'Doc2.pdf');

        when(
          () => mockApi.getDocuments(mockRoom.id),
        ).thenAnswer((_) async => [doc1, doc2]);

        // Act
        await tester.pumpWidget(
          createTestApp(
            home: Scaffold(
              body: ChatInput(
                onSend: (_) {},
                roomId: mockRoom.id,
                selectedDocuments: {doc1, doc2},
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

        // Assert
        expect(find.text('Doc1.pdf'), findsOneWidget);
        expect(find.text('Doc2.pdf'), findsOneWidget);
        expect(find.byIcon(Icons.description), findsNWidgets(2));
        expect(find.byIcon(Icons.close), findsNWidgets(2));
      });

      testWidgets('preserves initial selection when opening picker', (
        tester,
      ) async {
        // Arrange
        final mockRoom = TestData.createRoom();
        final mockThread = TestData.createThread();
        final mockApi = MockSoliplexApi();
        final doc1 = TestData.createDocument(id: 'doc-1', title: 'Doc1.pdf');
        final doc2 = TestData.createDocument(id: 'doc-2', title: 'Doc2.pdf');
        final documents = [doc1, doc2];

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
                selectedDocuments: {doc1},
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
        await tester.tap(find.widgetWithIcon(IconButton, Icons.filter_alt));
        await tester.pumpAndSettle();

        // Assert - first doc should be pre-selected
        final checkboxes = tester
            .widgetList<CheckboxListTile>(find.byType(CheckboxListTile))
            .toList();
        expect(checkboxes[0].value, isTrue);
        expect(checkboxes[1].value, isFalse);
      });
    });

    group('Suggestions', () {
      testWidgets('displays suggestion chips when showSuggestions is true', (
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
              body: ChatInput(
                onSend: (_) {},
                roomId: mockRoom.id,
                suggestions: const ['How can I help?', 'Tell me more'],
                showSuggestions: true,
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

        // Assert
        expect(find.text('How can I help?'), findsOneWidget);
        expect(find.text('Tell me more'), findsOneWidget);
        expect(find.byType(ActionChip), findsNWidgets(2));
      });

      testWidgets('hides suggestion chips when showSuggestions is false', (
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
              body: ChatInput(
                onSend: (_) {},
                roomId: mockRoom.id,
                suggestions: const ['How can I help?', 'Tell me more'],
                // showSuggestions defaults to false
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

        // Assert
        expect(find.text('How can I help?'), findsNothing);
        expect(find.text('Tell me more'), findsNothing);
        expect(find.byType(ActionChip), findsNothing);
      });

      testWidgets('calls onSend when suggestion chip is tapped', (
        tester,
      ) async {
        // Arrange
        final mockRoom = TestData.createRoom();
        final mockThread = TestData.createThread();
        final mockApi = MockSoliplexApi();
        String? sentText;

        when(
          () => mockApi.getDocuments(mockRoom.id),
        ).thenAnswer((_) async => <RagDocument>[]);

        // Act
        await tester.pumpWidget(
          createTestApp(
            home: Scaffold(
              body: ChatInput(
                onSend: (text) => sentText = text,
                roomId: mockRoom.id,
                suggestions: const ['How can I help?'],
                showSuggestions: true,
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

        // Tap the suggestion chip
        await tester.tap(find.text('How can I help?'));
        await tester.pump();

        // Assert
        expect(sentText, equals('How can I help?'));
      });

      testWidgets('shows nothing when suggestions list is empty', (
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
              body: ChatInput(
                onSend: (_) {},
                roomId: mockRoom.id,
                // suggestions defaults to empty list
                showSuggestions: true,
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

        // Assert
        expect(find.byType(ActionChip), findsNothing);
      });
    });

    group('Document Picker Loading', () {
      testWidgets('shows spinner while documents are loading', (tester) async {
        // Arrange
        final mockRoom = TestData.createRoom();
        final mockThread = TestData.createThread();
        final mockApi = MockSoliplexApi();

        // Use a Completer to keep the future pending
        final completer = Completer<List<RagDocument>>();
        when(
          () => mockApi.getDocuments(mockRoom.id),
        ).thenAnswer((_) => completer.future);

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
        await tester.tap(find.widgetWithIcon(IconButton, Icons.filter_alt));
        await tester.pump();

        // Assert - spinner should be visible
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.byType(CheckboxListTile), findsNothing);
      });

      testWidgets('list appears after loading completes', (tester) async {
        // Arrange
        final mockRoom = TestData.createRoom();
        final mockThread = TestData.createThread();
        final mockApi = MockSoliplexApi();
        final documents = [
          TestData.createDocument(id: 'doc-1', title: 'Document 1.pdf'),
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

        // Open picker
        await tester.tap(find.widgetWithIcon(IconButton, Icons.filter_alt));
        await tester.pumpAndSettle();

        // Assert - list should be visible, spinner should be gone
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(find.byType(CheckboxListTile), findsOneWidget);
      });

      testWidgets('Done button is disabled while loading', (tester) async {
        // Arrange
        final mockRoom = TestData.createRoom();
        final mockThread = TestData.createThread();
        final mockApi = MockSoliplexApi();

        // Use a Completer to keep the future pending
        final completer = Completer<List<RagDocument>>();
        when(
          () => mockApi.getDocuments(mockRoom.id),
        ).thenAnswer((_) => completer.future);

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
        await tester.tap(find.widgetWithIcon(IconButton, Icons.filter_alt));
        await tester.pump();

        // Assert - Done button should be disabled
        final doneButton = tester.widget<TextButton>(
          find.widgetWithText(TextButton, 'Done'),
        );
        expect(doneButton.onPressed, isNull);
      });

      testWidgets('Done button is enabled after loading completes', (
        tester,
      ) async {
        // Arrange
        final mockRoom = TestData.createRoom();
        final mockThread = TestData.createThread();
        final mockApi = MockSoliplexApi();
        final documents = [
          TestData.createDocument(id: 'doc-1', title: 'Document 1.pdf'),
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

        // Open picker
        await tester.tap(find.widgetWithIcon(IconButton, Icons.filter_alt));
        await tester.pumpAndSettle();

        // Assert - Done button should be enabled
        final doneButton = tester.widget<TextButton>(
          find.widgetWithText(TextButton, 'Done'),
        );
        expect(doneButton.onPressed, isNotNull);
      });
    });

    group('Document Picker Search', () {
      testWidgets('search field is visible in picker', (tester) async {
        // Arrange
        final mockRoom = TestData.createRoom();
        final mockThread = TestData.createThread();
        final mockApi = MockSoliplexApi();
        final documents = [
          TestData.createDocument(id: 'doc-1', title: 'Document 1.pdf'),
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

        // Open picker
        await tester.tap(find.widgetWithIcon(IconButton, Icons.filter_alt));
        await tester.pumpAndSettle();

        // Assert
        expect(find.byIcon(Icons.search), findsOneWidget);
        expect(find.text('Search documents...'), findsOneWidget);
      });

      testWidgets('typing filters the document list', (tester) async {
        // Arrange
        final mockRoom = TestData.createRoom();
        final mockThread = TestData.createThread();
        final mockApi = MockSoliplexApi();
        final documents = [
          TestData.createDocument(id: 'doc-1', title: 'Report.pdf'),
          TestData.createDocument(id: 'doc-2', title: 'Manual.pdf'),
          TestData.createDocument(id: 'doc-3', title: 'Notes.txt'),
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

        // Open picker
        await tester.tap(find.widgetWithIcon(IconButton, Icons.filter_alt));
        await tester.pumpAndSettle();

        // All documents should be visible
        expect(find.text('Report.pdf'), findsOneWidget);
        expect(find.text('Manual.pdf'), findsOneWidget);
        expect(find.text('Notes.txt'), findsOneWidget);

        // Type in search field
        final searchFieldFinder = find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        );
        await tester.enterText(searchFieldFinder, 'pdf');
        await tester.pumpAndSettle();

        // Assert - only pdf files should be visible
        expect(find.text('Report.pdf'), findsOneWidget);
        expect(find.text('Manual.pdf'), findsOneWidget);
        expect(find.text('Notes.txt'), findsNothing);
      });

      testWidgets('search is case-insensitive', (tester) async {
        // Arrange
        final mockRoom = TestData.createRoom();
        final mockThread = TestData.createThread();
        final mockApi = MockSoliplexApi();
        final documents = [
          TestData.createDocument(id: 'doc-1', title: 'Report.PDF'),
          TestData.createDocument(id: 'doc-2', title: 'manual.pdf'),
          TestData.createDocument(id: 'doc-3', title: 'Notes.txt'),
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

        // Open picker
        await tester.tap(find.widgetWithIcon(IconButton, Icons.filter_alt));
        await tester.pumpAndSettle();

        // Search with different case
        final searchFieldFinder = find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        );
        await tester.enterText(searchFieldFinder, 'PDF');
        await tester.pumpAndSettle();

        // Assert - both PDF and pdf should match
        expect(find.text('Report.PDF'), findsOneWidget);
        expect(find.text('manual.pdf'), findsOneWidget);
        expect(find.text('Notes.txt'), findsNothing);
      });

      testWidgets('shows "No matches" when filter yields empty', (
        tester,
      ) async {
        // Arrange
        final mockRoom = TestData.createRoom();
        final mockThread = TestData.createThread();
        final mockApi = MockSoliplexApi();
        final documents = [
          TestData.createDocument(id: 'doc-1', title: 'Report.pdf'),
          TestData.createDocument(id: 'doc-2', title: 'Manual.pdf'),
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

        // Open picker
        await tester.tap(find.widgetWithIcon(IconButton, Icons.filter_alt));
        await tester.pumpAndSettle();

        // Search for something that doesn't exist
        final searchFieldFinder = find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        );
        await tester.enterText(searchFieldFinder, 'xyz123');
        await tester.pumpAndSettle();

        // Assert
        expect(find.text('No matches'), findsOneWidget);
        expect(find.byType(CheckboxListTile), findsNothing);
      });

      testWidgets('search field is auto-focused on open', (tester) async {
        // Arrange
        final mockRoom = TestData.createRoom();
        final mockThread = TestData.createThread();
        final mockApi = MockSoliplexApi();
        final documents = [
          TestData.createDocument(id: 'doc-1', title: 'Document 1.pdf'),
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

        // Open picker
        await tester.tap(find.widgetWithIcon(IconButton, Icons.filter_alt));
        await tester.pumpAndSettle();

        // Assert - search field in dialog should have autofocus enabled
        final searchFieldFinder = find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        );
        final searchField = tester.widget<TextField>(searchFieldFinder);
        expect(searchField.autofocus, isTrue);
      });

      testWidgets('clearing search shows all documents again', (tester) async {
        // Arrange
        final mockRoom = TestData.createRoom();
        final mockThread = TestData.createThread();
        final mockApi = MockSoliplexApi();
        final documents = [
          TestData.createDocument(id: 'doc-1', title: 'Report.pdf'),
          TestData.createDocument(id: 'doc-2', title: 'Notes.txt'),
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

        // Open picker
        await tester.tap(find.widgetWithIcon(IconButton, Icons.filter_alt));
        await tester.pumpAndSettle();

        // Find the search field inside the dialog
        final searchFieldFinder = find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        );

        // Filter to only pdf
        await tester.enterText(searchFieldFinder, 'pdf');
        await tester.pumpAndSettle();
        expect(find.text('Notes.txt'), findsNothing);

        // Clear search
        await tester.enterText(searchFieldFinder, '');
        await tester.pumpAndSettle();

        // Assert - all documents visible again
        expect(find.text('Report.pdf'), findsOneWidget);
        expect(find.text('Notes.txt'), findsOneWidget);
      });

      testWidgets('selected documents remain selected after filtering', (
        tester,
      ) async {
        // Arrange
        final mockRoom = TestData.createRoom();
        final mockThread = TestData.createThread();
        final mockApi = MockSoliplexApi();
        final documents = [
          TestData.createDocument(id: 'doc-1', title: 'Report.pdf'),
          TestData.createDocument(id: 'doc-2', title: 'Notes.txt'),
        ];
        var selectedDocs = <RagDocument>{};

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
                onDocumentsChanged: (docs) => selectedDocs = docs,
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
        await tester.tap(find.widgetWithIcon(IconButton, Icons.filter_alt));
        await tester.pumpAndSettle();

        // Find the search field inside the dialog
        final searchFieldFinder = find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        );

        // Select the Report.pdf
        await tester.tap(find.text('Report.pdf'));
        await tester.pump();

        // Filter to only txt
        await tester.enterText(searchFieldFinder, 'txt');
        await tester.pumpAndSettle();

        // Clear filter
        await tester.enterText(searchFieldFinder, '');
        await tester.pumpAndSettle();

        // The Report.pdf should still be selected
        final checkboxes = tester
            .widgetList<CheckboxListTile>(find.byType(CheckboxListTile))
            .toList();
        expect(checkboxes[0].value, isTrue); // Report.pdf
        expect(checkboxes[1].value, isFalse); // Notes.txt

        // Confirm and check
        await tester.tap(find.text('Done'));
        await tester.pumpAndSettle();

        expect(selectedDocs.length, equals(1));
        expect(selectedDocs.first.title, equals('Report.pdf'));
      });
    });
  });
}
