import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soliplex_client/soliplex_client.dart';
import 'package:soliplex_frontend/core/providers/active_run_provider.dart';
import 'package:soliplex_frontend/core/providers/documents_provider.dart';
import 'package:soliplex_frontend/design/tokens/spacing.dart';

/// Widget for chat message input.
///
/// Provides:
/// - Text field for typing messages
/// - Send button (enabled/disabled based on canSendMessageProvider)
/// - Document picker button (📎) for narrowing RAG searches
/// - Selected document display above input
/// - Keyboard shortcuts: Enter to send, Shift+Enter for new line
/// - Auto-clear input after send
///
/// Example:
/// ```dart
/// ChatInput(
///   onSend: (text) {
///     // Handle sending message
///   },
///   roomId: 'room-123',
///   selectedDocument: document,
///   onDocumentSelected: (doc) {
///     // Handle document selection
///   },
/// )
/// ```
class ChatInput extends ConsumerStatefulWidget {
  /// Creates a chat input widget.
  const ChatInput({
    required this.onSend,
    this.roomId,
    this.selectedDocument,
    this.onDocumentSelected,
    super.key,
  });

  /// Callback invoked when user sends a message.
  final void Function(String text) onSend;

  /// The current room ID for fetching documents.
  final String? roomId;

  /// The currently selected document for RAG filtering.
  final RagDocument? selectedDocument;

  /// Callback invoked when document selection changes.
  final void Function(RagDocument?)? onDocumentSelected;

  @override
  ConsumerState<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends ConsumerState<ChatInput> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// Handles sending the message.
  void _handleSend() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    widget.onSend(text);
    _controller.clear();
  }

  /// Handles cancelling the active run.
  Future<void> _handleCancel() async {
    try {
      await ref.read(activeRunNotifierProvider.notifier).cancelRun();
    } catch (e, stackTrace) {
      debugPrint('Failed to cancel run: $e');
      debugPrint(stackTrace.toString());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to cancel: $e')),
        );
      }
    }
  }

  Future<void> _showDocumentPicker() async {
    final roomId = widget.roomId;
    if (roomId == null) return;

    final result = await showDialog<RagDocument>(
      context: context,
      builder: (context) => _DocumentPickerDialog(roomId: roomId),
    );

    if (result != null) {
      widget.onDocumentSelected?.call(result);
    }
  }

  void _clearSelectedDocument() {
    widget.onDocumentSelected?.call(null);
  }

  @override
  Widget build(BuildContext context) {
    final canSend = ref.watch(canSendMessageProvider);
    final runState = ref.watch(activeRunNotifierProvider);
    final hasRoom = widget.roomId != null;
    final selectedDoc = widget.selectedDocument;

    return Container(
      padding: const EdgeInsets.all(SoliplexSpacing.s4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Selected document chips
          if (selectedDoc != null)
            Padding(
              padding: const EdgeInsets.only(bottom: SoliplexSpacing.s2),
              child: Wrap(
                spacing: SoliplexSpacing.s2,
                runSpacing: SoliplexSpacing.s1,
                children: [
                  InputChip(
                    label: Text(selectedDoc.title),
                    avatar: const Icon(Icons.description, size: 18),
                    onDeleted: _clearSelectedDocument,
                    deleteButtonTooltipMessage: 'Remove document filter',
                  ),
                ],
              ),
            ),

          // Input row
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Document picker button
              if (hasRoom)
                IconButton(
                  tooltip: 'Select document',
                  onPressed: canSend ? _showDocumentPicker : null,
                  icon: const Icon(Icons.attach_file),
                ),
              const SizedBox(width: 8),
              // Text field
              Expanded(
                child: CallbackShortcuts(
                  bindings: {
                    const SingleActivator(LogicalKeyboardKey.enter): canSend
                        ? _handleSend
                        : () {},
                    const SingleActivator(LogicalKeyboardKey.escape): () =>
                        _focusNode.unfocus(),
                  },
                  child: Semantics(
                    label: 'Chat message input',
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      maxLines: null,
                      textInputAction: TextInputAction.newline,
                      decoration: InputDecoration(
                        hintText: canSend
                            ? 'Type a message...'
                            : 'Select a room to start chatting',
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      enabled: canSend,
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (runState.isRunning)
                IconButton(
                  tooltip: 'Abort message generation',
                  onPressed: _handleCancel,
                  icon: const Icon(Icons.stop),
                  style: IconButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  ),
                )
              else
                IconButton(
                  tooltip: 'Send message',
                  onPressed: canSend && _controller.text.trim().isNotEmpty
                      ? _handleSend
                      : null,
                  icon: const Icon(Icons.send),
                  style: IconButton.styleFrom(
                    backgroundColor:
                        canSend && _controller.text.trim().isNotEmpty
                            ? Theme.of(context).colorScheme.primary
                            : null,
                    foregroundColor:
                        canSend && _controller.text.trim().isNotEmpty
                            ? Theme.of(context).colorScheme.onPrimary
                            : null,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Dialog for selecting a document from the room's document list.
class _DocumentPickerDialog extends ConsumerWidget {
  const _DocumentPickerDialog({required this.roomId});

  final String roomId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final documentsAsync = ref.watch(documentsProvider(roomId));

    return AlertDialog(
      title: const Text('Select a document'),
      content: SizedBox(
        width: 300,
        height: 400,
        child: documentsAsync.when(
          data: (documents) {
            if (documents.isEmpty) {
              return const Center(child: Text('No documents in this room.'));
            }
            return ListView.builder(
              itemCount: documents.length,
              itemBuilder: (context, index) {
                final doc = documents[index];
                return ListTile(
                  title: Text(doc.title),
                  onTap: () => Navigator.of(context).pop(doc),
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('Error: $error')),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
