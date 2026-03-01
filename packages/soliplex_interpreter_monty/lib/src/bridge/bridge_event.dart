/// Protocol-agnostic lifecycle events emitted by a bridge.
///
/// These events describe what happened during Python execution without
/// coupling to any specific event protocol (e.g. ag-ui). Downstream
/// consumers map these to their own protocol types.
sealed class BridgeEvent {
  const BridgeEvent();
}

/// Execution started.
class BridgeRunStarted extends BridgeEvent {
  const BridgeRunStarted({required this.threadId, required this.runId});
  final String threadId;
  final String runId;
}

/// Execution completed successfully.
class BridgeRunFinished extends BridgeEvent {
  const BridgeRunFinished({required this.threadId, required this.runId});
  final String threadId;
  final String runId;
}

/// Execution failed with an error.
class BridgeRunError extends BridgeEvent {
  const BridgeRunError({required this.message});
  final String message;
}

/// A host function call step started.
class BridgeStepStarted extends BridgeEvent {
  const BridgeStepStarted({required this.stepId});
  final String stepId;
}

/// A host function call step finished.
class BridgeStepFinished extends BridgeEvent {
  const BridgeStepFinished({required this.stepId});
  final String stepId;
}

/// A tool call began (function name known).
class BridgeToolCallStart extends BridgeEvent {
  const BridgeToolCallStart({required this.callId, required this.name});
  final String callId;
  final String name;
}

/// Tool call arguments (JSON delta).
class BridgeToolCallArgs extends BridgeEvent {
  const BridgeToolCallArgs({required this.callId, required this.delta});
  final String callId;
  final String delta;
}

/// Tool call arguments complete.
class BridgeToolCallEnd extends BridgeEvent {
  const BridgeToolCallEnd({required this.callId});
  final String callId;
}

/// Tool call result (handler output or error).
class BridgeToolCallResult extends BridgeEvent {
  const BridgeToolCallResult({required this.callId, required this.result});
  final String callId;
  final String result;
}

/// Text output started (print buffer flush).
class BridgeTextStart extends BridgeEvent {
  const BridgeTextStart({required this.messageId});
  final String messageId;
}

/// Text output content delta.
class BridgeTextContent extends BridgeEvent {
  const BridgeTextContent({required this.messageId, required this.delta});
  final String messageId;
  final String delta;
}

/// Text output ended.
class BridgeTextEnd extends BridgeEvent {
  const BridgeTextEnd({required this.messageId});
  final String messageId;
}
