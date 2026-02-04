# 16 - Client: Application Logic

## Overview

Core application logic implementing event processing, streaming state management,
citation extraction, and JSON patching. Uses Redux-style reducers for predictable
state transitions and history replay.

## Files

| File | Purpose |
|------|---------|
| `packages/soliplex_client/lib/src/application/agui_event_processor.dart` | Event reducer |
| `packages/soliplex_client/lib/src/application/application.dart` | Barrel export |
| `packages/soliplex_client/lib/src/application/citation_extractor.dart` | Schema firewall |
| `packages/soliplex_client/lib/src/application/json_patch.dart` | RFC 6902 impl |
| `packages/soliplex_client/lib/src/application/streaming_state.dart` | UI streaming state |

## Public API

### Event Processing

**`EventProcessingResult`** - Container for state transition result

- `conversation` - Persistent domain state
- `streamingState` - Ephemeral UI state

**`processEvent(Conversation, StreamingState, BaseEvent)`**

Pure reducer function: `(State, Event) → State`

### Streaming State (sealed)

- `AwaitingText` - Waiting for tokens (may receive Thinking)
- `TextStreaming` - Actively receiving text tokens

**`ActivityType`** (sealed) - Current backend mode

- `ProcessingActivity`, `ThinkingActivity`
- `ToolCallActivity`, `RespondingActivity`

### Citation Extraction

**`CitationExtractor.extractNew(...)`**

Schema firewall - only place importing generated code. Compares AG-UI state
snapshots, detects appended citations, converts to domain `SourceReference`.

### JSON Patch

**`applyJsonPatch(state, operations)`**

RFC 6902 implementation for `add`, `replace`, `remove` operations.

## Dependencies

### External Packages

- `ag_ui` - Event definitions
- `meta` - Annotations

### Internal

- `src/domain/*` - Conversation, ChatMessage, SourceReference
- `src/schema/*` - Generated code (exclusive to CitationExtractor)

## Event Processing Flow

```text
1. Event arrives (SSE live or history replay)
2. processEvent identifies event type:
   ├─ Text/Thinking → Accumulate in StreamingState
   ├─ State → Apply JSON patch to aguiState
   └─ Lifecycle → Update run status
3. On completion, create domain objects
4. CitationExtractor compares before/after aguiState for new citations
```

## Architectural Patterns

### Redux / State Reducer

Functional core: `(State, Event) -> State`. Easy testing, reliable replay.

### Sealed State Machines

`StreamingState` enforces exhaustive handling of UI states.

### Schema Firewall

`CitationExtractor` as Anti-Corruption Layer translating schema JSON to domain.

### JSON Patch (RFC 6902)

Standard protocol for minimal state deltas from backend.

## Cross-Component Dependencies

### Depends On

- **13 - Domain Models**: Domain entities and value objects (Conversation, ChatMessage, SourceReference)

### Used By

- **15 - API Endpoints**: Event processing and state reconstruction during history replay

## Contribution Guidelines

### DO

- **Pure Reducers:** `processEvent` must be a pure function `(State, Event) → State`. No API calls or side effects inside.
- **Exhaustive Switch:** Use Dart's `sealed` classes for States and Activities to force compile-time checks on exhaustive switch statements.
- **Immutable State:** Treat `StreamingState` and `Conversation` as immutable. Always return a new instance/copy on change.
- **Isolate Generated Code:** Only `CitationExtractor` is allowed to import generated schema code. Keep the rest of the application logic decoupled from schema changes.
- **Schema Firewall:** If the backend schema changes, update the `CitationExtractor` to translate to clean Domain objects immediately.

### DON'T

- **No Mutable Mutations:** Do not modify list elements in place. Use `toList()` + `add()` or similar patterns to create new collections.
- **Don't Import Flutter:** This is strictly business logic. Visuals belong in the UI package.
- **Avoid Non-Deterministic Logic:** Reducers should not rely on `DateTime.now()` or `Random()` unless passed in as arguments (for replayability).
- **Don't Ignore Unknown Events:** Log a warning for unknown event types but return current state unchanged (robustness principle).
- **No Direct Network Calls:** This component processes *results* of network calls, it does not *make* them.

### Extending This Component

- **New Event Type:** Add to `ag_ui` package first, then update the switch case in `agui_event_processor.dart`.
- **New State:** Define within `streaming_state.dart` as a subtype of the sealed class.
- **Logic Change:** Add a unit test verifying the `(State + Event) → NewState` transition before modifying the reducer.
