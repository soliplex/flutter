import 'package:flutter/material.dart';
import 'package:soliplex_client/soliplex_client.dart' hide State;
import 'package:soliplex_frontend/design/design.dart';

/// Expandable section showing source citations for a message.
///
/// Displays a header with citation count that can be tapped to expand/collapse
/// the full citation list. Each citation shows the document title, a snippet
/// of content, and an optional link to view the source.
class CitationsSection extends StatefulWidget {
  /// Creates a citations section with the given citations.
  const CitationsSection({required this.citations, super.key});

  /// The citations to display.
  final List<Citation> citations;

  @override
  State<CitationsSection> createState() => _CitationsSectionState();
}

class _CitationsSectionState extends State<CitationsSection> {
  bool _expanded = false;
  final Set<int> _expandedCitations = {};

  @override
  Widget build(BuildContext context) {
    if (widget.citations.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final count = widget.citations.length;

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
          _buildHeader(theme, count),
          if (_expanded) ..._buildCitationRows(),
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, int count) {
    return InkWell(
      onTap: () => setState(() => _expanded = !_expanded),
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
              _expanded ? Icons.expand_less : Icons.expand_more,
              size: 20,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildCitationRows() {
    return widget.citations.asMap().entries.map((entry) {
      final index = entry.key;
      return _CitationRow(
        index: index + 1,
        citation: entry.value,
        isExpanded: _expandedCitations.contains(index),
        onToggle: () {
          setState(() {
            if (_expandedCitations.contains(index)) {
              _expandedCitations.remove(index);
            } else {
              _expandedCitations.add(index);
            }
          });
        },
      );
    }).toList();
  }
}

class _CitationRow extends StatelessWidget {
  const _CitationRow({
    required this.index,
    required this.citation,
    required this.isExpanded,
    required this.onToggle,
  });

  final int index;
  final Citation citation;
  final bool isExpanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final soliplexTheme = SoliplexTheme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: SoliplexSpacing.s2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row (always visible, tappable to toggle)
          InkWell(
            onTap: onToggle,
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
                    Text(
                      citation.headings!.join(' > '),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontStyle: FontStyle.italic,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: SoliplexSpacing.s1),
                  ],
                  // Scrollable content preview
                  if (citation.content.isNotEmpty)
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 150),
                      child: SingleChildScrollView(
                        child: Text(
                          citation.content,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
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
