import 'package:flutter/material.dart';

import 'package:soliplex_frontend/features/inspector/models/http_event_group.dart';
import 'package:soliplex_frontend/features/inspector/widgets/http_status_display.dart';
import 'package:soliplex_frontend/shared/utils/format_utils.dart';

/// Displays a grouped HTTP request with its outcome.
///
/// Groups related events (request + response/error) into a single tile
/// showing method, path, timestamp, and result status.
class HttpEventTile extends StatelessWidget {
  const HttpEventTile({
    required this.group,
    this.dense = false,
    super.key,
  });

  /// The grouped events for a single HTTP request.
  final HttpEventGroup group;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      label: group.semanticLabel,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: dense ? 8 : 12,
          vertical: dense ? 6 : 8,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildRequestLine(theme),
            SizedBox(height: dense ? 2 : 4),
            _buildResultLine(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestLine(ThemeData theme) {
    final colorScheme = theme.colorScheme;

    final methodStyle =
        (dense ? theme.textTheme.bodySmall : theme.textTheme.bodyMedium)
            ?.copyWith(
      fontWeight: FontWeight.bold,
      color: group.isStream ? colorScheme.secondary : colorScheme.primary,
    );

    final pathStyle =
        dense ? theme.textTheme.bodySmall : theme.textTheme.bodyMedium;

    return Row(
      children: [
        Text(
          group.methodLabel,
          style: methodStyle,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            group.pathWithQuery,
            style: pathStyle,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
      ],
    );
  }

  Widget _buildResultLine(ThemeData theme) {
    final colorScheme = theme.colorScheme;

    final metaStyle = theme.textTheme.bodySmall?.copyWith(
      color: colorScheme.onSurfaceVariant,
      fontSize: dense ? 11 : null,
    );

    return Row(
      children: [
        if (!dense) ...[
          Text(
            group.timestamp.toHttpTimeString(),
            style: metaStyle,
          ),
          const SizedBox(width: 4),
          Text('→', style: metaStyle),
          const SizedBox(width: 4),
        ],
        Expanded(
          child: HttpStatusDisplay(
            group: group,
          ),
        ),
      ],
    );
  }
}
