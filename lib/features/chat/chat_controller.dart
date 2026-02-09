import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soliplex_client/soliplex_client.dart';

import 'package:soliplex_frontend/core/logging/loggers.dart';
import 'package:soliplex_frontend/core/providers/active_run_provider.dart';
import 'package:soliplex_frontend/core/providers/rooms_provider.dart';
import 'package:soliplex_frontend/core/providers/selected_documents_provider.dart';
import 'package:soliplex_frontend/core/providers/threads_provider.dart';
import 'package:soliplex_frontend/features/chat/send_message_provider.dart';

/// Result of [ChatController.send].
@immutable
sealed class SendResult {
  const SendResult();
}

/// Message sent to an existing thread.
class MessageSent extends SendResult {
  const MessageSent();

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is MessageSent;

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() => 'MessageSent()';
}

/// A new thread was created. The widget should navigate to it.
class ThreadCreated extends SendResult {
  const ThreadCreated({required this.roomId, required this.threadId});

  final String roomId;
  final String threadId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ThreadCreated &&
          roomId == other.roomId &&
          threadId == other.threadId;

  @override
  int get hashCode => Object.hash(roomId, threadId);

  @override
  String toString() => 'ThreadCreated(roomId: $roomId, threadId: $threadId)';
}

/// Sending failed. The widget should display [message].
class SendFailed extends SendResult {
  const SendFailed(this.message);

  final String message;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is SendFailed && message == other.message;

  @override
  int get hashCode => message.hashCode;

  @override
  String toString() => 'SendFailed($message)';
}

/// Orchestrates chat actions: sending messages, retrying, and
/// managing pending document selections.
///
/// State is `Set<RagDocument>` — the pending documents held before
/// a thread exists. [send] returns a [SendResult] so the widget
/// can perform navigation or show errors.
class ChatController extends Notifier<Set<RagDocument>> {
  @override
  Set<RagDocument> build() {
    ref.listen(currentRoomIdProvider, (previous, next) {
      if (previous != next && state.isNotEmpty) {
        state = {};
      }
    });

    return {};
  }

  /// Sends a message, creating a new thread if needed.
  Future<SendResult> send(String text) async {
    final room = ref.read(currentRoomProvider);
    if (room == null) {
      return const SendFailed('No room selected');
    }

    final thread = ref.read(currentThreadProvider);
    final selection = ref.read(threadSelectionProvider);

    try {
      final result = await ref.read(sendMessageProvider).call(
            roomId: room.id,
            text: text,
            pendingDocuments: state,
            currentThread: thread,
            isNewThreadIntent: selection is NewThreadIntent,
          );

      if (result.isNewThread) {
        ref
            .read(threadSelectionProvider.notifier)
            .set(ThreadSelected(result.threadId));

        unawaited(
          setLastViewedThread(
            roomId: room.id,
            threadId: result.threadId,
            invalidate: (roomId) =>
                ref.invalidate(lastViewedThreadProvider(roomId)),
          ).catchError((Object e) {
            Loggers.room.warning(
              'Failed to persist last viewed thread: $e',
            );
          }),
        );

        if (state.isNotEmpty) {
          state = {};
        }

        ref.invalidate(threadsProvider(room.id));

        return ThreadCreated(roomId: room.id, threadId: result.threadId);
      }

      return const MessageSent();
    } on NetworkException catch (e, stackTrace) {
      Loggers.chat.error(
        'Failed to send message: Network error',
        error: e,
        stackTrace: stackTrace,
      );
      return SendFailed('Network error: ${e.message}');
    } on AuthException catch (e, stackTrace) {
      Loggers.chat.error(
        'Failed to send message: Auth error',
        error: e,
        stackTrace: stackTrace,
      );
      return SendFailed('Authentication error: ${e.message}');
    } catch (e, stackTrace) {
      Loggers.chat.error(
        'Failed to send message',
        error: e,
        stackTrace: stackTrace,
      );
      return SendFailed('Failed to send message: $e');
    }
  }

  /// Resets the active run after an error.
  Future<void> retry() async {
    await ref.read(activeRunNotifierProvider.notifier).reset();
  }

  /// Updates document selection.
  ///
  /// If a thread is active, delegates to the document selection provider.
  /// Otherwise, stores in pending state until a thread is created.
  void updateDocuments(Set<RagDocument> documents) {
    final roomId = ref.read(currentRoomIdProvider);
    final threadId = ref.read(currentThreadIdProvider);

    if (roomId != null && threadId != null) {
      ref
          .read(selectedDocumentsNotifierProvider.notifier)
          .setForThread(roomId, threadId, documents);
    } else {
      state = documents;
    }
  }
}

/// Provider for [ChatController].
final chatControllerProvider =
    NotifierProvider<ChatController, Set<RagDocument>>(
  ChatController.new,
);
