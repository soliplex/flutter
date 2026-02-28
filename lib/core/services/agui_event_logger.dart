import 'package:soliplex_client/soliplex_client.dart';
import 'package:soliplex_frontend/core/logging/loggers.dart';

/// Logs AG-UI events at appropriate levels.
///
/// Extracted from ActiveRunNotifier for testability and single
/// responsibility. Uses [Loggers.activeRun] for all output.
void logAguiEvent(BaseEvent event) {
  switch (event) {
    case RunStartedEvent():
      Loggers.activeRun.debug('RUN_STARTED');
    case RunFinishedEvent():
      Loggers.activeRun.debug('RUN_FINISHED');
    case RunErrorEvent(:final message):
      Loggers.activeRun.error('RUN_ERROR: $message');
    case ThinkingTextMessageStartEvent():
      Loggers.activeRun.trace('THINKING_START');
    case ThinkingTextMessageContentEvent():
      Loggers.activeRun.trace('THINKING_CONTENT');
    case ThinkingTextMessageEndEvent():
      Loggers.activeRun.trace('THINKING_END');
    case TextMessageStartEvent(:final messageId):
      Loggers.activeRun.debug('TEXT_START: $messageId');
    case TextMessageContentEvent(:final messageId):
      Loggers.activeRun.trace('TEXT_CONTENT: $messageId');
    case TextMessageEndEvent(:final messageId):
      Loggers.activeRun.debug('TEXT_END: $messageId');
    case ToolCallStartEvent(:final toolCallId, :final toolCallName):
      Loggers.activeRun.debug('TOOL_START: $toolCallName ($toolCallId)');
    case ToolCallArgsEvent(:final toolCallId):
      Loggers.activeRun.trace('TOOL_ARGS: $toolCallId');
    case ToolCallEndEvent(:final toolCallId):
      Loggers.activeRun.debug('TOOL_END: $toolCallId');
    case ToolCallResultEvent(:final toolCallId):
      Loggers.activeRun.debug('TOOL_RESULT: $toolCallId');
    case StateSnapshotEvent():
      Loggers.activeRun.debug('STATE_SNAPSHOT');
    case StateDeltaEvent():
      Loggers.activeRun.debug('STATE_DELTA');
    default:
      Loggers.activeRun.trace('EVENT: ${event.runtimeType}');
  }
}
