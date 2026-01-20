# ADR: Narrowed RAG Search Implementation

## Status

Proposed

## Context

Users need to narrow RAG searches to specific documents within a room. This
requires:

1. A UI mechanism to select documents inline within the prompt input.
2. Frontend logic to fetch and filter available documents.
3. Integration with the backend API to scope RAG queries.

See [SPEC.md](./SPEC.md) for requirements and use cases.

## Decision

### UI Component

Evaluated packages for mention/autocomplete functionality:

| Criteria     | flutter_mentions | super_editor | extended_text_field | mentionable_text_field |
| ------------ | ---------------- | ------------ | ------------------- | ---------------------- |
| Intrusion    | Medium           | High         | Low                 | Low                    |
| License      | MIT, Free        | MIT, Free    | MIT, Free           | MIT, Free              |
| Completeness | High             | Very High    | Medium              | Medium                 |
| Maintenance  | Active           | Very Active  | Moderate            | Stale                  |
| Pub likes    | ~300             | ~800         | ~400                | ~50                    |

**Decision:** `flutter_mentions`

- Right level of abstraction—built specifically for this use case.
- Handles the hard parts: cursor management, overlay positioning.
- Structured output via `markupBuilder`—encodes both ID and display in markup.
- Actively maintained with responsive maintainer.
- Reasonable intrusion—some setup, but not an architectural overhaul.

**Rendering:** Mentions are rendered as styled text (`TextSpan`), not inline
widgets (`WidgetSpan`). This means the cursor can be positioned within a mention,
which requires atomic deletion handling (see below).

**Keyboard Navigation:** The package does not provide built-in keyboard navigation
(arrow keys + enter to select). We will implement this ourselves using Flutter's
`Shortcuts` and `Actions` widgets to meet the functional requirement.

**Display/Markup Duality:** The `flutter_mentions` controller maintains two
parallel text representations:

| Property | Contains | Example |
|----------|----------|---------|
| `controller.text` | Display text (user-visible) | `Use #manual.pdf` |
| `controller.markupText` | Markup with encoded IDs | `Use #[manual.pdf](uuid-123)` |

When a user selects a document from the autocomplete:

1. The **display text** shows the document title with styling (e.g., `#manual.pdf`
   in a distinct color).
2. The **markup text** encodes both title and ID using the format defined by
   `markupBuilder`: `#[title](id)`.

This duality allows us to:

- Show human-readable titles to the user.
- Preserve document IDs for AG-UI state without parsing the display text.
- Use `controller.text` directly as the prompt sent to the LLM.

### Trigger Symbol

Use `#` as the trigger symbol for document mentions. We reserve `@` for a
hypothetical user-mention feature, since `@` is the established convention for
user mentions across most software.

### Document Fetching

- Endpoint: `GET /api/v1/rooms/{room_id}/documents` (existing)
- Caching strategy: TBD

### Error Handling

**Retry strategy:** When fetching documents fails with a retryable status
(5xx, 408, 429), retry up to 3 times with exponential backoff (1s, 2s, 4s).
Non-retryable errors (4xx except 408/429) fail immediately.

**Fallback behavior:** If all retries are exhausted, treat the response as an
empty document list. The autocomplete popup displays "Could not load documents."
and the user can continue typing without document selection.

**Rationale:** Document selection is an enhancement, not a blocking feature.
Users should always be able to submit prompts. A failed fetch degrades gracefully
to the existing behavior (RAG across all documents).

**Testing approach:**

1. **Unit tests for retry logic:**
   - Mock HTTP client to return 503, verify 3 retry attempts with correct delays.
   - Mock HTTP client to return 404, verify immediate failure (no retries).
   - Mock HTTP client to succeed on 2nd attempt, verify result returned.

2. **Widget tests for UI states:**
   - Provide mock that returns loading state, verify spinner displayed.
   - Provide mock that returns empty list, verify "No documents" message.
   - Provide mock that throws after retries, verify "Could not load" message.
   - Verify user can dismiss error state and continue typing.

3. **Integration test (optional):**
   - Use a test backend or WireMock to simulate transient failures.
   - Verify end-to-end retry behavior in a realistic scenario.

### State Management

**AG-UI State for Document Filtering:**

Selected documents are communicated to the backend via the AG-UI state. When
submitting a run, the frontend includes a `filter_documents` object in
`RunAgentInput.state`:

```json
{
  "filter_documents": {
    "document_ids": ["uuid-1", "uuid-2"]
  }
}
```

- `document_ids`: List of document UUIDs, or `null`/absent for no filtering.
- The backend `ask_with_rich_citations` tool reads this state and builds a
  LanceDB filter: `id IN ('uuid-1', 'uuid-2')`.

**FilterDocuments Model:**

- **Python**: Defined in `soliplex/src/soliplex/agui/features.py`
- **Dart**: Generated via JSON Schema + quicktype (see
  `soliplex/scripts/generate_dart_models.sh`)
- The Dart class lives in `lib/core/models/agui_features/filter_documents.dart`

**Frontend State:**

- Selected documents are tracked locally during prompt composition.
- On submit, the frontend:
  1. Builds the prompt text with document titles (for LLM context).
  2. Populates `RunAgentInput.state["filter_documents"]` with document IDs.

### Selection Tracking

We maintain a local `Set<DocumentRecord>` as the single source of truth for
selected documents, where each record contains:

```dart
class DocumentRecord {
  final String id;    // Document UUID (for AG-UI state)
  final String name;  // Document title (for display and filtering)
}
```

This set is used for:

1. **Autocomplete filtering**: Exclude already-selected documents from suggestions.
2. **AG-UI state population**: Extract IDs on submit.
3. **Prompt text**: Extract names for display.

**Tracking additions:** Use `flutter_mentions`' `onMentionAdd` callback, which
provides the full mention data map (including `id` and `display`) when a document
is selected.

**Tracking removals:** Derive from atomic deletion events (see below). When a
mention is atomically deleted, we remove the corresponding record from the set.

**Markup configuration:** Configure `markupBuilder` to produce the parseable
format described in "Display/Markup Duality" above:

```dart
markupBuilder: (trigger, mention, value) => '$trigger[$mention]($value)',
```

### Atomic Deletion

Since `flutter_mentions` renders mentions as styled text (`TextSpan`), the cursor
can be positioned within a mention. The package does not provide atomic deletion
(deleting the entire mention when backspace is pressed). We implement this
ourselves.

**Implementation approach:**

1. **Intercept backspace**: Wrap the input with a `Focus` widget using
   `onKeyEvent` to catch `LogicalKeyboardKey.backspace`.

2. **Detect cursor position**: Get `controller.selection.start` to find the
   cursor offset.

3. **Find mention boundaries**: Parse `markupText` to identify mention spans and
   their corresponding positions in the display text.

4. **Delete entire mention**: If the cursor is within or immediately after a
   mention span, delete the entire span and update the controller value.

```dart
Focus(
  onKeyEvent: (node, event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace) {
      final cursor = controller.selection.start;
      final mention = findMentionContaining(cursor);
      if (mention != null) {
        deleteMention(mention);
        selectedDocuments.remove(mention.record);
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  },
  child: FlutterMentions(...),
)
```

**Mobile keyboards:** On-screen keyboards may not fire key events for backspace.
As a fallback, we use `onMarkupChanged` to detect when a mention becomes partial
(unparseable) and delete it entirely.

### Prompt Format

**Decision:** Structured payload with separation of concerns.

- **Prompt text**: Contains document **titles** (human-readable, gives LLM
  context).
- **AG-UI state**: Contains document **IDs** (for RAG filtering).

Example prompt text:

```text
Which symbol indicates an issue with oil level? Use #mercedes_c330_manual.pdf
and #mercedes_c330_troubleshooting.pdf
```

Corresponding state:

```json
{
  "filter_documents": {
    "document_ids": ["uuid-manual", "uuid-troubleshooting"]
  }
}
```

This approach:

- Keeps the state schema minimal (just IDs).
- Gives the LLM readable document references in the prompt.
- Avoids parsing complexity on the backend.

## Consequences

### Positive

- Users get more relevant RAG results by scoping searches.
- Familiar UX pattern (GitHub Copilot, Slack mentions).

### Negative

- Adds complexity to prompt input handling.
- New dependency on `flutter_mentions`.
- Custom keyboard navigation and atomic deletion implementations required.

### Risks

- Custom implementations (keyboard navigation, atomic deletion) add maintenance
  burden and may have edge cases on specific platforms.
- Mobile keyboard backspace detection may be unreliable; fallback logic needed.
- Performance if room has many documents.

## Alternatives Considered

| Option                     | Why not chosen                                       |
| -------------------------- | ---------------------------------------------------- |
| `super_editor`             | High intrusion—architectural overhaul                |
| `extended_text_field`      | Medium completeness, moderate maintenance            |
| `mentionable_text_field`   | Stale maintenance, low pub likes                     |
| `mention_tag_text_field`   | Lower adoption (~29 likes), no overlay positioning,  |
|                            | no keyboard nav; would require same custom work      |
| Custom `TextField` + Overlay | Reinvents solved problems (cursor, overlay positioning) |

## Known Gaps

The following limitations are intentionally deferred for future work:

1. **Document ID Validation**: The backend does not validate that submitted
   `document_ids` exist in the room's RAG database. Invalid IDs are silently
   ignored (the RAG query returns no matches for those IDs). This is acceptable
   for MVP but may warrant validation in the future for better error messaging.

2. **State Confirmation**: The frontend has no explicit confirmation that the
   backend applied the document filter. The AG-UI protocol could be extended
   with a `state_applied` event if needed.

3. **Stale Document References**: If a document is deleted after the user
   selects it but before submitting, the reference becomes stale. No
   client-side validation is performed.

## References

- [flutter_mentions on pub.dev](https://pub.dev/packages/flutter_mentions)
- [flutter_mentions GitHub](https://github.com/fayeed/flutter_mentions)
- [mention_tag_text_field on pub.dev](https://pub.dev/packages/mention_tag_text_field)
- [super_editor on pub.dev](https://pub.dev/packages/super_editor)
- [Flutter Actions and Shortcuts](https://docs.flutter.dev/ui/interactivity/actions-and-shortcuts)
- [Material Design Input Chips](https://m3.material.io/components/chips/overview)
