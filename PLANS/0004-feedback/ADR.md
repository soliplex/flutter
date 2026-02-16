# ADR: Run Feedback Integration

## Status

Proposed

## Context

Users need to rate assistant responses. The backend endpoint exists (PR #371);
the frontend needs to wire up UI and API calls.

See [SPEC.md](./SPEC.md) for requirements and use cases.

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

### 4. Local Widget State, No Provider

Feedback state (idle/loading/submitted) is managed by a small private
`_FeedbackButtons` StatefulWidget, not a Riverpod provider. While a request is
in flight, the tapped thumb is replaced by a small spinner — this prevents
double-taps naturally and gives immediate visual feedback.

`MessageList` (a `ConsumerStatefulWidget` with `ref` access) constructs the API
callback and passes it down through `ChatMessageWidget` to `_FeedbackButtons`.

**Rationale:** Feedback state is ephemeral — no other widget needs it, it
doesn't survive navigation, and it isn't derived from other state. A Riverpod
family provider would add machinery for something simpler than the clipboard
copy that's already handled inline. The spinner-while-loading approach avoids
rollback logic and race conditions.

### 5. Fire-and-Forget Persistence (v1)

Feedback state is local to the widget instance. On page reload or app restart,
buttons reset to unselected. The backend stores feedback but there is no GET
endpoint to read it back.

**Rationale:** Simplest viable approach. A read-back endpoint can be added
later without changing the write path.

### 6. Thumbs Buttons in Agent Actions Row

Add thumbs-up/thumbs-down buttons to `_buildAgentMessageActionsRow()` in
`ChatMessageWidget`. This widget already renders per-message action buttons for
assistant messages.

**Rationale:** Minimal UI change. Follows the existing pattern (copy button).
The actions row is already gated on `!isStreaming`, so feedback buttons
automatically hide during streaming.

## Consequences

### Positive

- Minimal structural change — one new field on `MessageState`, one new API
  method, one new StatefulWidget, no new providers.
- `runId` in `MessageState` benefits any future per-run feature (analytics,
  re-run, etc.).
- Type-safe feedback values via enum.

### Negative

- Feedback state does not survive page reload (acceptable for v1).
- `MessageState` grows by one field (minor).

### Risks

- **Backend `feedback` value contract:** The backend currently accepts any
  string. If it later validates against a fixed set, our values
  (`thumbs_up` / `thumbs_down`) must be in that set. Low risk — we control
  both codebases.

## Alternatives Considered

### 1. Separate `runId` Lookup Map

**Approach:** Maintain a separate `Map<String, String>` mapping user message IDs
to run IDs, independent of `MessageState`.

**Rejected because:** `MessageState` already exists for exactly this purpose
(per-run metadata keyed by user message). A parallel map adds complexity without
benefit.

### 2. Feedback as Part of `Conversation`

**Approach:** Store feedback state directly on the `Conversation` domain model.

**Rejected because:** `Conversation` is the streaming aggregate root. Feedback
is a post-completion concern. Mixing them conflates lifecycle stages.

### 3. Optimistic UI with Rollback

**Approach:** Highlight the thumb immediately on tap (before the API responds).
If the API call fails, un-highlight back to the previous state.

**Rejected because:** Requires tracking both displayed state and in-flight
state separately, plus handling race conditions when the user taps again during
a request. The spinner approach gives immediate visual feedback without any of
this complexity — the button is replaced so double-taps are impossible, and no
"selected" state is shown that would need reverting.

### 4. Toggle-Off (Withdraw Feedback)

**Approach:** Allow tapping the active thumb again to un-highlight and withdraw
feedback.

**Rejected because:** The backend has only a POST endpoint (create/replace),
no DELETE. Un-highlighting locally while the backend retains the feedback would
mislead the user into thinking they withdrew it. Once feedback is given, the
user can switch direction but not withdraw.

### 5. Riverpod Family Provider for Feedback State

**Approach:** Create a family provider keyed by run ID to hold feedback state,
with the UI reading from the provider.

**Rejected because:** Feedback state is ephemeral and local to a single widget.
No other widget needs to read it, it doesn't survive navigation, and it isn't
derived from other state. A provider adds Riverpod machinery for something
simpler than the clipboard copy already handled inline. Local `StatefulWidget`
state is the correct tool for ephemeral UI state.

### 6. Backend GET Endpoint for Read-Back

**Approach:** Request a GET endpoint and persist feedback across sessions.

**Deferred:** Adds scope to both frontend and backend. Fire-and-forget is
sufficient for v1. Can be added later as a non-breaking enhancement.

## References

- [Issue #355: Feedback API](https://github.com/soliplex/soliplex/issues/355)
- [PR #371: Backend feedback endpoint](https://github.com/soliplex/soliplex/pull/371)
