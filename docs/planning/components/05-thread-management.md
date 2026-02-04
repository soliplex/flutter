# 05 - Thread Management

## Overview

Handles retrieval, caching, selection, and persistence of conversation threads. Manages
two distinct data types: thread list (metadata) and thread history (messages). Implements
cache-first strategy with request deduplication.

## Files

| File | Purpose |
|------|---------|
| `lib/core/providers/thread_history_cache.dart` | Message history caching with deduplication |
| `lib/core/providers/threads_provider.dart` | Thread list fetching, selection state |
| `lib/features/history/history_panel.dart` | Thread list sidebar UI |
| `lib/features/history/widgets/new_conversation_button.dart` | New thread trigger button |
| `lib/features/history/widgets/thread_list_item.dart` | Single thread row widget |

## Public API

### Cache (thread_history_cache.dart)

- `ThreadHistoryCache` (Notifier) - Source of truth for message history
  - `getHistory(roomId, threadId)` - Returns cached or fetches from API
  - `updateHistory(threadId, history)` - Manual cache update (post-run sync)
  - `refreshHistory(roomId, threadId)` - Invalidate and force fetch

### Providers (threads_provider.dart)

| Provider | Type | Purpose |
|----------|------|---------|
| `threadsProvider` | `FutureProvider.family` | Fetch thread list for room (newest first) |
| `threadSelectionProvider` | `StateProvider` | Current selection state |
| `lastViewedThreadProvider` | `FutureProvider.family` | Persisted last-viewed per room |

### State Machines

**`ThreadSelection`** (sealed):

- `NoThreadSelected` - Initial state
- `ThreadSelected(threadId)` - Viewing specific thread
- `NewThreadIntent` - New conversation pending

**`LastViewed`** (sealed):

- `HasLastViewed(threadId)` - Has persisted selection
- `NoLastViewed` - No previous selection

### Helper Functions

- `selectThread(...)` - Updates selection, persists to SharedPreferences, navigates
- `selectAndPersistThread(...)` - Updates selection and persistence (no navigation)

### Widgets

- `HistoryPanel` - Thread list sidebar with loading/empty states
- `ThreadListItem` - Single thread row with relative time, selection highlight
- `NewConversationButton` - Triggers `NewThreadIntent`

## Dependencies

### External Packages

- `flutter_riverpod` - State management
- `shared_preferences` - Last-viewed persistence
- `go_router` - Navigation
- `soliplex_client` - Domain models (`ThreadInfo`, `ThreadHistory`)

### Internal Dependencies

| Domain | Imports |
|--------|---------|
| Core/Providers | `api_provider`, `active_run_provider`, `rooms_provider` |
| Design | Theme extensions, UI constants |
| Shared | `AsyncValueHandler`, `EmptyState` |

## Data Flow

### Thread List Loading

```text
1. HistoryPanel watches threadsProvider(roomId)
2. Provider calls api.getThreads(roomId)
3. Data sorted (newest first) and rendered via ListView
```

### Thread Selection

```text
1. User taps ThreadListItem
2. selectThread helper called
3. threadSelectionProvider → ThreadSelected(id)
4. SharedPreferences stores lastViewedThread_{roomId}
5. Router navigates to /rooms/{roomId}?thread={threadId}
```

### History Retrieval

```text
1. ThreadHistoryCache checks internal Map
2. If missing, _fetchAndCache calls api.getThreadHistory
3. Requests deduplicated via _inFlightFetches Map
```

## Architectural Patterns

### Repository/Cache Pattern

`ThreadHistoryCache` abstracts decision between memory data vs network fetch.

### Request Deduplication

Tracks `_inFlightFetches` to prevent race conditions when multiple widgets
request same thread simultaneously.

### Sealed Class State Machines

`ThreadSelection` and `LastViewed` ensure exhaustive pattern matching in UI.

### Manual Equality

Sealed classes implement `==` and `hashCode` manually to avoid `freezed`
dependency overhead for simple value objects.

### Family Providers

`threadsProvider` and `lastViewedThreadProvider` scoped by `roomId`.

## Cross-Component Dependencies

### Depends On

- **03 - State Core**: API provider for fetching thread data
- **04 - Active Run**: Accessing current run state and providers
- **06 - Rooms**: Room context association
- **11 - Design System**: UI styling and tokens
- **12 - Shared Widgets**: Reusable UI components
- **14 - HTTP Layer**: Network client types via soliplex_client
- **17 - Utilities**: Date formatting logic

### Used By

- **04 - Active Run**: Thread history access via cache providers
- **06 - Rooms**: Integration of thread lists within room features
- **07 - Documents**: Associating selected documents with thread context
- **08 - Chat UI**: Displaying chat messages and history
- **12 - Shared Widgets**: Error display widgets requiring thread context

## Contribution Guidelines

### DO

- **Deduplicate Requests:** Use the `_inFlightFetches` pattern in Notifiers when multiple widgets might request the same async resource simultaneously.
- **Scope by Family:** Always use `.family` providers for data belonging to a specific parent entity (e.g., `threadsProvider(roomId)`).
- **Use Derived Providers:** Create small `Provider` wrappers (like `currentThreadIdProvider`) to extract specific fields from complex state, minimizing widget rebuilds.
- **Manual Sealed Classes:** Implement `==` and `hashCode` manually for state sealed classes to avoid unnecessary `freezed` generation overhead.
- **Sort at Source:** Sort lists (e.g., by `createdAt`) inside the Provider immediately after fetching, ensuring consistent order across the UI.

### DON'T

- **Violate the Ref Rule:** Never write helper functions that accept `WidgetRef`. Move this logic into the Notifier.
- **Mix UI and Data Providers:** Do not store "Selection" state in the same provider as the "Thread List" data. Keep them separate.
- **Persist without Invalidation:** Do not write to `SharedPreferences` without immediately invalidating the corresponding read provider.
- **Swallow Fetch Errors:** Do not catch exceptions in `_fetchAndCache` without re-throwing or updating state to an error state.
- **Expose Mutable Lists:** Do not return mutable `List<ThreadInfo>` from providers; rely on Riverpod's immutability guarantees.

### Extending This Component

- **New Selection Modes:** Add variants to `ThreadSelection` (e.g., `MultiSelectThread`) if implementing bulk actions.
- **New Sort Orders:** Add a `SortOrder` parameter to the `threadsProvider.family` tuple if user-configurable sorting is required.
- **New Message Types:** Update `ThreadHistoryCache` to handle new message subtypes if the backend protocol changes.
