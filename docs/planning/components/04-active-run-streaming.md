# 04 - Active Run & Streaming

## Overview

Manages the lifecycle, state, and data flow of an active AG-UI chat run. Coordinates
between UI, caching layer, and streaming infrastructure. Implements optimistic UI
updates and merged data sources (cache + live stream).

## Files

| File | Purpose |
|------|---------|
| `lib/core/models/active_run_state.dart` | Sealed state hierarchy for run status |
| `lib/core/models/agui_features/filter_documents.dart` | Document filter AG-UI state model |
| `lib/core/providers/active_run_notifier.dart` | Central notifier for chat run logic |
| `lib/core/providers/active_run_provider.dart` | Provider definitions and derived state |
| `lib/core/application/run_lifecycle_impl.dart` | Side effect implementation (wake lock) |
| `lib/core/domain/interfaces/run_lifecycle.dart` | Lifecycle interface |

## Public API

### Models (active_run_state.dart)

Sealed class hierarchy:

- `ActiveRunState` (sealed)
  - `IdleState` - No active conversation
  - `RunningState` - Active execution; holds `Conversation` and `StreamingState`
  - `CompletedState` - Finished run; holds `CompletionResult` (Success/Failed/Cancelled)

- `FilterDocuments` - AG-UI state key data model for document filtering

### Providers (active_run_provider.dart)

| Provider | Type | Purpose |
|----------|------|---------|
| `activeRunNotifierProvider` | `Notifier<ActiveRunState>` | Primary chat run manager |
| `allMessagesProvider` | `FutureProvider<List<ChatMessage>>` | Merges cache + streaming messages |
| `canSendMessageProvider` | `Provider<bool>` | Input bar enable/disable logic |
| `isStreamingProvider` | `Provider<bool>` | UI loading state convenience |

### Notifier Methods (active_run_notifier.dart)

- `startRun(...)` - Initiates run (API creation -> stream setup)
- `cancelRun()` - Cancels active stream
- `reset()` - Clears state, disposes resources

### Lifecycle (run_lifecycle.dart, run_lifecycle_impl.dart)

- `RunLifecycle` (interface) - Abstracts hardware side effects
- `RunLifecycleImpl` - Implementation with reference counting for wake lock

## Dependencies

### External Packages

- `flutter_riverpod` - State management
- `soliplex_client` - Domain logic (`AgUiClient`, `Conversation`, `ChatMessage`, `StreamingState`)
- `dio` - HTTP (via `CancelToken`)

### Internal Dependencies

| Domain | Imports |
|--------|---------|
| Core/Providers | `api_provider`, `infrastructure_providers` |
| Core/Cache | `thread_history_cache` |
| Features | `threads_provider`, `rooms_provider` |

## Data Flow

### Start Run

```text
1. User triggers activeRunNotifier.startRun
2. Preparation:
   ├─ apiProvider creates run ID on backend
   ├─ Local user message created (optimistic UI)
   └─ Historical messages retrieved from ThreadHistoryCache
3. Stream Initialization:
   ├─ ActiveRunState → RunningState
   ├─ RunLifecycle triggers ScreenWakeLock
   └─ AgUiClient.runAgent called with history + AG-UI state
```

### Execution Loop

```text
4. Notifier listens to SSE stream
5. Events passed to processEvent (client lib)
6. State updated via _mapResultToState
```

### Completion

```text
7. Stream ends or errors
8. Citation Correlation:
   └─ CitationExtractor compares pre/post run state
9. Cache Update:
   └─ Full conversation written to ThreadHistoryCache
10. RunLifecycle releases ScreenWakeLock
```

## Architectural Patterns

### Sealed State Hierarchy

`ActiveRunState` enables exhaustive pattern matching for UI rendering.

### Resource Safety

`NotifierInternalState` (sealed) separates safe, immutable UI state from dangerous,
mutable resources (`StreamSubscription`, `CancelToken`).

### Optimistic UI

User message added to local state immediately before stream connects.

### Merged Data Sources

`allMessagesProvider` implements "Cache + Live" strategy, merging stable history
with volatile streaming data (deduplicated).

### Separation of Concerns

`RunLifecycle` abstracts hardware interactions (WakeLock) away from business logic.
Uses reference counting for potential concurrent runs.

## Cross-Component Dependencies

### Depends On

- **03 - State Core**: Accessing API providers and infrastructure providers
- **05 - Threads**: Thread history caching and thread management providers
- **06 - Rooms**: Accessing room context via rooms_provider
- **14 - HTTP Layer**: Network client types via soliplex_client
- **18 - Native Platform**: Domain interfaces for platform-specific implementations

### Used By

- **05 - Threads**: History features requiring active run state context
- **08 - Chat UI**: Source reference providers and chat features utilizing active run data
- **18 - Native Platform**: Implementation of platform-specific logic using active run models

## Contribution Guidelines

### DO

- **Use Exhaustive Pattern Matching:** Always use `switch (state)` on `ActiveRunState` to handle `IdleState`, `RunningState`, and `CompletedState`. This ensures UI validity during transitions.
- **Separate Safe vs. Unsafe State:** Keep UI data (immutable) in `ActiveRunState` and mutable resources (StreamSubscription, CancelToken) in `NotifierInternalState`.
- **Merge Data Sources:** Use `allMessagesProvider` for the message list. It automatically deduplicates and merges the stable `ThreadHistoryCache` with the volatile `ActiveRunState.messages`.
- **Delegate Lifecycle to Notifier:** Always call `ref.read(activeRunNotifierProvider.notifier).startRun/cancelRun`. Never manually manage stream subscriptions or WakeLocks in the UI.
- **Correlate on Completion:** Ensure `_mapResultToState` calls `_correlateMessageStateOnCompletion` to extract citations and update the history cache when a run finishes.

### DON'T

- **No Direct State Mutation:** Never modify `ActiveRunState` fields directly. Use `.copyWith()` or create new state instances to trigger Riverpod updates.
- **Don't Access ThreadID on Idle:** Do not access `.threadId` on `IdleState` (it is a sentinel). Only access it on `RunningState` or `CompletedState`.
- **No Resource Leakage:** Do not store `StreamSubscription` or `CancelToken` in the public `ActiveRunState`. They belong in `_internalState` and must be disposed in `ref.onDispose`.
- **Don't Bypass Lifecycle Interface:** Do not use `WakelockPlus` directly in widgets. Use the `RunLifecycle` interface injected into the Notifier.
- **No Logic in Widgets:** Do not put retry logic, error parsing, or SSE event handling in `ChatPanel`. These belong in `ActiveRunNotifier._processEvent`.

### Extending This Component

- **New States:** If adding a state (e.g., `PausedState`), add it to the sealed class hierarchy in `active_run_state.dart` and update all `switch` expressions.
- **New Events:** To handle new SSE events, update `soliplex_client` first, then map the result in `ActiveRunNotifier._mapResultToState`.
- **Optimistic Updates:** To add new optimistic behaviors (e.g., tool calls), update `startRun` to inject the initial state before the stream connects.
