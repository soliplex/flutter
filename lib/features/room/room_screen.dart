import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:soliplex_client/soliplex_client.dart';
import 'package:soliplex_frontend/core/logging/loggers.dart';
import 'package:soliplex_frontend/core/providers/rooms_provider.dart';
import 'package:soliplex_frontend/core/providers/shell_config_provider.dart';
import 'package:soliplex_frontend/core/providers/threads_provider.dart';
import 'package:soliplex_frontend/core/providers/unread_runs_provider.dart';
import 'package:soliplex_frontend/design/design.dart';
import 'package:soliplex_frontend/features/chat/chat_panel.dart';
import 'package:soliplex_frontend/features/history/history_panel.dart';
import 'package:soliplex_frontend/shared/widgets/app_shell.dart';
import 'package:soliplex_frontend/shared/widgets/shell_config.dart';

/// Screen displaying threads within a specific room.
///
/// Implements async thread selection on mount:
/// 1. Query param (`initialThreadId`) if valid
/// 2. Last viewed thread from SharedPreferences if valid
/// 3. First thread in list
///
/// This is a dynamic screen that builds its own AppShell to provide
/// dynamic ShellConfig (room name in title, sidebar toggle, room dropdown).
class RoomScreen extends ConsumerStatefulWidget {
  const RoomScreen({required this.roomId, this.initialThreadId, super.key});

  final String roomId;

  /// Thread ID from query param (?thread=xyz). Used for deep linking.
  final String? initialThreadId;

  @override
  ConsumerState<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends ConsumerState<RoomScreen> {
  String? _initializedForRoomId;
  bool _sidebarCollapsed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeThreadSelection();
    });
  }

  @override
  void didUpdateWidget(RoomScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.roomId != widget.roomId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _initializeThreadSelection();
      });
    }
  }

  /// Initializes thread selection with fallback chain.
  ///
  /// Priority: query param → last viewed → first thread.
  Future<void> _initializeThreadSelection() async {
    if (_initializedForRoomId == widget.roomId) return;
    _initializedForRoomId = widget.roomId;

    Loggers.room.debug('Room screen initialized for ${widget.roomId}');

    // Sync global room ID for currentRoomProvider and currentThreadProvider
    ref.read(currentRoomIdProvider.notifier).set(widget.roomId);

    final threads = await ref.read(threadsProvider(widget.roomId).future);
    if (!mounted) return;

    if (threads.isEmpty) {
      ref.read(threadSelectionProvider.notifier).set(const NoThreadSelected());
      return;
    }

    // 1. Query param (if valid)
    if (widget.initialThreadId != null &&
        threads.any((t) => t.id == widget.initialThreadId)) {
      Loggers.room.debug(
        'Thread selection: query param ${widget.initialThreadId}',
      );
      _selectThread(widget.initialThreadId!);
      return;
    }

    // 2. Last viewed (if valid)
    final lastViewed = await ref.read(
      lastViewedThreadProvider(widget.roomId).future,
    );
    if (!mounted) return;

    if (lastViewed
        case HasLastViewed(
          :final threadId,
        ) when threads.any((t) => t.id == threadId)) {
      Loggers.room.debug('Thread selection: last viewed $threadId');
      ref
          .read(unreadRunsProvider.notifier)
          .markRead((roomId: widget.roomId, threadId: threadId));
      ref.read(threadSelectionProvider.notifier).set(ThreadSelected(threadId));
      return;
    }

    // 3. First thread
    Loggers.room.debug(
      'Thread selection: first thread fallback ${threads.first.id}',
    );
    _selectThread(threads.first.id);
  }

  /// Selects a thread and persists as last viewed.
  void _selectThread(String threadId) {
    ref
        .read(unreadRunsProvider.notifier)
        .markRead((roomId: widget.roomId, threadId: threadId));
    selectAndPersistThread(ref: ref, roomId: widget.roomId, threadId: threadId);
  }

  /// Sidebar width for desktop layout.
  static const double _sidebarWidth = 300;

  @override
  Widget build(BuildContext context) {
    final isDesktop =
        MediaQuery.of(context).size.width >= SoliplexBreakpoints.desktop;

    final currentRoom = ref.watch(currentRoomProvider);
    final quizzes = currentRoom?.quizzes ?? const <String, String>{};

    final features = ref.watch(featuresProvider);

    return AppShell(
      config: ShellConfig(
        leading: isDesktop ? _buildSidebarToggle() : _buildBackButton(),
        title: _buildRoomDropdown(),
        actions: [
          if (currentRoom != null) _buildInfoButton(currentRoom),
          if (quizzes.isNotEmpty) _buildQuizButton(quizzes),
          if (features.enableSettings) _buildSettingsButton(),
        ],
        drawer: isDesktop ? null : HistoryPanel(roomId: widget.roomId),
      ),
      body: isDesktop ? _buildDesktopLayout(context) : const ChatPanel(),
    );
  }

  Widget _buildInfoButton(Room room) {
    return IconButton(
      icon: const Icon(Icons.info_outline),
      tooltip: 'Room information',
      onPressed: () => context.push('/rooms/${widget.roomId}/info'),
    );
  }

  Widget _buildBackButton() {
    return IconButton(
      icon: Icon(Icons.adaptive.arrow_back),
      tooltip: 'Back to rooms',
      onPressed: () => context.go('/rooms'),
    );
  }

  Widget _buildQuizButton(Map<String, String> quizzes) {
    return IconButton(
      icon: const Icon(Icons.quiz),
      tooltip: 'Take quiz',
      onPressed: () {
        if (quizzes.length == 1) {
          context.go('/rooms/${widget.roomId}/quiz/${quizzes.keys.first}');
        } else {
          _showQuizPicker(quizzes);
        }
      },
    );
  }

  Widget _buildSettingsButton() {
    return Semantics(
      label: 'Settings',
      child: IconButton(
        icon: const Icon(Icons.settings),
        onPressed: () => context.push('/settings'),
        tooltip: 'Open settings',
      ),
    );
  }

  Future<void> _showQuizPicker(Map<String, String> quizzes) async {
    final sortedEntries = quizzes.entries.toList()
      ..sort((a, b) => a.value.toLowerCase().compareTo(b.value.toLowerCase()));

    final selectedQuizId = await showDialog<String>(
      context: context,
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;

        return AlertDialog(
          title: const Text('Select Quiz'),
          contentPadding:
              const EdgeInsets.symmetric(vertical: SoliplexSpacing.s2),
          content: SizedBox(
            width: 480,
            height: 400,
            child: ListView.builder(
              itemCount: sortedEntries.length,
              itemBuilder: (context, index) {
                final entry = sortedEntries[index];
                return ListTile(
                  title: Text(entry.value),
                  leading: Icon(
                    Icons.quiz,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  onTap: () => Navigator.pop(context, entry.key),
                );
              },
            ),
          ),
        );
      },
    );

    if (selectedQuizId != null && mounted) {
      context.go('/rooms/${widget.roomId}/quiz/$selectedQuizId');
    }
  }

  Widget _buildSidebarToggle() {
    return IconButton(
      icon: Icon(_sidebarCollapsed ? Icons.menu : Icons.menu_open),
      tooltip: _sidebarCollapsed ? 'Show threads' : 'Hide threads',
      onPressed: () => setState(() => _sidebarCollapsed = !_sidebarCollapsed),
    );
  }

  Widget _buildRoomDropdown() {
    final roomsAsync = ref.watch(roomsProvider);
    final currentRoom = ref.watch(currentRoomProvider);

    String trimRoomName(String name) {
      const maxLength = 16;
      if (name.length <= maxLength) return name;
      return '${name.substring(0, maxLength - 3)}...';
    }

    return roomsAsync.when(
      data: (rooms) => Semantics(
        label: 'Room selector, current: ${currentRoom?.name ?? 'none'}',
        child: Tooltip(
          message: 'Switch to another room',
          child: InkWell(
            onTap: () => _showRoomPicker(rooms),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    trimRoomName(currentRoom?.name ?? 'Select Room'),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Icon(Icons.arrow_drop_down),
              ],
            ),
          ),
        ),
      ),
      loading: () => Semantics(
        label: 'Loading rooms',
        child: const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      error: (error, stackTrace) {
        Loggers.room.error(
          'Failed to load rooms',
          error: error,
          stackTrace: stackTrace,
        );
        return Semantics(
          label: 'Error loading rooms',
          child: const Tooltip(
            message: 'Failed to load rooms',
            child: Icon(Icons.error_outline),
          ),
        );
      },
    );
  }

  Future<void> _showRoomPicker(List<Room> rooms) async {
    final currentRoom = ref.read(currentRoomProvider);
    final sortedRooms = [...rooms]..sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );

    Loggers.room.debug('Room picker: opening (${sortedRooms.length} rooms)');
    final openedAt = DateTime.now();
    final selectedId = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        final colorScheme = Theme.of(dialogContext).colorScheme;

        return AlertDialog(
          title: const Text('Switch Room'),
          contentPadding:
              const EdgeInsets.symmetric(vertical: SoliplexSpacing.s2),
          content: SizedBox(
            width: 480,
            height: 400,
            child: ListView.builder(
              itemCount: sortedRooms.length,
              itemBuilder: (context, index) {
                final room = sortedRooms[index];
                final isSelected = room.id == currentRoom?.id;
                return ListTile(
                  title: Text(room.name),
                  subtitle: room.hasDescription ? Text(room.description) : null,
                  selected: isSelected,
                  selectedTileColor: colorScheme.primaryContainer,
                  selectedColor: colorScheme.onPrimaryContainer,
                  leading: Icon(
                    Icons.meeting_room,
                    color: isSelected ? colorScheme.primary : null,
                  ),
                  trailing: isSelected
                      ? Icon(Icons.check, color: colorScheme.primary)
                      : null,
                  onTap: () => Navigator.pop(dialogContext, room.id),
                );
              },
            ),
          ),
        );
      },
    );
    final closedAfter = DateTime.now().difference(openedAt);
    Loggers.room.debug(
      'Room picker: closed after ${closedAfter.inMilliseconds}ms, '
      'selectedId=$selectedId, mounted=$mounted',
    );
    if (selectedId == null && closedAfter.inMilliseconds < 300) {
      Loggers.room.warning(
        'Room picker: dismissed suspiciously fast '
        '(${closedAfter.inMilliseconds}ms) — likely popped by navigation '
        'rebuild, not user action',
      );
    }

    if (selectedId != null && mounted) {
      Loggers.room.info('Room switched to $selectedId');
      context.go('/rooms/$selectedId');
    }
  }

  Widget _buildDesktopLayout(BuildContext context) {
    return Row(
      children: [
        if (!_sidebarCollapsed)
          SizedBox(
            width: _sidebarWidth,
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border(
                  right: BorderSide(
                    color: Theme.of(context).dividerTheme.color!,
                  ),
                ),
              ),
              child: HistoryPanel(roomId: widget.roomId),
            ),
          ),
        const Expanded(child: ChatPanel()),
      ],
    );
  }
}
