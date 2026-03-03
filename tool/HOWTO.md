# Landing Feature Branches — Agent HOWTO

This guide explains how to use `land_branch.sh` and `validate_pr.sh` to
squash-land a feature branch onto `main` as a single clean commit with
full validation.

## Overview

```text
feature branch (messy commits)
        │
        ▼
  land_branch.sh
        │
        ├─ creates git worktree from main
        ├─ squash-merges feature branch into it
        ├─ runs validate_pr.sh (analyze, test, coverage, review)
        │
        ▼
  single clean commit on land/<name> branch
        │
        ▼
  push → PR → CI → merge
```

## Prerequisites

- Run from the **main checkout** (not a worktree)
- The feature branch must exist locally or on the `runyaga` remote
- `fvm` (Flutter Version Manager) installed, or `dart`/`flutter` on PATH
- `dcm` (Dart Code Metrics) installed for static analysis

## Quick Start

```bash
# From the main checkout:
cd /Users/runyaga/dev/flutter

# Fetch latest remote branches
git fetch runyaga

# Land a feature branch with package validation
tool/land_branch.sh feat/soliplex-schema \
  --packages packages/soliplex_schema \
  --pr-goal "Add soliplex_schema package"
```

## Step-by-Step Workflow

### 1. Run land_branch.sh

```bash
tool/land_branch.sh <feature-branch> [options]
```

This will:
1. Create a worktree at `.claude/worktrees/land-<branch-basename>/`
2. Create a new branch `land/<branch-basename>` from `runyaga/main`
3. Squash-merge the feature branch into it
4. Run `flutter pub get`
5. Create a temporary commit and run `validate_pr.sh`

**Options passed through to validate_pr.sh:**

| Flag | Purpose |
|------|---------|
| `--packages <dir> [dir...]` | Package directories to analyze and test |
| `--app-tests` | Also run `flutter test` on the app root |
| `--coverage-threshold N` | Minimum patch coverage % (default: 90) |
| `--pr-goal "text"` | One-line description for Gemini code review |

**land_branch.sh-specific options:**

| Flag | Purpose |
|------|---------|
| `--name NAME` | Override worktree/branch name |
| `--skip-validate` | Just create worktree + squash-merge, skip validation |

### 2. Handle Validation Results

**If all gates pass (exit 0):**

```bash
cd .claude/worktrees/land-<name>

# Amend the WIP commit with a proper message
git commit --amend -m '<type>(<scope>): <description>

<body>'

# Push and create PR
git push runyaga land/<name>
gh pr create --base main --title '<type>(<scope>): <title>' --body '...'
```

**If validation fails (exit 1):**

```bash
cd .claude/worktrees/land-<name>

# Fix the issues (edit files, add tests, etc.)
git add -A
git commit --amend --no-edit

# Re-run validation
tool/validate_pr.sh \
  --packages packages/<pkg> \
  --pr-goal "..."
```

**If merge has conflicts (exit 1 during squash-merge):**

```bash
cd .claude/worktrees/land-<name>

# Resolve conflicts
# edit files...
git add <resolved-files>

# Then run validation manually
tool/validate_pr.sh \
  --packages packages/<pkg> \
  --pr-goal "..."
```

### 3. Clean Up After Merge

```bash
# From the main checkout
cd /Users/runyaga/dev/flutter

# Remove the worktree
git worktree remove .claude/worktrees/land-<name>

# Delete the remote branch (optional — GitHub does this on merge)
git push runyaga --delete land/<name>
```

## validate_pr.sh Reference

Runs six validation gates in order:

| Gate | What it checks |
|------|----------------|
| **Unified diff** | Generates diff against base branch, reports stats |
| **Static analysis** | `dart analyze --fatal-infos` on each `--packages` dir and app |
| **DCM analysis** | Runs DCM on changed `.dart` lib files only |
| **Tests + coverage** | `dart test` (packages) / `flutter test` (app) with coverage |
| **Patch coverage** | Checks new/changed lines meet coverage threshold |
| **Gemini review** | Produces file list + prompt for `mcp__gemini__read_files` |

**Safety guards:**
- Must run from a git worktree (not the main checkout)
- Must be on a feature branch (not `main`, `master`, or `clean/integration`)

### Running validate_pr.sh Standalone

```bash
# From inside a worktree on a feature branch:
tool/validate_pr.sh \
  --packages packages/soliplex_client packages/soliplex_agent \
  --app-tests \
  --coverage-threshold 85 \
  --pr-goal "Move run types from agent to client"
```

### Gemini Code Review

After validation, the script produces a review package in `.validation/`:
- `gemini_review_files.txt` — list of files (diff + changed sources)
- `gemini_review_prompt.txt` — structured review prompt

To run the review with Gemini MCP:

```text
mcp__gemini__read_files(
  file_paths: <contents of gemini_review_files.txt>,
  prompt: <contents of gemini_review_prompt.txt>
)
```

## Examples

### Land a new package

```bash
tool/land_branch.sh feat/soliplex-schema \
  --packages packages/soliplex_schema \
  --pr-goal "Add soliplex_schema package with Flutter widget definitions"
```

### Land a cross-cutting feature

```bash
tool/land_branch.sh feat/multi-server-support \
  --packages packages/soliplex_client packages/soliplex_agent \
  --app-tests \
  --coverage-threshold 80 \
  --pr-goal "Add multi-server support to client and agent packages"
```

### Land with skip-validate (for manual review)

```bash
tool/land_branch.sh feat/experimental \
  --skip-validate
```

## Adapting for Other Repos

The git workflow in `land_branch.sh` is language-agnostic. To adapt:

1. Replace `flutter pub get` (lines 136-140) with your install command
2. Create a `validate_pr.sh` with your language's gates:
   - **Python:** ruff, mypy, pytest, coverage
   - **Go:** go vet, golangci-lint, go test -cover
   - **Node:** eslint, tsc, jest/vitest

The worktree + squash-merge + validate + PR pattern works for any git repo.

## File Inventory

| File | Purpose |
|------|---------|
| `tool/land_branch.sh` | Orchestrator: worktree + squash-merge + validate |
| `tool/validate_pr.sh` | Validation gates: analyze, test, coverage, review |
| `tool/patch_coverage.py` | Computes coverage on new/changed lines from diff + lcov |
| `tool/HOWTO.md` | This file |
