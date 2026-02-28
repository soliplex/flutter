import 'package:flutter_test/flutter_test.dart';
import 'package:soliplex_client/soliplex_client.dart';
import 'package:soliplex_frontend/core/services/agui_event_logger.dart';

void main() {
  group('logAguiEvent', () {
    test('handles RunStartedEvent without throwing', () {
      expect(
        () => logAguiEvent(
          const RunStartedEvent(threadId: 't1', runId: 'r1'),
        ),
        returnsNormally,
      );
    });

    test('handles TextMessageStartEvent without throwing', () {
      expect(
        () => logAguiEvent(
          const TextMessageStartEvent(messageId: 'msg-1'),
        ),
        returnsNormally,
      );
    });

    test('handles ToolCallStartEvent without throwing', () {
      expect(
        () => logAguiEvent(
          const ToolCallStartEvent(
            toolCallId: 'tc-1',
            toolCallName: 'search',
          ),
        ),
        returnsNormally,
      );
    });

    test('handles ToolCallResultEvent without throwing', () {
      expect(
        () => logAguiEvent(
          const ToolCallResultEvent(
            messageId: 'msg-1',
            toolCallId: 'tc-1',
            content: 'result',
          ),
        ),
        returnsNormally,
      );
    });

    test('handles RunErrorEvent without throwing', () {
      expect(
        () => logAguiEvent(
          const RunErrorEvent(message: 'something failed'),
        ),
        returnsNormally,
      );
    });

    test('handles StateSnapshotEvent without throwing', () {
      expect(
        () => logAguiEvent(
          const StateSnapshotEvent(snapshot: <dynamic>[]),
        ),
        returnsNormally,
      );
    });

    test('handles RunFinishedEvent without throwing', () {
      expect(
        () => logAguiEvent(
          const RunFinishedEvent(threadId: 't1', runId: 'r1'),
        ),
        returnsNormally,
      );
    });
  });
}
