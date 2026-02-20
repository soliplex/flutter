# ADR: Run Feedback Integration

## Status

Accepted

## Context

Users need to rate assistant responses. The backend endpoint exists (PR #371);
the frontend needs to wire up UI and API calls.

See [SPEC.md](./SPEC.md) for requirements, use cases, and state machine.

**Issue:** <https://github.com/soliplex/soliplex/issues/355>

### Current Architecture

Assistant messages are rendered by `ChatMessageWidget`. Each message has an
actions row with a copy button. Messages are keyed by `ChatMessage.id`, and
per-message metadata lives in `MessageState` (keyed by user message ID).

The backend feedback endpoint requires `room_id`, `thread_id`, and `run_id`.
The frontend currently tracks `roomId` and `threadId` in providers, but `runId`
is not available at the UI layer — it exists only transiently in `RunHandle`
during streaming and is discarded after run completion.

## Decision

### 1. Add `runId` to `MessageState`

`MessageState` already bridges per-run data (citations) to the UI. Adding
`runId` is the minimal change to make feedback possible. The field is populated
at the same two sites where `MessageState` is already created:

- `ActiveRunNotifier._correlateMessagesForRun()` — has `RunHandle.runId`
- `SoliplexApi._replayEventsToHistory()` — has the run ID from the runs map

A `runIdForUserMessageProvider` was added to `source_references_provider.dart`
to expose `runId` at the UI layer, following the same pattern as the existing
`sourceReferencesForUserMessageProvider`.

**Rationale:** Avoids creating a parallel data structure. `MessageState` is
already keyed by user message ID and flows through the provider layer to the UI.
Adding one field is simpler than introducing a separate `runId` lookup.

### 2. `submitFeedback` on `SoliplexApi`

A new method following the existing transport/error pattern. Takes `roomId`,
`threadId`, `runId`, `feedback`, and optional `reason`. Returns `void` (backend
returns 205 with no body).

**Rationale:** Consistent with the existing API client design. No new
abstractions needed.

### 3. Feedback Domain Model in `soliplex_client`

A simple enum (`FeedbackType`) with `thumbsUp` and `thumbsDown` values,
serialized to `"thumbs_up"` / `"thumbs_down"`. Pure Dart, lives in the domain
layer.

**Rationale:** Type safety for a fixed set of values. The enum prevents typos
and makes the API contract explicit.

### 4. Deferred Sending with Countdown Timer

Feedback is not sent immediately on thumb tap. A 5-second countdown timer
starts. The backend call happens only when:

- The timer expires (feedback sent with `reason: null`), or
- The user submits a reason via the modal (feedback sent with reason).

**Rationale:** Deferred sending enables toggle-off (undo accidental taps) and
gives users a natural window to add a reason. With immediate sending, toggle-off
would require a DELETE endpoint (which doesn't exist) or would create
inconsistency between UI state and backend state.

### 5. Toggle-Off During Countdown Only

During the countdown (before any backend call), tapping the active thumb
cancels the feedback and returns to idle. After the countdown expires (feedback
sent), toggle-off is disabled — the active thumb is locked.

**Rationale:** The backend has only a POST endpoint (create/replace), no DELETE.
After sending, un-highlighting locally while the backend retains the feedback
would mislead the user. During the countdown, no call has been made, so
cancellation is clean.

### 6. Switching Direction Replaces Feedback

During the countdown, tapping the opposite thumb cancels the current direction
and starts a fresh countdown for the new direction. After submission, tapping
the opposite thumb starts a new countdown — on expiry, the backend replaces the
previous feedback (upsert behavior confirmed in `save_run_feedback`).

### 7. Unified Reason Flow for Both Directions

Both thumbs-up and thumbs-down show the same "Tell us why!" countdown and
the same reason modal. No asymmetric behavior between directions.

**Rationale:** Simplifies the state machine and UI implementation. Users may
want to explain positive feedback ("Great summary!") just as much as negative.
A single code path handles both.

### 8. Fire-and-Forget Sending, No Loading Indicator

When the countdown expires or the user submits via the modal, the API call is
made with no loading spinner. The UI transitions to Submitted immediately. If
the API call fails, the error is logged locally (via the app logging system).
The user is not shown an error.

**Rationale:** Feedback is low-stakes. Showing a spinner or error snackbar for
a thumbs-up failing would be disproportionate friction. The countdown timer
already provides visual feedback during the decision window. Logging ensures
failed feedback can be investigated without disrupting the user.

### 9. Local Widget State, No Provider

Feedback state (Idle/Countdown/Modal/Submitted) is managed by `FeedbackButtons`
(a StatefulWidget), not a Riverpod provider. The countdown timer is local widget
state.

`MessageList` (a `ConsumerStatefulWidget` with `ref` access) constructs the API
callback and passes it down through `ChatMessageWidget` to `FeedbackButtons`.

**Rationale:** Feedback state is ephemeral — no other widget needs it, it
doesn't survive navigation, and it isn't derived from other state. A Riverpod
family provider would add machinery for something simpler than the clipboard
copy that's already handled inline. Local `StatefulWidget` state is the correct
tool for ephemeral UI state with a timer.

### 10. Fire-and-Forget Persistence (v1)

Feedback state is local to the widget instance. On page reload or app restart,
buttons reset to unselected. The backend stores feedback but there is no GET
endpoint to read it back.

**Rationale:** Simplest viable approach. A read-back endpoint can be added
later without changing the write path.

### 11. Thumbs Buttons in Agent Actions Row

Add thumbs-up/thumbs-down buttons to `_buildAgentMessageActionsRow()` in
`ChatMessageWidget`. This widget already renders per-message action buttons for
assistant messages.

**Rationale:** Minimal UI change. Follows the existing pattern (copy button).
The actions row is already gated on `!isStreaming`, so feedback buttons
automatically hide during streaming.

### 12. Submit on Dispose

When `FeedbackButtons` disposes during the countdown or modal phase (e.g., user
navigates away), feedback is submitted immediately with `reason: null`. The
user's directional intent is preserved.

**Rationale:** The user deliberately chose a direction. Discarding that intent
on navigation would silently lose feedback. Since feedback is fire-and-forget
and low-stakes, submitting with no reason is the safest default. The
`onFeedbackSubmit` callback is called directly (not via `setState`) since
`setState` is illegal during `dispose`.

## Consequences

### Positive

- Minimal structural change — one new field on `MessageState`, one new API
  method, one new StatefulWidget, no new providers.
- `runId` in `MessageState` benefits any future per-run feature (analytics,
  re-run, etc.).
- Type-safe feedback values via enum.
- Deferred sending enables clean toggle-off without a DELETE endpoint.
- Unified reason flow reduces code paths.
- Submit-on-dispose prevents silent feedback loss on navigation.

### Negative

- Feedback state does not survive page reload (acceptable for v1).
- `MessageState` grows by one field (minor).
- Failed API calls are invisible to the user (acceptable for low-stakes
  feedback; logged for debugging).

### Risks

- **Backend `feedback` value contract:** The backend currently accepts any
  string. If it later validates against a fixed set, our values
  (`thumbs_up` / `thumbs_down`) must be in that set. Low risk — we control
  both codebases.

## Alternatives Considered

### 1. Immediate Sending (send on thumb tap)

**Approach:** Send feedback to the backend immediately when the user taps a
thumb.

**Rejected because:** Immediate sending prevents clean toggle-off (would require
a DELETE endpoint or create UI/backend inconsistency). It also eliminates the
natural window for reason input. The 5-second countdown is minimal friction and
enables both features.

### 2. Separate `runId` Lookup Map

**Approach:** Maintain a separate `Map<String, String>` mapping user message IDs
to run IDs, independent of `MessageState`.

**Rejected because:** `MessageState` already exists for exactly this purpose
(per-run metadata keyed by user message). A parallel map adds complexity without
benefit.

### 3. Feedback as Part of `Conversation`

**Approach:** Store feedback state directly on the `Conversation` domain model.

**Rejected because:** `Conversation` is the streaming aggregate root. Feedback
is a post-completion concern. Mixing them conflates lifecycle stages.

### 4. Optimistic UI with Rollback

**Approach:** Highlight the thumb immediately on tap (before the API responds).
If the API call fails, un-highlight back to the previous state.

**Rejected because:** Deferred sending with a countdown timer provides a better
UX. The countdown gives users time to reconsider or add a reason. After the
countdown, the send is fire-and-forget with no rollback needed. Optimistic UI
would require tracking both displayed state and in-flight state plus handling
race conditions.

### 5. Spinner While Loading

**Approach:** Replace the tapped thumb with a spinner during the API call.

**Rejected because:** The countdown timer replaces the spinner's role as visual
feedback. After the countdown, the send is fire-and-forget — no loading state
is needed. Adding a spinner after the countdown would be redundant.

### 6. Toggle-Off After Submission

**Approach:** Allow withdrawing feedback at any time by tapping the active
thumb.

**Rejected because:** The backend has only a POST endpoint (create/replace),
no DELETE. Un-highlighting locally while the backend retains the feedback would
mislead the user. Toggle-off during the countdown (before sending) avoids this
problem entirely.

### 7. Asymmetric Reason Flow (prompt on down, optional on up)

**Approach:** Automatically prompt for a reason on thumbs-down but show only an
optional "Add reason" link on thumbs-up.

**Rejected because:** The countdown-based "Tell us why!" flow handles both
directions uniformly. A unified flow is simpler to implement and maintain, and
doesn't make assumptions about when users want to provide reasons.

### 8. Riverpod Family Provider for Feedback State

**Approach:** Create a family provider keyed by run ID to hold feedback state,
with the UI reading from the provider.

**Rejected because:** Feedback state is ephemeral and local to a single widget.
No other widget needs to read it, it doesn't survive navigation, and it isn't
derived from other state. A provider adds Riverpod machinery for something
simpler than the clipboard copy already handled inline. Local `StatefulWidget`
state is the correct tool for ephemeral UI state.

### 9. Backend GET Endpoint for Read-Back

**Approach:** Request a GET endpoint and persist feedback across sessions.

**Deferred:** Adds scope to both frontend and backend. Fire-and-forget is
sufficient for v1. Can be added later as a non-breaking enhancement.

## References

- [Issue #355: Feedback API](https://github.com/soliplex/soliplex/issues/355)
- [PR #371: Backend feedback endpoint](https://github.com/soliplex/soliplex/pull/371)
