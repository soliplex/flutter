# Specification: `/rework` Skill and Architectural Tooling

## Overview

Three tools that codify the Clean Architecture decisions from
[ADR.md](./ADR.md), grounded in the principles from Robert C. Martin's
[The Clean Architecture](https://blog.cleancoder.com/uncle-bob/2012/08/13/the-clean-architecture.html).

[TARGET.md](./TARGET.md) provides concrete examples of how these
principles apply to this codebase, but it is a point-in-time snapshot.
The principles themselves — the dependency rule, rich entities, thin
adapters — are the enduring source of truth.

## Foundational Reference

All three tools should eagerly read the Clean Architecture blog post
at the start of their execution to ground themselves in the original
principles. This ensures alignment with the architecture's intent
rather than just the letter of TARGET.md, which will inevitably
drift as the codebase evolves.

**URL**: <https://blog.cleancoder.com/uncle-bob/2012/08/13/the-clean-architecture.html>

**Key principles to internalize**:

- The dependency rule: source code dependencies point inward only
- Entities contain enterprise-wide business rules (richest layer)
- Use cases contain application-specific business rules (orchestration)
- Interface adapters convert data between formats for entities/use cases
- Frameworks and drivers are details — kept at the outermost layer

## Tool 1: `/rework` Skill

### Purpose

Enable a developer to point Claude at any feature (by name, file, or
provider) and receive a precisely scoped refactoring proposal that:
- Follows the dependency rule
- Fits in one PR
- Fits in one reviewer's head

### Invocation

```text
/rework quiz
/rework lib/core/providers/threads_provider.dart
/rework active_run
/rework chat
```

The argument is a feature name, file path, or keyword. The skill
resolves it to the relevant set of files.

### Behavior

1. **Read the Clean Architecture principles**: Fetch and internalize
   the blog post to ensure the analysis is grounded in principles,
   not just local conventions.

2. **Read architectural context**: Load
   `PLANS/0006-clean-architecture/TARGET.md` and
   `PLANS/0006-clean-architecture/ANALYSIS.md` for codebase-specific
   examples and known anti-patterns.

3. **Resolve scope**: From the argument, identify:
   - The provider file(s) involved
   - The domain types they contain (sealed classes, state machines)
   - The widgets that consume these providers
   - Related files (other providers watched/read by these providers)

4. **Diagnose**: For each provider file, run the responsibility check:
   - [ ] Does the file do anything beyond DI and reactive rebuilds?
   - [ ] Domain types in provider or models file — sealed classes,
     typedefs, identity records (should be in `lib/core/domain/`)
   - [ ] State machine logic in Notifier (should be domain methods)
   - [ ] Business rules in provider (should be domain methods)
   - [ ] Data transformation in provider (should be domain methods)
   - [ ] I/O orchestration in Notifier without a use case (should be
     in `lib/core/usecases/` — no size threshold)
   - [ ] Convenience providers that could be `.select()` at call sites
   - [ ] Free functions that should be methods on domain objects

5. **Propose transformation**: For each diagnosed issue:
   - What moves where (source file:line → target file)
   - What new domain methods to add (with signatures)
   - What the provider file looks like after (sketch, not full code)
   - What tests need updating

6. **Output a plan**: Structured as:
   - **Summary**: One sentence describing the rework
   - **Diagnosis**: Which anti-patterns are present
   - **Changes**: Ordered list of file changes
   - **New files**: Any new domain/use case files needed
   - **Test impact**: Which test files need updating
   - **Risk**: What could break and how to verify

### Constraints

- The proposal must be independently deployable (no cascading changes
  to unrelated features)
- Provider public API should not change (widgets keep the same
  `ref.watch(...)` calls) unless the rework explicitly simplifies them
- Each proposal should be reviewable in one sitting

### Skill File Location

`.claude/skills/rework/SKILL.md`

Supporting files:
- `.claude/skills/rework/diagnosis-checklist.md` — the diagnostic checks
- References `PLANS/0006-clean-architecture/TARGET.md` for examples

## Tool 2: Claude Hooks for Prevention

### Purpose

Catch anti-patterns the moment Claude writes them, before code is
staged or committed. Claude hooks run as part of Claude's execution
loop — they are guaranteed to fire and provide immediate feedback.

### Hook: Architecture Lint (`architecture-lint.sh`)

**Trigger**: After any Write or Edit to a `.dart` file.

The hook checks three directory scopes with appropriate rules for each:

**Provider files** (`lib/core/providers/*.dart`):

1. **Sealed class**: Warn if `sealed class` keyword appears — sealed
   classes are domain types, move to `lib/core/domain/`
2. **State machine signals**: Warn if file contains state transition
   patterns (multiple `state =` assignments inside conditional logic)

**Models files** (`lib/core/models/*.dart`):

1. **Sealed class**: Warn that domain types in `models/` should migrate
   to `lib/core/domain/` during reworks

**Domain and usecases files** (`lib/core/domain/*.dart`,
`lib/core/usecases/*.dart`):

1. **Forbidden imports**: Warn if the file imports Flutter, Riverpod,
   or GoRouter — these violate the dependency rule

**Output**: Warning message describing the violation and suggesting
where the code should live instead.

**Non-blocking**: These are warnings, not errors. Claude sees the
feedback and can self-correct, but the write isn't prevented.

### Configuration Location

`.claude/settings.json` (committed to git, shared across the team)

## Tool 3: Architect Agent

### Purpose

When planning a new feature (translating a functional spec into an ADR),
apply the clean architecture knowledge proactively. This prevents new
features from being born with the same anti-patterns that `/rework`
fixes in existing code.

### Invocation

A custom agent at `.claude/agents/architect.md`, invoked with:

```text
claude --agent architect
```

Architectural planning is a conversation — the agent needs to ask
questions, explore the codebase, and iterate on the decomposition
with the developer. An agent (not a skill) is the right vehicle
because it operates in a conversational, exploratory mode with its
own system prompt embedding the clean architecture principles.

### Behavior

When given a functional specification, the agent:

1. **Reads the Clean Architecture principles**: Fetches and
   internalizes the blog post. This is not optional — the agent must
   understand the dependency rule from its source, not from a
   second-hand summary.

2. **Reads codebase context**: Loads TARGET.md for current examples
   and ANALYSIS.md for known anti-patterns to avoid.

3. **Identifies domain concepts**: What entities, value objects, and
   aggregates does this feature introduce or extend?

4. **Designs domain behavior**: What business rules and state machines
   does this feature need? These become methods on domain objects.

5. **Names use cases by intent**: What can the user do? Each user
   action becomes a use case class: `CreateRoom`,
   `InviteCollaborator`, `ExportConversation`, etc.

6. **Identifies I/O boundaries**: What API calls, persistence, or
   external services does this feature need? These are orchestrated
   by use cases, not domain objects.

7. **Designs provider wiring**: What providers are needed to expose
   domain objects and use cases to the widget tree? Each should be
   a one-liner.

8. **Produces an ADR**: Following the project's ADR template, with
   the layer decomposition made explicit.

### Key Principle

The agent must resist Claude's default "one concern = one file"
decomposition. Instead, it groups by **cohesion**: related concepts
belong together in domain objects, not spread across provider files.

### Agent File Location

`.claude/agents/architect.md`

### Relationship to `/rework`

`/rework` and the architect agent encode the same architectural
judgment. The difference is timing:
- `/rework`: retroactive — fixes existing code
- Architect agent: proactive — designs new code correctly from the start

Both read the Clean Architecture blog post as their source of truth
and use TARGET.md for codebase-specific illustration.
