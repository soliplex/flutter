# M32 - Guidelines: State Management

## Goal

Add "Contribution Guidelines" section to state management component docs (2 components).

## Components

| # | Component | Doc File | Source Files |
|---|-----------|----------|--------------|
| 04 | Active Run & Streaming | components/04-active-run-streaming.md | 6 |
| 07 | Document Selection | components/07-document-selection.md | 2 |

**Total: 2 component docs + 8 source files**

---

## Source File Inventory

### Component 04 - Active Run & Streaming (6 files)

```text
lib/core/models/active_run_state.dart
lib/core/models/agui_features/filter_documents.dart
lib/core/providers/active_run_notifier.dart
lib/core/providers/active_run_provider.dart
lib/core/application/run_lifecycle_impl.dart
lib/core/domain/interfaces/run_lifecycle.dart
```

### Component 07 - Document Selection (2 files)

```text
lib/core/providers/documents_provider.dart
lib/core/providers/selected_documents_provider.dart
```

---

## Batching Strategy

### Batch 1: Components 04 + 07 (Gemini read_files)

**Files (10):**

```text
docs/planning/components/04-active-run-streaming.md
docs/planning/components/07-document-selection.md
lib/core/models/active_run_state.dart
lib/core/models/agui_features/filter_documents.dart
lib/core/providers/active_run_notifier.dart
lib/core/providers/active_run_provider.dart
lib/core/application/run_lifecycle_impl.dart
lib/core/domain/interfaces/run_lifecycle.dart
lib/core/providers/documents_provider.dart
lib/core/providers/selected_documents_provider.dart
```

### Batch 2: MAINTENANCE.md Rules (Gemini read_files)

**Files (1):**

```text
docs/planning/MAINTENANCE.md
```

---

## Tasks

### Phase 1: Pattern Extraction

- [x] **Task 1.1**: Gemini `read_files` Batch 1 (Components 04 + 07)
  - Model: `gemini-3-pro-preview`
  - Files: 10 files (2 .md + 8 .dart)
  - Prompt: "Extract state machine patterns, sealed class hierarchies, resource
    management patterns, family provider patterns. Identify DO/DON'T candidates
    for state management components. Focus on:
    - ActiveRunState sealed hierarchy
    - Notifier state transition methods
    - Resource cleanup (StreamSubscription, CancelToken)
    - Record types as map keys
    - Derived state providers"

### Phase 2: Rules Cross-Reference

- [x] **Task 2.1**: Gemini `read_files` MAINTENANCE.md
  - Model: `gemini-3-pro-preview`
  - Files: 1 file
  - Prompt: "Extract rules applicable to state management: sealed state machines,
    one responsibility per Notifier, state transitions in Notifier methods,
    family providers for per-entity state, derived providers using select()."

### Phase 3: Guidelines Synthesis

- [x] **Task 3.1**: Gemini synthesize guidelines for Component 04
  - Model: `gemini-3-pro-preview`
  - Input: Batch 1 analysis + MAINTENANCE.md rules
  - Output: DO (5 items), DON'T (5 items), Extending (3 items)
  - Focus:
    - Sealed state hierarchy (Idle/Running/Completed)
    - Resource safety (NotifierInternalState separation)
    - Optimistic UI (user message before stream)
    - Merged data sources (cache + live)
    - Lifecycle management (wake lock)

- [x] **Task 3.2**: Gemini synthesize guidelines for Component 07
  - Model: `gemini-3-pro-preview`
  - Focus:
    - Family pattern for per-room data
    - Derived state combining multiple providers
    - Record types as composite map keys
    - In-memory state (no persistence)
    - Thread isolation for selections

### Phase 4: Document Updates

- [x] **Task 4.1**: Claude adds "Contribution Guidelines" to 04-active-run-streaming.md
- [x] **Task 4.2**: Claude adds "Contribution Guidelines" to 07-document-selection.md

### Phase 5: Validation

- [x] **Task 5.1**: Codex validation (10min timeout)
  - **Result**: Both files PASS

- [x] **Task 5.2**: Update TASK_LIST.md → M32 ✅ Complete

---

## Key Guidelines to Include

From MAINTENANCE.md applicable to state management:

### State Machine Rules

- Use sealed classes for state variants (exhaustive matching)
- One responsibility per Notifier (single state machine)
- State transitions ONLY in Notifier methods, never in widgets

### Provider Rules

- NotifierProvider for stateful features with complex state machines
- FutureProvider.family for per-entity data access
- Derived providers use `select()` or separate provider

### Resource Management Rules

- Separate mutable resources from immutable state (NotifierInternalState pattern)
- Clean up StreamSubscription and CancelToken on dispose
- Reference counting for shared resources (wake lock)

### State-Specific Patterns

- Run state machine: Idle → Running → Completed (Success/Failed/Cancelled)
- Selection patterns: Optional state with clear/set semantics
- Buffer patterns: Accumulate streaming data before emit
- Record types as composite keys for thread/room isolation

---

## Section Format

Each component doc gets appended:

```markdown
## Contribution Guidelines

### DO

- [5 specific practices]

### DON'T

- [5 specific anti-patterns]

### Extending This Component

- [3 guidelines for new functionality]
```

---

## Verification Criteria

- Both component docs have "Contribution Guidelines" section
- Each section has: DO, DON'T, Extending This Component subsections
- Guidelines reflect DESIRED patterns (not current violations)
- No references to specific line numbers
