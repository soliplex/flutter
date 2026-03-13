import 'package:flutter/material.dart';
import 'package:soliplex_client/soliplex_client.dart' hide State;

import 'package:soliplex_frontend/design/tokens/radii.dart';
import 'package:soliplex_frontend/design/tokens/spacing.dart';
import 'package:soliplex_frontend/shared/widgets/overflow_tooltip.dart';

class RoomListTile extends StatefulWidget {
  const RoomListTile({
    required this.room,
    required this.onTap,
    this.unreadCount = 0,
    super.key,
  });

  final Room room;
  final VoidCallback onTap;
  final int unreadCount;

  @override
  State<RoomListTile> createState() => _RoomListTileState();
}

class _RoomListTileState extends State<RoomListTile> {
  bool isHovered = false;

  Room get room => widget.room;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      button: true,
      label: 'Open room: ${room.name}',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => isHovered = true),
        onExit: (_) => setState(() => isHovered = false),
        child: AnimatedScale(
          scale: isHovered ? 1.02 : 1.0,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(soliplexRadii.md),
              boxShadow: [
                BoxShadow(
                  color: theme.shadowColor
                      .withValues(alpha: isHovered ? 0.15 : 0.05),
                  blurRadius: isHovered ? 12 : 4,
                  offset: Offset(0, isHovered ? 4 : 2),
                ),
              ],
            ),
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(soliplexRadii.md),
                side: BorderSide(
                  color: isHovered
                      ? theme.colorScheme.outline
                      : theme.colorScheme.outlineVariant,
                ),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(soliplexRadii.md),
                onTap: widget.onTap,
                child: Padding(
                  padding: const EdgeInsets.all(SoliplexSpacing.s6),
                  child: Row(
                    children: [
                      const Icon(Icons.meeting_room, size: 28),
                      const SizedBox(width: SoliplexSpacing.s2),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            OverflowTooltip(
                              text: room.name,
                              style: theme.textTheme.titleMedium,
                            ),
                            if (room.hasDescription)
                              OverflowTooltip(
                                text: room.description,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (widget.unreadCount > 0)
                        _UnreadBadge(count: widget.unreadCount),
                      Icon(
                        Icons.chevron_right,
                        color: theme.iconTheme.color?.withAlpha(
                          (0.6 * 255).toInt(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: colorScheme.primary,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$count',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colorScheme.onPrimary,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}
