# Diagnosis Checklist

For each provider file in scope, check for these anti-patterns.
Each check includes what to look for and what the fix looks like.

## 1. Responsibility Check

**Check**: Does this provider file do anything beyond dependency injection
and reactive rebuilds?

A clean provider file contains only:

- Provider declarations (`Provider`, `FutureProvider`, `NotifierProvider`, etc.)
- Thin Notifiers that delegate to domain objects and use cases (the Humble
  Object pattern — push testable logic out, leave only trivial delegation)

If the file defines types, encodes business rules, manages state transitions,
or transforms data, those responsibilities belong elsewhere — regardless
of file length. A 200-line provider with only legitimate adapter logic
(DI, error handling, stream management, logging) is architecturally sound.
A 30-line provider that reimplements a domain invariant is not.

File length is a secondary signal: files over 150 lines are worth reviewing,
but the responsibility check is what matters.

## 2. Domain Types in Provider Files

**Check**: Does the file define types that express domain concepts?

Look for:
- `sealed class` hierarchies (domain vocabulary)
- `typedef` or type aliases for domain identity (e.g.,
  `typedef SessionKey = ({String roomId, String quizId})`)
- Record types or classes that represent domain identity or value objects

These are domain types — they define the vocabulary of the business.
They belong in `lib/core/domain/`, not in provider files. The test:
would this type exist even without Riverpod? If yes, it's domain.

**Fix**: Move to `lib/core/domain/<concept>.dart`. The provider file
imports the types but does not define them.

## 3. State Machine Logic in Notifiers

**Check**: Does a Notifier contain conditional state transitions?

Look for patterns like:
- Multiple `state =` assignments inside `if`/`switch` blocks
- Methods that check `state is X` before transitioning to `Y`
- Guard clauses that enforce valid transitions

These are domain invariants. The Notifier should call a domain method
that encodes the transition, not implement the logic itself.

**Fix**: Add transition methods to the domain sealed class. The Notifier
calls `state = domainObject.transitionMethod()`.

## 4. Business Rules in Providers

**Check**: Does the provider contain logic that answers a domain question?

Examples:
- "Can the user send a message right now?" (multi-condition check)
- "What's the next quiz question?" (progression logic)
- "Should citations be correlated?" (completion check)

**Fix**: Move the logic to a method or getter on the relevant domain
object. The provider calls the method.

## 5. Data Transformation in Providers

**Check**: Does the provider merge, filter, deduplicate, or reshape data?

Examples:
- Merging cached messages with streaming messages
- Filtering documents by selection state
- Correlating citations with user messages

**Fix**: These are composition rules that belong on the domain aggregate.
Add a method like `conversation.withStreamingMessages(running)`.

## 6. Convenience Providers

**Check**: Is this provider just extracting a field from another provider?

Examples:
- `isStreamingProvider` that wraps `activeRunNotifierProvider.isRunning`
- `currentThreadIdProvider` that extracts from `threadSelectionProvider`

**Fix**:
- If 3 or fewer usages: eliminate, use `.select()` at call sites
- If 4+ usages: keep, but make it a one-liner using a domain getter

## 7. Free Functions That Should Be Methods

**Check**: Are there top-level or file-private functions that operate on
domain objects?

Examples:
- `_mergeMessages(cached, running)` operating on `List<ChatMessage>`
- `selectAndPersistThread(ref, roomId, threadId)` operating on thread state

**Fix**: If the function's primary argument is a domain object, make it
a method on that object. If it takes `ref` or `WidgetRef`, it's adapter
logic — move to a use case or keep as a helper in the adapter layer.

## 8. Persistence Logic in Providers

**Check**: Does the provider directly access SharedPreferences, databases,
or file storage?

**Fix**: Extract to a repository or keep as adapter logic. The domain
layer defines the state worth persisting through its structure and
invariants — it does not have persistence-aware methods like
`shouldPersist()`. The use case decides *when* to persist (after a
user action) and the adapter decides *how* (SharedPreferences, DB).
The domain just defines *what* (its own state).

## 9. Navigation Logic in Providers

**Check**: Does the provider file contain functions that construct routes
or call navigation APIs?

**Fix**: Navigation is adapter-layer. These functions can stay in the
provider file or move to a separate adapter file. They should NOT be in
domain objects.

## 10. I/O Orchestration in Notifiers

**Check**: Does a Notifier method make API calls, access persistence,
or call external services?

Look for patterns like:
- `ref.read(apiProvider).someMethod(...)` inside a Notifier method
- `SharedPreferences` reads/writes in a Notifier
- Any `await` on an I/O operation inside a Notifier

**Fix**: Extract to an intent-named use case in `lib/core/usecases/`.
The Notifier calls the use case and updates state with the result.

**There is no size threshold.** A Notifier method that makes a single
API call still needs a use case. The reasoning "it's just one call,
it can stay in the Notifier" is the same reasoning that built 625-line
provider files — each piece was "small enough" individually. The
dependency rule is structural, not volumetric. If a Notifier performs
I/O, that I/O orchestration belongs in the application layer (use case),
not the adapter layer (provider).

A use case that today wraps a single API call is:
- The right place for future orchestration (retry, analytics, logging)
- Independently testable with a mocked port — no ProviderContainer
- A named entry in the "menu" of what the system can do
- Consistent application of the dependency rule

## Severity Scoring

For reporting, classify each finding:

- **Critical**: Domain types in provider file, state machine in Notifier
  (these are the core anti-pattern)
- **Major**: Business rules or data transformation in provider,
  I/O orchestration in Notifier without a use case
  (domain/application logic in the wrong layer)
- **Minor**: Convenience provider, free function that could be a method
  (code smell, not architectural violation)
- **Info**: File length warning, persistence logic co-located with
  provider (may be intentional)
