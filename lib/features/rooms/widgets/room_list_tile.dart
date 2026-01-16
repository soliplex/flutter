import 'package:dashed_border/dashed_border.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:soliplex_client/soliplex_client.dart' hide State;

import 'package:soliplex_frontend/core/providers/rooms_provider.dart';
import 'package:soliplex_frontend/design/tokens/spacing.dart';

class RoomListTile extends ConsumerStatefulWidget {
  const RoomListTile({required this.room, super.key});

  final Room room;

  @override
  ConsumerState<RoomListTile> createState() => _RoomListTileState();

  static Widget ghost({required BuildContext context}) {
    return GestureDetector(
      onTap: () {},
      child: Container(
        height: 86,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: DashedBorder(
            color: Theme.of(context).dividerTheme.color!,
            width: 2,
            dashGap: 6,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: SoliplexSpacing.s2,
          children: [
            const Icon(Icons.add, size: 48, color: Colors.grey),
            const SizedBox(width: SoliplexSpacing.s2),
            Text(
              'New Room',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoomListTileState extends ConsumerState<RoomListTile> {
  bool isHovered = false;

  Room get room => widget.room;

  @override
  Widget build(BuildContext context) {
    final divider = Theme.of(context).dividerTheme;

    return MouseRegion(
      onEnter: (_) => setState(() => isHovered = true),
      onExit: (_) => setState(() => isHovered = false),
      child: GestureDetector(
        onTap: () {
          ref.read(currentRoomIdProvider.notifier).set(room.id);
          context.push('/rooms/${room.id}');
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.all(24),
          foregroundDecoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(12),
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
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: Theme.of(context).iconTheme.color?.withAlpha(
                      (0.6 * 255).toInt(),
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
