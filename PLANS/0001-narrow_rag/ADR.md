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

**Recommendation:** `flutter_mentions`

- Right level of abstraction—built specifically for this use case.
- Handles the hard parts: cursor management, deletion, overlay positioning.
- Structured output—returns mentions as parsed objects, ready for API.
- Actively maintained with responsive maintainer.
- Reasonable intrusion—some setup, but not an architectural overhaul.

*Decision:* TBD (pending team review)

### Trigger Symbol

Use `#` as the trigger symbol for document mentions. We reserve `@` for a
hypothetical user-mention feature, since `@` is the established convention for
user mentions across most software.

### Document Fetching

- Endpoint: `GET /api/v1/rooms/{room_id}/documents` (existing)
- Caching strategy: TBD

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
- Selection does not persist across runs (user selects fresh each time).

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
- New dependency on `flutter_mentions` (if chosen).

### Risks

- `flutter_mentions` may not meet all requirements (keyboard nav,
  cross-platform support)—needs prototyping.
- Performance if room has many documents.

## Alternatives Considered

| Option                    | Why not chosen                                      |
| ------------------------- | --------------------------------------------------- |
| `super_editor`            | High intrusion—architectural overhaul               |
| `extended_text_field`     | Medium completeness, moderate maintenance           |
| `mentionable_text_field`  | Stale maintenance, low pub likes                    |
| Custom `TextField` + Overlay | Reinvents solved problems (cursor, deletion, positioning) |

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
- [super_editor on pub.dev](https://pub.dev/packages/super_editor)
- [Material Design Input Chips](https://m3.material.io/components/chips/overview)
