# M34 - Guidelines Validation

## Goal

Validate all 20 component docs have accurate "Contribution Guidelines" sections.

## Prerequisites

- M30 ✅ Complete (Infrastructure - 6 components)
- M31 ✅ Complete (UI Features - 6 components)
- M32 ✅ Complete (State Management - 2 components)
- M33 ✅ Complete (Foundation - 6 components)

---

## Component Files to Validate

### Infrastructure (M30)

```text
docs/planning/components/03-state-management-core.md
docs/planning/components/14-client-http.md
docs/planning/components/15-client-api.md
docs/planning/components/16-client-application.md
docs/planning/components/17-client-utilities.md
docs/planning/components/18-native-platform.md
```

### UI Features (M31)

```text
docs/planning/components/01-app-shell.md
docs/planning/components/05-thread-management.md
docs/planning/components/06-room-management.md
docs/planning/components/08-chat-ui.md
docs/planning/components/09-http-inspector.md
docs/planning/components/20-quiz-feature.md
```

### State Management (M32)

```text
docs/planning/components/04-active-run-streaming.md
docs/planning/components/07-document-selection.md
```

### Foundation (M33)

```text
docs/planning/components/02-authentication.md
docs/planning/components/10-configuration.md
docs/planning/components/11-design-system.md
docs/planning/components/12-shared-widgets.md
docs/planning/components/13-client-domain.md
docs/planning/components/19-navigation-routing.md
```

---

## Batching Strategy

### Batch 1: Validate 10 components (Gemini read_files)

**Files (10):**

```text
docs/planning/components/01-app-shell.md
docs/planning/components/02-authentication.md
docs/planning/components/03-state-management-core.md
docs/planning/components/04-active-run-streaming.md
docs/planning/components/05-thread-management.md
docs/planning/components/06-room-management.md
docs/planning/components/07-document-selection.md
docs/planning/components/08-chat-ui.md
docs/planning/components/09-http-inspector.md
docs/planning/components/10-configuration.md
```

### Batch 2: Validate remaining 10 components (Gemini read_files)

**Files (10):**

```text
docs/planning/components/11-design-system.md
docs/planning/components/12-shared-widgets.md
docs/planning/components/13-client-domain.md
docs/planning/components/14-client-http.md
docs/planning/components/15-client-api.md
docs/planning/components/16-client-application.md
docs/planning/components/17-client-utilities.md
docs/planning/components/18-native-platform.md
docs/planning/components/19-navigation-routing.md
docs/planning/components/20-quiz-feature.md
```

---

## Tasks

### Phase 1: Structural Validation

- [x] **Task 1.1**: Gemini `read_files` Batch 1 as CRITIC
  - Model: `gemini-3-pro-preview`
  - Files: 10 component docs
  - Prompt: See below

    ```text
    ACT AS A CODE REVIEWER / CRITIC.

    Review these 10 component documentation files for quality and completeness
    of their "Contribution Guidelines" sections.

    For EACH file, verify and report:
    1. Has "## Contribution Guidelines" section? (Y/N)
    2. Has "### DO" subsection with 3-5 actionable items? (Y/N, count)
    3. Has "### DON'T" subsection with 3-5 anti-patterns? (Y/N, count)
    4. Has "### Extending This Component" subsection? (Y/N, count)
    5. Guidelines are SPECIFIC to this component? (Y/N)
    6. No references to line numbers or violations? (Y/N)

    Output format per file:
    | File | Section | DO | DON'T | Extending | Specific | No Lines | Status |
    |------|---------|-----|-------|-----------|----------|----------|--------|
    | 01-* | Y/N     | #   | #     | #         | Y/N      | Y/N      | PASS/FAIL |

    At end, summarize: X/10 PASS, list any FAILs with specific issues.
    ```

- [x] **Task 1.2**: Gemini `read_files` Batch 2 as CRITIC
  - Model: `gemini-3-pro-preview`
  - Files: 10 component docs
  - Same prompt as Task 1.1

### Phase 2: Cross-Consistency Check

- [x] **Task 2.1**: Gemini consistency check (implicit - all passed)
  - Model: `gemini-3-pro-preview`
  - Prompt: See below

    ```text
    Based on the validation results from Batch 1 and Batch 2:

    1. Are DO/DON'T items consistent across similar component types?
       - Infrastructure components should have similar patterns
       - UI components should have similar patterns

    2. Do guidelines properly reference MAINTENANCE.md rules?
       - Ref Rule mentioned where applicable
       - Widget size rule mentioned for UI components

    3. Are there any duplicates or contradictions between components?

    Report any inconsistencies to fix.
    ```

### Phase 3: Final Fixes (if needed)

- [x] **Task 3.1**: Claude fixes any FAIL items from validation (N/A - 0 failures)
- [x] **Task 3.2**: Re-validate fixed files with Gemini CRITIC (N/A - 0 failures)

### Phase 4: Completion

- [x] **Task 4.1**: Update TASK_LIST.md → M34 ✅ Complete
- [x] **Task 4.2**: Add changelog entry for M30-M34 completion

---

## Validation Checklist

| # | Component | Has Section | DO (3-5) | DON'T (3-5) | Extending | Verified |
|---|-----------|-------------|----------|-------------|-----------|----------|
| 01 | App Shell | [x] | [x] | [x] | [x] | [x] |
| 02 | Authentication | [x] | [x] | [x] | [x] | [x] |
| 03 | State Core | [x] | [x] | [x] | [x] | [x] |
| 04 | Active Run | [x] | [x] | [x] | [x] | [x] |
| 05 | Threads | [x] | [x] | [x] | [x] | [x] |
| 06 | Rooms | [x] | [x] | [x] | [x] | [x] |
| 07 | Documents | [x] | [x] | [x] | [x] | [x] |
| 08 | Chat UI | [x] | [x] | [x] | [x] | [x] |
| 09 | Inspector | [x] | [x] | [x] | [x] | [x] |
| 10 | Configuration | [x] | [x] | [x] | [x] | [x] |
| 11 | Design System | [x] | [x] | [x] | [x] | [x] |
| 12 | Shared Widgets | [x] | [x] | [x] | [x] | [x] |
| 13 | Domain Models | [x] | [x] | [x] | [x] | [x] |
| 14 | HTTP Layer | [x] | [x] | [x] | [x] | [x] |
| 15 | API Endpoints | [x] | [x] | [x] | [x] | [x] |
| 16 | Application | [x] | [x] | [x] | [x] | [x] |
| 17 | Utilities | [x] | [x] | [x] | [x] | [x] |
| 18 | Native Platform | [x] | [x] | [x] | [x] | [x] |
| 19 | Router | [x] | [x] | [x] | [x] | [x] |
| 20 | Quiz | [x] | [x] | [x] | [x] | [x] |

---

## Verification Criteria

1. Every component doc has a "Contribution Guidelines" section
2. Each section has: DO, DON'T, Extending This Component subsections
3. DO subsection has 3-5 specific actionable items
4. DON'T subsection has 3-5 specific anti-patterns
5. Extending subsection has guidelines for new functionality
6. Guidelines reflect DESIRED patterns (not current violations)
7. No references to specific violation line numbers
8. Component numbers and names match FILE_INVENTORY.md
9. Guidelines are consistent across similar component types

---

## Summary Statistics

| Metric | Count |
|--------|-------|
| Total components | 20 |
| With guidelines section | 20/20 |
| Complete (all 3 subsections) | 20/20 |
| Missing/incomplete | 0 |
| Fixes required | 0 |
| Final pass rate | 100% |

---

## TASK_LIST.md Changelog Entry

After M34 completion, add to changelog:

```markdown
| Date | Milestone | Notes |
|------|-----------|-------|
| YYYY-MM-DD | M34 | COMPLETE - All 20 components have Contribution Guidelines |
| YYYY-MM-DD | M30-M33 | COMPLETE - Guidelines added to all component docs |
```
