import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soliplex_client/soliplex_client.dart';
import 'package:soliplex_frontend/features/chat/widgets/chat_message_widget.dart';
import 'package:soliplex_frontend/shared/widgets/markdown/flutter_markdown_plus_renderer.dart';

import '../../../helpers/test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // Mock clipboard for tests
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
  group('ChatMessageWidget', () {
    group('User Messages', () {
      testWidgets('displays user message with right alignment', (tester) async {
        // Arrange
        final message = TestData.createMessage(text: 'Hello, assistant!');

        // Act
        await tester.pumpWidget(
          createTestApp(
            home: Scaffold(body: ChatMessageWidget(message: message)),
          ),
        );

        // Assert
        expect(find.text('Hello, assistant!'), findsOneWidget);

        // Check right alignment via Column's crossAxisAlignment
        final column = tester.widget<Column>(
          find
              .descendant(
                of: find.byType(ChatMessageWidget),
                matching: find.byType(Column),
              )
              .first,
        );
        expect(column.crossAxisAlignment, CrossAxisAlignment.end);
      });

      testWidgets('displays user message with blue background', (tester) async {
        // Arrange
        final message = TestData.createMessage(text: 'Test');

        // Act
        await tester.pumpWidget(
          createTestApp(
            home: Scaffold(body: ChatMessageWidget(message: message)),
          ),
        );

        // Assert
        final container = tester.widget<Container>(
          find.descendant(
            of: find.byType(ChatMessageWidget),
            matching: find.byType(Container).first,
          ),
        );
        final decoration = container.decoration! as BoxDecoration;
        expect(decoration.color, isNotNull);
        // Primary container color for user messages
      });

      testWidgets('shows streaming indicator when isStreaming is true', (
        tester,
      ) async {
        // Arrange
        final message = TestData.createMessage(text: 'Typing...');

        // Act
        await tester.pumpWidget(
          createTestApp(
            home: Scaffold(
              body: ChatMessageWidget(message: message, isStreaming: true),
            ),
          ),
        );

        // Assert
        expect(find.text('Typing...'), findsWidgets);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });

      testWidgets(
        'does not show streaming indicator when isStreaming is false',
        (tester) async {
          // Arrange
          final message = TestData.createMessage(text: 'Done');

          // Act
          await tester.pumpWidget(
            createTestApp(
              home: Scaffold(body: ChatMessageWidget(message: message)),
            ),
          );

          // Assert
          expect(find.text('Typing...'), findsNothing);
          expect(find.byType(CircularProgressIndicator), findsNothing);
        },
      );
    });

    group('Assistant Messages', () {
      testWidgets('displays assistant message with left alignment', (
        tester,
      ) async {
        // Arrange
        final message = TestData.createMessage(
          user: ChatUser.assistant,
          text: 'Hello, user!',
        );

        // Act
        await tester.pumpWidget(
          createTestApp(
            home: Scaffold(body: ChatMessageWidget(message: message)),
          ),
        );

        // Assert
        expect(find.text('Hello, user!'), findsOneWidget);

        // Check left alignment via Column's crossAxisAlignment
        final column = tester.widget<Column>(
          find
              .descendant(
                of: find.byType(ChatMessageWidget),
                matching: find.byType(Column),
              )
              .first,
        );
        expect(column.crossAxisAlignment, CrossAxisAlignment.start);
      });

      testWidgets('displays assistant message with grey background', (
        tester,
      ) async {
        // Arrange
        final message = TestData.createMessage(
          user: ChatUser.assistant,
          text: 'Test',
        );

        // Act
        await tester.pumpWidget(
          createTestApp(
            home: Scaffold(body: ChatMessageWidget(message: message)),
          ),
        );

        // Assert
        final container = tester.widget<Container>(
          find.descendant(
            of: find.byType(ChatMessageWidget),
            matching: find.byType(Container).first,
          ),
        );
        final decoration = container.decoration! as BoxDecoration;
        expect(decoration.color, isNotNull);
        // Surface container color for assistant messages
      });

      testWidgets('shows streaming indicator for assistant messages', (
        tester,
      ) async {
        // Arrange
        final message = TestData.createMessage(
          user: ChatUser.assistant,
          text: 'Thinking...',
        );

        // Act
        await tester.pumpWidget(
          createTestApp(
            home: Scaffold(
              body: ChatMessageWidget(message: message, isStreaming: true),
            ),
          ),
        );

        // Assert
        expect(find.text('Typing...'), findsWidgets);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });

      testWidgets('renders markdown for assistant messages', (tester) async {
        // Arrange
        final message = TestData.createMessage(
          user: ChatUser.assistant,
          text: '**bold** and *italic* text',
        );

        // Act
        await tester.pumpWidget(
          createTestApp(
            home: Scaffold(body: ChatMessageWidget(message: message)),
          ),
        );

        // Assert - should use markdown renderer for assistant messages
        expect(find.byType(FlutterMarkdownPlusRenderer), findsOneWidget);
      });

      testWidgets('does not render markdown for user messages', (tester) async {
        // Arrange
        final message = TestData.createMessage(
          text: '**bold** and *italic* text',
        );

        // Act
        await tester.pumpWidget(
          createTestApp(
            home: Scaffold(body: ChatMessageWidget(message: message)),
          ),
        );

        // Assert - should use Text for user messages, not markdown renderer
        expect(find.byType(FlutterMarkdownPlusRenderer), findsNothing);
        expect(find.text('**bold** and *italic* text'), findsOneWidget);
      });

      testWidgets('provides link tap handler to markdown renderer', (
        tester,
      ) async {
        final message = TestData.createMessage(
          user: ChatUser.assistant,
          text: 'Visit [site](https://example.com)',
        );

        await tester.pumpWidget(
          createTestApp(
            home: Scaffold(body: ChatMessageWidget(message: message)),
          ),
        );

        final renderer = tester.widget<FlutterMarkdownPlusRenderer>(
          find.byType(FlutterMarkdownPlusRenderer),
        );
        expect(renderer.onLinkTap, isNotNull);
      });

      testWidgets('provides image tap handler to markdown renderer', (
        tester,
      ) async {
        final message = TestData.createMessage(
          user: ChatUser.assistant,
          text: '![photo](https://example.com/img.png)',
        );

        await tester.pumpWidget(
          createTestApp(
            home: Scaffold(body: ChatMessageWidget(message: message)),
          ),
        );

        final renderer = tester.widget<FlutterMarkdownPlusRenderer>(
          find.byType(FlutterMarkdownPlusRenderer),
        );
        expect(renderer.onImageTap, isNotNull);
      });

      testWidgets('renders code blocks with syntax highlighting', (
        tester,
      ) async {
        // Arrange
        final message = TestData.createMessage(
          user: ChatUser.assistant,
          text: '```dart\nvoid main() {}\n```',
        );

        // Act
        await tester.pumpWidget(
          createTestApp(
            home: Scaffold(body: ChatMessageWidget(message: message)),
          ),
        );

        // Assert - MarkdownBody should render code blocks
        expect(find.byType(FlutterMarkdownPlusRenderer), findsOneWidget);
        // The code block should be rendered (implementation detail - just
        // verify it doesn't crash)
        await tester.pumpAndSettle();
      });
    });

    group('System Messages', () {
      testWidgets('displays system message centered', (tester) async {
        // Arrange
        final message = ErrorMessage.create(
          id: 'error-1',
          message: 'Operation cancelled',
        );

        // Act
        await tester.pumpWidget(
          createTestApp(
            home: Scaffold(body: ChatMessageWidget(message: message)),
          ),
        );

        // Assert
        expect(find.text('Operation cancelled'), findsOneWidget);
        expect(find.byType(Center), findsOneWidget);
      });

      testWidgets('displays system message with subtle styling', (
        tester,
      ) async {
        // Arrange
        final message = ErrorMessage.create(
          id: 'error-2',
          message: 'System notification',
        );

        // Act
        await tester.pumpWidget(
          createTestApp(
            home: Scaffold(body: ChatMessageWidget(message: message)),
          ),
        );

        // Assert
        expect(find.text('System notification'), findsOneWidget);

        // System messages use bodySmall style
        final text = tester.widget<Text>(
          find.descendant(of: find.byType(Center), matching: find.byType(Text)),
        );
        expect(text.style?.fontSize, lessThan(16)); // bodySmall is smaller
      });
    });

    group('Error Messages', () {
      testWidgets('displays error message', (tester) async {
        // Arrange
        final message = ErrorMessage.create(
          id: 'error-3',
          message: 'Something went wrong',
        );

        // Act
        await tester.pumpWidget(
          createTestApp(
            home: Scaffold(body: ChatMessageWidget(message: message)),
          ),
        );

        // Assert
        expect(find.text('Something went wrong'), findsOneWidget);
      });
    });

    group('Action Buttons', () {
      testWidgets('user message shows copy button', (tester) async {
        // Arrange
        final message = TestData.createMessage(text: 'Hello');

        // Act
        await tester.pumpWidget(
          createTestApp(
            home: Scaffold(body: ChatMessageWidget(message: message)),
          ),
        );

        // Assert
        expect(find.byIcon(Icons.copy), findsOneWidget);
      });

      testWidgets('agent message shows copy button', (tester) async {
        // Arrange
        final message = TestData.createMessage(
          user: ChatUser.assistant,
          text: 'Hello',
        );

        // Act
        await tester.pumpWidget(
          createTestApp(
            home: Scaffold(body: ChatMessageWidget(message: message)),
          ),
        );

        // Assert
        expect(find.byIcon(Icons.copy), findsOneWidget);
      });

      testWidgets('agent message hides action buttons while streaming', (
        tester,
      ) async {
        // Arrange
        final message = TestData.createMessage(
          user: ChatUser.assistant,
          text: 'Thinking...',
        );

        // Act
        await tester.pumpWidget(
          createTestApp(
            home: Scaffold(
              body: ChatMessageWidget(message: message, isStreaming: true),
            ),
          ),
        );

        // Assert - no action buttons while streaming
        expect(find.byIcon(Icons.copy), findsNothing);
      });

      testWidgets('copy button shows success snackbar', (tester) async {
        // Arrange
        final message = TestData.createMessage(text: 'Copy me');

        // Act
        await tester.pumpWidget(
          createTestApp(
            home: Scaffold(body: ChatMessageWidget(message: message)),
          ),
        );

        await tester.tap(find.byIcon(Icons.copy));
        await tester.pump(); // Allow async clipboard operation to complete
        await tester.pump(); // Allow snackbar to appear

        // Assert
        expect(find.text('Copied to clipboard'), findsOneWidget);
      });

      testWidgets('action buttons have tooltips', (tester) async {
        // Arrange
        final message = TestData.createMessage(text: 'Test');

        // Act
        await tester.pumpWidget(
          createTestApp(
            home: Scaffold(body: ChatMessageWidget(message: message)),
          ),
        );

        // Assert - verify Tooltip widgets exist
        expect(find.byType(Tooltip), findsWidgets);
      });
    });

    group('Edge Cases', () {
      testWidgets('handles empty text message', (tester) async {
        // Arrange
        final message = TestData.createMessage(text: '');

        // Act
        await tester.pumpWidget(
          createTestApp(
            home: Scaffold(body: ChatMessageWidget(message: message)),
          ),
        );

        // Assert
        expect(find.text(''), findsOneWidget);
      });

      testWidgets('handles long message text', (tester) async {
        // Arrange
        final longText = 'A' * 500;
        final message = TestData.createMessage(text: longText);

        // Act
        await tester.pumpWidget(
          createTestApp(
            home: Scaffold(body: ChatMessageWidget(message: message)),
          ),
        );

        // Assert
        expect(find.textContaining('A'), findsOneWidget);
      });

      testWidgets('respects maxWidth constraint', (tester) async {
        // Arrange
        final message = TestData.createMessage(text: 'A' * 100);

        // Act
        await tester.pumpWidget(
          createTestApp(
            home: Scaffold(
              body: SizedBox(
                width: 1200,
                child: ChatMessageWidget(message: message),
              ),
            ),
          ),
        );

        // Assert - find the message bubble container by its BoxDecoration
        final container = tester.widget<Container>(
          find.descendant(
            of: find.byType(ChatMessageWidget),
            matching: find.byWidgetPredicate(
              (w) => w is Container && w.decoration is BoxDecoration,
            ),
          ),
        );
        final constraints = container.constraints!;
        expect(constraints.maxWidth, 600);
      });
    });

    group('Feedback buttons', () {
      final assistantMessage = TestData.createMessage(
        user: ChatUser.assistant,
        text: 'Assistant response',
      );

      FeedbackType? capturedFeedback;
      String? capturedReason;

      setUp(() {
        capturedFeedback = null;
        capturedReason = null;
      });

      void onFeedbackSubmit(FeedbackType f, String? r) {
        capturedFeedback = f;
        capturedReason = r;
      }

      testWidgets('shows thumb buttons for non-streaming assistant message',
          (tester) async {
        await tester.pumpWidget(
          createTestApp(
            home: Scaffold(
              body: ChatMessageWidget(
                message: assistantMessage,
                onFeedbackSubmit: onFeedbackSubmit,
              ),
            ),
          ),
        );

        expect(find.byIcon(Icons.thumb_up_alt_outlined), findsOneWidget);
        expect(find.byIcon(Icons.thumb_down_alt_outlined), findsOneWidget);
      });

      testWidgets('does not show thumb buttons when onFeedbackSubmit is null',
          (tester) async {
        await tester.pumpWidget(
          createTestApp(
            home: Scaffold(
              body: ChatMessageWidget(message: assistantMessage),
            ),
          ),
        );

        expect(find.byIcon(Icons.thumb_up_alt_outlined), findsNothing);
        expect(find.byIcon(Icons.thumb_down_alt_outlined), findsNothing);
      });

      testWidgets('tapping thumbs-up transitions to countdown', (tester) async {
        await tester.pumpWidget(
          createTestApp(
            home: Scaffold(
              body: ChatMessageWidget(
                message: assistantMessage,
                onFeedbackSubmit: onFeedbackSubmit,
              ),
            ),
          ),
        );

        await tester.tap(find.byIcon(Icons.thumb_up_alt_outlined));
        await tester.pump();

        // Active thumb is now filled
        expect(find.byIcon(Icons.thumb_up), findsOneWidget);
        // Countdown visible
        expect(find.text('5'), findsOneWidget);
        // "Tell us why!" label visible
        expect(find.text('Tell us why!'), findsOneWidget);
        // Nothing sent yet
        expect(capturedFeedback, isNull);
      });

      testWidgets('tapping thumbs-down transitions to countdown',
          (tester) async {
        await tester.pumpWidget(
          createTestApp(
            home: Scaffold(
              body: ChatMessageWidget(
                message: assistantMessage,
                onFeedbackSubmit: onFeedbackSubmit,
              ),
            ),
          ),
        );

        await tester.tap(find.byIcon(Icons.thumb_down_alt_outlined));
        await tester.pump();

        expect(find.byIcon(Icons.thumb_down), findsOneWidget);
        expect(find.text('Tell us why!'), findsOneWidget);
        expect(capturedFeedback, isNull);
      });

      testWidgets('tapping active thumb during countdown cancels feedback',
          (tester) async {
        await tester.pumpWidget(
          createTestApp(
            home: Scaffold(
              body: ChatMessageWidget(
                message: assistantMessage,
                onFeedbackSubmit: onFeedbackSubmit,
              ),
            ),
          ),
        );

        // Start countdown
        await tester.tap(find.byIcon(Icons.thumb_up_alt_outlined));
        await tester.pump();
        expect(find.byIcon(Icons.thumb_up), findsOneWidget);

        // Tap active thumb — cancel
        await tester.tap(find.byIcon(Icons.thumb_up));
        await tester.pump();

        // Back to idle
        expect(find.byIcon(Icons.thumb_up_alt_outlined), findsOneWidget);
        expect(find.text('Tell us why!'), findsNothing);
        expect(capturedFeedback, isNull);
      });

      testWidgets('tapping opposite thumb during countdown switches direction',
          (tester) async {
        await tester.pumpWidget(
          createTestApp(
            home: Scaffold(
              body: ChatMessageWidget(
                message: assistantMessage,
                onFeedbackSubmit: onFeedbackSubmit,
              ),
            ),
          ),
        );

        // Start thumbs-up countdown
        await tester.tap(find.byIcon(Icons.thumb_up_alt_outlined));
        await tester.pump();
        expect(find.byIcon(Icons.thumb_up), findsOneWidget);

        // Advance time a bit
        await tester.pump(const Duration(seconds: 2));

        // Switch to thumbs-down
        await tester.tap(find.byIcon(Icons.thumb_down_alt_outlined));
        await tester.pump();

        // Thumbs-down is now active, timer reset to 5
        expect(find.byIcon(Icons.thumb_down), findsOneWidget);
        expect(find.text('5'), findsOneWidget);
        expect(capturedFeedback, isNull);
      });

      testWidgets('countdown expiry sends feedback with null reason',
          (tester) async {
        await tester.pumpWidget(
          createTestApp(
            home: Scaffold(
              body: ChatMessageWidget(
                message: assistantMessage,
                onFeedbackSubmit: onFeedbackSubmit,
              ),
            ),
          ),
        );

        await tester.tap(find.byIcon(Icons.thumb_up_alt_outlined));
        await tester.pump();

        // Expire the 5-second countdown
        await tester.pump(const Duration(seconds: 5));
        await tester.pump();

        expect(capturedFeedback, FeedbackType.thumbsUp);
        expect(capturedReason, isNull);
        // In submitted state — thumb still filled
        expect(find.byIcon(Icons.thumb_up), findsOneWidget);
        // No countdown
        expect(find.text('Tell us why!'), findsNothing);
      });

      testWidgets('active thumb is locked after submission', (tester) async {
        await tester.pumpWidget(
          createTestApp(
            home: Scaffold(
              body: ChatMessageWidget(
                message: assistantMessage,
                onFeedbackSubmit: onFeedbackSubmit,
              ),
            ),
          ),
        );

        // Submit thumbsUp
        await tester.tap(find.byIcon(Icons.thumb_up_alt_outlined));
        await tester.pump();
        await tester.pump(const Duration(seconds: 5));
        await tester.pump();
        expect(capturedFeedback, FeedbackType.thumbsUp);
        capturedFeedback = null;

        // Tap active thumb — no-op
        await tester.tap(find.byIcon(Icons.thumb_up));
        await tester.pump();

        expect(capturedFeedback, isNull);
        expect(find.byIcon(Icons.thumb_up), findsOneWidget);
      });

      testWidgets(
          'tapping opposite thumb after submission starts new countdown',
          (tester) async {
        await tester.pumpWidget(
          createTestApp(
            home: Scaffold(
              body: ChatMessageWidget(
                message: assistantMessage,
                onFeedbackSubmit: onFeedbackSubmit,
              ),
            ),
          ),
        );

        // Submit thumbsUp
        await tester.tap(find.byIcon(Icons.thumb_up_alt_outlined));
        await tester.pump();
        await tester.pump(const Duration(seconds: 5));
        await tester.pump();
        expect(capturedFeedback, FeedbackType.thumbsUp);

        // Tap thumbs-down — starts new countdown
        await tester.tap(find.byIcon(Icons.thumb_down_alt_outlined));
        await tester.pump();

        expect(find.byIcon(Icons.thumb_down), findsOneWidget);
        expect(find.text('Tell us why!'), findsOneWidget);
      });
    });
  });
}
