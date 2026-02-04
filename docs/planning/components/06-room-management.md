# 06 - Room Management

## Overview

Manages room listing, selection, filtering, and the room detail view shell. Handles
responsive layout switching between grid/list views and sidebar/drawer modes. Implements
deep-link thread selection with priority chain logic.

## Files

| File | Purpose |
|------|---------|
| `lib/core/providers/rooms_provider.dart` | Room list fetching, selection state |
| `lib/features/room/room_screen.dart` | Room detail shell with thread selection |
| `lib/features/rooms/rooms_screen.dart` | Room list with search and view toggle |
| `lib/features/rooms/widgets/room_grid_card.dart` | Grid card display widget |
| `lib/features/rooms/widgets/room_list_tile.dart` | List tile display widget |
| `lib/features/rooms/widgets/room_search_toolbar.dart` | Search input and view toggle |

## Public API

### Providers (rooms_provider.dart)

| Provider | Type | Purpose |
|----------|------|---------|
| `roomsProvider` | `FutureProvider<List<Room>>` | Fetches/caches room list |
| `currentRoomIdNotifier` | `NotifierProvider<String?>` | Selected room ID state |
| `currentRoomProvider` | `Provider<Room?>` | Computed current room object |

### Screen Providers (rooms_screen.dart)

| Provider | Type | Purpose |
|----------|------|---------|
| `filteredRoomsProvider` | `Provider` | Rooms filtered by search query |
| `isGridViewProvider` | `NotifierProvider` | List/grid view toggle |
| `roomSearchQueryProvider` | `NotifierProvider` | Search text state |

### Screens

**`RoomsScreen`** - Room list entry point

- Handles responsive layout (grid vs list)
- Empty states and search filtering

**`RoomScreen`** - Room detail shell

- Constructor: `RoomScreen(roomId, initialThreadId)`
- Configures AppShell (sidebar, titles, actions)
- Manages thread selection initialization

### Widgets

- `RoomGridCard` - Card format with hover effects
- `RoomListTile` - Horizontal tile format
- `RoomSearchToolbar` - Search input + view toggle button

## Dependencies

### External Packages

- `flutter_riverpod` - State management and caching
- `soliplex_client` - Domain models (`Room`)
- `go_router` - Navigation and deep linking

### Internal Dependencies

| Domain | Imports |
|--------|---------|
| Core/Providers | `api_provider`, `shell_config_provider`, `threads_provider` |
| Shared | `AppShell`, `HistoryPanel`, `ChatPanel`, `LoadingIndicator`, `ErrorDisplay` |
| Design | `SoliplexBreakpoints`, `SoliplexSpacing`, `soliplexRadii` |

## Data Flow

### Room List Loading

```text
1. RoomsScreen watches filteredRoomsProvider
2. roomsProvider triggers api.getRooms()
3. Data cached; search filters client-side
```

### Room Selection

```text
1. User selects room
2. currentRoomIdProvider updated
3. context.push('/rooms/:id')
```

### Thread Selection Initialization

```text
RoomScreen.initState triggers _initializeThreadSelection:

Priority Chain:
1. Query Param: ?thread=xyz in URL (if valid)
2. Last Viewed: lastViewedThreadProvider (AsyncStorage)
3. Default: First available thread

Then: selectAndPersistThread saves selection
```

## Architectural Patterns

### Computed State

Derived providers (`filteredRoomsProvider`, `currentRoomProvider`) keep UI reactive.

### Responsive Layout

- `RoomsScreen`: LayoutBuilder toggles column widths and grid/list density
- `RoomScreen`: MediaQuery switches between sidebar (desktop) and drawer (mobile)

### App Shell Configuration

`RoomScreen` dynamically configures global `AppShell`, injecting room switcher
dropdown and actions (Quizzes, Settings) into app bar.

### Imperative Initialization

Thread selection uses `addPostFrameCallback` and imperative `ref.read` within
StatefulWidget for one-off navigation logic (deviates from pure reactive).

## Cross-Component Dependencies

### Depends On

- **03 - State Core**: API provider access
- **05 - Threads**: Thread history integration within rooms
- **08 - Chat UI**: Embeds Chat Panel UI
- **10 - Configuration**: Shell configuration access
- **11 - Design System**: Theme and styling tokens
- **12 - Shared Widgets**: Common UI components
- **14 - HTTP Layer**: Client integration via barrel file

### Used By

- **04 - Active Run**: Room context for execution
- **05 - Threads**: Thread association with rooms
- **07 - Documents**: Selected documents context
- **08 - Chat UI**: Room state management access
- **19 - Router**: Navigation target (Room screens)

## Contribution Guidelines

### DO

- **Use Computed Providers for Filtering:** Do not filter lists inside the Widget's `build` method. Create a derived `Provider` (e.g., `filteredRoomsProvider`) that combines the raw data provider and the filter criteria provider.
- **Use `LayoutBuilder` for Density:** When switching between List and Grid views, use `LayoutBuilder` to calculate constrained widths and cross-axis counts rather than hardcoded pixel values.
- **Encapsulate Selection Logic:** Use `NotifierProvider` (like `currentRoomIdNotifier`) to manage selection state. Ensure the "Selected" object is derived via `Provider`.
- **Deep Link Priority Chain:** When initializing a room, follow the established priority chain: Query Parameter → Last Viewed (Storage) → Default (First Item).
- **Clean Shell Configuration:** Use the `ShellConfig` pattern to inject Room-specific actions into the global `AppShell` rather than building custom Scaffolds.

### DON'T

- **No Orchestration in `initState`:** Avoid complex `async` logic inside `initState` or `addPostFrameCallback`. Move this logic to a Controller provider.
- **Don't Pass `WidgetRef` to Helpers:** Never define helper methods that accept `WidgetRef`. Pass `Ref` and move the logic to the Provider layer.
- **No Hardcoded Breakpoints:** Do not use raw numbers for screen width checks. Use `SoliplexBreakpoints` tokens.
- **Don't Mix API and View Logic:** Do not call `api.getRooms()` directly from a widget. Watch `roomsProvider` instead.
- **Handle Null States:** Do not assume `currentRoomProvider` returns a value; always handle the `null` case gracefully.

### Extending This Component

- **New View Modes:** To add a new view (e.g., "Table View"), extend `isGridViewProvider` to be a `ViewModeNotifier` (enum) and add a new conditional builder in `RoomsScreen`.
- **New Filters:** Add the filter state to a dedicated Notifier, then update `filteredRoomsProvider` to react to the new state. Do not change `roomsProvider`.
- **Room Actions:** To add buttons to the Room header, update the `actions` list in the `ShellConfig` within `RoomScreen.build`.
