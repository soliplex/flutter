import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soliplex_client/soliplex_client.dart';
import 'package:soliplex_frontend/core/providers/api_provider.dart';
import 'package:soliplex_frontend/core/providers/rooms_provider.dart';
import 'package:soliplex_frontend/core/providers/threads_provider.dart';
import 'package:soliplex_frontend/features/chat/chat_panel.dart';
import 'package:soliplex_frontend/features/chat/widgets/chat_input.dart';

class MockSoliplexApi extends Mock implements SoliplexApi {}

class MockAgUiClient extends Mock implements AgUiClient {}

class FakeSimpleRunAgentInput extends Fake implements SimpleRunAgentInput {}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(const SimpleRunAgentInput(messages: []));
    registerFallbackValue(CancelToken());
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Tool Calling Widget Integration', () {
    testWidgets(
      'get_secret tool flow: sends message, triggers tool, gets date response',
      (tester) async {
        final mockApi = MockSoliplexApi();
        final mockAgUiClient = MockAgUiClient();

        // Stream controllers for controlled event emission
        final firstRunController = StreamController<BaseEvent>();
        final continuationRunController = StreamController<BaseEvent>();

        addTearDown(() {
          firstRunController.close();
          continuationRunController.close();
        });

        // Track which run we're on
        var runCounter = 0;

        // Generate threadId upfront for mock consistency
        final testThreadId = 'thread_${DateTime.now().millisecondsSinceEpoch}';

        // Mock createRun with positional args (roomId, threadId)
        when(
          () => mockApi.createRun(
            any(),
            any(),
            cancelToken: any(named: 'cancelToken'),
          ),
        ).thenAnswer((invocation) async {
          runCounter++;
          final passedThreadId = invocation.positionalArguments[1] as String;
          return RunInfo(
            id: 'run_$runCounter',
            threadId: passedThreadId, // Return matching threadId
            createdAt: DateTime.now(),
          );
        });

        when(
          () => mockAgUiClient.runAgent(
            any(),
            any(),
            cancelToken: any(named: 'cancelToken'),
          ),
        ).thenAnswer((invocation) {
          final endpoint = invocation.positionalArguments[0] as String;
          if (endpoint.contains('run_1')) {
            return firstRunController.stream;
          }
          return continuationRunController.stream;
        });

        // Calculate expected date
        final todayUtc = DateTime.now().toUtc();
        final dateString = '${todayUtc.year}-'
            '${todayUtc.month.toString().padLeft(2, '0')}-'
            '${todayUtc.day.toString().padLeft(2, '0')}';

        // Set up the test widget with ChatPanel
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ProviderScope(
                overrides: [
                  apiProvider.overrideWithValue(mockApi),
                  agUiClientProvider.overrideWithValue(mockAgUiClient),
                  currentRoomIdProvider.overrideWith(
                    () => MockCurrentRoomIdNotifier(initialRoomId: 'room_1'),
                  ),
                  threadSelectionProvider.overrideWith(
                    () => MockThreadSelectionNotifier(
                      initialSelection: ThreadSelected(testThreadId),
                    ),
                  ),
                  roomsProvider.overrideWith(
                    (ref) async => [
                      const Room(id: 'room_1', name: 'Test Room'),
                    ],
                  ),
                  threadsProvider('room_1').overrideWith(
                    (ref) async => [
                      ThreadInfo(
                        id: testThreadId,
                        roomId: 'room_1',
                        name: 'Test Thread',
                        createdAt: DateTime.now(),
                      ),
                    ],
                  ),
                ],
                child: const ChatPanel(),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Find the ChatInput widget
        final chatInput = find.byType(ChatInput);
        expect(chatInput, findsOneWidget);

        // Find the text field using semantic key
        final textField = find.byKey(const Key('chat_input'));
        expect(textField, findsOneWidget);

        // Enter text
        await tester.enterText(textField, 'what is the secret?');
        await tester.pump();

        // Find and tap send button using semantic key
        final sendButton = find.byKey(const Key('send_button'));
        expect(sendButton, findsOneWidget);
        await tester.tap(sendButton);
        await tester.pump();

        // Verify createRun was called for initial run
        await Future<void>.delayed(const Duration(milliseconds: 50));

        // Emit first run events (tool call)
        firstRunController.add(
          RunStartedEvent(runId: 'run_1', threadId: testThreadId),
        );
        await tester.pump();

        firstRunController.add(
          const ToolCallStartEvent(
            toolCallId: 'tc_1',
            toolCallName: 'get_secret',
          ),
        );
        await tester.pump();

        firstRunController.add(
          const ToolCallArgsEvent(toolCallId: 'tc_1', delta: '{}'),
        );
        await tester.pump();

        firstRunController.add(const ToolCallEndEvent(toolCallId: 'tc_1'));

        // Wait for tool execution
        await tester.pump(const Duration(milliseconds: 200));
        await tester.pumpAndSettle();

        // Emit continuation run events
        continuationRunController.add(
          RunStartedEvent(runId: 'run_2', threadId: testThreadId),
        );
        await tester.pump();

        continuationRunController.add(
          const TextMessageStartEvent(messageId: 'msg_1'),
        );
        await tester.pump();

        continuationRunController.add(
          TextMessageContentEvent(
            messageId: 'msg_1',
            delta: 'The secret is $dateString',
          ),
        );
        await tester.pump();

        continuationRunController.add(
          const TextMessageEndEvent(messageId: 'msg_1'),
        );
        await tester.pump();

        continuationRunController.add(
          RunFinishedEvent(runId: 'run_2', threadId: testThreadId),
        );

        await tester.pumpAndSettle();

        // Verify API calls were made correctly
        verify(
          () => mockApi.createRun(
            any(),
            any(),
            cancelToken: any(named: 'cancelToken'),
          ),
        ).called(greaterThanOrEqualTo(1));

        verify(
          () => mockAgUiClient.runAgent(
            any(),
            any(),
            cancelToken: any(named: 'cancelToken'),
          ),
        ).called(greaterThanOrEqualTo(1));

        // Verify date appears in UI
        expect(
          find.textContaining(dateString),
          findsOneWidget,
          reason: "Response should contain today's UTC date: $dateString",
        );
      },
    );
  });
}

/// Mock CurrentRoomIdNotifier for testing.
class MockCurrentRoomIdNotifier extends Notifier<String?>
    implements CurrentRoomIdNotifier {
  MockCurrentRoomIdNotifier({this.initialRoomId});

  final String? initialRoomId;

  @override
  String? build() => initialRoomId;

  @override
  void set(String? value) => state = value;
}

/// Mock ThreadSelectionNotifier for testing.
class MockThreadSelectionNotifier extends Notifier<ThreadSelection>
    implements ThreadSelectionNotifier {
  MockThreadSelectionNotifier({required this.initialSelection});

  final ThreadSelection initialSelection;

  @override
  ThreadSelection build() => initialSelection;

  @override
  void set(ThreadSelection value) => state = value;
}
