import 'package:flutter/material.dart';
import 'package:soliplex_client/soliplex_client.dart' hide State;
import 'package:soliplex_frontend/design/tokens/radii.dart';
import 'package:soliplex_frontend/design/tokens/spacing.dart';
import 'package:soliplex_frontend/shared/widgets/overflow_tooltip.dart';

class RoomGridCard extends StatefulWidget {
  const RoomGridCard({required this.room, required this.onTap, super.key});

  final Room room;
  final VoidCallback onTap;

  @override
  State<RoomGridCard> createState() => _RoomGridCardState();
}

class _RoomGridCardState extends State<RoomGridCard> {
  bool isHovered = false;

  Room get room => widget.room;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return MouseRegion(
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
                padding: const EdgeInsets.symmetric(
                  horizontal: SoliplexSpacing.s6,
                  vertical: SoliplexSpacing.s4,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: OverflowTooltip(
                            text: room.name,
                            style: theme.textTheme.titleMedium,
                          ),
                        ),
                        Icon(
                          Icons.chevron_right,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                    if (room.hasDescription) ...[
                      const SizedBox(height: 4),
                      OverflowTooltip(
                        text: room.description,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 3,
                      ),
                    ],
                    const Spacer(),
                    Text(
                      'Last active: 2 hours ago',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
