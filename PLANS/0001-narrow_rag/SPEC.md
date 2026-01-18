# Feature Specification: Narrowed RAG Search

## Overview

Allow users to narrow the scope of RAG searches to a specific subset of documents
(already ingested by the backend) by selecting them directly within the prompt
input field.

## Problem Statement

Currently, when a user submits a prompt, the backend performs RAG across the
entire document database for the room. Users often know which specific documents
contain relevant information and want to limit the search scope to improve
result relevance and reduce noise.

## Requirements

### Functional Requirements

1. Users can trigger a document selection UI by typing a trigger symbol (`#`) in
   the prompt input.
2. The UI displays an autocomplete list of available documents in the current
   room.
3. The autocomplete list filters as the user types additional characters after
   the trigger symbol.
4. Users can select documents using keyboard navigation (arrow keys + enter) or
   mouse/touch.
5. Selected documents appear as visual "chips" in the input field.
6. Users can select multiple documents within a single prompt.
7. Users can deselect/remove documents before submitting.
8. The prompt submission includes the selected document references, instructing
   the backend to limit RAG scope.

### Non-Functional Requirements

- Autocomplete response should feel instantaneous (document list can be cached).
- Works on both desktop (keyboard navigation) and mobile (touch selection).
- Accessible via keyboard-only interaction.

## Use Cases

### Use Case 1: New Thread with Document Selection

1. John starts a thread T in room R.
2. Frontend sends request to `/api/v1/rooms/{room_id}/agui`.
3. Backend responds with a new thread and the first (empty) Run.
4. John starts typing a prompt.
5. John types the file selection symbol `#`.
6. Frontend requests documents via `/api/v1/rooms/{room_id}/documents`.
7. Backend responds with the document list.
8. Frontend displays autocomplete widget, filtering as John types.
9. **Desktop:** John uses arrow keys and enter to select a document.
10. **Mobile:** John scrolls and taps a document to select it.
11. John continues typing (possibly selecting additional documents).
12. John submits the prompt.
13. Frontend populates RunAgentInput with prompt + State containing selected
    document references.
14. Frontend starts the Run.

### Use Case 2: Follow-up Run in Same Thread

Same UX as Use Case 1. Document selection does not carry over from previous
runs—John may select documents again (same or different).

### Use Case 3: Deselecting a Document

1. John selects document_A and document_B.
2. John finishes typing the prompt.
3. Before submitting, John realises document_A is unnecessary.
4. John removes document_A (clicks X on chip or backspaces over it).
5. John submits the prompt.
6. Frontend submits RunAgentInput with prompt and State referencing only
   document_B.

## Design

### User Experience

**Trigger:** Typing `#` in the prompt input opens an autocomplete popup.

**Autocomplete popup:**

- Shows all available documents initially.
- Filters list as user types characters after `#`.
- Keyboard navigable (up/down arrows, enter to select, escape to dismiss).
- Touch/click selection on mobile.

**Selected documents:**

- Displayed as chips (Material Design "input chips") inline with the text.
- Each chip shows the document name and a remove button.
- Chips can be removed by clicking the X or backspacing over them.

**Example prompt:**

```text
Which symbol indicates an issue with oil level? Use #mercedes_c330_manual.pdf
and #mercedes_c330_troubleshooting.pdf
```

## Acceptance Criteria

- [ ] Typing `#` in prompt input triggers document autocomplete popup.
- [ ] Autocomplete shows documents available in the current room.
- [ ] Autocomplete filters as user types after `#`.
- [ ] User can select document via keyboard (arrows + enter).
- [ ] User can select document via mouse click or touch.
- [ ] Selected document appears as a chip in the input.
- [ ] User can select multiple documents.
- [ ] User can remove a selected document before submitting.
- [ ] Submitted prompt includes selected document references in request payload.
- [ ] Works on desktop, web, iOS, and Android.

## Open Questions

1. **Should document selection persist across runs in the same thread?**
   - Pro: Less repetitive if conversation focuses on specific documents.
   - Con: User might forget which documents are "active" and get unexpected
     results.
   - *Needs team input.*
