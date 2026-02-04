# 07 - Document Selection

## Overview

Manages document fetching and selection state for RAG (Retrieval-Augmented Generation)
filtering. Selections are isolated by room and thread, enabling context-specific
document filtering for chat interactions.

## Files

| File | Purpose |
|------|---------|
| `lib/core/providers/documents_provider.dart` | Fetches documents per room |
| `lib/core/providers/selected_documents_provider.dart` | Manages selection state |

## Public API

### Providers (documents_provider.dart)

| Provider | Type | Purpose |
|----------|------|---------|
| `documentsProvider` | `FutureProvider.family<List<RagDocument>, String>` | Fetches/caches documents per room |

### Selection State (selected_documents_provider.dart)

**Types:**

- `ThreadKey` - Record type `({String roomId, String threadId})` for map keys

**Notifier:**

- `SelectedDocumentsNotifier` - In-memory selection state manager
  - `getForThread(roomId, threadId)` - Get selection for context
  - `setForThread(roomId, threadId, documents)` - Replace selection
  - `clearForThread(roomId, threadId)` - Remove thread selection
  - `clearForRoom(roomId)` - Remove all room selections

**Providers:**

| Provider | Type | Purpose |
|----------|------|---------|
| `selectedDocumentsNotifierProvider` | `NotifierProvider` | Selection notifier access |
| `currentSelectedDocumentsProvider` | `Provider<Set<RagDocument>>` | Current context selection |

## Dependencies

### External Packages

- `flutter_riverpod` - State management
- `soliplex_client` - Domain entities (`RagDocument`, `SoliplexApi`)

### Internal Dependencies

| Domain | Imports |
|--------|---------|
| Core/Providers | `api_provider`, `rooms_provider`, `threads_provider` |

## Data Flow

### Fetching Documents

```text
1. UI watches documentsProvider(roomId)
2. Provider calls api.getDocuments(roomId)
3. Result cached by Riverpod
```

### Managing Selections

```text
1. SelectedDocumentsNotifier starts with empty Map
2. User selects documents
3. UI calls setForThread(roomId, threadId, documents)
4. Notifier updates internal Map keyed by ThreadKey record
```

### Reading Current Selection

```text
1. UI watches currentSelectedDocumentsProvider
2. Provider watches currentRoomIdProvider + currentThreadIdProvider
3. Looks up entry in SelectedDocumentsNotifier state map
4. Returns empty set if no context active
```

## Architectural Patterns

### Family Pattern

`documentsProvider` creates unique state instances per `roomId`.

### Derived State

`currentSelectedDocumentsProvider` combines selection store, room store, and
thread store to provide specific data slice.

### Record Types as Keys

Uses Dart Records `({String roomId, String threadId})` as composite map keys
for thread isolation.

### In-Memory State

Selections stored in memory only. Lost on app restart (no persistence).

## Cross-Component Dependencies

### Depends On

- **03 - State Core**: API providers for fetching document data
- **05 - Threads**: Context for thread-specific documents
- **06 - Rooms**: Context for room-specific documents
- **14 - HTTP Layer**: Underlying network transport via barrel

### Used By

- **08 - Chat UI**: Displaying selected documents and managing attachments in chat input

## Contribution Guidelines

### DO

- **Use Record Keys:** Use the `ThreadKey` record definition `({String roomId, String threadId})` for all map operations to ensure strict type safety and uniqueness.
- **Isolate by Context:** Always scope selections to *both* Room ID and Thread ID. Selections in one thread must not leak into another.
- **Use Derived Providers:** Use `currentSelectedDocumentsProvider` in the UI. It combines `selectedDocumentsNotifierProvider` with `currentRoomId` and `currentThreadId` automatically.
- **Family Pattern for Fetching:** Always use `documentsProvider(roomId)` to fetch available documents. Do not create a non-family provider that depends on `currentRoomId`.
- **Clear on Exit:** Call `clearForRoom(roomId)` in the Notifier when a user leaves or deletes a room to prevent memory leaks in the map.

### DON'T

- **No Persistence:** Do not attempt to persist selections to local storage. This component is designed for in-memory, ephemeral state only.
- **No In-Place Set Mutation:** Do not mutate the `Set<RagDocument>` inside the map. Always replace the Set with a new instance when updating selections.
- **Don't Pass WidgetRef:** Do not pass `WidgetRef` to selection logic. Use `ref.read(selectedDocumentsNotifierProvider.notifier).setForThread(...)`.
- **Don't Assume Context:** Do not access `state.values.first` or assume a single active selection. Always look up by the explicit `ThreadKey`.
- **No Mixed Concerns:** Do not mix the logic for *fetching* documents (API) with *selecting* documents (UI state) in the same provider.

### Extending This Component

- **Bulk Operations:** If adding "Select All", implement it in the Notifier by reading `documentsProvider` and updating the map entry.
- **New Filtering:** If adding search/filtering, create a new derived provider (e.g., `filteredDocumentsProvider`) that watches `documentsProvider` and a new `searchQueryProvider`.
- **Cross-Thread Carryover:** If a feature requires carrying selections to a new thread, implement a specific method `copySelection(fromId, toId)` in the Notifier.
