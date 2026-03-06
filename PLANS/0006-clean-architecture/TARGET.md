# Target Architecture

## Guiding Principle: The Dependency Rule

> Source code dependencies can only point inwards.
> -- Robert C. Martin, "The Clean Architecture"

Nothing in an inner circle may reference anything in an outer circle.
The inner layers define the rules; the outer layers conform to them.

```text
┌─────────────────────────────────────────────────────┐
│  Frameworks & Drivers                               │
│  Flutter, Riverpod, GoRouter, HTTP client           │
│                                                     │
│  ┌─────────────────────────────────────────────┐    │
│  │  Interface Adapters                         │    │
│  │  Providers (thin glue), Repositories        │    │
│  │                                             │    │
│  │  ┌─────────────────────────────────────┐    │    │
│  │  │  Application Layer (Use Cases)      │    │    │
│  │  │  Orchestrate domain + I/O           │    │    │
│  │  │                                     │    │    │
│  │  │  ┌─────────────────────────────┐    │    │    │
│  │  │  │  Domain (Entities)          │    │    │    │
│  │  │  │  Rich objects with behavior │    │    │    │
│  │  │  │  Pure Dart, no imports from │    │    │    │
│  │  │  │  outer layers               │    │    │    │
│  │  │  └─────────────────────────────┘    │    │    │
│  │  └─────────────────────────────────────┘    │    │
│  └─────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────┘
```

## Layer Definitions

### 1. Domain (Entities) — `soliplex_client` + `lib/core/domain/`

**Contains**: Business rules, state machines, invariants, sealed hierarchies.
Pure Dart. No Flutter, no Riverpod, no I/O.

**The domain layer is rich.** Domain objects own their behavior:

- State transitions as methods that return new instances
- Validation and invariant enforcement
- Composition rules (e.g., how messages merge)
- Query methods that encode business knowledge

**When domain logic needs I/O**, it doesn't perform it. Instead, it defines
the *result* of a decision, and the application layer executes the side effect.
For example, `QuizSession.answerQuestion(result)` returns the next session
state — it doesn't call an API. The use case calls the API, then calls the
domain method with the result.

**Test strategy**: Plain Dart unit tests. No mocks needed for pure functions.

### 2. Application Layer (Use Cases) — `lib/core/usecases/`

**Contains**: Use cases that orchestrate domain objects and I/O.

**Use cases express intent with their class name.** Each class is a
single action the system can perform. Examples:
- `OpenCitation` — resolves a citation reference and opens the document
- `ResumeThreadWithMessage` — thread has history, user sends a follow-up
  (creates run, starts AG-UI stream)
- `StartThreadWithMessage` — creates a new thread from a first message
- `SubmitQuizAnswer` — submits an answer and records the result
- `SelectAndPersistThread` — selects a thread and persists it as last viewed

A use case:
1. Receives intent (named by its class)
2. Calls I/O via injected ports (API client, persistence)
3. Delegates business decisions to domain objects
4. Returns the domain result

**Use cases do not contain business rules.** They are orchestrators.
The "if/switch" logic that determines state transitions belongs in the
domain. The use case just calls `domain.doTheThing()` and handles the
I/O around it.

**Dependencies point inward**: use cases depend on domain objects,
never the reverse.

**Test strategy**: Unit tests with mocked I/O ports (API, persistence).

### 3. Interface Adapters (Providers) — `lib/core/providers/`

**Contains**: Riverpod providers that wire use cases into the widget tree.

A provider file should contain only provider declarations and thin
Notifiers that delegate to domain objects and use cases (the Humble
Object pattern). That's it.

Providers solve exactly two problems:
1. **Dependency injection** — construct objects with the right dependencies
2. **Reactive rebuilds** — `ref.watch()` triggers UI updates

**Providers do not contain**:
- Domain type definitions (sealed classes, typedefs, identity records)
- State machines or transition logic
- Business rules or validation
- Data transformation or merging logic
- I/O orchestration without a use case (if a Notifier calls an API,
  extract a use case — no size threshold)

**Test strategy**: Integration tests verifying wiring. Business logic
is already tested at the domain/use case layer.

### 4. Frameworks & Drivers — Flutter, Riverpod, GoRouter, HTTP

The outermost layer. These are details. The architecture doesn't depend
on them — they depend on the architecture.

## Concrete Transformations

### A. Conversation: Enrich the Aggregate Root

**Current state**: `Conversation` has `with*()` copy methods but no
business logic. Message merging lives in `active_run_provider.dart` as
a top-level function. Citation correlation lives in
`active_run_notifier.dart`.

**Target**: `Conversation` owns its composition rules.

```dart
// packages/soliplex_client/lib/src/domain/conversation.dart
class Conversation {
  // ... existing fields ...

  /// Merges streaming messages into the conversation, deduplicating by ID.
  ///
  /// Cached (historical) messages take precedence. New messages from
  /// the active run are appended if their ID hasn't been seen.
  Conversation withStreamingMessages(List<ChatMessage> streaming) {
    final seenIds = <String>{};
    final merged = <ChatMessage>[];
    for (final msg in messages) {
      if (seenIds.add(msg.id)) merged.add(msg);
    }
    for (final msg in streaming) {
      if (seenIds.add(msg.id)) merged.add(msg);
    }
    return copyWith(messages: merged);
  }

  /// Correlates citations with the user message that triggered them.
  ///
  /// Compares previous AG-UI state with current to find new citations,
  /// then records them as a MessageState for the given user message.
  Conversation withCorrelatedCitations(
    String userMessageId,
    Map<String, dynamic> previousAguiState,
    CitationExtractor extractor,
  ) {
    if (status is Running) return this; // only on completion
    final refs = extractor.extractNew(previousAguiState, aguiState);
    final ms = MessageState(
      userMessageId: userMessageId,
      sourceReferences: refs,
    );
    return withMessageState(userMessageId, ms);
  }
}
```

**What moves out of providers**:
- `_mergeMessages()` from `active_run_provider.dart` → `Conversation.withStreamingMessages()`
- `_correlateMessagesForRun()` from `active_run_notifier.dart` → `Conversation.withCorrelatedCitations()`

### B. QuizSession: Own the State Machine

**Current state**: `QuizSessionNotifier` (a Riverpod Notifier) contains
all state transitions AND the API call for submitting answers. The sealed
classes `QuizInput`, `QuestionState`, `QuizSession` are defined in the
same provider file.

**Target**: `QuizSession` is a rich domain object that owns its state
machine. The Notifier delegates to it.

```dart
// lib/core/domain/quiz_session.dart  (or packages/soliplex_client/)
sealed class QuizSession {
  const QuizSession();

  /// Starts a quiz. Returns QuizInProgress at question 0.
  /// Throws ArgumentError if quiz has no questions.
  static QuizInProgress start(Quiz quiz) { ... }
}

class QuizInProgress extends QuizSession {
  // ... existing fields and getters ...

  /// Updates user input. Returns new state with Composing questionState.
  /// No-op if currently Submitting or Answered.
  QuizInProgress withInput(QuizInput input) { ... }

  /// Clears input. Returns new state with AwaitingInput.
  QuizInProgress withInputCleared() { ... }

  /// Marks the current question as being submitted.
  /// Throws StateError if not in Composing state.
  QuizInProgress submitting() { ... }

  /// Records an answer result from the backend.
  /// Returns new state with Answered questionState and updated results map.
  QuizInProgress withAnswer(QuizAnswerResult result) { ... }

  /// Records a submission failure. Returns to Composing with input preserved.
  QuizInProgress withSubmissionFailed() { ... }

  /// Advances to next question or completes the quiz.
  /// Throws StateError if current question isn't Answered.
  QuizSession advance() { ... } // Returns QuizInProgress or QuizCompleted
}
```

The Notifier becomes trivial:

```dart
// lib/core/providers/quiz_provider.dart
class QuizSessionNotifier extends Notifier<QuizSession> {
  QuizSessionNotifier(this.arg);
  final QuizSessionKey arg;

  @override
  QuizSession build() => const QuizNotStarted();

  void start(Quiz quiz) => state = QuizSession.start(quiz);
  void updateInput(QuizInput input) => _update((s) => s.withInput(input));
  void clearInput() => _update((s) => s.withInputCleared());
  void advance() => _update((s) => s.advance());
  void reset() => state = const QuizNotStarted();

  Future<QuizAnswerResult> submitAnswer() async {
    final inProgress = _requireInProgress();
    state = inProgress.submitting();
    try {
      final api = ref.read(apiProvider);
      final result = await api.submitQuizAnswer(
        arg.roomId, inProgress.quiz.id,
        inProgress.currentQuestion.id,
        (inProgress.questionState as Composing).input.answerText,
      );
      _update((s) => s.withAnswer(result));
      return result;
    } catch (e, st) {
      _update((s) => s.withSubmissionFailed());
      rethrow;
    }
  }

  QuizInProgress _requireInProgress() => switch (state) {
    QuizInProgress s => s,
    _ => throw StateError('Not in progress'),
  };

  void _update(QuizSession Function(QuizInProgress) fn) {
    final s = state;
    if (s is QuizInProgress) state = fn(s);
  }
}
```

**What changes**:
- State machine transitions move from `QuizSessionNotifier` methods → `QuizInProgress` methods
- Sealed classes move from `quiz_provider.dart` → `lib/core/domain/quiz_session.dart`
- Notifier shrinks from ~190 lines of logic to ~40 lines of delegation
- API call stays in Notifier (it's I/O orchestration), but the state
  transitions before and after the call are domain methods

### C. ThreadSelection: Domain Type with Behavior

**Current state**: `ThreadSelection` sealed class, `LastViewed` sealed class,
`ThreadSelectionNotifier`, persistence functions, and navigation helpers —
all in `threads_provider.dart` (346 lines).

**Target**: Domain types in `lib/core/domain/`, persistence in a repository,
thin provider.

```dart
// lib/core/domain/thread_selection.dart
sealed class ThreadSelection {
  const ThreadSelection();

  /// The selected thread ID, if any.
  String? get threadId => switch (this) {
    ThreadSelected(:final threadId) => threadId,
    _ => null,
  };

  /// Whether a message can target this selection.
  bool get canSendMessage => switch (this) {
    ThreadSelected() => true,
    NewThreadIntent() => true,
    NoThreadSelected() => false,
  };
}

// lib/core/domain/last_viewed.dart
sealed class LastViewed { ... } // Pure types, no provider coupling
```

```dart
// lib/core/providers/threads_provider.dart  (~60 lines)
final threadsProvider = FutureProvider.family<List<ThreadInfo>, String>(...);

final threadSelectionProvider =
    NotifierProvider<ThreadSelectionNotifier, ThreadSelection>(...);

final currentThreadIdProvider = Provider<String?>((ref) {
  return ref.watch(threadSelectionProvider).threadId;
});

final currentThreadProvider = Provider<ThreadInfo?>((ref) { ... });

final lastViewedThreadProvider = FutureProvider.family<LastViewed, String>(...);
```

**What moves out**:
- `ThreadSelection` and `LastViewed` sealed classes → `lib/core/domain/`
- `selectThread()`, `selectAndPersistThread()` → either a use case or
  stay as free functions but move to a separate file (they take `WidgetRef`,
  which makes them adapter-layer, not domain)
- SharedPreferences helpers → repository or stay co-located with
  `lastViewedThreadProvider` (they're persistence adapters)

### D. ActiveRunNotifier: Extract Orchestration to Use Case

**Current state**: 557 lines. Contains run lifecycle, event processing,
citation correlation, cache updating, navigation sync, and logging.

**Target**: The notifier becomes a thin adapter. Domain logic moves to
`Conversation`. Orchestration moves to a use case or stays in a
drastically simplified notifier.

**What moves where**:

| Current location | Target | Layer |
|---|---|---|
| `_correlateMessagesForRun()` | `Conversation.withCorrelatedCitations()` | Domain |
| `_mergeMessages()` (in active_run_provider) | `Conversation.withStreamingMessages()` | Domain |
| `_mapResultForRun()` | Simplified — calls domain methods | Application |
| `_processEventForRun()` | Simplified — calls `processEvent()` then domain methods | Application |
| `_syncCurrentHandle()` | Stays in notifier (adapter concern) | Adapter |
| `_updateCacheOnCompletion()` | Stays in notifier or moves to use case | Application |
| `_logEvent()` | Stays (cross-cutting) | Application |
| `startRun()` orchestration | Use case or stays in simplified notifier | Application |

The notifier's `startRun()` currently does I/O orchestration (API calls,
stream setup) which is legitimate application-layer work. The question is
whether it should be a standalone use case class or remain in the notifier.

**Recommendation**: Extract to intent-named use cases in `lib/core/usecases/`.
The exact use case names should be determined during rework — the
naming must reflect the user's intent, not implementation details.
For example, `ResumeThreadWithMessage` means "thread has history,
user sends a follow-up." Each use case is a plain Dart class with
injected dependencies (API client, AG-UI client). The notifier calls
the use case and exposes the result. Domain logic (citation
correlation, message merging) stays in `Conversation`.

### E. Provider File Sizes After Transformation

| File | Current | Target | Change |
|---|---|---|---|
| `active_run_notifier.dart` | 557 | ~350 | Domain logic extracted to Conversation |
| `active_run_provider.dart` | 157 | ~60 | `_mergeMessages` → domain, `isStreamingProvider` → inline `.select()` |
| `threads_provider.dart` | 346 | ~80 | Sealed classes → domain/, helpers → separate file |
| `quiz_provider.dart` | 625 | ~80 | Sealed classes → domain/, state machine → domain methods |
| `documents_provider.dart` | 157 | 157 | No change (retry logic is adapter concern) |
| `thread_history_cache.dart` | 131 | 131 | No change (cache is adapter concern) |

### F. Convenience Providers: Eliminate or Justify

| Provider | Current | Action |
|---|---|---|
| `isStreamingProvider` | Wraps `activeRunNotifierProvider.isRunning` | Eliminate. Use `ref.watch(activeRunNotifierProvider.select((s) => s.isRunning))` at call sites (2 usages). |
| `currentThreadIdProvider` | Extracts ID from `threadSelectionProvider` | Keep. Used 5+ times, and `ThreadSelection.threadId` getter makes the provider a one-liner. |
| `canSendMessageProvider` | Multi-provider composition | Keep. Genuine derived state combining multiple sources. But could use `ThreadSelection.canSendMessage` to simplify. |

## Migration Approach

These transformations are independent and can be done incrementally:

1. **Quiz** (lowest risk, self-contained): Move sealed classes to domain/,
   add domain methods to `QuizSession`, simplify notifier.
2. **Threads** (medium): Move sealed classes to domain/, add behavior,
   simplify provider file.
3. **Conversation enrichment** (highest impact): Add `withStreamingMessages()`
   and `withCorrelatedCitations()`, simplify `active_run_notifier.dart` and
   `active_run_provider.dart`.

Each step is independently deployable and testable. The domain methods
are pure functions — they can be tested before the provider refactoring
happens.

## Non-Goals

- **Not reorganizing the file tree** into feature-based directories.
  File organization is cosmetic; this refactoring is about moving logic
  to the right layer.
- **Not introducing new abstractions** (repository interfaces, port
  classes) unless a domain object genuinely needs I/O indirection.
  The current codebase uses concrete dependencies — abstract only when
  there's a second implementation or a testing need that mocks don't cover.
- **Not changing the public API** of providers consumed by widgets.
  Widgets continue to `ref.watch(activeRunNotifierProvider)` etc.
  The refactoring is internal to the core layer.
