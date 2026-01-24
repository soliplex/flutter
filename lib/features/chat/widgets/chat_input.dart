import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soliplex_client/soliplex_client.dart';
import 'package:soliplex_frontend/core/providers/active_run_provider.dart';
import 'package:soliplex_frontend/core/providers/documents_provider.dart';
import 'package:soliplex_frontend/design/tokens/spacing.dart';

/// Formats a document path/title to show filename with up to 2 parent folders.
///
/// Examples:
/// - "file:///path/to/my/favorite/document.txt" -> "my/favorite/document.txt"
/// - "/path/to/file.pdf" -> "to/file.pdf"
/// - "document.txt" -> "document.txt"
String formatDocumentTitle(String title) {
  // Remove file:// prefix if present
  var path = title;
  if (path.startsWith('file://')) {
    path = path.substring(7);
  }

  // Split by path separator
  final segments = path.split('/').where((s) => s.isNotEmpty).toList();

  if (segments.isEmpty) return title;

  // Take the last 3 segments (filename + up to 2 parent folders)
  final displaySegments =
      segments.length <= 3 ? segments : segments.sublist(segments.length - 3);

  return displaySegments.join('/');
}

/// Widget for chat message input.
///
/// Provides:
/// - Text field for typing messages
/// - Send button (enabled/disabled based on canSendMessageProvider)
/// - Document picker button (📎) for narrowing RAG searches
/// - Selected documents display above input
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
///   selectedDocuments: {document1, document2},
///   onDocumentsChanged: (docs) {
///     // Handle documents change
///   },
/// )
/// ```
class ChatInput extends ConsumerStatefulWidget {
  /// Creates a chat input widget.
  const ChatInput({
    required this.onSend,
    this.roomId,
    this.selectedDocuments = const {},
    this.onDocumentsChanged,
    this.suggestions = const [],
    this.showSuggestions = false,
    super.key,
  });

  /// Callback invoked when user sends a message.
  final void Function(String text) onSend;

  /// The current room ID for fetching documents.
  final String? roomId;

  /// The currently selected documents for RAG filtering.
  final Set<RagDocument> selectedDocuments;

  /// Callback invoked when document selection changes.
  final void Function(Set<RagDocument>)? onDocumentsChanged;

  /// Suggested prompts to display as chips.
  final List<String> suggestions;

  /// Whether to show suggestion chips (typically when thread is empty).
  final bool showSuggestions;

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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to cancel: $e')));
      }
    }
  }

  Future<void> _showDocumentPicker() async {
    final roomId = widget.roomId;
    if (roomId == null) return;

    final result = await showDialog<Set<RagDocument>>(
      context: context,
      builder: (context) => _DocumentPickerDialog(
        roomId: roomId,
        initialSelection: widget.selectedDocuments,
      ),
    );

    if (result != null) {
      widget.onDocumentsChanged?.call(result);
    }
  }

  void _removeDocument(RagDocument doc) {
    final newSet = Set<RagDocument>.from(widget.selectedDocuments)..remove(doc);
    widget.onDocumentsChanged?.call(newSet);
  }

  @override
  Widget build(BuildContext context) {
    final canSend = ref.watch(canSendMessageProvider);
    final runState = ref.watch(activeRunNotifierProvider);
    final roomId = widget.roomId;
    final hasRoom = roomId != null;
    final selectedDocs = widget.selectedDocuments;

    // Check if room has documents for picker button state
    // Only disable when we KNOW the room is empty (not during loading/error)
    final documentsAsync =
        hasRoom ? ref.watch(documentsProvider(roomId)) : null;
    final isEmptyRoom = documentsAsync?.maybeWhen(
          data: (docs) => docs.isEmpty,
          orElse: () => false,
        ) ??
        false;
    final pickerEnabled = canSend && !isEmptyRoom;
    final pickerTooltip =
        isEmptyRoom ? 'No documents in this room' : 'Select document';

    final showChips = widget.showSuggestions && widget.suggestions.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(SoliplexSpacing.s4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Suggestion chips
          if (showChips)
            Padding(
              padding: const EdgeInsets.only(bottom: SoliplexSpacing.s2),
              child: Wrap(
                spacing: SoliplexSpacing.s2,
                runSpacing: SoliplexSpacing.s1,
                children: [
                  for (final suggestion in widget.suggestions)
                    ActionChip(
                      label: Text(suggestion),
                      onPressed: () => widget.onSend(suggestion),
                    ),
                ],
              ),
            ),

          // Selected documents display
          if (selectedDocs.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: SoliplexSpacing.s2),
              child: Wrap(
                spacing: SoliplexSpacing.s2,
                runSpacing: SoliplexSpacing.s1,
                children: [
                  for (final doc in selectedDocs)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.description,
                          size: 16,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: SoliplexSpacing.s1),
                        Text(
                          formatDocumentTitle(doc.title),
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                              ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        IconButton(
                          onPressed: () => _removeDocument(doc),
                          icon: const Icon(Icons.close, size: 16),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 24,
                            minHeight: 24,
                          ),
                          tooltip: 'Remove document filter',
                        ),
                      ],
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
                  tooltip: pickerTooltip,
                  onPressed: pickerEnabled ? _showDocumentPicker : null,
                  icon: const Icon(Icons.filter_alt),
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

/// Dialog for selecting documents from the room's document list.
class _DocumentPickerDialog extends ConsumerStatefulWidget {
  const _DocumentPickerDialog({
    required this.roomId,
    required this.initialSelection,
  });

  final String roomId;
  final Set<RagDocument> initialSelection;

  @override
  ConsumerState<_DocumentPickerDialog> createState() =>
      _DocumentPickerDialogState();
}

class _DocumentPickerDialogState extends ConsumerState<_DocumentPickerDialog> {
  late Set<RagDocument> _selected;
  late TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _selected = Set.from(widget.initialSelection);
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggleDocument(RagDocument doc) {
    setState(() {
      if (_selected.contains(doc)) {
        _selected.remove(doc);
      } else {
        _selected.add(doc);
      }
    });
  }

  List<RagDocument> _filterDocuments(List<RagDocument> documents) {
    final query = _searchController.text.toLowerCase();
    if (query.isEmpty) return documents;
    return documents
        .where((doc) => doc.title.toLowerCase().contains(query))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final documentsAsync = ref.watch(documentsProvider(widget.roomId));

    return AlertDialog(
      title: const Text('Select documents'),
      content: SizedBox(
        width: 300,
        height: 400,
        child: documentsAsync.when(
          data: (documents) {
            if (documents.isEmpty) {
              return const Center(child: Text('No documents in this room.'));
            }
            final filteredDocs = _filterDocuments(documents);
            return Column(
              children: [
                TextField(
                  controller: _searchController,
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: 'Search documents...',
                    prefixIcon: Icon(Icons.search),
                    isDense: true,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: SoliplexSpacing.s2),
                Expanded(
                  child: filteredDocs.isEmpty
                      ? const Center(child: Text('No matches'))
                      : ListView.builder(
                          itemCount: filteredDocs.length,
                          itemBuilder: (context, index) {
                            final doc = filteredDocs[index];
                            final isSelected = _selected.contains(doc);
                            return CheckboxListTile(
                              title: Text(formatDocumentTitle(doc.title)),
                              value: isSelected,
                              onChanged: (_) => _toggleDocument(doc),
                            );
                          },
                        ),
                ),
              ],
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
        TextButton(
          onPressed: documentsAsync.isLoading
              ? null
              : () => Navigator.of(context).pop(_selected),
          child: const Text('Done'),
        ),
      ],
    );
  }
}
