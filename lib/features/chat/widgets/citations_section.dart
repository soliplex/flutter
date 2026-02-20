import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soliplex_client/soliplex_client.dart'
    show SourceReference, SourceReferenceFormatting;
import 'package:soliplex_frontend/core/providers/citations_expanded_provider.dart';
import 'package:soliplex_frontend/core/providers/rooms_provider.dart';
import 'package:soliplex_frontend/core/providers/threads_provider.dart';
import 'package:soliplex_frontend/design/design.dart';
import 'package:soliplex_frontend/features/chat/widgets/chunk_visualization_page.dart';
import 'package:soliplex_frontend/shared/widgets/markdown/flutter_markdown_plus_renderer.dart';
import 'package:soliplex_frontend/shared/widgets/markdown/markdown_theme_extension.dart';
import 'package:url_launcher/url_launcher.dart';

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
  /// Creates a citations section with the given source references.
  const CitationsSection({
    required this.messageId,
    required this.sourceReferences,
    super.key,
  });

  /// The message ID used to persist expand state.
  final String messageId;

  /// The source references to display.
  final List<SourceReference> sourceReferences;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (sourceReferences.isEmpty) return const SizedBox.shrink();

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
    final count = sourceReferences.length;

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
            ...sourceReferences.asMap().entries.map((entry) {
              return _SourceReferenceRow(
                index: entry.key + 1,
                sourceReference: entry.value,
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

class _SourceReferenceRow extends ConsumerWidget {
  const _SourceReferenceRow({
    required this.index,
    required this.sourceReference,
    required this.threadId,
    required this.messageId,
    required this.citationIndex,
  });

  final int index;
  final SourceReference sourceReference;
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
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: sourceReference.displayTitle,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (sourceReference.formattedPageNumbers
                            case final pageNums?) ...[
                          TextSpan(
                            text: '  •  $pageNums',
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
                if (sourceReference.isPdf)
                  _PdfViewButton(sourceReference: sourceReference),
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
              child: SelectionArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Headings breadcrumb
                    if (sourceReference.headings.isNotEmpty) ...[
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
                              sourceReference.headings.join(' > '),
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
                    if (sourceReference.content.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(SoliplexSpacing.s3),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(
                            soliplexTheme.radii.sm,
                          ),
                        ),
                        constraints: const BoxConstraints(maxHeight: 250),
                        child: SingleChildScrollView(
                          child: _CitationMarkdown(
                            data: sourceReference.content,
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
                          sourceReference.isPdf
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
                                  text: sourceReference.documentUri,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                    fontFamily: 'monospace',
                                    fontSize: 11,
                                  ),
                                ),
                                if (sourceReference.formattedPageNumbers
                                    case final pageNums?) ...[
                                  TextSpan(
                                    text: '  •  $pageNums',
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
            ),
          ],
        ],
      ),
    );
  }
}

/// Renders citation content as markdown, scaled to `bodySmall`.
///
/// Overrides the app-level [MarkdownThemeExtension] so that paragraph text
/// matches the surrounding citation typography instead of the chat-message
/// default (`bodyMedium`).
class _CitationMarkdown extends StatelessWidget {
  const _CitationMarkdown({required this.data});

  final String data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mdTheme = theme.extension<MarkdownThemeExtension>();
    final smallBody = theme.textTheme.bodySmall;

    return Theme(
      data: theme.copyWith(
        extensions: {
          ...theme.extensions.values,
          if (mdTheme != null) mdTheme.copyWith(body: smallBody),
        },
      ),
      child: FlutterMarkdownPlusRenderer(
        data: data,
        onLinkTap: _openLink,
      ),
    );
  }

  Future<void> _openLink(String href, String? title) async {
    final uri = Uri.tryParse(href);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class _PdfViewButton extends ConsumerWidget {
  const _PdfViewButton({required this.sourceReference});

  final SourceReference sourceReference;

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
        chunkId: sourceReference.chunkId,
        documentTitle: sourceReference.displayTitle,
      ),
      tooltip: 'View page',
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
    );
  }
}
