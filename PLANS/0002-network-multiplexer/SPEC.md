# Feature Specification: Network Multiplexer (Run Registry)

## Overview

Allow AG-UI streams to continue when users navigate between threads and rooms.
Currently, navigation cancels active streams immediately, causing users to lose
streaming responses.

## Problem Statement

When users switch threads or rooms, `ActiveRunNotifier` listens to
`threadSelectionProvider` and calls `reset()`, which cancels the `CancelToken`
and stream subscription. This design assumption (one active run at a time,
scoped to the current thread) causes users to lose AI responses when navigating.

**Issue:** <https://github.com/soliplex/flutter/issues/71>

**Current behavior (lines 90-96 of active_run_notifier.dart):**

```dart
ref.listen(threadSelectionProvider, (previous, next) {
  if (previous is ThreadSelected) {
    unawaited(reset());
  }
});
```

When the user leaves thread A (previous is `ThreadSelected`), the run is reset
regardless of whether it was still streaming.

## Requirements

### Functional Requirements

1. Active runs continue streaming when users navigate away from a thread.
2. Users can start runs in multiple threads concurrently.
3. When returning to a thread with an active run, the UI shows its current state.
4. When a run completes in the background, the message cache is updated.
5. The system broadcasts lifecycle events (start, complete) for background
   awareness.
6. Runs are keyed by (roomId, threadId) to support cross-room persistence.

### Non-Functional Requirements

- Minimal provider footprint (one provider or integrate into existing notifier).
- Domain logic lives in a dedicated class, not scattered across providers.
- UI subscribes to lifecycle events; UI layer decides presentation (toast,
  badge, dot).
- Smooth transitions when switching between threads with active runs.

## Use Cases

### Use Case 1: Navigate Away and Return

1. Alice opens thread T1 in room R1.
2. Alice types a question and submits.
3. The AI starts streaming a response.
4. Alice clicks on thread T2 to check something.
5. The run in T1 continues streaming in the background.
6. Alice returns to T1.
7. Alice sees the response that streamed while she was away.

### Use Case 2: Concurrent Runs in Multiple Threads

1. Bob opens thread T1 and submits a question.
2. While the AI is responding, Bob opens thread T2.
3. Bob submits a different question in T2.
4. Both threads now have active runs streaming concurrently.
5. Bob can switch between T1 and T2, seeing each thread's streaming state.

### Use Case 3: Background Run Completion

1. Carol submits a question in thread T1.
2. Carol navigates to thread T2.
3. The run in T1 completes while Carol is viewing T2.
4. The message cache for T1 is updated with the complete response.
5. A lifecycle event is broadcast (UI can show notification if desired).
6. Carol returns to T1 and sees all messages.

### Use Case 4: Cross-Room Navigation

1. Dave submits a question in thread T1 of room R1.
2. Dave switches to room R2 to check a different conversation.
3. The run in R1/T1 continues streaming.
4. Dave returns to R1/T1 and sees the streamed response.

## Design

### Architecture

```text
┌─────────────────────────────────────────────────────────────────┐
│                          UI Layer                               │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────┐   │
│  │ ChatPanel    │  │ HistoryPanel │  │ Background Indicator │   │
│  └──────┬───────┘  └──────────────┘  └──────────┬───────────┘   │
│         │                                       │               │
│         │ watches state                         │ listens to    │
│         │ for current thread                    │ lifecycle     │
│         ▼                                       ▼               │
├─────────────────────────────────────────────────────────────────┤
│                       Provider Layer                            │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │              ActiveRunNotifier (modified)                 │   │
│  │  - Embeds RunRegistry, exposes via registry getter       │   │
│  │  - Syncs current handle on room/thread navigation        │   │
│  │  - Exposes state for current thread only                 │   │
│  └──────────────────────────┬───────────────────────────────┘   │
│                             │                                   │
│                             │ owns                              │
│                             ▼                                   │
├─────────────────────────────────────────────────────────────────┤
│                       Service Layer                             │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │                    RunRegistry                            │   │
│  │  - Map<RunKey, RunHandle>                                │   │
│  │  - Manages run lifecycle                                 │   │
│  │  - Broadcasts Stream<RunLifecycleEvent>                  │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │                    RunHandle                              │   │
│  │  - CancelToken                                           │   │
│  │  - StreamSubscription                                    │   │
│  │  - Current ActiveRunState                                │   │
│  └──────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

### Key Components

**RunKey:** `typedef RunKey = ({String roomId, String threadId})` — a named
record providing a type-safe composite identifier with value equality.
Used as the map key in RunRegistry, the identity field in RunHandle and
RunLifecycleEvent. Convenience getters on RunHandle and RunLifecycleEvent
expose `roomId` and `threadId` directly so consumers never need `.key`
indirection.

**RunHandle:** Encapsulates resources for a single run:

- `RunKey key` for identity (with `roomId`/`threadId` convenience getters)
- `String runId` — backend-generated run ID
- `CancelToken` for cancellation
- `StreamSubscription<BaseEvent>` for the event stream
- `String userMessageId` — ID of the message that triggered the run
- `Map<String, dynamic> previousAguiState` — state snapshot before the run
- Current `ActiveRunState` (Idle, Running, Completed)
- `bool isActive` — whether the run is currently running

**RunRegistry:** Pure Dart class managing multiple runs:

- `Map<RunKey, RunHandle>` with type-safe record keys
- `registerRun()` adds a RunHandle and emits `RunStarted`
- `completeRun()` atomically sets terminal state and emits `RunCompleted`
- `removeRun(RunKey)` removes a run and disposes its resources
- `getRunState(RunKey)` returns the current state for a run
- `Stream<RunLifecycleEvent>` broadcasts all lifecycle events unconditionally

**ActiveRunNotifier (modified):**

- Removes thread navigation listener (slice 1)
- Embeds `RunRegistry` as a field; exposes via `registry` getter (slice 4)
- Creates `RunHandle` in `startRun()` and registers with embedded registry
- Syncs `_currentHandle` and exposed state on room/thread navigation (slice 6)
- State reflects current thread only

### Lifecycle Events

```dart
@immutable
sealed class RunLifecycleEvent {
  const RunLifecycleEvent({required this.key});
  final RunKey key;
  String get roomId => key.roomId;
  String get threadId => key.threadId;
}

@immutable
class RunStarted extends RunLifecycleEvent { ... }

@immutable
class RunCompleted extends RunLifecycleEvent {
  final CompletionResult result;  // Success, FailedResult, or CancelledResult
}
```

Two event types instead of three. A run that errors *has completed* — the
outcome is encoded in the existing `CompletionResult` sealed hierarchy
(`Success`, `FailedResult`, `CancelledResult`), which already provides
exhaustive pattern matching. A separate `RunErrored` type would duplicate
information that `FailedResult` already carries and force downstream
consumers to handle two event types identically in most branches.

The registry emits `RunCompleted` unconditionally for all terminal
transitions, including cancellations. Consumers decide which results to
act on. This keeps the registry a faithful event bus — it reports what
happened without encoding business policy about which events are
"interesting."

Events use `RunKey` as their identity field with convenience getters for
`roomId` and `threadId`. This gives the registry a type-safe map key
(record value equality, no string concatenation) while keeping consumer
access clean (`event.roomId` instead of `event.key.roomId`).

UI components listen to these events and decide how to present them
(toast, badge, colored dot, etc.). The design of the alert UI is
intentionally deferred for separate UX discussion.

## Acceptance Criteria

- [ ] User can navigate away from thread with active run; run continues.
- [ ] User can return to thread; sees streamed messages.
- [ ] User can start runs in multiple threads concurrently.
- [ ] Background run completion updates message cache.
- [ ] Lifecycle events are broadcast for background awareness.
- [ ] Runs persist across room navigation.
- [ ] All existing tests pass or are updated appropriately.

## UI Notification Design

Per @runyaga's feedback ([comment](https://github.com/soliplex/flutter/issues/71#issuecomment-3841467295)):

1. **Thread badge:** Blue dot with glow on threads with unread completed runs
   in the history sidebar.
2. **Room badge:** White number on blue background (same blue as thread dot)
   showing the count of threads with unread completed runs.

This gives users visibility at both the room and thread level without intrusive
notifications. The blue color provides consistent visual language across both
indicators.
