# Architecture Documentation Plan

## Purpose

Systematically document the Soliplex Flutter codebase with 100% file coverage using Claude as orchestrator with Gemini and Codex as analysis tools.

## How to Continue Work

1. Open `TASK_LIST.md` - find the next ⬜ Pending milestone
2. Open `milestones/MXX-name.md` for that milestone
3. Execute each `[ ]` task following the tool rules below
4. Mark tasks `[x]` as complete
5. Update `TASK_LIST.md` status to ✅ Complete
6. Repeat with next milestone

---

## Tool Rules

### Gemini (Analysis)

| Setting | Value |
|---------|-------|
| Model | `gemini-3-pro-preview` |
| Method | `read_files` (pass absolute file paths) |
| Max files | **20 files per call** |
| Batching | Split into multiple calls if >20 files |

**CRITICAL: Pass BOTH the milestone .md file AND all source files listed in it to Gemini `read_files`. Gemini needs the milestone for context AND the actual Dart code to analyze.**

**Usage:**

```text
mcp__gemini__read_files
  file_paths: [
    "/Users/runyaga/dev/soliplex-flutter/docs/planning/milestones/M02-app-shell.md",  # milestone context
    "/Users/runyaga/dev/soliplex-flutter/lib/app.dart",                                # source files
    "/Users/runyaga/dev/soliplex-flutter/lib/main.dart",
    ... (all source files listed in milestone)
  ]
  prompt: <use standard prompt below>
  model: "gemini-3-pro-preview"
```

**Standard Gemini Prompt:**

```text
Analyze these Dart files for architecture documentation:

1. List all public classes/methods and their purpose (prioritize /// doc comments if present)
2. List dependencies:
   - External packages (from pub)
   - Internal features (imports from other lib/ directories)
3. Describe the data/initialization flow
4. Note architectural patterns (sealed classes, DI patterns, state management)
5. Flag BACKLOG items (do not put in main doc, list separately):
   - God classes or mixed concerns
   - Brittle/critical sequences
   - Missing documentation
   - Refactoring candidates
```

### Codex (Validation)

| Setting | Value |
|---------|-------|
| Model | `gpt-5.2` |
| Method | prompt with cwd |
| Max files | **15 file paths in prompt** |
| Timeout | **10 minutes** |
| Fallback | Use Gemini (`gemini-3-pro-preview`) for review if timeout |

**Usage:**

```text
mcp__codex__codex
  prompt: "Review [component].md for completeness. Verify these files are documented: [list 15 or fewer paths]"
  cwd: "/Users/runyaga/dev/soliplex-flutter"
```

### Claude (Orchestration)

- Gathers file paths (Glob tool)
- Calls Gemini `read_files` with batched file paths
- Synthesizes Gemini analysis into markdown
- Writes component docs (Write tool)
- Updates milestone checkboxes and TASK_LIST.md

---

## Workflow Per Milestone

```text
1. Read milestones/MXX-name.md to get file list
2. Claude: Build array of ABSOLUTE file paths from the milestone's "Files" section
3. Gemini: read_files with THE ACTUAL SOURCE FILES (not the milestone.md!)
   - Pass all files listed in milestone (batch if >20)
   - Use the Standard Gemini Prompt from Tool Rules above
4. Claude: Synthesize Gemini output into components/XX-component-name.md
5. Claude: Move any BACKLOG items Gemini flagged → BACKLOG.md
6. Codex: Review draft (10min timeout)
   - If timeout → Gemini review instead
7. Claude: Mark milestone tasks [x] complete
8. Claude: Update TASK_LIST.md status → ✅ Complete
```

**REMINDER: Gemini cannot read files unless you pass them to `read_files`. The milestone .md file only lists the paths - you must pass those actual .dart files to Gemini.**

---

## File Structure

```text
docs/planning/
├── PLAN.md              # This file - how to work
├── TASK_LIST.md         # Milestone index + status
├── FILE_INVENTORY.md    # All 156 files mapped to domains
├── BACKLOG.md           # Refactoring ideas (captured, not acted on)
├── milestones/          # One file per milestone
│   ├── M02-app-shell.md
│   ├── M03-authentication.md
│   └── ...
├── components/          # Output: architecture docs
│   ├── 01-app-shell.md
│   └── ...
└── tests/               # Output: test documentation
    └── ...
```

---

## Rules

1. **Document AS-IS only** - No refactoring during documentation
2. **Capture ideas in BACKLOG.md** - Don't lose insights, but don't act on them
3. **Every file in exactly one component** - 100% coverage, no duplicates
4. **Batch files properly** - Never exceed Gemini (20) or Codex (15) limits
5. **Markdown is source of truth** - All context in files, conversation is transient
6. **One milestone per session** - Clean restart points

---

## Current State

Check `TASK_LIST.md` for progress. Open the next ⬜ Pending milestone file to continue.

---

## Guidelines Workflow (M30-M34)

Guidelines milestones add "Contribution Guidelines" sections to component docs.
Different workflow from documentation milestones.

### Guidelines Task Flow

```text
1. Claude: Read milestone to get component list and source files
2. Claude: Build file arrays for each batch (source + md files)
3. Gemini: read_files (Batch 1) with model "gemini-3-pro-preview"
   - Pass: component docs + source files (max 20 total)
   - Prompt: Extract DO/DON'T patterns from code
4. Gemini: read_files (Batch 2 if needed)
5. Gemini: read_files MAINTENANCE.md for rules cross-reference
6. Gemini: Synthesize final DO/DON'T/Extending for each component
7. Claude: Add "Contribution Guidelines" section to each component doc
8. Codex: Validate additions (10min timeout)
   - If timeout → Gemini validates instead
9. Claude: Mark milestone complete
```

### Guidelines Gemini Prompt

```text
Analyze these source files and component documentation:

1. Extract architectural patterns actually used:
   - Provider types (NotifierProvider, FutureProvider, etc.)
   - State patterns (sealed classes, state machines)
   - Code organization patterns

2. Cross-reference with MAINTENANCE.md rules to identify:
   - Which rules apply to this component category
   - Best practices that should be documented

3. Synthesize into:
   DO: 3-5 specific practices developers SHOULD follow
   DON'T: 3-5 specific anti-patterns to AVOID
   Extending: 3-5 guidelines for adding new functionality

Focus on DESIRED patterns, not current violations.
Keep guidelines actionable and specific to this component type.
```

### Guidelines Validation Prompt (Codex)

```text
Review these component docs for "Contribution Guidelines" sections.
Verify each has:
1. DO subsection with 3-5 items
2. DON'T subsection with 3-5 items
3. Extending This Component subsection with 3-5 items
4. Guidelines are specific (not generic advice)
5. No references to specific line numbers or violations

Files: [list component doc paths]
```

### Batching Rules (CRITICAL)

| Tool | Max Files | Notes |
|------|-----------|-------|
| Gemini `read_files` | 20 | Include both .md and .dart files |
| Codex | 15 paths | Pass as comma-separated in prompt |

**Batch Construction Example:**

For a milestone with 6 components and 40 source files:

- Batch 1: 6 component docs + 14 source files = 20 files (Gemini)
- Batch 2: remaining 26 source files split into 2 calls of 13 files each
- MAINTENANCE.md: separate call for rules cross-reference

### Codex Timeout Fallback

```text
Codex has 10-minute timeout. If exceeded:
1. Kill the Codex call
2. Use Gemini gemini-3-pro-preview as CRITIC for validation instead
3. Document fallback in milestone notes
```

**Gemini Critic Prompt (when Codex times out):**

```text
ACT AS A CODE REVIEWER / CRITIC.

Review these component documentation files for quality and completeness
of their "Contribution Guidelines" sections.

For each file, verify:
1. Has "## Contribution Guidelines" section
2. Has "### DO" subsection with 3-5 actionable items
3. Has "### DON'T" subsection with 3-5 specific anti-patterns
4. Has "### Extending This Component" subsection
5. Guidelines are SPECIFIC to this component (not generic advice)
6. No references to specific line numbers or current violations

Report:
- PASS: All criteria met
- FAIL: List specific issues per file

Files to review: [list .md paths]
```
