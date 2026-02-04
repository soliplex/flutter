# 13 - Client: Domain Models

## Overview

Pure Dart domain layer defining core business logic, data structures, and state
representations. Emphasizes immutability, type safety via sealed classes, and
separation of frontend models from volatile backend schemas.

## Files

| File | Purpose |
|------|---------|
| `packages/soliplex_client/lib/src/domain/auth_provider_config.dart` | Identity provider config |
| `packages/soliplex_client/lib/src/domain/backend_version_info.dart` | Backend versioning |
| `packages/soliplex_client/lib/src/domain/chat_message.dart` | Polymorphic message types |
| `packages/soliplex_client/lib/src/domain/chunk_visualization.dart` | Document chunk images |
| `packages/soliplex_client/lib/src/domain/citation_formatting.dart` | Citation display logic |
| `packages/soliplex_client/lib/src/domain/conversation.dart` | Conversation aggregate root |
| `packages/soliplex_client/lib/src/domain/domain.dart` | Barrel export |
| `packages/soliplex_client/lib/src/domain/message_state.dart` | Citation associations |
| `packages/soliplex_client/lib/src/domain/quiz.dart` | Quiz system models |
| `packages/soliplex_client/lib/src/domain/rag_document.dart` | Searchable documents |
| `packages/soliplex_client/lib/src/domain/room.dart` | Workspace context |
| `packages/soliplex_client/lib/src/domain/run_info.dart` | LLM execution run |
| `packages/soliplex_client/lib/src/domain/source_reference.dart` | Citation references |
| `packages/soliplex_client/lib/src/domain/thread_history.dart` | Historical messages |
| `packages/soliplex_client/lib/src/domain/thread_info.dart` | Thread metadata |
| `packages/soliplex_client/lib/src/schema/agui_features/*.dart` | AG-UI serialization |

## Public API

### Chat & Conversation

**`Conversation`** - Aggregate root for live conversation state

- `empty({required String threadId})` - Factory for new conversations
- `withAppendedMessage`, `withToolCall`, `withStatus` - Immutable mutation

**`ConversationStatus`** (sealed) - `Idle`, `Running`, `Completed`, `Failed`, `Cancelled`

**`ChatMessage`** (sealed) - Polymorphic message types

- `TextMessage` - Standard content with streaming/thinking support
- `ErrorMessage` - System/processing errors
- `ToolCallMessage` - Assistant tool usage
- `GenUiMessage` - Client-side widget rendering
- `LoadingMessage` - Typing indicator

**`ChatUser`** (enum) - `user`, `assistant`, `system`

### RAG & Citations

- `SourceReference` - Frontend-owned citation (with formatting extension)
- `MessageState` - Associates user message with retrieved citations
- `RagDocument` - Searchable document for scope narrowing
- `ChunkVisualization` - Visual context images for chunks

### Quiz System

- `Quiz` - Quiz associated with room
- `QuizQuestion` - Single question
- `QuestionType` (sealed) - `MultipleChoice`, `FillBlank`, `FreeForm`
- `QuestionLimit` (sealed) - `AllQuestions`, `LimitedQuestions`
- `QuizAnswerResult` (sealed) - `CorrectAnswer`, `IncorrectAnswer`

### Configuration

- `AuthProviderConfig` - Identity provider configuration
- `BackendVersionInfo` - Backend versioning data
- `Room` - Workspace containing quizzes and suggestions

## Dependencies

### External Packages

- `meta` - `@immutable` annotations
- `collection` - `ListEquality`, `DeepCollectionEquality`

### Internal

- `src/schema/` - Generated JSON serialization classes

## Data Flow

```text
1. Ingestion: Raw JSON → Schema classes (src/schema/)
2. Mapping: Schema → Domain objects (Citation → SourceReference)
3. State Management:
   ├─ Conversation as Aggregate Root
   ├─ Initialize via Conversation.empty or ThreadHistory
   └─ Evolve via copyWith methods on events
4. UI Consumption: Widgets consume Conversation.messages and messageStates
```

## Architectural Patterns

### Sealed Classes (State Machines)

Extensively used for mutually exclusive states. Forces explicit handling of all cases.

### Immutable Value Objects

All domain classes use `@immutable` and implement value equality for predictable
state management.

### Rich Domain Model

Business logic encapsulated in domain objects (QuestionLimit logic, formatting
extensions) rather than UI or data layers.

### Extension Methods

Display logic separated from data structures via extensions (CitationFormatting,
SourceReferenceFormatting), keeping data classes pure.

## Cross-Component Dependencies

### Depends On

- **None**: Leaf component containing pure domain logic and schema definitions

### Used By

- **15 - API Endpoints**: Type definitions for API requests and responses
- **16 - Application**: Core business logic data structures

## Contribution Guidelines

### DO

- **Enforce Deep Immutability:** Always annotate classes with `@immutable`. Use `List.unmodifiable()` or `Map.unmodifiable()` in constructors for collection fields to prevent accidental mutation.
- **Use Sealed Hierarchies for State:** Specific finite states (e.g., `ConversationStatus`, `QuestionType`) must be implemented as `sealed` classes to enforce exhaustive pattern matching.
- **Implement Value Equality:** Override `operator ==` and `hashCode` for all domain objects. Use `package:collection`'s `ListEquality` for collection fields.
- **Encapsulate Mutation Logic:** Return new instances via methods like `withAppendedMessage` or `copyWith` rather than exposing setters. This creates a reliable Aggregate Root pattern.
- **Use Extension Methods for Display Logic:** Keep data classes pure (just data). Move formatting logic into extension methods to separate concerns.

### DON'T

- **No Flutter Dependencies:** Never import `package:flutter` in this component. `soliplex_client` is a Pure Dart package intended for use in CLI tools, servers, or web workers.
- **No Mutable Collections:** Do not expose `List<T>` fields that reference a mutable list passed into the constructor. Always copy and freeze collections on initialization.
- **No Logic in Constructors (Except Validation):** Avoid complex initialization logic in constructors. Use static `factory` methods for logic like generating timestamps or IDs.
- **No "Fat" Data Objects:** Don't mix backend serialization details with domain logic. Map volatile schema to stable Domain Objects instead.
- **No Partial State:** Avoid allowing invalid states via nullable fields if a sealed class hierarchy can represent the state more precisely.

### Extending This Component

- **Adding New Message Types:** Extend the `ChatMessage` sealed class. Update all `switch` statements in the UI due to the exhaustiveness check.
- **Domain vs. Schema:** When the backend API changes, update the schema classes in `src/schema/`, then update the mapping logic to convert to stable Domain Models.
- **New Aggregate Roots:** If creating a new complex entity, define it as an immutable class that manages its own consistency via methods that return updated copies.
