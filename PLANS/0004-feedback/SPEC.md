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
2. Tapping a thumb highlights it and starts a 5-second countdown timer.
3. Feedback is **not** sent to the backend until the countdown expires or the
   user submits a reason via the modal.
4. During the countdown, tapping the active thumb toggles it off (cancels
   feedback, nothing sent).
5. During the countdown, tapping the opposite thumb switches direction and
   restarts the timer.
6. During the countdown, tapping "Tell us why!" opens a reason modal.
7. After countdown expires, feedback is sent with `reason: null`. The thumb is
   locked (no toggle-off).
8. After submission, tapping the opposite thumb starts a new countdown for the
   new direction.
9. Feedback buttons appear only on non-streaming assistant messages.

### Non-Functional Requirements

- Feedback state is fire-and-forget for v1 (not persisted across sessions).
- `soliplex_client` remains pure Dart (no Flutter imports).
- API errors are logged locally, not surfaced to the user.

## Use Cases

### Use Case 1: Thumbs Up (no reason)

1. Alice reads an assistant response she finds helpful.
2. Alice taps the thumbs-up icon.
3. The icon highlights and a 5-second countdown timer with "Tell us why!"
   appears.
4. Alice does not interact further.
5. The timer expires. The frontend sends
   `{ "feedback": "thumbs_up", "reason": null }`.
6. The timer disappears. The thumbs-up icon remains highlighted (locked).

### Use Case 2: Thumbs Down with Reason

1. Bob reads an inaccurate assistant response.
2. Bob taps the thumbs-down icon. It highlights, countdown starts.
3. Bob taps "Tell us why!" before the timer expires.
4. A modal opens with a text field. The timer is disposed.
5. Bob types "The citation is wrong" and taps Ok/Send.
6. The frontend sends
   `{ "feedback": "thumbs_down", "reason": "The citation is wrong" }`.
7. The modal closes. Thumbs-down remains highlighted (locked).

### Use Case 3: Toggle Off During Countdown

1. Carol accidentally taps thumbs-up. It highlights, countdown starts.
2. Carol taps thumbs-up again during the countdown.
3. The icon unhighlights, the timer disappears. Back to idle.
4. Nothing was sent to the backend.

### Use Case 4: Switch Direction During Countdown

1. Dave taps thumbs-up. It highlights, 5-second countdown starts.
2. Dave changes his mind and taps thumbs-down during the countdown.
3. Thumbs-up unhighlights. Thumbs-down highlights. Timer restarts at 5 seconds.

### Use Case 5: Switch After Submission

1. Eve previously gave thumbs-up (timer expired, feedback sent).
2. Eve changes her mind and taps thumbs-down.
3. A new 5-second countdown starts for thumbs-down.
4. The timer expires. New feedback is sent (backend replaces the previous entry).

### Use Case 6: Cancel Reason Modal

1. Frank taps thumbs-down. It highlights, countdown starts.
2. Frank taps "Tell us why!". The modal opens (timer disposed).
3. Frank starts typing but changes his mind. He taps Cancel.
4. The modal closes. Thumbs-down remains highlighted. Timer resets to 5 seconds
   and starts counting down again.

### Use Case 7: API Error

1. Grace taps thumbs-up while offline. Countdown runs.
2. The timer expires. The frontend attempts to send feedback.
3. The request fails. The error is logged locally.
4. The UI remains in the submitted state (thumbs-up highlighted). Grace is
   unaware of the failure.

## Design

### Key Structural Gap: `runId` at the UI Layer

The backend endpoint requires `run_id`. Currently, `MessageState` does not carry
`runId`. It must be added so that the feedback UI can construct the API call.

`runId` is available at the two places where `MessageState` is created:

- `ActiveRunNotifier._correlateMessagesForRun()` (live runs via `RunHandle`)
- `SoliplexApi._replayEventsToHistory()` (history replay from run data)

### State Machine

```text
          tap thumb                timer expires
  [Idle] ──────────> [Countdown] ──────────────> [Submitted]
              tap active  ^  |                     |
              thumb       |  | tap "Tell us why!"  | tap opposite
              (toggle off)|  v                     | thumb
          <───────── [Countdown]  [Modal] ─────>   |
  [Idle]    cancel    (reset)       |  |           v
                        ^          Ok  Cancel   [Countdown]
                        |          |     |        (new direction)
                        |          v     v
                        |   [Submitted] [Countdown]
                        └──────────────── (reset)
```

**States:**

- **Idle:** Both thumbs unhighlighted, no timer.
- **Countdown:** One thumb highlighted, circular timer with "Tell us why!"
  visible, 5-second countdown running. No backend call yet.
- **Modal:** Reason dialog open, timer disposed.
- **Submitted:** Thumb highlighted, no timer, feedback sent to backend.
  Active thumb locked. Opposite thumb can start a new countdown.

### Data Flow

```text
User taps thumb
    |
    v
_FeedbackButtons (local state: Idle → Countdown, 5s timer starts)
    |
    [timer expires OR modal submit]
    |
    v
onSubmit callback (constructed by MessageList, which has ref access)
    |
    v
SoliplexApi.submitFeedback(roomId, threadId, runId, feedback, reason)
    |                                                [fire-and-forget]
    v
POST /v1/rooms/{room_id}/agui/{thread_id}/{run_id}/feedback
```

No Riverpod provider needed. Feedback state is ephemeral and local to a single
message widget — it doesn't need to be shared, derived, or persisted. A
`_FeedbackButtons` StatefulWidget manages the Idle/Countdown/Modal/Submitted
state machine. `MessageList` (a `ConsumerStatefulWidget` with `ref`) constructs
the API callback and passes it down.

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

### Deferred sending with countdown timer

Feedback is not sent to the backend immediately on thumb tap. Instead, a
5-second countdown timer starts. The backend call happens only when the timer
expires (with `reason: null`) or when the user submits a reason via the modal.

This enables two interactions that immediate sending would not:

1. **Toggle-off:** The user can undo an accidental thumb tap during the
   countdown (nothing was sent, so no inconsistency).
2. **Reason input:** The user has a natural window to add a reason before the
   feedback is committed.

### Toggle-off during countdown only

During the countdown, tapping the active thumb cancels the feedback and returns
to idle. No backend call is made. After the countdown expires (feedback sent),
toggle-off is not possible.

**Rationale:** The backend has only a POST endpoint (create/replace), no DELETE.
After sending, un-highlighting locally while the backend retains the feedback
would mislead the user. During the countdown, no call has been made, so
cancellation is clean.

### Switching direction replaces feedback

During the countdown, tapping the opposite thumb cancels the current direction
and starts a fresh countdown for the new direction. After submission, tapping
the opposite thumb starts a new countdown — on expiry, the backend replaces the
previous feedback (upsert behavior confirmed in `save_run_feedback`).

### Unified reason flow for both directions

Both thumbs-up and thumbs-down show the same "Tell us why!" countdown and
the same reason modal. No asymmetric behavior between directions.

**Rationale:** Simplifies the state machine and UI implementation. Users may
want to explain positive feedback ("Great summary!") just as much as negative.
A single code path handles both.

### Fire-and-forget sending, no loading indicator

When the countdown expires or the user submits via the modal, the API call is
made with no loading spinner. The UI transitions to Submitted immediately. If
the API call fails, the error is logged locally (via the app logging system).
The user is not shown an error.

**Rationale:** Feedback is low-stakes. Showing a spinner or error snackbar for
a thumbs-up failing would be disproportionate friction. The countdown timer
already provides visual feedback during the decision window. Logging ensures
failed feedback can be investigated without disrupting the user.

### No Riverpod provider

Feedback state (Idle/Countdown/Modal/Submitted) is managed by a private
`_FeedbackButtons` StatefulWidget, not a Riverpod provider. The countdown timer
is local widget state.

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
- [ ] Tapping a thumb highlights it and starts 5-second countdown
- [ ] Countdown expiry sends feedback with `reason: null` to backend
- [ ] Tapping active thumb during countdown toggles off (nothing sent)
- [ ] Tapping opposite thumb during countdown switches direction, restarts timer
- [ ] Tapping opposite thumb after submission starts new countdown
- [ ] "Tell us why!" opens reason modal (timer disposed)
- [ ] Modal Ok/Send sends feedback with reason to backend
- [ ] Modal Cancel closes dialog, resets timer to 5s
- [ ] After submission, active thumb locked (no toggle-off)
- [ ] API errors logged locally, UI unaffected
- [ ] Buttons hidden during streaming
- [ ] `soliplex_client` remains pure Dart
- [ ] All tests pass, analyzer clean
