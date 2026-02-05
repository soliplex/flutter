import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:soliplex_client/soliplex_client.dart';

import 'package:soliplex_frontend/core/providers/rooms_provider.dart';
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

class RoomSearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  String get query => state;
  set query(String value) => state = value;

  void clear() => state = '';
}

final roomSearchQueryProvider =
    NotifierProvider<RoomSearchQueryNotifier, String>(
  RoomSearchQueryNotifier.new,
);

final filteredRoomsProvider = Provider<AsyncValue<List<Room>>>((ref) {
  final roomsAsync = ref.watch(roomsProvider);
  final query = ref.watch(roomSearchQueryProvider).toLowerCase().trim();

  return roomsAsync.whenData((rooms) {
    if (query.isEmpty) return rooms;

    return rooms.where((room) {
      return room.name.toLowerCase().contains(query) ||
          (room.hasDescription &&
              room.description.toLowerCase().contains(query));
    }).toList();
  });
});

/// Screen displaying list of available rooms.
///
/// Returns body content only; AppShell wrapper is provided by the router.
class RoomsScreen extends ConsumerWidget {
  const RoomsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roomsAsync = ref.watch(filteredRoomsProvider);
    final isGridView = ref.watch(isGridViewProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isMobile = width < SoliplexBreakpoints.tablet;

        final maxContentWidth = width >= SoliplexBreakpoints.desktop
            ? width * 2 / 3
            : width - SoliplexSpacing.s4 * 2;

        return Align(
          alignment: AlignmentDirectional.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxContentWidth),
            child: Column(
              spacing: SoliplexSpacing.s4,
              children: [
                RoomSearchToolbar(
                  query: ref.watch(roomSearchQueryProvider),
                  isGridView: isGridView,
                  showViewToggle: !isMobile,
                  onQueryChanged: (value) =>
                      ref.read(roomSearchQueryProvider.notifier).query = value,
                  onToggleView: () =>
                      ref.read(isGridViewProvider.notifier).toggle(),
                ),
                Expanded(
                  child: roomsAsync.when(
                    data: (rooms) {
                      if (rooms.isEmpty) {
                        return const EmptyState(
                          message: 'No rooms available',
                          icon: Icons.meeting_room_outlined,
                        );
                      }

                      void navigateToRoom(Room room) {
                        ref.read(currentRoomIdProvider.notifier).set(room.id);
                        context.push('/rooms/${room.id}');
                      }

                      if (isGridView && !isMobile) {
                        return GridView.builder(
                          gridDelegate:
                              const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 300,
                            childAspectRatio: 3 / 2,
                            crossAxisSpacing: SoliplexSpacing.s2,
                            mainAxisSpacing: SoliplexSpacing.s2,
                          ),
                          itemCount: rooms.length,
                          itemBuilder: (context, index) {
                            final room = rooms[index];
                            return RoomGridCard(
                              room: room,
                              onTap: () => navigateToRoom(room),
                            );
                          },
                        );
                      }

                      return ListView.builder(
                        itemCount: rooms.length,
                        itemBuilder: (context, index) {
                          final room = rooms[index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: SoliplexSpacing.s1,
                            ),
                            child: RoomListTile(
                              room: room,
                              onTap: () => navigateToRoom(room),
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
            ),
          ),
        );
      },
    );
  }
}
