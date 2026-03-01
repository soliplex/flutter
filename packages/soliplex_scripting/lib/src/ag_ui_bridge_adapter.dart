import 'package:ag_ui/ag_ui.dart';
import 'package:soliplex_interpreter_monty/soliplex_interpreter_monty.dart';

/// Stateless adapter mapping [BridgeEvent]s to ag-ui [BaseEvent]s.
///
/// The mapping is 1:1 and exhaustive — every [BridgeEvent] subtype produces
/// exactly one [BaseEvent]. Run-level IDs (`threadId`, `runId`) on the bridge
/// events are overridden with the adapter's conversational-context IDs.
class AgUiBridgeAdapter {
  /// Creates an adapter that injects the given [threadId] and [runId]
  /// into run-level events.
  const AgUiBridgeAdapter({
    required this.threadId,
    required this.runId,
  });

  /// Thread identifier injected into [RunStartedEvent] / [RunFinishedEvent].
  final String threadId;

  /// Run identifier injected into [RunStartedEvent] / [RunFinishedEvent].
  final String runId;

  /// Transforms a [Stream] of [BridgeEvent]s into ag-ui [BaseEvent]s.
  Stream<BaseEvent> adapt(Stream<BridgeEvent> source) => source.map(mapEvent);

  /// Maps a single [BridgeEvent] to its ag-ui [BaseEvent] equivalent.
  BaseEvent mapEvent(BridgeEvent event) => switch (event) {
        BridgeRunStarted() => RunStartedEvent(
            threadId: threadId,
            runId: runId,
          ),
        BridgeRunFinished() => RunFinishedEvent(
            threadId: threadId,
            runId: runId,
          ),
        BridgeRunError(:final message) => RunErrorEvent(
            message: message,
          ),
        BridgeStepStarted(:final stepId) => StepStartedEvent(
            stepName: stepId,
          ),
        BridgeStepFinished(:final stepId) => StepFinishedEvent(
            stepName: stepId,
          ),
        BridgeToolCallStart(:final callId, :final name) => ToolCallStartEvent(
            toolCallId: callId,
            toolCallName: name,
          ),
        BridgeToolCallArgs(:final callId, :final delta) => ToolCallArgsEvent(
            toolCallId: callId,
            delta: delta,
          ),
        BridgeToolCallEnd(:final callId) => ToolCallEndEvent(
            toolCallId: callId,
          ),
        BridgeToolCallResult(:final callId, :final result) =>
          ToolCallResultEvent(
            messageId: callId,
            toolCallId: callId,
            content: result,
          ),
        BridgeTextStart(:final messageId) => TextMessageStartEvent(
            messageId: messageId,
          ),
        BridgeTextContent(:final messageId, :final delta) =>
          TextMessageContentEvent(
            messageId: messageId,
            delta: delta,
          ),
        BridgeTextEnd(:final messageId) => TextMessageEndEvent(
            messageId: messageId,
          ),
      };
}
