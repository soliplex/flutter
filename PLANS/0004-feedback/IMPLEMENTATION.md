# Implementation Plan: Run Feedback

## Overview

Three slices. Slice 1 lays the data foundation (`runId` plumbing + API method).
Slice 2 adds the feedback buttons with countdown timer and state machine.
Slice 3 adds the reason modal.

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
6. Update existing tests for `MessageState` and `SoliplexApi`

### Key Files

**Modified:**

- `packages/soliplex_client/lib/src/domain/message_state.dart`
- `packages/soliplex_client/lib/src/api/soliplex_api.dart`
- `lib/core/providers/active_run_notifier.dart`

**Created:**

- `packages/soliplex_client/lib/src/domain/feedback_type.dart`

### Acceptance Criteria

- [ ] `MessageState.runId` populated for both live and historical messages
- [ ] `SoliplexApi.submitFeedback()` sends correct POST request
- [ ] `FeedbackType` enum serializes to `"thumbs_up"` / `"thumbs_down"`
- [ ] Existing tests updated and passing
- [ ] Analyzer clean

---

## Slice 2: Feedback Buttons + Countdown

**Goal:** Users can tap thumbs-up/down on assistant messages with a 5-second
countdown before sending.

### Tasks

1. Create `_FeedbackButtons` StatefulWidget with the Idle/Countdown/Submitted
   state machine
2. Implement countdown timer (5s). Integrate Jaemin's circular timer widget
   (or placeholder until provided).
3. Implement all Countdown transitions: toggle-off (tap active thumb), switch
   direction (tap opposite thumb), and timer expiry (fire-and-forget send)
4. Implement Submitted state: active thumb locked, opposite thumb starts new
   countdown
5. In `MessageList`, construct the API callback (has `ref` access to
   `SoliplexApi`, `roomId`, `threadId`) and pass through `ChatMessageWidget`
   to `_FeedbackButtons`
6. Pass `runId` from `MessageState` down to `ChatMessageWidget`
7. Fire-and-forget error handling: log errors via app logging, no UI indication
8. Write widget tests for all state transitions

### Key Files

**Modified:**

- `lib/features/chat/widgets/chat_message_widget.dart`
- `lib/features/chat/widgets/message_list.dart` (construct callback, pass
  `runId`)

### Acceptance Criteria

- [ ] Thumbs-up/down buttons visible on completed assistant messages
- [ ] Tapping a thumb highlights it and starts 5s countdown
- [ ] Countdown expiry sends feedback with `reason: null`
- [ ] Tapping active thumb during countdown toggles off (nothing sent)
- [ ] Tapping opposite thumb during countdown switches direction, restarts timer
- [ ] Tapping opposite thumb after submission starts new countdown
- [ ] Active thumb locked after submission (no toggle-off)
- [ ] API errors logged, no UI indication
- [ ] Buttons hidden during streaming
- [ ] Tests passing, analyzer clean

---

## Slice 3: Reason Modal

**Goal:** Users can provide a reason for their feedback via a modal dialog.

### Tasks

1. Make "Tell us why!" text tappable during Countdown state
2. Create reason dialog with text field, Ok/Send button, and Cancel button
3. Implement Countdown → Modal transition: dispose timer, open dialog
4. Implement Modal → Submitted transition (Ok/Send): send feedback with reason,
   close dialog
5. Implement Modal → Countdown reset transition (Cancel): close dialog, keep
   thumb highlighted, restart 5s timer
6. Write widget tests for modal interactions

### Key Files

**Modified:**

- `lib/features/chat/widgets/chat_message_widget.dart`

**Created:**

- `lib/features/chat/widgets/feedback_reason_dialog.dart` (if extracted)

### Acceptance Criteria

- [ ] "Tell us why!" text is tappable during countdown
- [ ] Tapping opens reason dialog with text field, Ok/Send, Cancel
- [ ] Ok/Send sends feedback with reason to backend
- [ ] Cancel closes dialog, resets timer to 5s
- [ ] Timer disposed while modal is open
- [ ] Tests passing, analyzer clean

---

## Definition of Done (per slice)

- [ ] All tasks completed
- [ ] All tests written and passing (TDD)
- [ ] Code formatted (`dart format`)
- [ ] No analyzer issues (`flutter analyze --fatal-infos`)
- [ ] PR reviewed and approved
- [ ] Merged to main
