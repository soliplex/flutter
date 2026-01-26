# ADR: Narrowed RAG Search Implementation

## Status

Proposed

## Context

Users need to narrow RAG searches to specific documents within a room. This
requires:

1. A UI mechanism to select documents from a picker.
2. Display of selected documents as chips above the text input.
3. Frontend logic to fetch and cache available documents.
4. Integration with the backend API to scope RAG queries via AG-UI state.
5. Persistence of document selection across runs within a thread.

See [SPEC.md](./SPEC.md) for requirements and use cases.

## Decision

### UI Approach: Chips Above Input

We use a **chips-above-input** pattern rather than inline mentions:

```text
┌─────────────────────────────────────────────────────────────┐
│ [manual.pdf ×] [troubleshooting.pdf ×]                      │  ← Chip row
├─────────────────────────────────────────────────────────────┤
│ 📎 Type your message...                              [Send] │  ← Input row
└─────────────────────────────────────────────────────────────┘
```

**Rationale:**

- Flutter's `TextField` cannot embed widgets (chips) inline with editable text.
- Mention packages like `flutter_mentions` are abandoned (4+ years without
  updates) and have critical bugs (broken hit testing, no keyboard navigation).
- Chips above input is a well-established pattern (Gmail compose, Slack).
- Cleaner separation: text editing is standard; document selection is separate.

### UI Components

**Document Picker Button (📎):**

- Positioned at the start of the input row.
- Opens a popup/dialog with the document picker.
- Tooltip: "Select documents"

**Document Picker Popup:**

- Modal popup positioned above or below the input.
- Contains a search field for filtering.
- Multi-select list with checkboxes showing all room documents.
- Each item shows a file type icon based on extension (PDF icon for `.pdf`,
  Word icon for `.docx`, etc.); unknown/missing extensions use a generic icon.
- Document paths shortened to filename + up to 2 parent folders.
- Selected documents are pre-checked when reopening.
- Scrollable when list exceeds max height.
- Keyboard navigable: Tab to search, arrows to navigate, Space to toggle,
  Escape to close.
- Closes on click outside or Escape.

**Implementation:** Use Flutter's `RawAutocomplete` or a simple
`PopupMenuButton`/`Dialog` with `ListView` and `CheckboxListTile`. No external
packages required. Use a helper function to map file extensions to icon widgets.

**Document Chips:**

- Displayed in a `Wrap` widget above the text input.
- Each chip shows file type icon + shortened document path + × button.
- Use Material `InputChip` or `RawChip` with `onDeleted` callback.
- Chip row hidden when no documents selected.

### Document Fetching

**Endpoint:** `GET /api/v1/rooms/{room_id}/documents`

**Caching:** Use a Riverpod `FutureProvider.family` keyed by room ID. Documents
are cached per room and can be refreshed on demand.

**Error Handling:**

- Retry up to 3 times on retryable errors (5xx, 408, 429) with exponential
  backoff (1s, 2s, 4s).
- Non-retryable errors (4xx except 408/429) fail immediately.
- On exhausted retries, show "Could not load documents. Tap to retry." in the
  picker.
- Document selection is optional—users can always submit without it.

### State Management

**Local Selection State:**

Selected documents are stored in a `Set<RAGDocument>` managed by the input
widget's state. This set:

- Populates the chip row.
- Filters the picker (already-selected documents are checked, not hidden).
- Provides document IDs for AG-UI state on submit.

**Persistence Across Runs:**

Document selection persists within a thread until the user explicitly removes
documents. The selection is stored per-thread, either:

- In widget state (if thread context is preserved), or
- In a Riverpod provider keyed by thread ID.

Switching threads clears/restores the selection for that thread.

**AG-UI State for Document Filtering:**

Selected documents are communicated to the backend via AG-UI state. On submit,
the frontend includes a `filter_documents` object in `RunAgentInput.state`:

```json
{
  "filter_documents": {
    "document_ids": ["uuid-1", "uuid-2"]
  }
}
```

- `document_ids`: List of document UUIDs, or `null`/absent if no filtering.
- The backend `ask_with_rich_citations` tool reads this and applies a LanceDB
  filter.

**FilterDocuments Model:**

- **Python**: Defined in `soliplex/src/soliplex/agui/features.py`
- **Dart**: Generated via JSON Schema + quicktype

### Prompt Format

The prompt text sent to the LLM is **plain text** without any document markup.
Document filtering is handled entirely via AG-UI state, not by parsing the
prompt.

Example:

- **Prompt text:** `Which symbol indicates an issue with oil level?`
- **AG-UI state:** `{"filter_documents": {"document_ids": ["uuid-1", "uuid-2"]}}`

The LLM sees the question; the backend filters RAG to the specified documents.

## Consequences

### Positive

- Uses standard Flutter widgets—no abandoned third-party packages.
- Clear separation between text input and document selection.
- Multi-select picker is more efficient than one-at-a-time inline mentions.
- Selection persistence reduces repetitive selection across runs.
- Simpler implementation—no cursor management, overlay positioning hacks, or
  atomic deletion logic.

### Negative

- Document references are not visible in the prompt text itself. Users see chips
  but the LLM doesn't see document names in the prompt.
- Requires managing selection state persistence per thread.

### Risks

- Performance if room has many documents (hundreds). May need virtualized list
  or pagination in picker.
- Thread-keyed state adds complexity if thread switching is frequent.

## Alternatives Considered

### Inline Mentions with flutter_mentions

**Evaluated and rejected.** The `flutter_mentions` package:

- Has not been updated in 4+ years.
- Has broken hit testing (taps on suggestions don't register).
- Lacks keyboard navigation for the suggestion popup.
- Uses `flutter_portal` which adds complexity.
- Would require custom implementations for atomic deletion and keyboard nav.

### Inline Mentions with Custom Implementation

Building inline mentions from scratch using `TextField` + `Overlay` would
require solving:

- Cursor positioning within styled mention spans.
- Atomic deletion when backspacing into a mention.
- Overlay positioning relative to cursor.
- Mobile keyboard compatibility.

This is significant complexity for limited UX benefit over the chips approach.

### Other Mention Packages

| Package                  | Status                                     |
| ------------------------ | ------------------------------------------ |
| `super_editor`           | Active, but high intrusion (rich text)     |
| `extended_text_field`    | Moderate maintenance, medium completeness  |
| `mentionable_text_field` | Stale, low adoption                        |

None offer a maintained, low-intrusion inline mention solution.

## Known Gaps

1. **Document ID Validation**: The backend does not validate that submitted
   `document_ids` exist. Invalid IDs are silently ignored.

2. **Stale Document References**: If a document is deleted after selection but
   before submit, the reference becomes stale. No client-side validation.

3. **Large Document Lists**: No pagination or virtualization in the initial
   implementation. May need optimization for rooms with 100+ documents.

## References

- [Material Design Input Chips](https://m3.material.io/components/chips/overview)
- [Flutter RawAutocomplete](https://api.flutter.dev/flutter/widgets/RawAutocomplete-class.html)
- [Riverpod FutureProvider.family](https://riverpod.dev/docs/providers/future_provider)
