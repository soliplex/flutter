---
name: rework
description: Analyze a feature's architecture and propose a scoped refactoring that applies the Clean Architecture dependency rule. Moves domain logic out of providers into rich domain objects and intent-named use cases.
argument-hint: "<feature-name|file-path|keyword>"
---

# Rework Skill

Analyze a feature and propose a precisely scoped refactoring that follows the
Clean Architecture dependency rule. The proposal must fit in one PR and in
one reviewer's head.

## Step 0: Ground Yourself in Principles

Before analyzing any code, do these two things:

1. **Fetch and read the Clean Architecture blog post** at
   <https://blog.cleancoder.com/uncle-bob/2012/08/13/the-clean-architecture.html>
   — internalize the dependency rule, the four layers, and the distinction
   between entities (rich business rules) and use cases (orchestration).

2. **Read the project's target architecture** at
   `PLANS/0006-clean-architecture/TARGET.md` — this shows how the Clean
   Architecture principles apply specifically to this codebase, with
   concrete before/after examples.

3. **Read the analysis** at `PLANS/0006-clean-architecture/ANALYSIS.md`
   — this documents the known anti-patterns and their root cause.

Do NOT skip this step. The principles are the source of truth. TARGET.md
is illustrative but may be outdated.

## Step 1: Resolve Scope

The user invoked `/rework $ARGUMENTS`.

Resolve `$ARGUMENTS` to a set of files:

- If it's a file path: start from that file
- If it's a feature name (e.g., `quiz`, `chat`, `threads`): find the
  corresponding provider file(s) in `lib/core/providers/` and the
  feature directory in `lib/features/`
- If it's a keyword (e.g., `active_run`): search for matching files

Then expand the scope to include:
- **Provider files**: the provider file(s) at the center of the feature
- **Domain types**: sealed classes, state machines defined in those files
- **Consuming widgets**: files in `lib/features/` that `ref.watch()` or
  `ref.read()` these providers
- **Related providers**: other providers watched/read by the target providers
- **Existing domain classes**: related classes in `lib/core/domain/`,
  `lib/core/models/`, or `packages/soliplex_client/` that could be enriched.
  Note: `lib/core/models/` contains legacy types that migrate to `domain/`
  during reworks.
- **Tests**: corresponding test files in `test/`

Present the resolved scope to the user before proceeding.

### Measure Comprehension Cost (Before)

Before proposing changes, measure the current comprehension cost:

- **Domain story files**: How many files contain business rules for this
  feature? Count files with sealed classes, state machines, business logic,
  or data transformation rules — regardless of which directory they're in
  (providers, models, or domain).
- **Whole story files**: How many files must a developer read to understand
  this feature end-to-end? Count the domain story files plus providers,
  use cases, and the primary widget(s) that trigger the feature.

Counting convention — what counts as a file:

- Production files that contain logic relevant to the feature (yes)
- Test files (no — they verify, they don't define)
- Barrel/export files (no — they re-export, they don't define)
- Widgets with only a `ref.watch()` one-liner (no — trivial glue)
- Widgets with conditional rendering based on domain state (yes)

The metric doesn't need to be precise — it needs to be consistently
applied so before/after comparisons are meaningful.

Present as:

> **Comprehension cost (before):** N domain-story files, M whole-story files

These numbers will be compared against the projected "after" in Step 4.

## Step 2: Diagnose

For each provider file in scope, run through the
[diagnosis checklist](./diagnosis-checklist.md).

Summarize findings as a table:

| File | Lines | Anti-patterns Found |
|------|-------|---------------------|
| ... | ... | ... |

## Step 3: Propose Transformation

For each diagnosed anti-pattern, propose a specific change:

### Domain Enrichment (dependency rule: entities own business rules)

- Identify logic that should be **methods on domain objects**
  (state transitions, composition rules, validation, invariant checks)
- Show the method signature and which domain class it belongs to
- The domain class must be pure Dart (no Flutter, no Riverpod)
- Domain classes live in `lib/core/domain/` or
  `packages/soliplex_client/lib/src/domain/`

### Use Case Extraction (dependency rule: use cases orchestrate I/O)

- Identify I/O orchestration that should be an **intent-named use case**
- Name the use case by what the user does: `SubmitQuizAnswer`,
  `ResumeThreadWithMessage`, `SelectAndPersistThread`
- Use cases live in `lib/core/usecases/`
- Use cases are plain Dart classes with injected dependencies

**There is no size threshold for extraction.** If a Notifier makes an
API call, that I/O belongs in a use case — even if it's "just one call."
The reasoning "it's thin enough to stay in the Notifier" is the same
reasoning that produced 625-line provider files. Each piece was locally
small; cumulatively they violated the dependency rule. Apply the rule
consistently: I/O orchestration lives in use cases, not adapters.

### Provider Thinning (dependency rule: adapters are glue)

- Show what the provider file looks like after extraction
- Provider files should contain only provider declarations and thin
  Notifiers — the Humble Object pattern: push all testable logic out,
  leave only trivial delegation
- Provider public API should not change (widgets keep same `ref.watch()`)

### Domain Type Relocation

- Any `sealed class` in a provider or models file must move to
  `lib/core/domain/`
- Any `typedef`, type alias, or record type that expresses domain
  identity (e.g., `typedef SessionKey = ({String roomId, String quizId})`)
  must also move — the test is "would this type exist without Riverpod?"
- Show the target file path

### Convenience Provider Elimination

- Providers that just wrap `.select()` should be eliminated
- Show the replacement `ref.watch(provider.select(...))` call at each
  call site
- Only if there are 3 or fewer usages; keep if widely used (5+)

### Test Transformation

Tests are not an afterthought — they are part of the rework. Analyze
existing tests with the same rigor as production code:

- **New domain tests**: Each new domain method (state transition,
  composition rule, validation) gets its own unit tests. These are
  plain Dart tests — no Riverpod container, no mocks needed.
- **Migrated provider tests**: Tests that currently verify business
  logic through a provider should be rewritten as domain unit tests.
  The logic moved to the domain layer, so the tests follow it.
- **Simplified provider tests**: Remaining provider tests should only
  verify wiring — that the provider constructs the right objects and
  that `ref.watch()` triggers rebuilds. These become trivially simple.
- **Deleted tests**: Tests that duplicate domain tests through the
  provider layer should be deleted, not kept for "extra coverage."
- **Use case tests**: Each use case gets unit tests with mocked I/O
  ports (API client, persistence). These verify the orchestration
  sequence: correct I/O calls in the right order, domain methods
  called with the right arguments.

## Step 4: Output the Plan

Structure the output as:

### Summary

One sentence describing the rework.

### Diagnosis

Table from Step 2.

### Changes (ordered)

For each change:
1. **What**: description of the change
2. **From**: source file and line range
3. **To**: target file (new or existing)
4. **Code sketch**: key signatures or structure (not full implementation)

### New Files

List any new files that need to be created, with their layer and purpose.
Include both production and test files.

### Test Plan

For each area of the rework:
- **Domain tests** (new): list test cases for new domain methods
- **Provider tests** (simplified): what remains after logic extraction
- **Use case tests** (new): what orchestration sequences to verify
- **Deleted tests**: which existing tests become redundant and why

### Cohesion Assessment

Compare the comprehension cost before and after the proposed rework:

| Metric | Before | After |
|--------|--------|-------|
| Domain story files | N | M |
| Whole story files | P | Q |

The domain story count should decrease — scattered business logic
consolidates into fewer, richer domain objects. The whole story count
should decrease or stay the same — fewer files overall, and each file
has a single clear responsibility.

If the whole story count does not improve, explain why (e.g., the feature
genuinely spans multiple layers and each layer is necessary).

### Risk

What could break, and how to verify:
- Does this change any provider's public API?
- Are there widgets that will need updating?
- What test commands verify the change is safe?

## Constraints

- **One PR scope**: The proposal must be independently deployable.
  No cascading changes to unrelated features.
- **No public API changes** to providers unless explicitly simplifying.
  Widgets should keep the same `ref.watch(...)` calls.
- **Reviewable in one sitting**: If the change is too large, split it
  into sequential steps and present step 1 only.
- **Principle over convention**: When TARGET.md and the Clean
  Architecture principles disagree, follow the principles.
- **Tests are first-class**: Every line of domain logic that moves
  must have a corresponding test that moves with it or is written new.
