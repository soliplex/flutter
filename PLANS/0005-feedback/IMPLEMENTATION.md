# Implementation Plan: Run Feedback

## Overview

Three slices, plus one post-slice bugfix. Slice 1 lays the data foundation
(`runId` plumbing + API method). Slice 2 adds the feedback buttons with
countdown timer and state machine. Slice 3 adds the reason modal.

## Slice Summary

| # | Slice | Customer Value |
|---|-------|----------------|
| 1 | Data foundation | `runId` available at UI layer, API method ready |
| 2 | Feedback buttons + countdown | Users can thumbs-up/down with 5s grace period to cancel or switch |
| 3 | Reason modal | Users can explain why they gave their feedback |

## Dependency Structure

```text
[1] Data foundation
         |
         v
[2] Feedback buttons + countdown
         |
         v
[3] Reason modal
```

Strictly sequential — each slice builds on the previous.

---

## Slice 1: Data Foundation

**Goal:** Make `runId` available at the UI layer and add the API method.

### Tasks

1. Add `runId` field to `MessageState` in `soliplex_client`
2. Populate `runId` in `ActiveRunNotifier._correlateMessagesForRun()` from
   `RunHandle.runId`
3. Populate `runId` in `SoliplexApi._replayEventsToHistory()` from the run data
4. Add `FeedbackType` enum to `soliplex_client` domain layer (`thumbsUp`,
   `thumbsDown`, serialized to `"thumbs_up"` / `"thumbs_down"`)
5. Add `submitFeedback()` method to `SoliplexApi`
6. Add `runIdForUserMessageProvider` to `source_references_provider.dart`
7. Update existing tests for `MessageState` and `SoliplexApi`

### Key Files

**Modified:**

- `packages/soliplex_client/lib/src/domain/message_state.dart`
- `packages/soliplex_client/lib/src/api/soliplex_api.dart`
- `lib/core/providers/active_run_notifier.dart`
- `lib/core/providers/source_references_provider.dart`

**Created:**

- `packages/soliplex_client/lib/src/domain/feedback_type.dart`

### Acceptance Criteria

- [x] `MessageState.runId` populated for both live and historical messages
- [x] `SoliplexApi.submitFeedback()` sends correct POST request
- [x] `FeedbackType` enum serializes to `"thumbs_up"` / `"thumbs_down"`
- [x] `runIdForUserMessageProvider` exposes `runId` at the UI layer
- [x] Existing tests updated and passing
- [x] Analyzer clean

---

## Slice 2: Feedback Buttons + Countdown

**Goal:** Users can tap thumbs-up/down on assistant messages with a 5-second
countdown before sending.

### Tasks

1. Create `FeedbackButtons` StatefulWidget with the Idle/Countdown/Submitted
   state machine
2. Implement countdown timer (5s) with circular progress indicator and
   remaining-seconds label
3. Implement all Countdown transitions: toggle-off (tap active thumb), switch
   direction (tap opposite thumb), and timer expiry (fire-and-forget send)
4. Implement Submitted state: active thumb locked, opposite thumb starts new
   countdown
5. In `MessageList`, construct the API callback (has `ref` access to
   `SoliplexApi`, `roomId`, `threadId`) and pass through `ChatMessageWidget`
   to `FeedbackButtons`
6. Pass `runId` from `MessageState` down to `ChatMessageWidget`
7. Fire-and-forget error handling: log errors via app logging, no UI indication
8. Write widget tests for all state transitions

### Key Files

**Modified:**

- `lib/features/chat/widgets/chat_message_widget.dart`
- `lib/features/chat/widgets/message_list.dart`

**Created:**

- `lib/features/chat/widgets/feedback_buttons.dart`

### Acceptance Criteria

- [x] Thumbs-up/down buttons visible on completed assistant messages
- [x] Tapping a thumb highlights it and starts 5s countdown
- [x] Countdown expiry sends feedback with `reason: null`
- [x] Tapping active thumb during countdown toggles off (nothing sent)
- [x] Tapping opposite thumb during countdown switches direction, restarts timer
- [x] Tapping opposite thumb after submission starts new countdown
- [x] Active thumb locked after submission (no toggle-off)
- [x] API errors logged, no UI indication
- [x] Buttons hidden during streaming
- [x] Tests passing, analyzer clean

---

## Slice 3: Reason Modal

**Goal:** Users can provide a reason for their feedback via a modal dialog.

### Tasks

1. Make "Tell us why!" text tappable during Countdown state
2. Create reason dialog with multiline text field, Send button, and Cancel
   button
3. Implement Countdown → Modal transition: dispose timer, open dialog
4. Implement Modal → Submitted transition (Send): send feedback with reason,
   close dialog (empty/whitespace-only text treated as `null` reason)
5. Implement Modal → Countdown reset transition (Cancel): close dialog, keep
   thumb highlighted, restart 5s timer
6. Write widget tests for modal interactions

### Key Files

**Modified:**

- `lib/features/chat/widgets/feedback_buttons.dart`

**Created:**

- `lib/features/chat/widgets/feedback_reason_dialog.dart`

### Acceptance Criteria

- [x] "Tell us why!" text is tappable during countdown
- [x] Tapping opens reason dialog with multiline text field, Send, Cancel
- [x] Send sends feedback with reason to backend
- [x] Cancel closes dialog, resets timer to 5s
- [x] Timer disposed while modal is open
- [x] Tests passing, analyzer clean

---

## Post-Slice Fix: Submit on Dispose

**Goal:** Preserve the user's feedback intent when they navigate away before
the countdown expires or while the modal is open.

### Tasks

1. In `FeedbackButtons.dispose()`, submit feedback with `reason: null` if the
   phase is `countdown` or `modal`
2. Call `onFeedbackSubmit` directly (not `_submit()`, which calls `setState`)
3. Write widget tests for dispose during countdown and dispose during modal

### Key Files

**Modified:**

- `lib/features/chat/widgets/feedback_buttons.dart`

### Acceptance Criteria

- [x] Disposing during countdown submits feedback with `null` reason
- [x] Disposing during modal submits feedback with `null` reason
- [x] Tests passing, analyzer clean

---

## Definition of Done (per slice)

- [x] All tasks completed
- [x] All tests written and passing (TDD)
- [x] Code formatted (`dart format`)
- [x] No analyzer issues (`flutter analyze --fatal-infos`)
- [x] PR reviewed and approved
- [x] Merged to main
