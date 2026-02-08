import 'package:flutter/material.dart';
import 'package:soliplex_frontend/design/design.dart';
import 'package:soliplex_frontend/features/log_viewer/widgets/log_level_badge.dart';
import 'package:soliplex_logging/soliplex_logging.dart';

/// Displays a single log record.
///
/// Layout: `[LogLevelBadge] [HH:mm:ss.SSS] [loggerName]` / `[message]`
///
/// Records with [LogRecord.error] or [LogRecord.stackTrace] render as an
/// [ExpansionTile] so the user can expand to see error details.
/// Records without use a plain [Padding] with the same visual layout.
class LogRecordTile extends StatelessWidget {
  const LogRecordTile({required this.record, super.key});

  final LogRecord record;

  @override
  Widget build(BuildContext context) {
    if (record.hasDetails) {
      return _ExpandableTile(record: record);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: SoliplexSpacing.s4,
        vertical: SoliplexSpacing.s2,
      ),
      child: _TileContent(record: record),
    );
  }
}

class _ExpandableTile extends StatelessWidget {
  const _ExpandableTile({required this.record});

  final LogRecord record;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: SoliplexSpacing.s4),
      childrenPadding: const EdgeInsets.fromLTRB(
        SoliplexSpacing.s4,
        0,
        SoliplexSpacing.s4,
        SoliplexSpacing.s2,
      ),
      title: _TileContent(record: record),
      children: [
        if (record.error != null)
          _DetailSection(label: 'Error', text: record.error.toString()),
        if (record.stackTrace != null)
          _DetailSection(
            label: 'Stack Trace',
            text: record.stackTrace.toString(),
            style: theme.textTheme.bodySmall?.copyWith(
              fontFamily: 'monospace',
              fontSize: 11,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}

class _TileContent extends StatelessWidget {
  const _TileContent({required this.record});

  final LogRecord record;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          spacing: SoliplexSpacing.s2,
          children: [
            LogLevelBadge(level: record.level),
            Text(
              record.formattedTimestamp,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              record.loggerName,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          record.message,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium,
        ),
      ],
    );
  }
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({
    required this.label,
    required this.text,
    this.style,
  });

  final String label;
  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Align(
      alignment: Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          SelectableText(
            text,
            style: style ??
                theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
          ),
        ],
      ),
    );
  }
}
