# Feature Specification: Narrowed RAG Search

## Overview

Allow users to narrow the scope of RAG searches to a specific subset of documents
(already ingested by the backend) by selecting them before submitting a prompt.

## Problem Statement

Currently, when a user submits a prompt, the backend performs RAG across the
entire document database for the room. Users often know which specific documents
contain relevant information and want to limit the search scope to improve
result relevance and reduce noise.

## Requirements

### Functional Requirements

1. Users can open a document picker by clicking a document button in the input
   area.
2. The picker displays a searchable, multi-select list of available documents in
   the current room.
3. Users can filter the list by typing a search query.
4. Users can toggle document selection using keyboard (arrows + space/enter) or
   mouse/touch.
5. Users can select multiple documents before closing the picker.
6. Selected documents appear as chips above the text input field.
7. Users can remove a selected document by clicking the × button on its chip.
8. The prompt submission includes the selected document references, instructing
   the backend to limit RAG scope.
9. Selected documents persist across runs in the same thread until the user
   removes them.
10. Changes to document selection are sent with the next run via AGUI state.

### Non-Functional Requirements

- Picker response should feel instantaneous (document list is cached client-side
  after first fetch).
- Works on both desktop (keyboard navigation) and mobile (touch selection).
- Accessible via keyboard-only interaction.

## Use Cases

### Use Case 1: New Thread with Document Selection

1. John starts a thread T in room R.
2. Frontend sends request to `/api/v1/rooms/{room_id}/agui`.
3. Backend responds with a new thread and the first (empty) Run.
4. John clicks the 📎 button to open the document picker.
5. Frontend requests documents via `/api/v1/rooms/{room_id}/documents`.
6. Backend responds with the document list.
7. Frontend displays the picker popup with a search field and multi-select list.
8. John selects document_A (checkbox toggles on).
9. John selects document_B (checkbox toggles on).
10. John closes the picker (clicks outside or presses Escape).
11. Both documents appear as chips above the text input.
12. John types their prompt in the text field.
13. John submits the prompt.
14. Frontend populates RunAgentInput with prompt + State containing selected
    document references.
15. Frontend starts the Run.

### Use Case 2: Follow-up Run with Persisted Selection

1. John's previous run used document_A and document_B.
2. The chips for document_A and document_B remain visible above the input.
3. John types a follow-up question without changing the document selection.
4. John submits the prompt.
5. Frontend sends RunAgentInput with the same document references in State.
6. The backend uses the same narrowed document scope.

### Use Case 3: Modifying Selection for a Follow-up Run

1. John's previous run used document_A and document_B.
2. John clicks × on the document_A chip to remove it.
3. John opens the picker and adds document_C.
4. John types a follow-up question.
5. John submits the prompt.
6. Frontend sends RunAgentInput with document_B and document_C in State.
7. The backend uses the updated document scope.

### Use Case 4: Clearing All Selected Documents

1. John has document_A and document_B selected.
2. John removes both chips by clicking × on each.
3. John types a question.
4. John submits the prompt.
5. Frontend sends RunAgentInput with no document references in State.
6. The backend performs RAG across all documents in the room.

## Design

### User Experience

**Layout:**

```text
┌─────────────────────────────────────────────────────────────┐
│ [manual.pdf ×] [troubleshooting.pdf ×]                      │  ← Chip row
├─────────────────────────────────────────────────────────────┤
│ 📎 Type your message...                              [Send] │  ← Input row
└─────────────────────────────────────────────────────────────┘
```

- The chip row only appears when at least one document is selected.
- The 📎 button opens the document picker popup.

**Trigger:**

- Clicking the 📎 button opens the picker popup.

**Picker popup:**

- Positioned above or below the input area.
- Contains a search field at the top for filtering.
- Lists all documents with checkboxes; selected documents are checked.
- Each document displays a file type icon matching its extension (e.g., PDF icon
  for `.pdf`, Word icon for `.docx`); unknown or missing extensions show a
  generic file icon.
- Document paths are shortened to show filename plus up to 2 parent folders
  (e.g., `my/folder/document.pdf`).
- Multi-select: user can toggle multiple documents before closing.
- Keyboard navigable: Tab to search, arrows to navigate list, Space to toggle,
  Escape to dismiss.
- Touch/click to toggle selection on mobile.
- Scrollable if the list exceeds the popup height.
- Closes when user clicks outside or presses Escape.

**Selected document chips:**

- Displayed in a row above the text input.
- Each chip shows a file type icon (matching the document's extension), the
  shortened document path, and an × button.
- Clicking × removes the document from selection.
- Row wraps if many documents are selected.
- Chips persist across runs until explicitly removed.

**Selection persistence:**

- Document selection is maintained across runs within the same thread.
- When the user submits a prompt, the current selection is sent via AGUI state.
- Users can modify the selection at any time; changes apply to the next run.
- Switching threads clears the selection (each thread has independent state).

**Loading state:**

- While documents are being fetched, the picker shows a loading indicator.
- The user can dismiss the picker and continue typing.

**Empty state:**

- If the room has no documents, the picker shows: "No documents in this room."
- The user can dismiss the picker and continue typing.

**Error state:**

- If document fetching fails after retries, the picker shows: "Could not load
  documents. Tap to retry."
- The user can dismiss the picker and continue typing without document
  selection.

## Acceptance Criteria

- [ ] Clicking 📎 button opens document picker popup.
- [ ] Picker shows all documents available in the current room.
- [ ] Picker has a search field that filters the document list.
- [ ] Picker supports multi-select (checkboxes, user can select many before
      closing).
- [ ] User can toggle selection via keyboard (arrows + space).
- [ ] User can toggle selection via mouse click or touch.
- [ ] Selected documents appear as chips above the text input.
- [ ] User can remove a chip by clicking its × button.
- [ ] Picker popup is scrollable when document list is long.
- [ ] Picker closes on click outside or Escape key.
- [ ] Document selection persists across runs in the same thread.
- [ ] Submitted prompt includes selected document references in AGUI state.
- [ ] Switching threads clears the document selection.
- [ ] Works on desktop, web, iOS, and Android.

## Open Questions

*None at this time.*
