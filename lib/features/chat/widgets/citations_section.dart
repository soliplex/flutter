import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soliplex_client/soliplex_client.dart' hide State;
import 'package:soliplex_frontend/core/providers/citations_expanded_provider.dart';
import 'package:soliplex_frontend/core/providers/rooms_provider.dart';
import 'package:soliplex_frontend/core/providers/threads_provider.dart';
import 'package:soliplex_frontend/design/design.dart';
import 'package:soliplex_frontend/features/chat/widgets/chunk_visualization_page.dart';

/// Expandable section showing source citations for a message.
///
/// Displays a header with citation count that can be tapped to expand/collapse
/// the full citation list. Each citation shows the document title, a snippet
/// of content, and an optional link to view the source.
///
/// Both section and individual citation expand state is persisted via Riverpod
/// provider, scoped by thread. State survives widget rebuilds and is cleaned up
/// when leaving the thread.
class CitationsSection extends ConsumerWidget {
  /// Creates a citations section with the given citations.
  const CitationsSection({
    required this.messageId,
    required this.citations,
    super.key,
  });

  /// The message ID used to persist expand state.
  final String messageId;

  /// The citations to display.
  final List<Citation> citations;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (citations.isEmpty) return const SizedBox.shrink();

    // Get current thread ID from selection state
    final selection = ref.watch(threadSelectionProvider);
    final threadId = switch (selection) {
      ThreadSelected(:final threadId) => threadId,
      _ => null,
    };

    // No thread selected - can't persist expand state
    if (threadId == null) return const SizedBox.shrink();

    // Use select to only rebuild when this section's expand state changes
    final expanded = ref.watch(
      citationsExpandedProvider(threadId).select((s) => s.contains(messageId)),
    );

    final theme = Theme.of(context);
    final count = citations.length;

    return Container(
      margin: const EdgeInsets.only(top: SoliplexSpacing.s2),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(
            context,
            ref,
            theme,
            count,
            threadId: threadId,
            expanded: expanded,
          ),
          if (expanded)
            ...citations.asMap().entries.map((entry) {
              return _CitationRow(
                index: entry.key + 1,
                citation: entry.value,
                threadId: threadId,
                messageId: messageId,
                citationIndex: entry.key,
              );
            }),
        ],
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
    int count, {
    required String threadId,
    required bool expanded,
  }) {
    return InkWell(
      onTap: () =>
          ref.read(citationsExpandedProvider(threadId).notifier).toggle(
                messageId,
              ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: SoliplexSpacing.s2),
        child: Row(
          children: [
            Transform.flip(
              flipX: true,
              child: Icon(
                Icons.format_quote,
                size: 16,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: SoliplexSpacing.s2),
            Text(
              '$count source${count == 1 ? '' : 's'}',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
            const Spacer(),
            Icon(
              expanded ? Icons.expand_less : Icons.expand_more,
              size: 20,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

class _CitationRow extends ConsumerWidget {
  const _CitationRow({
    required this.index,
    required this.citation,
    required this.threadId,
    required this.messageId,
    required this.citationIndex,
  });

  final int index;
  final Citation citation;
  final String threadId;
  final String messageId;
  final int citationIndex;

  String get _expandKey => '$messageId:$citationIndex';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isExpanded = ref.watch(
      citationsExpandedProvider(threadId).select((s) => s.contains(_expandKey)),
    );

    final theme = Theme.of(context);
    final soliplexTheme = SoliplexTheme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: SoliplexSpacing.s2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row (always visible, tappable to toggle)
          InkWell(
            onTap: () => ref
                .read(citationsExpandedProvider(threadId).notifier)
                .toggle(_expandKey),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(soliplexTheme.radii.sm),
                  ),
                  child: Text(
                    '$index',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: SoliplexSpacing.s2),
                Expanded(
                  child: Text(
                    citation.displayTitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (citation.isPdf) _PdfViewButton(citation: citation),
                Icon(
                  isExpanded ? Icons.expand_less : Icons.expand_more,
                  size: 20,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),

          // Expanded content
          if (isExpanded) ...[
            Padding(
              padding: const EdgeInsets.only(
                left: 32, // 24 badge + 8 spacing
                top: SoliplexSpacing.s2,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Headings breadcrumb
                  if (citation.headings != null &&
                      citation.headings!.isNotEmpty) ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.subdirectory_arrow_right,
                          size: 14,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: SoliplexSpacing.s1),
                        Expanded(
                          child: Text(
                            citation.headings!.join(' > '),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: SoliplexSpacing.s2),
                  ],
                  // Content preview in styled container
                  if (citation.content.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(SoliplexSpacing.s3),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(
                          soliplexTheme.radii.sm,
                        ),
                      ),
                      constraints: const BoxConstraints(maxHeight: 150),
                      child: SingleChildScrollView(
                        child: Text(
                          citation.content,
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ),
                    const SizedBox(height: SoliplexSpacing.s2),
                  ],
                  // File path and page numbers
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        citation.isPdf
                            ? Icons.picture_as_pdf_outlined
                            : Icons.insert_drive_file_outlined,
                        size: 14,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: SoliplexSpacing.s1),
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: citation.documentUri,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontFamily: 'monospace',
                                  fontSize: 11,
                                ),
                              ),
                              if (citation.formattedPageNumbers != null) ...[
                                TextSpan(
                                  text: '  •  ${citation.formattedPageNumbers}',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PdfViewButton extends ConsumerWidget {
  const _PdfViewButton({required this.citation});

  final Citation citation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roomId = ref.watch(currentRoomIdProvider);

    // Can't show button without room context
    if (roomId == null) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);

    return IconButton(
      icon: Icon(
        Icons.visibility_outlined,
        size: 18,
        color: theme.colorScheme.primary,
      ),
      onPressed: () => ChunkVisualizationPage.show(
        context: context,
        roomId: roomId,
        chunkId: citation.chunkId,
        documentTitle: citation.displayTitle,
      ),
      tooltip: 'View page',
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
    );
  }
}
