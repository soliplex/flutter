# Implementation Plan: Run Feedback

## Overview

Three slices. Slice 1 lays the data foundation (`runId` plumbing + API method).
Slice 2 adds the feedback UI with local widget state. Slice 3 adds the reason
input flow.

## Slice Summary

| # | Slice | Customer Value |
|---|-------|----------------|
| 1 | Data foundation | `runId` available at UI layer, API method ready |
| 2 | Feedback buttons | Users can thumbs-up/down assistant messages |
| 3 | Reason input | Users can explain why feedback is negative (or positive) |

## Dependency Structure

```text
[1] Data foundation
         |
         v
[2] Feedback buttons
         |
         v
[3] Reason input
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

## Slice 2: Feedback Buttons

**Goal:** Users can tap thumbs-up/down on assistant messages.

### Tasks

1. Create a private `_FeedbackButtons` StatefulWidget with local state
   (idle/loading/submitted) that accepts an `onSubmit` callback
2. In `MessageList`, construct the API callback (has `ref` access to
   `SoliplexApi`, `roomId`, `threadId`) and pass it through
   `ChatMessageWidget` to `_FeedbackButtons`
3. Pass `runId` from `MessageState` down to `ChatMessageWidget`
4. While request is in flight, replace the tapped thumb with a small spinner
5. On success, show highlighted thumb. On failure, revert to unhighlighted
   icon and show snackbar
6. Write widget tests

### Key Files

**Modified:**

- `lib/features/chat/widgets/chat_message_widget.dart`
- `lib/features/chat/widgets/message_list.dart` (construct callback, pass
  `runId`)

### Acceptance Criteria

- [ ] Thumbs-up/down buttons visible on completed assistant messages
- [ ] Tapping sends feedback to backend
- [ ] Tapping opposite thumb replaces previous selection
- [ ] Tapping active thumb is a no-op
- [ ] In-flight request shows spinner in place of tapped thumb
- [ ] API errors revert spinner to unhighlighted icon + snackbar
- [ ] Buttons hidden during streaming
- [ ] Tests passing, analyzer clean

---

## Slice 3: Reason Input

**Goal:** Users can provide a reason for their feedback.

### Tasks

1. On thumbs-down tap, show a dialog/bottom sheet with a text field for reason
   and submit/cancel buttons
2. On thumbs-up tap, show an optional "Add reason" affordance (small text
   button or link near the thumbs) that opens the same dialog
3. Submit feedback with reason to backend
4. Write widget tests for the reason dialog

### Key Files

**Modified:**

- `lib/features/chat/widgets/chat_message_widget.dart`

**Created:**

- `lib/features/chat/widgets/feedback_reason_dialog.dart` (if extracted)

### Acceptance Criteria

- [ ] Thumbs-down shows reason dialog
- [ ] Thumbs-up shows optional "Add reason" affordance
- [ ] Reason submitted to backend
- [ ] Dialog can be dismissed without providing reason
- [ ] Tests passing, analyzer clean

---

## Definition of Done (per slice)

- [ ] All tasks completed
- [ ] All tests written and passing (TDD)
- [ ] Code formatted (`dart format`)
- [ ] No analyzer issues (`flutter analyze --fatal-infos`)
- [ ] PR reviewed and approved
- [ ] Merged to main
