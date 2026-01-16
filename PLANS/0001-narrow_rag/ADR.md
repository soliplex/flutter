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

Use `@` as the trigger symbol for document mentions (consistent with GitHub
Copilot and other tools).

### Document Fetching

- Endpoint: `GET /api/v1/rooms/{room_id}/documents` (existing)
- Caching strategy: TBD

### State Management

<!-- How to track selected documents? -->

TBD

### Prompt Format (Backend)

How should document references appear in the raw prompt sent to the backend?

| Format             | Example                              | Pros                                            | Cons                        |
| ------------------ | ------------------------------------ | ----------------------------------------------- | --------------------------- |
| Markdown-style     | `@[manual.pdf](uuid-123)`            | Human-readable, familiar                        | Parsing complexity          |
| Slack-style        | `<@uuid-123\|manual.pdf>`            | Established pattern                             | Ugly in raw form            |
| Structured payload | Text + separate `file_ids[]`         | Clean API contract, backend doesn't parse text  | Requires sync between text and metadata |
| Placeholder tokens | `What is X? {{DOC:uuid-123}}`        | Simple regex parsing                            | Not human-readable          |

*Decision:* TBD (needs team input)

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

## References

- [flutter_mentions on pub.dev](https://pub.dev/packages/flutter_mentions)
- [super_editor on pub.dev](https://pub.dev/packages/super_editor)
- [Material Design Input Chips](https://m3.material.io/components/chips/overview)
