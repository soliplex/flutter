# 15 - Client: API Endpoints

## Overview

Primary facade for Soliplex backend communication. Handles authentication, URL
building, response parsing, and history reconstruction through event sourcing.
Implements LRU caching for completed run events.

## Files

| File | Purpose |
|------|---------|
| `packages/soliplex_client/lib/src/api/agui_message_mapper.dart` | Domain→AG-UI conversion |
| `packages/soliplex_client/lib/src/api/api.dart` | Barrel export |
| `packages/soliplex_client/lib/src/api/fetch_auth_providers.dart` | Pre-auth provider fetch |
| `packages/soliplex_client/lib/src/api/mappers.dart` | JSON parsing functions |
| `packages/soliplex_client/lib/src/api/soliplex_api.dart` | Main API facade |

## Public API

### SoliplexApi (Main Facade)

**Room & Thread Management:**

- `getRooms()`, `getRoom(roomId)` - Room fetching
- `getDocuments(roomId)` - RAG documents
- `getThreads(roomId)`, `getThread(roomId, threadId)` - Thread listing
- `createThread(roomId)`, `deleteThread(...)` - Thread lifecycle

**Run & History:**

- `createRun(roomId, threadId)` - Start LLM inference
- `getRun(...)` - Run status/metadata
- `getThreadHistory(roomId, threadId)` - Full conversation reconstruction

**Quiz & Visualization:**

- `getQuiz(...)`, `submitQuizAnswer(...)` - Quiz interactions
- `getChunkVisualization(...)` - RAG debug images
- `getBackendVersionInfo()` - Version compatibility

### Supporting Functions

**`convertToAgui(List<ChatMessage>)`** - Converts domain messages to AG-UI protocol

**`fetchAuthProviders(...)`** - Pre-auth identity provider fetch

**Mappers** - JSON parsing with graceful degradation:

- `backendVersionInfoFromJson`, `roomFromJson`, `ragDocumentFromJson`
- `threadInfoFromJson`, `runInfoFromJson`, `quizFromJson`

## Dependencies

### External Packages

- `ag_ui` - Protocol message definitions
- `meta` - Annotations

### Internal

- `src/domain/*` - Domain entities
- `src/http/http_transport.dart` - Network abstraction
- `src/application/*` - Event processing, citation extraction

## History Reconstruction Flow

```text
getThreadHistory:
1. Fetch list of runs for thread
2. Filter completed runs, sort chronologically
3. Fetch events for each run (parallel)
   ├─ LRU Cache hit → return cached
   └─ Cache miss → fetch, synthesize user message events, cache
4. Replay events through processEvent
5. Return reconstructed Conversation + AG-UI state
```

## Architectural Patterns

### Facade Pattern

`SoliplexApi` hides complexity of endpoints and parsing behind clean interface.

### Event Sourcing (Client-Side)

Client fetches events and reconstructs state, ensuring identical representation
to server's execution path.

### LRU Caching

Manual cache for completed run events (immutable data).

### Graceful Degradation

Mappers log warnings and fallback on unknown types rather than crashing.

## Cross-Component Dependencies

### Depends On

- **13 - Domain Models**: Data models for request/response bodies
- **14 - HTTP Layer**: Network transport execution
- **16 - Application**: Event processing and citation extraction logic
- **17 - Utilities**: Error handling and URL building utilities

### Used By

- **None (Direct)**: Accessed via `soliplex_client` barrel export rather than direct imports

## Contribution Guidelines

### DO

- **Use Mappers:** Keep JSON parsing logic in `mappers.dart`. The facade methods should only coordinate the call and the mapping.
- **Graceful Degradation:** When mapping JSON, handle unknown enum values or missing optional fields without throwing, to support backend forward-compatibility.
- **Update Facade Interface:** Expose new endpoints via `SoliplexApi` abstract class before implementing them.
- **Pure Dart Only:** Ensure no Flutter dependencies. This logic runs in background isolates or CLI tools.
- **Use UrlBuilder:** Construct paths using `UrlBuilder` to ensure consistent base URL handling and query parameter encoding.

### DON'T

- **No Business Logic in Mappers:** Mappers should strictly convert JSON → Domain Entity. Do not calculate derived state here.
- **Don't Return Raw JSON:** Always return typed Domain objects or `void`.
- **Avoid Race Conditions:** When caching or updating state (like in `getThreadHistory`), ensure atomic operations or proper synchronization.
- **Don't Leak Implementation:** The consumer should not know if data came from REST, GraphQL, or a cache.
- **No Hardcoded Strings:** Use constants or the `UrlBuilder` for all API paths.

### Extending This Component

- **New Endpoint:** Add the method signature to `SoliplexApi`, implement in the concrete class, and add a test case using a mock transport.
- **New Data Model:** Add the entity to `domain/`, create a mapper in `mappers.dart`, and hook it up in the API method.
- **Documentation:** Add the new method to the "Public API" section of this document.
