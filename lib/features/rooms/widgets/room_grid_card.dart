import 'package:dashed_border/dashed_border.dart';
import 'package:flutter/material.dart';
import 'package:soliplex_client/soliplex_client.dart' hide State;

import 'package:soliplex_frontend/design/tokens/spacing.dart';

class RoomGridCard extends StatefulWidget {
  const RoomGridCard({required this.room, required this.onTap, super.key});

  final Room room;
  final VoidCallback onTap;

  @override
  State<RoomGridCard> createState() => _RoomGridCardState();

  /// Placeholder card for creating a new room.
  ///
  /// The [onTap] callback will be wired to room creation when implemented.
  static Widget ghost({
    required BuildContext context,
    VoidCallback? onTap,
  }) {
    return Semantics(
      button: true,
      label: 'Create new room',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: DashedBorder(
              color: Theme.of(context).dividerTheme.color!,
              width: 2,
              dashGap: 6,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.add, size: 64, color: Colors.grey),
              const SizedBox(height: SoliplexSpacing.s2),
              Text(
                'New Room',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Colors.grey,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoomGridCardState extends State<RoomGridCard> {
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
              padding: const EdgeInsets.all(24),
              foregroundDecoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: divider.color!,
                  width: divider.thickness! * (isHovered ? 2 : 1),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  /// Header
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: SoliplexSpacing.s2,
                    children: [
                      const Icon(Icons.meeting_room, size: 32),
                      const SizedBox(width: SoliplexSpacing.s2),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              room.name,
                              style: Theme.of(context).textTheme.titleMedium,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (room.hasDescription)
                              Text(
                                room.description,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                              ),
                          ],
                        ),
                      ),
                    ],
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
