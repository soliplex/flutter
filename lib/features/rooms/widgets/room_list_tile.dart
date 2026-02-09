import 'package:flutter/material.dart';
import 'package:soliplex_client/soliplex_client.dart' hide State;

import 'package:soliplex_frontend/design/tokens/radii.dart';
import 'package:soliplex_frontend/design/tokens/spacing.dart';

class RoomListTile extends StatefulWidget {
  const RoomListTile({required this.room, required this.onTap, super.key});

  final Room room;
  final VoidCallback onTap;

  @override
  State<RoomListTile> createState() => _RoomListTileState();
}

class _RoomListTileState extends State<RoomListTile> {
  bool isHovered = false;

  Room get room => widget.room;

  @override
  Widget build(BuildContext context) {
    final divider = Theme.of(context).dividerTheme;

    return Semantics(
      button: true,
      label: 'Open room: ${room.name}',
      child: Tooltip(
        message: room.name,
        waitDuration: const Duration(milliseconds: 500),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => isHovered = true),
          onExit: (_) => setState(() => isHovered = false),
          child: GestureDetector(
            onTap: widget.onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              padding: const EdgeInsets.all(SoliplexSpacing.s6),
              foregroundDecoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(soliplexRadii.md),
                border: Border.all(
                  color: divider.color!,
                  width: divider.thickness! * (isHovered ? 2 : 1),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.meeting_room, size: 28),
                  const SizedBox(width: SoliplexSpacing.s2),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          room.name,
                          style: Theme.of(context).textTheme.titleMedium,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (room.hasDescription)
                          Text(
                            room.description,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: Theme.of(
                      context,
                    ).iconTheme.color?.withAlpha((0.6 * 255).toInt()),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
