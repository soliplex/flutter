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
                  _DocumentChip(
                    title: selectedDoc.title,
                    onDeleted: _clearSelectedDocument,
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
                    const SingleActivator(LogicalKeyboardKey.enter):
                        canSend ? _handleSend : () {},
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

/// Styled chip displaying a document name with delete button.
class _DocumentChip extends StatelessWidget {
  const _DocumentChip({
    required this.title,
    required this.onDeleted,
  });

  final String title;
  final VoidCallback onDeleted;

  /// Extracts filename with up to 2 parent folders from a path or URI.
  String _shortName(String fullPath) {
    // Remove file:// prefix if present
    var path = fullPath;
    if (path.startsWith('file://')) {
      path = path.substring(7);
    }

    final segments = path.split('/').where((s) => s.isNotEmpty).toList();
    if (segments.length <= 3) {
      return segments.join('/');
    }
    return segments.sublist(segments.length - 3).join('/');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: colorScheme.primaryContainer,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {}, // Makes the chip feel interactive
        child: Padding(
          padding: const EdgeInsets.only(
            left: 12,
            right: 4,
            top: 6,
            bottom: 6,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.description_outlined,
                size: 16,
                color: colorScheme.onPrimaryContainer,
              ),
              const SizedBox(width: 6),
              Text(
                _shortName(title),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                onPressed: onDeleted,
                icon: Icon(
                  Icons.close,
                  size: 16,
                  color: colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: 24,
                  minHeight: 24,
                ),
                tooltip: 'Remove document filter',
                style: IconButton.styleFrom(
                  shape: const CircleBorder(),
                ),
              ),
            ],
          ),
        ),
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
