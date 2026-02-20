# Provider Architecture Analysis

## Context

This analysis was conducted to understand and address the phenomenon of
"providers fragmenting the domain" in the Soliplex Flutter frontend. The
codebase was developed with Claude Code generating large batches of code,
and the team identified that Riverpod providers had absorbed domain
responsibilities rather than serving as thin glue between domain logic
and UI.

## Inventory

### Provider Count: 62 total across 22 files

| Category | Count | Files |
|----------|-------|-------|
| Authentication & Session | 10 | `auth_provider.dart` |
| Configuration & Shell | 4 | `config_provider.dart`, `shell_config_provider.dart` |
| HTTP & API Infrastructure | 8 | `api_provider.dart` |
| HTTP Logging | 1 | `http_log_provider.dart` |
| Connectivity | 1 | `connectivity_provider.dart` |
| Backend Health & Version | 2 | `backend_health_provider.dart`, `backend_version_provider.dart` |
| Rooms & Threads | 8 | `rooms_provider.dart`, `threads_provider.dart` |
| Documents & Content | 3 | `documents_provider.dart`, `selected_documents_provider.dart` |
| Chat & Running | 4 | `active_run_provider.dart`, `active_run_notifier.dart` |
| History Caching | 1 | `thread_history_cache.dart` |
| Citations & References | 2 | `source_references_provider.dart`, `citations_expanded_provider.dart` |
| Quiz | 2 | `quiz_provider.dart` |
| Chunk Visualization | 1 | `chunk_visualization_provider.dart` |
| Logging & Telemetry | 11 | `logging_provider.dart`, `backend_logging_provider.dart` |
| Routing | 1 | `app_router.dart` |
| Rooms Screen UI | 3 | `rooms_screen.dart` |

### Domain Models (in soliplex_client - well-structured)

The `packages/soliplex_client/` layer is clean pure Dart:

- **Aggregate root**: `Conversation` (threadId, messages, toolCalls, status, aguiState, messageStates)
- **Entities**: `Room`, `ThreadInfo`, `RunInfo`, `Quiz`, `QuizQuestion`
- **Value objects**: `ChatMessage` (sealed), `SourceReference`, `MessageState`, `RagDocument`, `ChunkVisualization`
- **Sealed hierarchies**: `ConversationStatus`, `RunState`, `ChatMessage`, `QuestionType`, `QuestionLimit`, `QuizAnswerResult`
- **Application layer**: `StreamingState`, `ActivityType`, `AgUiEventProcessor`, `CitationExtractor`

### Frontend Models (in lib/core/models/)

- `ActiveRunState` (sealed: Idle, Running, Completed) - wraps `Conversation` + `StreamingState`
- `CompletionResult` (sealed: Success, Failed, Cancelled)
- `RunHandle` - encapsulated resources for a single run
- `AppConfig`, `SoliplexConfig`, `Features`, `LogoConfig`, `ThemeConfig`, `RouteConfig`

## Diagnosis

### The Core Problem: Cohesion Deficit

The domain is expressed through a **flat collection of unrelated provider files**
rather than through cohesive domain aggregates. Provider files have become
repositories for domain concepts - they contain sealed classes, state machines,
and business logic that should live in proper domain/application layer objects.

**Metaphor**: Riverpod should be glue, but the whole furniture kit was stuffed
into the tube of glue.

### Root Cause: Claude's Default Decomposition Strategy

When Claude writes Riverpod code without explicit grouping constraints, it
follows "one concern = one file":
1. Need to fetch documents? Create `documents_provider.dart`
2. Need to track selection? Create `selected_documents_provider.dart`
3. Need citations? Create `source_references_provider.dart`
4. Need expand/collapse? Create `citations_expanded_provider.dart`

Each file is internally well-structured, but relationships between files are
implicit - existing only in the dependency graph, not in code organization.

Claude optimizes for **local correctness** (each file is clean, tested,
documented) rather than **global cohesion** (files together tell a story).

### Symptoms

**1. Provider files are domain concept containers**

`threads_provider.dart` (346 lines) contains:
- Data fetching (`threadsProvider`)
- Selection state machine (`ThreadSelection` sealed class + 3 variants + notifier)
- Current-item derivation (`currentThreadIdProvider`, `currentThreadProvider`)
- Persistence logic (`lastViewedThreadProvider` + SharedPreferences helpers)
- Navigation helpers (`selectThread`, `selectAndPersistThread`)

`quiz_provider.dart` (625 lines) contains **four sealed class hierarchies**:
- `QuizInput` (MultipleChoiceInput, TextInput)
- `QuestionState` (AwaitingInput, Composing, Submitting, Answered)
- `QuizSession` (QuizNotStarted, QuizInProgress, QuizCompleted)
- `QuizSessionNotifier` with full state machine logic

**2. Cross-file scattering of cohesive concepts**

To understand "sending a message" requires reading 6 files:
- `active_run_notifier.dart` - startRun() lifecycle
- `active_run_provider.dart` - allMessagesProvider, canSendMessageProvider
- `threads_provider.dart` - currentThreadProvider, threadSelectionProvider
- `rooms_provider.dart` - currentRoomProvider, currentRoomIdProvider
- `thread_history_cache.dart` - cached messages
- `selected_documents_provider.dart` - document filtering state

To understand "a thread's full state" is scattered across:
- `threads_provider.dart` - ThreadInfo data, selection, last-viewed
- `thread_history_cache.dart` - messages + AG-UI state
- `active_run_provider.dart` - running state, streaming messages
- `selected_documents_provider.dart` - document selections
- `citations_expanded_provider.dart` - UI expand/collapse state
- `source_references_provider.dart` - citation data

**3. Convenience providers that could be `.select()`**

- `isStreamingProvider` = `activeRunNotifierProvider.isRunning` (2 usages)
- `currentThreadIdProvider` = extract from `threadSelectionProvider` (5+ usages)
- `hasAppAccessProvider` = check `authProvider` type

### What's NOT Wrong

- `soliplex_client` is clean: proper domain models, sealed classes, well-layered
- Family providers are used correctly: per-room, per-thread, per-quiz isolation
- No god providers: `activeRunNotifierProvider` is complex but single-responsibility
- Feature layer is restrained: only `rooms_screen.dart` defines local providers
- The individual provider code quality is high

## Strategy: Consolidate into Cohesive Application Layer

### Philosophy

Providers should be **thin glue** (interactors in Clean Architecture terms) that
wire Riverpod-free application layer classes into the UI. Domain logic, state
machines, and sealed class hierarchies should live in plain Dart classes that
providers merely expose.

### Approach

**Extract domain/application logic from providers into plain Dart classes,
then use providers only to expose these classes to the widget tree.**

Example transformation for threads:

```text
BEFORE (spread across providers):
  threads_provider.dart     → ThreadSelection sealed class + notifier + 5 providers
  thread_history_cache.dart → cache logic + notifier + provider

AFTER (rich domain + thin providers):
  lib/core/domain/thread_selection.dart   → ThreadSelection, LastViewed (rich domain types)
  lib/core/usecases/select_and_persist_thread.dart → SelectAndPersistThread (intent-named)
  lib/core/providers/threads_provider.dart → thin: 2-3 providers delegating to domain
```

Example transformation for quiz:

```text
BEFORE:
  quiz_provider.dart (625 lines) → 4 sealed hierarchies + state machine + 2 providers

AFTER:
  lib/core/domain/quiz_session.dart       → QuizInput, QuestionState, QuizSession (rich domain)
  lib/core/usecases/submit_quiz_answer.dart → SubmitQuizAnswer (orchestrates API + domain)
  lib/core/providers/quiz_provider.dart   → thin: 2 providers delegating to domain
```

### Guiding Principles

1. **Sealed classes and state machines are domain concepts**, not provider
   implementation details. They belong in `lib/core/models/` or
   `packages/soliplex_client/`.

2. **Provider files contain only DI and reactive rebuilds.** If a provider
   defines types, encodes business rules, or manages state transitions,
   extract that logic to `lib/core/domain/` or `lib/core/usecases/`.

3. **Prefer plain Dart classes over Notifiers** for business logic. Notifiers
   should delegate to service/domain classes.

4. **Related concepts should be in the same class or module**, not in separate
   provider files. Thread selection + thread history + thread persistence
   are one concern.

5. **Providers exist to solve two problems**: (a) dependency injection and
   (b) reactive rebuilds. Everything else is domain/application logic.

## Provider-Feature Consumption Matrix

| Feature | Screens | Providers Watched | Providers Read | Local Providers |
|---------|---------|-------------------|----------------|-----------------|
| auth | 1 | 2 | 2 | 0 |
| chat | 7 | 11 | 8 | 0 |
| history | 3 | 4 | 2 | 0 |
| home | 2 | 2 | 4 | 0 |
| inspector | 7 | 1 | 1 | 0 |
| log_viewer | 4 | 1 | 1 | 0 |
| login | 1 | 1 | 2 | 0 |
| quiz | 1 | 3 | 2 | 0 |
| room | 1 | 6 | 5 | 0 |
| rooms | 4 | 4 | 3 | 3 |
| settings | 3 | 6 | 1 | 0 |
| **TOTAL** | **34** | **41+** | **31+** | **3** |

## Prevention: Claude Configuration

### CLAUDE.md Provider Guidelines

```markdown
## Provider Architecture

Providers are thin glue. They wire application-layer classes into
the widget tree for dependency injection and reactive rebuilds. Nothing more.

Rules:
- DO NOT put sealed classes, state machines, or business logic in provider files
- DO NOT create a new provider file without checking if the concept fits in
  an existing application-layer class
- DO NOT create convenience providers that just wrap .select() - use
  ref.watch(provider.select(...)) at the call site
- Provider files should be < 100 lines. Extract domain logic to models/services.
- When adding a feature that needs state, create or extend a plain Dart class
  first, then expose it via a provider
- Notifiers should delegate to service/domain classes, not contain business logic
```

### Detection Hooks / CI Checks

Potential automated checks:
- Warn if a provider file exceeds 150 lines
- Warn if `sealed class` appears in a file under `providers/`
- Warn if a new provider file is created (prompt: should this be a method on
  an existing service?)
- Track provider count over time to detect sprawl

### flutter_rules.md Additions

Add to the State Management section:
- Separate application logic from Riverpod wiring
- Provider files contain only provider declarations and thin Notifiers
- Domain types belong in `lib/core/models/` or `soliplex_client`
- Test domain logic via plain Dart unit tests, not provider tests
