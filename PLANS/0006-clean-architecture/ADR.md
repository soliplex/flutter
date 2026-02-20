# ADR: Clean Architecture — Rich Domain, Thin Providers

## Status

Proposed

## Context

The Soliplex Flutter frontend has 62 Riverpod providers across 22 files.
Provider files have absorbed domain responsibilities — sealed class
hierarchies, state machines, business logic, persistence — rather than
serving as thin glue between domain logic and UI.

See [ANALYSIS.md](./ANALYSIS.md) for the full inventory and root cause
analysis.

### The Problem: Cohesion Deficit

Riverpod should be glue, but the whole furniture kit was stuffed into
the tube of glue. Related domain concepts are scattered across separate
provider files, making them hard to reason about as a whole:

- Understanding "sending a message" requires reading 6 provider files
- `quiz_provider.dart` (625 lines) contains 4 sealed class hierarchies
  and a full state machine
- `threads_provider.dart` (346 lines) contains 2 sealed hierarchies,
  a notifier, persistence logic, and navigation helpers

### Root Cause

Claude Code's default decomposition strategy: "one concern = one file."
Each file is locally clean, but relationships between files are implicit.
Claude optimizes for local correctness over global cohesion.

### What's Not Wrong

- `soliplex_client` is well-structured with proper domain models
- Individual provider code quality is high
- Family providers are used correctly for isolation
- No god providers exist

## Decision

Apply the Clean Architecture dependency rule to restructure the codebase:

1. **Rich domain layer** (`soliplex_client` + `lib/core/domain/`):
   Domain objects own their behavior — state machines, composition rules,
   validation, invariants. Pure Dart, no framework imports.

2. **Intent-named use cases** (`lib/core/usecases/`): Each use case is
   a plain Dart class whose name expresses user intent:
   `OpenCitation`, `ResumeThreadWithMessage`, `SubmitQuizAnswer`,
   `StartThreadWithMessage`, `SelectAndPersistThread`. Use cases
   orchestrate domain objects and I/O. They do not contain business
   rules.

3. **Thin provider layer** (`lib/core/providers/`): Providers solve
   exactly two problems: dependency injection and reactive rebuilds.
   Provider files contain only provider declarations and thin Notifiers
   (the Humble Object pattern). No sealed classes, no state machines,
   no business logic.

4. **The dependency rule**: Source code dependencies can only point
   inwards. Domain depends on nothing. Use cases depend on domain.
   Providers depend on use cases and domain. Never the reverse.

See [TARGET.md](./TARGET.md) for the complete target architecture with
concrete transformation examples.

## Three Problems, Three Tools

This decision addresses three distinct problems that require different
tools:

### Problem 1: Existing Code — The `/rework` Skill

Existing provider files contain domain logic that needs extraction.
A rigid refactoring roadmap would go stale when priorities shift.

**Solution**: A Claude skill (`/rework`) that encodes the architectural
judgment from this ADR and TARGET.md. Any developer can invoke it on
any feature, at any time, and receive a precisely scoped refactoring
proposal sized for one PR.

This approach:
- Accommodates priority changes (interrupt without staling a plan)
- Enables opportunistic transformation (rework when already touching it)
- Keeps each change reviewable (fits in one human's head)

See [SPEC.md](./SPEC.md) for detailed specifications of all three tools.

### Problem 2: Future Code — Prevention via Claude Hooks

Old habits die hard. Without guardrails, Claude (and human developers)
will recreate the anti-patterns in new code.

**Solution**: Complementary guardrails at two levels:

1. **CLAUDE.md rules** codifying the dependency rule and provider
   constraints. Claude reads these on every session — the first line
   of defense.

2. **Claude hooks** (in `.claude/settings.json`, committed to git)
   that run after file writes and catch violations in real time.
   Unlike git hooks (which are developer-discretionary and fire late
   at commit time), Claude hooks are part of Claude's own execution
   loop. They intercept the anti-pattern the moment Claude writes it
   — before the code is even staged. The `architecture-lint.sh` hook
   checks three directory scopes:
   - Provider files: warn if `sealed class` or state machine patterns
   - Models files: warn if domain types should migrate to `domain/`
   - Domain/usecases files: warn if forbidden imports violate purity

Prevention is designed after the `/rework` skill, because guardrails
that say "don't do X" without codifying "do Y instead" confuse more
than they help.

### Problem 3: New Features — The Architect Agent

The `/rework` skill fixes existing code. Prevention rules stop bad
patterns. But neither helps when **planning a new feature from scratch**
— translating a functional spec into an ADR/technical plan that
respects the clean architecture from the start.

Today, when Claude generates an ADR for a new feature, it defaults to
its "one concern = one file" decomposition — the same root cause that
created the provider sprawl. The architectural knowledge we've codified
needs to be available at planning time, not just at refactoring time.

**Solution**: A custom Claude agent (`.claude/agents/architect.md`)
invoked with `claude --agent architect`. The agent:
- Reads the Clean Architecture blog post to ground itself in principles
- Takes a functional specification as input
- Applies the dependency rule to decompose the feature into layers
- Names use cases by intent (what the user does, not what the code does)
- Places domain logic in rich domain objects, I/O in use cases,
  wiring in providers
- Produces an ADR that follows the clean architecture from the start

An agent (not a skill) is the right vehicle because architectural
planning is a conversation — the agent needs to ask questions, explore
the codebase, and iterate on the decomposition with the developer.

## Consequences

### Positive

- Domain logic is testable with plain Dart unit tests (no mocks)
- Related concepts are co-located in rich domain objects
- Provider files become trivially reviewable
- New features naturally follow the pattern via the architect agent
- Codebase transforms gradually without disrupting feature development
- Use case names create a readable "menu" of what the system can do
- Claude hooks provide immediate feedback, shortening the loop vs
  commit-time checks

### Negative

- Some domain objects gain methods, increasing their surface area
- Developers must learn to distinguish domain behavior from I/O
  orchestration
- Three tools to maintain (`/rework`, Claude hooks, architect agent)

### Risks

- Over-extraction: moving logic that genuinely belongs in the adapter
  layer (e.g., Riverpod lifecycle hooks) into domain objects
- Mitigation: TARGET.md explicitly lists what stays in providers
  (dependency injection, reactive rebuilds, disposal)
- Under-utilization: tools exist but developers bypass them
- Mitigation: Claude hooks catch drift even when skills aren't invoked
