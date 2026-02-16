# Feature Specification: Run Feedback

## Overview

Wire frontend feedback UI to the backend feedback endpoint so users can rate
assistant responses as good or bad, with an optional reason.

## Problem Statement

The backend provides a feedback endpoint
(`POST /v1/rooms/{room_id}/agui/{thread_id}/{run_id}/feedback`, PR #371, merged)
but the frontend has zero feedback code. Users cannot rate responses.

**Issue:** <https://github.com/soliplex/soliplex/issues/355>

**Backend endpoint:**

```text
POST /v1/rooms/{room_id}/agui/{thread_id}/{run_id}/feedback
Body: { "feedback": "<string>", "reason": "<string|null>" }
Response: HTTP 205
```

Feedback is one-to-one with a run. Re-submitting replaces the previous entry.

**Frontend current state:**

- `ChatMessageWidget._buildAgentMessageActionsRow()` has only a "copy" button
- `SoliplexApi` has no feedback method
- `MessageState` tracks `userMessageId` + `sourceReferences` but not `runId`

## Requirements

### Functional Requirements

1. Each completed assistant message shows thumbs-up and thumbs-down buttons.
2. Tapping a thumb sends feedback to the backend.
3. Tapping thumbs-down prompts for a reason (text input).
4. Tapping thumbs-up shows an optional "Add reason" affordance.
5. Tapping the opposite thumb replaces the previous feedback.
6. Feedback buttons appear only on non-streaming assistant messages.

### Non-Functional Requirements

- Feedback state is fire-and-forget for v1 (not persisted across sessions).
- `soliplex_client` remains pure Dart (no Flutter imports).
- API errors are surfaced to the user (snackbar), not silently swallowed.

## Use Cases

### Use Case 1: Thumbs Up

1. Alice reads an assistant response she finds helpful.
2. Alice taps the thumbs-up icon below the message.
3. The icon is replaced by a small spinner while the request is in flight.
4. On success, the spinner is replaced by a highlighted thumbs-up icon.
5. The frontend sent `{ "feedback": "thumbs_up", "reason": null }` to the
   backend.

### Use Case 2: Thumbs Down with Reason

1. Bob reads an inaccurate assistant response.
2. Bob taps the thumbs-down icon.
3. A dialog/bottom sheet prompts for a reason.
4. Bob types "The citation is wrong" and submits.
5. The icon is replaced by a spinner. On success, it becomes a highlighted
   thumbs-down. The frontend sent
   `{ "feedback": "thumbs_down", "reason": "The citation is wrong" }`.

### Use Case 3: Change Feedback

1. Carol previously gave thumbs-up.
2. Carol taps thumbs-down instead.
3. Spinner replaces thumbs-down during the request.
4. On success, thumbs-up un-highlights and thumbs-down highlights.
5. The frontend sends the new feedback (replaces the previous one on backend).

### Use Case 4: Optional Reason on Thumbs Up

1. Dave taps thumbs-up.
2. An "Add reason" link/button appears near the thumbs.
3. Dave taps it, types "Great summary!", submits.
4. The frontend re-sends `{ "feedback": "thumbs_up", "reason": "Great summary!" }`.

### Use Case 5: API Error

1. Eve taps thumbs-down while offline.
2. The icon is replaced by a spinner.
3. The request fails.
4. The spinner reverts to the original unhighlighted icon.
5. A snackbar shows an error message.

## Design

### Key Structural Gap: `runId` at the UI Layer

The backend endpoint requires `run_id`. Currently, `MessageState` does not carry
`runId`. It must be added so that the feedback UI can construct the API call.

`runId` is available at the two places where `MessageState` is created:

- `ActiveRunNotifier._correlateMessagesForRun()` (live runs via `RunHandle`)
- `SoliplexApi._replayEventsToHistory()` (history replay from run data)

### Data Flow

```text
User taps thumb
    |
    v
_FeedbackButtons (local StatefulWidget state: idle/loading/submitted)
    |
    v
onSubmit callback (constructed by MessageList, which has ref access)
    |
    v
SoliplexApi.submitFeedback(roomId, threadId, runId, feedback, reason)
    |
    v
POST /v1/rooms/{room_id}/agui/{thread_id}/{run_id}/feedback
```

No Riverpod provider needed. Feedback state is ephemeral and local to a single
message widget — it doesn't need to be shared, derived, or persisted. A small
`_FeedbackButtons` StatefulWidget manages the idle/loading/submitted state
machine. `MessageList` (a `ConsumerStatefulWidget` with `ref`) constructs the
API callback and passes it down.

### Feedback Values

- `"thumbs_up"` — positive feedback
- `"thumbs_down"` — negative feedback

Represented as a Dart enum, serialized to these strings.

## Design Decisions

### Feedback is per-run, not per-message

The backend models feedback as `RunFeedback` attached to the `Run` entity, with
the endpoint scoped to `/{run_id}/feedback`. The thumbs buttons appear next to
the assistant's response because that's the natural UI placement, but the
feedback is on the run as a whole. A single run could theoretically produce
multiple messages — the feedback covers the entire interaction.

**Evidence:** Backend `RunFeedback` table has a one-to-one relationship with
`Run` (via `run_id_` FK), not with individual messages. PR #371 endpoint path
includes `{run_id}`.

### Feedback values: `thumbs_up` / `thumbs_down`

The backend accepts any string for the `feedback` field (PR #371 tests use
arbitrary strings like `"test-feedback"`). We chose `"thumbs_up"` /
`"thumbs_down"` because:

- Issue #355 specifies "whether its good or bad" — binary sentiment.
- The UI is thumbs-up/thumbs-down icons — values match the visual directly.
- Simple, unambiguous strings that are easy to aggregate in analytics.

Represented as a `FeedbackType` enum in `soliplex_client` for type safety.

### No toggle-off (feedback cannot be withdrawn)

Once feedback is submitted, the user can switch between thumbs-up and
thumbs-down but cannot remove feedback entirely. Tapping the already-active
thumb is a no-op.

**Evidence:** The backend has only a POST endpoint (create/replace). There is no
DELETE endpoint for feedback. If we allowed toggle-off, the UI would un-highlight
(suggesting withdrawal) while the backend still stores the old value — misleading
the user.

### Spinner-while-loading (not optimistic UI)

On thumb tap, the icon is replaced by a small spinner. On success, the spinner
becomes a highlighted thumb. On failure, it reverts to the unhighlighted icon.

Three approaches were considered:

1. **Optimistic UI:** Highlight immediately, rollback on failure. Requires
   tracking both displayed state and in-flight state, handling race conditions
   when the user taps again during a request (cancel? queue? ignore?). ~10-15
   lines of rollback/concurrency logic.
2. **Wait-for-success:** Disable the button or do nothing until the response.
   Simplest, but no visual feedback — the user doesn't know their tap registered.
3. **Spinner (chosen):** Immediate visual feedback (spinner replaces icon),
   prevents double-taps naturally (button is replaced), no rollback logic (never
   showed a false "selected" state). Middle ground between the other two.

### Reason UX: prompt on thumbs-down, optional on thumbs-up

- **Thumbs-down** shows a dialog prompting for a reason. The reason helps
  identify what went wrong (citations, accuracy, relevance).
- **Thumbs-up** shows an optional "Add reason" affordance after submission. Most
  users won't bother for positive feedback, so we don't block the interaction.

### No Riverpod provider

Feedback state (idle/loading/submitted) is ephemeral and local to a single
message's buttons. No other widget needs it, it doesn't survive navigation, and
it isn't derived from other state. A `_FeedbackButtons` StatefulWidget manages
the state machine locally.

**Evidence:** Compared against Andrea Bizzotto's 4-layer architecture
(Presentation → Application → Domain → Data). The Application layer is for
"service classes that mediate between controllers and repositories when logic
depends on multiple data sources." Feedback has no such logic — it's a single
POST with two outcomes. Adding a provider or service layer would create
pass-through classes. The clipboard copy in the same actions row is already
handled inline with less complexity.

### Fire-and-forget persistence (v1)

Feedback state is local to the widget instance. On page reload or app restart,
buttons reset to unselected. The backend stores feedback but there is no GET
endpoint to read it back.

**Evidence:** Backend PR #371 added only a POST endpoint. No GET endpoint
exists. Adding read-back would require scope on both frontend and backend. The
write path is independent of read-back, so this can be added later without
changing existing code.

## Acceptance Criteria

- [ ] Thumbs-up and thumbs-down buttons visible on completed assistant messages
- [ ] Tapping a thumb sends correct payload to backend
- [ ] Thumbs-down prompts for reason
- [ ] Thumbs-up shows optional "Add reason" affordance
- [ ] Tapping opposite thumb replaces feedback
- [ ] In-flight request shows spinner in place of the tapped thumb
- [ ] API errors revert spinner to unhighlighted icon + snackbar
- [ ] Buttons hidden during streaming
- [ ] `soliplex_client` remains pure Dart
- [ ] All tests pass, analyzer clean
