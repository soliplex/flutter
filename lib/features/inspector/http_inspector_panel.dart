import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:soliplex_frontend/core/providers/http_log_provider.dart';
import 'package:soliplex_frontend/design/design.dart';
import 'package:soliplex_frontend/features/inspector/models/http_event_group.dart';
import 'package:soliplex_frontend/features/inspector/models/http_event_grouper.dart';
import 'package:soliplex_frontend/features/inspector/widgets/http_event_tile.dart';

/// Panel displaying HTTP traffic log for debugging.
class HttpInspectorPanel extends ConsumerWidget {
  const HttpInspectorPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = ref.watch(httpLogProvider);
    final groups = groupHttpEvents(events);
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < SoliplexBreakpoints.mobile;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(theme, ref, groups.length, isCompact),
            const Divider(height: 1),
            Expanded(
              child: groups.isEmpty
                  ? _buildEmptyState(theme, isCompact)
                  : _buildList(groups, isCompact),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEmptyState(ThemeData theme, bool isCompact) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(isCompact ? 16 : 24),
        child: Text(
          'No HTTP activity yet',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  Widget _buildList(List<HttpEventGroup> groups, bool isCompact) {
    return ListView.separated(
      reverse: true,
      padding: EdgeInsets.symmetric(
        vertical: isCompact ? 4 : 8,
      ),
      itemCount: groups.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final reversedIndex = groups.length - 1 - index;
        return HttpEventTile(
          group: groups[reversedIndex],
          dense: isCompact,
        );
      },
    );
  }

  Widget _buildHeader(
    ThemeData theme,
    WidgetRef ref,
    int requestCount,
    bool isCompact,
  ) {
    final titleStyle =
        isCompact ? theme.textTheme.titleSmall : theme.textTheme.titleMedium;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 12 : 16,
        vertical: isCompact ? 10 : 12,
      ),
      child: isCompact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('HTTP Inspector', style: titleStyle),
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (requestCount > 0)
                      Text(
                        // ignore: lines_longer_than_80_chars
                        '$requestCount ${requestCount == 1 ? 'request' : 'requests'}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () =>
                          ref.read(httpLogProvider.notifier).clear(),
                      tooltip: 'Clear log',
                    ),
                  ],
                ),
              ],
            )
          : Row(
              children: [
                Text('HTTP Inspector', style: titleStyle),
                const Spacer(),
                if (requestCount > 0)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(
                      // ignore: lines_longer_than_80_chars
                      '$requestCount ${requestCount == 1 ? 'request' : 'requests'}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => ref.read(httpLogProvider.notifier).clear(),
                  tooltip: 'Clear log',
                ),
              ],
            ),
    );
  }
}
