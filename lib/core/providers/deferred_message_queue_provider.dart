import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soliplex_frontend/core/models/thread_key.dart';

/// A message to be delivered to another thread after the current run completes.
@immutable
class DeferredMessage {
  const DeferredMessage({required this.targetKey, required this.message});

  /// The thread to deliver the message to.
  final ThreadKey targetKey;

  /// The user message text to send.
  final String message;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DeferredMessage &&
          targetKey == other.targetKey &&
          message == other.message;

  @override
  int get hashCode => Object.hash(targetKey, message);

  @override
  String toString() =>
      'DeferredMessage(targetKey: $targetKey, message: $message)';
}

/// FIFO queue for messages deferred until the current run completes.
///
/// Tools enqueue messages during a run; the lifecycle listener in
/// `ActiveRunNotifier` dequeues and delivers them after `RunCompleted`.
class DeferredMessageQueueNotifier extends Notifier<List<DeferredMessage>> {
  @override
  List<DeferredMessage> build() => const [];

  /// Add a message to the end of the queue.
  void enqueue(DeferredMessage message) => state = [...state, message];

  /// Remove and return the first message, or null if empty.
  DeferredMessage? pop() {
    if (state.isEmpty) return null;
    final message = state.first;
    state = state.sublist(1);
    return message;
  }

  /// Discard all queued messages.
  void clear() => state = const [];
}

/// Provider for the deferred message queue.
final deferredMessageQueueProvider =
    NotifierProvider<DeferredMessageQueueNotifier, List<DeferredMessage>>(
  DeferredMessageQueueNotifier.new,
);
