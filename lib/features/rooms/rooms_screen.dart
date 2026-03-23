import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:soliplex_client/soliplex_client.dart';
import 'package:soliplex_frontend/core/logging/loggers.dart';
import 'package:soliplex_frontend/core/providers/rooms_provider.dart';
import 'package:soliplex_frontend/core/providers/unread_runs_provider.dart';
import 'package:soliplex_frontend/design/tokens/breakpoints.dart';
import 'package:soliplex_frontend/design/tokens/spacing.dart';
import 'package:soliplex_frontend/features/rooms/widgets/room_grid_card.dart';
import 'package:soliplex_frontend/features/rooms/widgets/room_list_tile.dart';
import 'package:soliplex_frontend/features/rooms/widgets/room_search_toolbar.dart';
import 'package:soliplex_frontend/shared/widgets/empty_state.dart';
import 'package:soliplex_frontend/shared/widgets/error_display.dart';
import 'package:soliplex_frontend/shared/widgets/loading_indicator.dart';

class IsGridViewNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() => state = !state;
}

final isGridViewProvider = NotifierProvider<IsGridViewNotifier, bool>(
  IsGridViewNotifier.new,
);

/// Screen displaying list of available rooms.
///
/// Returns body content only; AppShell wrapper is provided by the router.
class RoomsScreen extends ConsumerStatefulWidget {
  const RoomsScreen({super.key});

  @override
  ConsumerState<RoomsScreen> createState() => _RoomsScreenState();
}

class _RoomsScreenState extends ConsumerState<RoomsScreen> {
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(roomsProvider);
    });
  }

  List<Room> _filterRooms(List<Room> rooms) {
    final query = _searchQuery.toLowerCase().trim();
    if (query.isEmpty) return rooms;

    return rooms.where((room) {
      return room.name.toLowerCase().contains(query) ||
          (room.hasDescription &&
              room.description.toLowerCase().contains(query));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final roomsAsync = ref.watch(roomsProvider);
    final isGridView = ref.watch(isGridViewProvider);
    final unreadRuns = ref.watch(unreadRunsProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isMobile = width < SoliplexBreakpoints.tablet;

        final maxContentWidth = width >= SoliplexBreakpoints.desktop
            ? width * 2 / 3
            : width - SoliplexSpacing.s4 * 2;

        return Column(
          children: [
            Align(
              alignment: AlignmentDirectional.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxContentWidth),
                child: RoomSearchToolbar(
                  query: _searchQuery,
                  isGridView: isGridView,
                  showViewToggle: !isMobile,
                  onQueryChanged: (value) =>
                      setState(() => _searchQuery = value),
                  onToggleView: () =>
                      ref.read(isGridViewProvider.notifier).toggle(),
                ),
              ),
            ),
            const SizedBox(height: SoliplexSpacing.s4),
            Expanded(
              child: roomsAsync.when(
                data: (rooms) {
                  final filtered = _filterRooms(rooms);
                  Loggers.room.debug('Rooms loaded: ${filtered.length}');
                  if (filtered.isEmpty) {
                    return const EmptyState(
                      message: 'No rooms available',
                      icon: Icons.meeting_room_outlined,
                    );
                  }

                  void navigateToRoom(Room room) {
                    Loggers.room.info(
                      'Room selected:'
                      ' ${room.id} (${room.name})',
                    );
                    ref
                        .read(
                          currentRoomIdProvider.notifier,
                        )
                        .set(room.id);
                    context.push('/rooms/${room.id}');
                  }

                  if (isGridView && !isMobile) {
                    const cardSpacing = SoliplexSpacing.s3;
                    final cardsPerRow =
                        width >= SoliplexBreakpoints.desktop ? 3 : 2;
                    final rowCount =
                        (filtered.length + cardsPerRow - 1) ~/ cardsPerRow;

                    return ListView.builder(
                      itemCount: rowCount,
                      itemBuilder: (context, rowIndex) {
                        final start = rowIndex * cardsPerRow;
                        final end =
                            (start + cardsPerRow).clamp(0, filtered.length);
                        final rowRooms = filtered.sublist(start, end);

                        return Center(
                          child: ConstrainedBox(
                            constraints:
                                BoxConstraints(maxWidth: maxContentWidth),
                            child: Padding(
                              padding: EdgeInsets.only(
                                bottom:
                                    rowIndex < rowCount - 1 ? cardSpacing : 0,
                              ),
                              child: Row(
                                spacing: cardSpacing,
                                children: [
                                  for (var i = 0; i < cardsPerRow; i++)
                                    Expanded(
                                      child: i < rowRooms.length
                                          ? AspectRatio(
                                              aspectRatio: 1.25,
                                              child: RoomGridCard(
                                                room: rowRooms[i],
                                                onTap: () => navigateToRoom(
                                                  rowRooms[i],
                                                ),
                                                unreadCount: unreadRuns
                                                    .unreadCountForRoom(
                                                  rowRooms[i].id,
                                                ),
                                              ),
                                            )
                                          : const SizedBox.shrink(),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  }

                  return ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final room = filtered[index];
                      return Center(
                        child: ConstrainedBox(
                          constraints:
                              BoxConstraints(maxWidth: maxContentWidth),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: SoliplexSpacing.s1,
                            ),
                            child: RoomListTile(
                              room: room,
                              onTap: () => navigateToRoom(room),
                              unreadCount:
                                  unreadRuns.unreadCountForRoom(room.id),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
                loading: () =>
                    const LoadingIndicator(message: 'Loading rooms...'),
                error: (error, stack) => ErrorDisplay(
                  error: error,
                  stackTrace: stack,
                  onRetry: () => ref.invalidate(roomsProvider),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
