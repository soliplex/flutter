# Implementation Plan: Narrowed RAG Search

## Overview

This plan breaks the feature into 7 vertical slices, each delivering customer
value. Slices are organized web-first, then mobile, enabling parallel
development by platform specialists.

## Slice Summary

| # | Slice | Platform | Customer Value |
|---|-------|----------|----------------|
| 1 | Type `#` to see documents in this room | Web | Browse and pick documents with mouse |
| 2 | Selected documents focus the AI's search | Web | AI answers draw only from chosen documents |
| 3 | Navigate document list with arrow keys | Web | Keyboard users can pick documents without mouse |
| 4 | Backspace removes entire document reference | Desktop | Clean editing—no partial document names left behind |
| 5 | Document removal works on mobile | Mobile | Mobile users can undo a document selection |
| 6 | Already-selected documents hidden from list | All | No clutter, no accidental duplicate selections |
| 7 | Clear feedback when documents can't load | All | User knows why list is empty or unavailable |

## Dependency Graph

```text
[1] Type # to see documents
         │
         ▼
[2] Selected documents focus AI search ──┬──► [3] Arrow key navigation
                                         │
                                         ├──► [4] Backspace removes document (Desktop)
                                         │
                                         └──► [5] Document removal on mobile
                                                       │
                           ┌─────────────────────────┬─┘
                           ▼                         ▼
         [6] Hide already-selected          [7] Loading/empty/error feedback
```

**Parallelization opportunities:**

- After slice 2: slices 3, 4, and 5 can run in parallel
- After slices 4 and 5: slices 6 and 7 can run in parallel

---

## Slice 1: Type `#` to see documents in this room

**Branch:** `feat/narrow-rag/1-hashtag-shows-documents`

**Customer value:** User types `#` and sees a list of documents available in the
current room. They can browse and select with mouse/touch.

### Tasks

1. **Add Dart models for documents**
   - Create `RoomDocuments` and `RAGDocument` in
     `packages/soliplex_client/lib/src/models/`
   - Fields: `id`, `uri`, `title`, `metadata`, `createdAt`, `updatedAt`

2. **Add `getDocuments()` to SoliplexApi**
   - Location: `packages/soliplex_client/lib/src/api/soliplex_api.dart`
   - Endpoint: `GET /api/v1/rooms/{room_id}/documents`

3. **Create documents provider with retry logic**
   - Location: `lib/core/providers/documents_provider.dart`
   - Retry: 3 attempts, exponential backoff (1s, 2s, 4s) on 5xx/408/429
   - Fallback: return empty list after exhausted retries

4. **Add `flutter_mentions` dependency**

5. **Create `MentionablePromptInput` widget**
   - Location: `lib/features/chat/widgets/mentionable_prompt_input.dart`
   - Configure trigger `#`, wire documents to autocomplete suggestions
   - Configure `markupBuilder` for `#[title](id)` format

6. **Replace `ChatInput` in `ChatPanel`**
   - Swap to `MentionablePromptInput`
   - Preserve existing submit behavior using `controller.text`

### Tests

- Unit: `getDocuments()` parses backend response correctly
- Unit: Provider retries on 503, returns data on success
- Unit: Provider returns empty list after 3 failed retries
- Widget: Typing `#` opens autocomplete popup
- Widget: Popup displays document titles from provider
- Widget: Clicking a document inserts styled text

### Acceptance Criteria

- [ ] Typing `#` shows autocomplete with room's documents
- [ ] Selecting a document inserts it as styled text
- [ ] Mouse/touch selection works
- [ ] Existing prompt submission still works
- [ ] All tests pass

---

## Slice 2: Selected documents focus the AI's search

**Branch:** `feat/narrow-rag/2-selection-filters-rag`

**Customer value:** When user selects documents and submits, the AI only
searches within those documents—not the entire room.

### Tasks

1. **Generate `FilterDocuments` Dart model**
   - Run: `soliplex/scripts/generate_dart_models.sh lib/core/models/agui_features`
   - Verify `filter_documents.dart` is created

2. **Track selected documents in `MentionablePromptInput`**
   - Maintain `Set<DocumentRecord>` with `{id, title}`
   - Populate via `onMentionAdd` callback
   - Expose selection via callback to parent

3. **Wire selection to submission in `ChatPanel`**
   - On submit, build `FilterDocuments(documentIds: [...])`
   - Include in `initialState` passed to `activeRunNotifier.startRun()`

4. **Verify `ActiveRunNotifier` passes state to backend**
   - Ensure `initialState` flows through to `SimpleRunAgentInput.state`

### Tests

- Unit: `onMentionAdd` adds document to selection set
- Unit: `FilterDocuments.toJson()` produces correct structure
- Integration: Submit with 2 documents includes both IDs in state
- Integration: Submit with no documents omits `filter_documents` key

### Acceptance Criteria

- [ ] Selected documents tracked during composition
- [ ] Submission includes `filter_documents.document_ids` in AG-UI state
- [ ] Backend receives and applies document filter
- [ ] All tests pass

---

## Slice 3: Navigate document list with arrow keys

**Branch:** `feat/narrow-rag/3-keyboard-navigation`

**Customer value:** Keyboard users can navigate the autocomplete list with arrow
keys and select with Enter, without reaching for the mouse.

### Tasks

1. **Implement keyboard navigation in autocomplete**
   - Arrow Up/Down: move highlight through suggestions
   - Enter: select highlighted suggestion
   - Escape: dismiss popup without selecting
   - Use Flutter `Shortcuts` and `Actions` widgets

2. **Ensure focus management**
   - Input retains focus after selection
   - Popup dismisses after selection

### Tests

- Widget: Arrow Down moves highlight to next suggestion
- Widget: Arrow Up moves highlight to previous suggestion
- Widget: Enter selects highlighted suggestion
- Widget: Escape dismisses popup
- Widget: Focus remains on input after selection

### Acceptance Criteria

- [ ] Arrow keys navigate suggestions
- [ ] Enter selects highlighted document
- [ ] Escape dismisses autocomplete
- [ ] Focus stays on input throughout
- [ ] All tests pass

---

## Slice 4: Backspace removes entire document reference

**Branch:** `feat/narrow-rag/4-atomic-deletion-desktop`

**Customer value:** When user backspaces into a document reference, the entire
reference is removed—no confusing partial text left behind.

### Tasks

1. **Intercept backspace key events**
   - Wrap input with `Focus` widget
   - Handle `LogicalKeyboardKey.backspace` in `onKeyEvent`

2. **Detect cursor position relative to mentions**
   - Parse `controller.markupText` to find mention boundaries
   - Map markup positions to display text positions

3. **Delete entire mention atomically**
   - If cursor is within or immediately after mention, delete entire span
   - Update controller value
   - Remove document from selection set

### Tests

- Widget: Backspace at end of mention deletes entire mention
- Widget: Backspace inside mention deletes entire mention
- Widget: Selection set updates when mention deleted
- Widget: Regular backspace (not in mention) works normally

### Acceptance Criteria

- [ ] Backspacing over a mention removes it entirely
- [ ] Selection tracking stays in sync
- [ ] Normal text deletion unaffected
- [ ] All tests pass

---

## Slice 5: Document removal works on mobile

**Branch:** `feat/narrow-rag/5-atomic-deletion-mobile`

**Customer value:** Mobile users can remove a document reference, even though
mobile keyboards don't fire backspace key events.

### Tasks

1. **Implement `onMarkupChanged` fallback**
   - Detect when a mention becomes partial/unparseable
   - Delete the entire mention when detected
   - Update selection set

2. **Test on iOS and Android**
   - Verify fallback triggers on both platforms
   - Ensure no double-deletion with desktop logic

### Tests

- Widget: Partial mention detected and deleted
- Widget: Selection set updates on mobile deletion
- Widget: No conflict with desktop backspace handling

### Acceptance Criteria

- [ ] Deleting part of a mention removes it entirely on mobile
- [ ] Selection tracking stays in sync
- [ ] Works on iOS and Android
- [ ] All tests pass

---

## Slice 6: Already-selected documents hidden from list

**Branch:** `feat/narrow-rag/6-exclude-selected`

**Customer value:** Once a document is selected, it disappears from the
autocomplete list—no clutter, no accidental duplicates.

### Tasks

1. **Filter autocomplete suggestions**
   - Exclude documents whose IDs are in the selection set
   - Update filter dynamically as selection changes

2. **Handle edge case: all documents selected**
   - Show appropriate message or empty state

### Tests

- Widget: Selected document not shown in autocomplete
- Widget: Deselected document reappears in autocomplete
- Widget: Selecting all documents shows empty/message state

### Acceptance Criteria

- [ ] Selected documents excluded from suggestions
- [ ] Removing a document adds it back to suggestions
- [ ] All tests pass

---

## Slice 7: Clear feedback when documents can't load

**Branch:** `feat/narrow-rag/7-loading-empty-error-states`

**Customer value:** User always knows what's happening—loading spinner while
fetching, clear message if room has no documents, clear message if fetch failed.

### Tasks

1. **Loading state**
   - Show spinner/skeleton while `documentsProvider` is loading
   - User can continue typing; popup updates when data arrives

2. **Empty state**
   - Show "No documents in this room." when room has no documents
   - User can dismiss and continue typing

3. **Error state**
   - Show "Could not load documents." after retries exhausted
   - User can dismiss and continue typing
   - No blocking modals

### Tests

- Widget: Loading state shows spinner
- Widget: Empty room shows "No documents" message
- Widget: Failed fetch shows "Could not load" message
- Widget: All states dismissable, typing continues

### Acceptance Criteria

- [ ] Loading indicator shown while fetching
- [ ] Empty room displays appropriate message
- [ ] Fetch failure displays error message
- [ ] User can always dismiss and continue typing
- [ ] All tests pass

---

## Branch Naming Convention

| Slice | Branch |
|-------|--------|
| 1 | `feat/narrow-rag/1-hashtag-shows-documents` |
| 2 | `feat/narrow-rag/2-selection-filters-rag` |
| 3 | `feat/narrow-rag/3-keyboard-navigation` |
| 4 | `feat/narrow-rag/4-atomic-deletion-desktop` |
| 5 | `feat/narrow-rag/5-atomic-deletion-mobile` |
| 6 | `feat/narrow-rag/6-exclude-selected` |
| 7 | `feat/narrow-rag/7-loading-empty-error-states` |

## Stacked PR Strategy

1. Create slice 1 branch from `main`
2. Open PR for slice 1 → `main`
3. Create slice 2 branch from slice 1 branch
4. Open PR for slice 2 → `main` (after slice 1 merges) or → slice 1 branch
5. Continue pattern; rebase onto `main` as base branches merge

## Definition of Done (per slice)

- [ ] All tasks completed
- [ ] All tests written (TDD) and passing
- [ ] Code formatted (`mcp__dart__dart_format`)
- [ ] No analyzer issues (`mcp__dart__analyze_files`)
- [ ] PR reviewed and approved
- [ ] Merged to `main`
