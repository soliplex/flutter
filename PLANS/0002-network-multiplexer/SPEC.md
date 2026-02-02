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
5. The system broadcasts lifecycle events (start, complete, error) for
   background awareness.
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
│  │  - Subscribes to current thread's run from registry      │   │
│  │  - Delegates startRun() to registry                      │   │
│  │  - Exposes state for current thread only                 │   │
│  └──────────────────────────┬───────────────────────────────┘   │
│                             │                                   │
│                             │ delegates to                      │
│                             ▼                                   │
├─────────────────────────────────────────────────────────────────┤
│                       Service Layer                             │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │                    RunRegistry                            │   │
│  │  - Map<(roomId, threadId), RunHandle>                    │   │
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

**RunHandle:** Encapsulates resources for a single run:

- `CancelToken` for cancellation
- `StreamSubscription<BaseEvent>` for the event stream
- Current `ActiveRunState` (Idle, Running, Completed)
- Room and thread IDs

**RunRegistry:** Pure Dart class managing multiple runs:

- `Map<RunKey, RunHandle>` where `RunKey = (roomId, threadId)`
- `registerRun()` adds a RunHandle to the registry
- `cancelRun()` cancels a specific run
- `getRunState()` returns the current state for a run
- `Stream<RunLifecycleEvent>` broadcasts start/complete/error events

**ActiveRunNotifier (modified):**

- Removes thread navigation listener (slice 1)
- Subscribes to the current thread's run from registry (slice 6)
- Delegates `startRun()` to registry (slice 4)
- State reflects current thread only

### Lifecycle Events

```dart
sealed class RunLifecycleEvent {
  RunKey get key;
}

class RunStarted extends RunLifecycleEvent { ... }
class RunCompleted extends RunLifecycleEvent {
  final CompletionResult result;
}
class RunErrored extends RunLifecycleEvent {
  final String errorMessage;
}
```

UI components can listen to these events and decide how to present them
(toast, badge, colored dot, etc.). The design of the alert UI is intentionally
deferred for separate UX discussion.

## Acceptance Criteria

- [ ] User can navigate away from thread with active run; run continues.
- [ ] User can return to thread; sees streamed messages.
- [ ] User can start runs in multiple threads concurrently.
- [ ] Background run completion updates message cache.
- [ ] Lifecycle events are broadcast for background awareness.
- [ ] Runs persist across room navigation.
- [ ] All existing tests pass or are updated appropriately.

## Open Questions

1. **Alert UI design:** When a background run completes, how should we alert the
   user? Options: toast notification, badge on thread in history, colored dot,
   or some combination. This needs UX discussion with @runyaga.
