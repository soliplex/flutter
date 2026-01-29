# Implementation Plan: Narrowed RAG Search

## Overview

This plan uses vertical slicing with a "walking skeleton" approach. Slice 1
delivers the bare minimum end-to-end feature. Subsequent slices add refinements
and can be implemented in parallel after slice 1.

## Slice Summary

| # | Slice | ~Lines | Customer Value |
|---|-------|--------|----------------|
| 1 | Walking skeleton | ~280 | User can select ONE doc, AI uses it |
| 2 | Chip styling | ~80 | Selected docs shown as proper chips |
| 3 | Multi-select | ~100 | User can select multiple documents |
| 4 | Search in picker | ~120 | User can find documents quickly |
| 5 | Selection persistence | ~150 | Selection survives across runs |
| 6 | Loading indicator | ~60 | Spinner while fetching documents |
| 7 | Empty room handling | ~40 | Picker button disabled when no docs |
| 8 | Error + retry | ~180 | Error feedback, retry button, backoff |
| 9 | Keyboard navigation | ~120 | Arrows, space, escape in picker |
| 10 | File type icons | ~80 | Visual cues for document types |

## Dependency Structure

```text
            [1] Walking skeleton
                     │
      ┌──────────────┼──────────────┐
      │              │              │
      ▼              ▼              ▼
     [2]            [5]            [7]
    chips         persist        empty
      │
      ▼
    [10] file-icons

                     │
                     ▼
                    [3] multi-select
                     │
                     ▼
                    [4] search
                     │
                     ▼
                    [6] loading
                     │
                     ▼
                    [8] error + retry
                     │
                     ▼
                    [9] keyboard
```

**Parallel from slice 1:** Slices 2, 5, 7 don't touch picker internals.

**Parallel from slice 2:** Slice 10 (file-icons) adds icons to chips and picker.

**Stacked (picker chain):** Slices 3→4→6→8→9 all modify the picker dialog
and must be stacked to avoid git conflicts.

## Implementation Order

1. **Slice 1** - Walking skeleton (required first)
2. **Slice 3** - Multi-select (start picker chain)
3. **Slice 5** - Persistence (parallel with picker chain)
4. **Slice 2** - Chips (parallel with picker chain)
5. **Slice 10** - File type icons (after chips)
6. **Slice 4** - Search (continues picker chain)
7. **Slice 8** - Error + retry
8. **Slice 7** - Empty room (parallel, low priority)
9. **Slice 6** - Loading
10. **Slice 9** - Keyboard nav

---

## Slice 1: Walking Skeleton

**Branch:** `feat/narrow-rag/01-skeleton`

**Target:** ~280 lines

**Customer value:** User can select ONE document, AI searches only that document.

### What's included (minimal)

- `RAGDocument` and `RoomDocuments` models
- `getDocuments()` API method
- Basic `documentsProvider` (no retry logic)
- 📎 button in chat input
- Single-select picker dialog (no search, no filtering)
- Plain text display of selected document above input
- `filter_documents` in AG-UI state on submit

### What's intentionally excluded

- Chip styling (slice 2)
- Multi-select (slice 3)
- Search (slice 4)
- Persistence (slice 5)
- Loading indicator (slice 6)
- Empty room handling (slice 7)
- Error handling/retry (slice 8)
- Keyboard navigation (slice 9)
- File type icons (slice 10)

### Tasks

1. Create `RAGDocument`, `RoomDocuments` models in soliplex_client
2. Add JSON mappers for `document_set` response format
3. Add `getDocuments()` to `SoliplexApi`
4. Create basic `documentsProvider` (FutureProvider.family)
5. Add 📎 IconButton to `ChatInput`
6. Create `DocumentPickerDialog` with simple list
7. Display selected document as plain Text above input
8. Build `filter_documents` state and pass to `startRun()`

### Tests

- Unit: Models parse correctly
- Unit: API returns documents
- Widget: Button opens picker
- Widget: Selecting document shows text above input
- Integration: Submit includes filter_documents in state

### Acceptance Criteria

- [ ] User can tap 📎 and see document list
- [ ] User can select one document
- [ ] Selected document name shown above input
- [ ] Submitting sends filter_documents to backend
- [ ] All tests pass

---

## Slice 2: Chip Styling

**Branch:** `feat/narrow-rag/02-chips`

**Target:** ~80 lines

**Customer value:** Selected documents displayed as proper chips with × button.

### Tasks

1. Replace plain Text with `RawChip` or `InputChip`
2. Add × button via `onDeleted` callback
3. Use `Wrap` widget for multiple chips (prep for slice 3)

### Tests

- Widget: Selected doc renders as chip
- Widget: × button removes chip
- Widget: Chip shows document title

### Acceptance Criteria

- [ ] Selected document shown as chip
- [ ] × button removes selection
- [ ] All tests pass

---

## Slice 3: Multi-select

**Branch:** `feat/narrow-rag/03-multi-select`

**Target:** ~100 lines

**Customer value:** User can select multiple documents at once.

### Tasks

1. Change picker from single-select to multi-select
2. Add checkboxes to list items
3. Track `Set<RAGDocument>` instead of single selection
4. Update `filter_documents` to include multiple IDs

### Tests

- Widget: Can select multiple documents
- Widget: Checkboxes toggle correctly
- Widget: Multiple chips displayed
- Integration: Multiple IDs in filter_documents

### Acceptance Criteria

- [ ] User can select multiple documents
- [ ] All selected documents shown as chips
- [ ] All IDs sent in filter_documents
- [ ] All tests pass

---

## Slice 4: Search in Picker

**Branch:** `feat/narrow-rag/04-search`

**Target:** ~120 lines

**Customer value:** User can quickly find documents by typing.

### Tasks

1. Add search TextField at top of picker
2. Filter list as user types (case-insensitive)
3. Show "No matches" when filter yields empty
4. Auto-focus search field on open

### Tests

- Widget: Search field visible
- Widget: Typing filters list
- Widget: Case-insensitive matching
- Widget: "No matches" shown when appropriate

### Acceptance Criteria

- [ ] Search field filters document list
- [ ] Filtering is instant
- [ ] Empty state when no matches
- [ ] All tests pass

---

## Slice 5: Selection Persistence

**Branch:** `feat/narrow-rag/05-persistence`

**Target:** ~150 lines

**Customer value:** Document selection persists across runs in same thread.

### Tasks

1. Create `ThreadDocumentSelectionNotifier` provider
2. Key selection state by thread ID
3. Restore selection when returning to thread
4. Clear when switching to different thread

### Tests

- Unit: Selection stored per thread
- Widget: Selection persists after submit
- Widget: Switching threads restores correct selection
- Widget: New thread has empty selection

### Acceptance Criteria

- [ ] Selection persists across runs
- [ ] Different threads have independent selections
- [ ] All tests pass

---

## Slice 6: Loading Indicator

**Branch:** `feat/narrow-rag/06-loading`

**Target:** ~60 lines

**Customer value:** User sees feedback while documents are loading.

### Tasks

1. Show `CircularProgressIndicator` in picker while loading
2. Disable interaction during load

### Tests

- Widget: Spinner shown while loading
- Widget: List appears after load completes

### Acceptance Criteria

- [ ] Loading indicator displayed
- [ ] Smooth transition to list
- [ ] All tests pass

---

## Slice 7: Empty Room Handling

**Branch:** `feat/narrow-rag/07-empty-room`

**Target:** ~40 lines

**Customer value:** Picker button disabled when room has no documents.

### Tasks

1. Check document count from provider
2. Disable/grey out 📎 button when count is 0
3. Update tooltip to explain why disabled

### Tests

- Widget: Button disabled when no documents
- Widget: Button enabled when documents exist
- Widget: Tooltip explains disabled state

### Acceptance Criteria

- [ ] Button disabled for empty rooms
- [ ] Clear indication of why
- [ ] All tests pass

---

## Slice 8: Error Handling + Retry

**Branch:** `feat/narrow-rag/08-error-retry`

**Target:** ~180 lines

**Customer value:** Graceful error handling with retry capability.

### Tasks

1. Add retry logic to `documentsProvider` (3 attempts, 1s/2s/4s backoff)
2. Retry on 5xx, 408, 429, NetworkException
3. Show error message in picker on failure
4. Add "Retry" button that refreshes provider

### Tests

- Unit: Provider retries on 503
- Unit: Provider gives up after 3 attempts
- Unit: No retry on 404
- Widget: Error message displayed
- Widget: Retry button triggers refresh

### Acceptance Criteria

- [ ] Transient errors retried automatically
- [ ] Error state shown after retries exhausted
- [ ] Retry button works
- [ ] All tests pass

---

## Slice 9: Keyboard Navigation

**Branch:** `feat/narrow-rag/09-keyboard`

**Target:** ~120 lines

**Customer value:** Picker fully usable via keyboard (accessibility).

### Tasks

1. Arrow keys navigate list items
2. Space toggles checkbox (if multi-select)
3. Enter confirms selection and closes
4. Escape closes without changes
5. Manage focus correctly

### Tests

- Widget: Arrow keys move focus
- Widget: Space toggles selection
- Widget: Enter closes picker
- Widget: Escape cancels

### Acceptance Criteria

- [ ] Full keyboard navigation
- [ ] Focus management correct
- [ ] All tests pass

---

## Slice 10: File Type Icons

**Branch:** `feat/narrow-rag/10-file-icons`

**Target:** ~80 lines

**Customer value:** Visual cues help users identify document types at a glance.

### Tasks

1. Create `getFileTypeIcon(String path)` helper that maps extensions to icons
2. Support common types: PDF, Word (.doc/.docx), Excel, PowerPoint, images, text
3. Use generic file icon for unknown/missing extensions
4. Apply icons in picker list items
5. Apply icons in selected document chips

### Icon Mapping

| Extension | Icon |
|-----------|------|
| `.pdf` | `Icons.picture_as_pdf` |
| `.doc`, `.docx` | `Icons.description` (or custom Word icon) |
| `.xls`, `.xlsx` | `Icons.table_chart` |
| `.ppt`, `.pptx` | `Icons.slideshow` |
| `.png`, `.jpg`, `.jpeg`, `.gif` | `Icons.image` |
| `.txt`, `.md` | `Icons.article` |
| (unknown) | `Icons.insert_drive_file` |

### Tests

- Unit: Extension mapping returns correct icons
- Unit: Case-insensitive extension matching
- Unit: Unknown extension returns generic icon
- Widget: Picker shows correct icons for each document type
- Widget: Chips show correct icons

### Acceptance Criteria

- [ ] PDF files show PDF icon
- [ ] Office documents show appropriate icons
- [ ] Unknown extensions show generic file icon
- [ ] Icons appear in both picker and chips
- [ ] All tests pass

---

## Branch Naming Convention

| Slice | Branch |
|-------|--------|
| 1 | `feat/narrow-rag/01-skeleton` |
| 2 | `feat/narrow-rag/02-chips` |
| 3 | `feat/narrow-rag/03-multi-select` |
| 4 | `feat/narrow-rag/04-search` |
| 5 | `feat/narrow-rag/05-persistence` |
| 6 | `feat/narrow-rag/06-loading` |
| 7 | `feat/narrow-rag/07-empty-room` |
| 8 | `feat/narrow-rag/08-error-retry` |
| 9 | `feat/narrow-rag/09-keyboard` |
| 10 | `feat/narrow-rag/10-file-icons` |

## Parallel Development with Git Worktrees

After slice 1 merges, use worktrees for the parallel slices:

```bash
# Parallel slices (branch from slice 1)
git worktree add ../narrow-rag-chips feat/narrow-rag/02-chips
git worktree add ../narrow-rag-persist feat/narrow-rag/05-persistence
git worktree add ../narrow-rag-empty feat/narrow-rag/07-empty-room
```

The picker chain (slices 3→4→6→8→9) must be developed sequentially in the
main worktree to avoid conflicts.

## Definition of Done (per slice)

- [ ] All tasks completed
- [ ] All tests written and passing
- [ ] Code formatted (`dart format .`)
- [ ] No analyzer issues (`dart analyze`)
- [ ] PR reviewed and approved
- [ ] Merged to `main`
