# CI Pipeline Improvements

**Status:** In Progress

**Date:** 2026-02-23

**Branch:** `chore/ci-review`

**PR:** Targeting `main`

## Problem Statement

The CI pipeline has five gaps discovered during the tool-calling PR stack
(#349-#351) and a broader audit of workflow configuration:

1. **Stacked PRs are invisible to CI.** PRs targeting feature branches (e.g.
   `feat/tool-calling`) only trigger secret scans (Gitleaks, TruffleHog). The
   Flutter CI workflow (`flutter.yaml`) restricts `pull_request.branches` to
   `[main]`, so lint, test, and build jobs never run on stacked PRs. Bugs land
   on feature branches unchecked and only surface when the feature branch itself
   merges to `main`.

2. **Markdown linting uses two different engines.** CI runs `npx markdownlint-cli`
   (Node.js) while pre-commit runs `pymarkdown` (Python). They implement the
   CommonMark spec differently, use different config formats, and disable
   different rules. A file can pass CI but fail pre-commit (or vice versa).

3. **Coverage threshold is below the documented target.** CLAUDE.md specifies an
   85% coverage target, but CI gates at 78%. Current measured coverage is 79.8%.
   The gap between the gate and the documented target invites erosion.

4. **No documentation lint gate.** Planning docs mention `dart doc --dry-run` as
   a CI step, but it was never added. Broken `{@link}`, `@see`, and unresolved
   doc references go undetected until someone reads the generated docs.

5. **DCM workflow uses a stale checkout action.** `dcm.yaml` pins
   `actions/checkout@v4` while all other workflows use `@v6`. Inconsistency
   creates maintenance burden and misses security patches.

6. **Boilerplate duplication across jobs.** The identical sequence of
   checkout + Flutter setup + pub cache + pub get is copy-pasted across `lint`,
   the `test` matrix (4 instances), `build-web`, and `dcm.yaml` — 6 copies of
   ~15 lines each.

7. **Build-web blocks on tests unnecessarily.** `build-web` uses
   `needs: [lint, test]`, forcing it to wait for all 4 test matrix entries. The
   web build only proves compilation — it doesn't depend on test results.

8. **Missing security hardening.** `dcm.yaml`, `gitleaks.yaml`, and
   `trufflehog.yaml` omit `permissions` blocks, falling back to repository
   defaults (potentially `write`). Secret scanners have version drift:
   Gitleaks uses `latest` Docker tag while pre-commit pins `v8.30.0`;
   TruffleHog uses `@main` (a mutable branch ref).

## Workflow Inventory (Before)

Four workflows exist in `.github/workflows/`:

| Workflow | File | Trigger | Jobs | Branch scope |
|----------|------|---------|------|-------------|
| Flutter CI | `flutter.yaml` | push + PR | lint, test (matrix: 4), build-web | `main` only |
| DCM Metrics | `dcm.yaml` | push + PR | analyze | `main` only |
| Gitleaks | `gitleaks.yaml` | push | gitleaks | `**` (all branches) |
| TruffleHog | `trufflehog.yaml` | push | trufflehog | `**` (all branches) |

**Key observation:** Only secret scanners run on all branches. Code quality
checks (lint, test, build) are restricted to `main`, leaving feature-branch
PRs unchecked.

## Pre-commit Parity Check

The local pre-commit pipeline (`.pre-commit-config.yaml`) runs:

| Hook | CI Equivalent | Parity |
|------|--------------|--------|
| `no-commit-to-branch` | N/A (branch protection) | OK |
| `check-merge-conflict` | N/A | OK |
| `check-toml` / `check-yaml` | N/A | OK |
| `gitleaks` v8.30.0 | `gitleaks.yaml` (Docker `latest`) | **Version drift** |
| `dart format --set-exit-if-changed` | `flutter.yaml` "Check formatting" | Match |
| `flutter analyze --fatal-infos` | `flutter.yaml` "Analyze code" | Match |
| `dart-analyze-packages` | Not in CI | Gap (packages analyzed via matrix tests) |
| `pymarkdown` v0.9.35 | `markdownlint-cli` (Node.js) | **Engine mismatch** |

The markdown mismatch is the most impactful: `.markdownlint.json` disables
`MD013,MD024,MD033,MD036,MD041,MD060` but `pymarkdown` disables the same rules
via CLI args with `extensions.front-matter.enabled=$!True`. Despite disabling the
same rule IDs, the engines interpret rules differently (especially around HTML
blocks and front matter).

## Changes — Phase 1 (This PR)

### 1. Enable Flutter CI for stacked PRs

**File:** `.github/workflows/flutter.yaml`

**Before:**

```yaml
pull_request:
  branches: [main]
```

**After:**

```yaml
pull_request:
  branches: [main, 'feat/**', 'fix/**', 'refactor/**', 'chore/**']
```

**Rationale:** Matches the branch naming conventions documented in CLAUDE.md
(`feat/name`, `fix/issue`, `refactor/area`). Adding `chore/**` covers
infrastructure branches like this one. The `push` trigger stays restricted to
`main` only — we don't need push-triggered builds on feature branches since PRs
already trigger them.

**Impact:** Any PR targeting a branch matching these patterns now gets the full
lint + test + build pipeline. Secret scanners (`gitleaks.yaml`,
`trufflehog.yaml`) continue running on all branches as before.

**What this does NOT change:**

- `push.branches` stays `[main]` (no duplicate builds)
- `paths-ignore` unchanged (docs-only PRs still skip CI)
- DCM workflow stays `main`-only (non-blocking, not worth the noise on stacked
  PRs)

### 2. Standardize markdown linting on pymarkdown

**File:** `.github/workflows/flutter.yaml`

**Removed:**

```yaml
- name: Setup Node.js
  uses: actions/setup-node@v4
  with:
    node-version: "20"

- name: Lint markdown
  run: npx markdownlint-cli "**/*.md"
```

**Added:**

```yaml
- name: Lint markdown
  run: |
    pip install pymarkdownlnt==0.9.35
    pymarkdown --set extensions.front-matter.enabled=\$!True \
      --disable-rules MD013,MD024,MD033,MD036,MD041,MD060 \
      scan docs/ *.md
```

**Config details:**

| Parameter | Value | Source |
|-----------|-------|--------|
| Version | `0.9.35` | `.pre-commit-config.yaml:33` |
| Front matter | `extensions.front-matter.enabled=$!True` | `.pre-commit-config.yaml:38` |
| Disabled rules | `MD013,MD024,MD033,MD036,MD041,MD060` | `.pre-commit-config.yaml:40` |
| Scan paths | `docs/ *.md` | Covers docs tree + root-level markdown |

**Rationale:**

- Single engine across local (pre-commit) and CI eliminates false
  positives/negatives from engine divergence
- Pinned version ensures reproducible linting
- Removes Node.js setup step (saves ~10s in CI and eliminates a dependency)

**Caching decision:** `pip install pymarkdownlnt` downloads ~3 MB and completes
in ~2 seconds. Adding `actions/cache` or `actions/setup-python` for pip would
add more overhead (5-10s for cache restore/save) than the install itself. No
caching needed.

**Residual artifacts:** `.markdownlint.json` and `.markdownlintignore` are now
unused by CI. They can be removed in a follow-up cleanup PR to keep this change
focused.

### 3. Bump coverage threshold to 80%

**File:** `.github/workflows/flutter.yaml`

**Before:**

```yaml
if [ "$COVERAGE_INT" -lt 78 ]; then
  echo "::error::Coverage ${COVERAGE}% is below minimum 78%"
```

**After:**

```yaml
if [ "$COVERAGE_INT" -lt 80 ]; then
  echo "::error::Coverage ${COVERAGE}% is below minimum 80%"
```

**Rationale:** Current measured coverage is **79.8%**. The documented target in
CLAUDE.md is **85%**. Jumping directly to 85% would fail CI immediately and
block all PRs. The 80% threshold:

- Provides ~0.2% buffer above current coverage (safe to merge)
- Establishes a ratchet that prevents regression
- Moves toward the 85% target incrementally

**Ratchet plan:**

| Phase | Threshold | When |
|-------|-----------|------|
| Current (before) | 78% | Established at project start |
| **This PR** | **80%** | Now |
| Next bump | 82% | When coverage reaches ~83% |
| Target | 85% | When coverage reaches ~86% |

Each bump should happen when actual coverage exceeds the proposed threshold by at
least 1%, ensuring CI is never red-on-merge.

### 4. Add dart doc dry-run gate

**File:** `.github/workflows/flutter.yaml` — new step in lint job after
"Analyze code", before "Lint markdown".

```yaml
- name: Check documentation
  run: dart doc --dry-run
```

**Rationale:** `dart doc --dry-run` parses all `///` doc comments and resolves
`{@link}`, `@see`, and cross-references without writing HTML output. It catches:

- References to deleted/renamed classes or members
- Malformed doc comment syntax
- Broken cross-package links

**Performance:** Typically completes in under 30 seconds. The lint job has a
10-minute timeout, which is more than sufficient.

### 5. Align DCM checkout version

**File:** `.github/workflows/dcm.yaml`

**Before:** `actions/checkout@v4`

**After:** `actions/checkout@v6`

**Rationale:** All other workflows already use `@v6`. Aligning DCM eliminates
version inconsistency and picks up security fixes. Backward-compatible for our
usage (no special parameters).

### 6. Extract composite action for environment setup

**File:** `.github/actions/setup-dart-env/action.yaml` (new)

The identical boilerplate sequence appears in every job:

```yaml
- uses: actions/checkout@v6
- uses: subosito/flutter-action@v2  # setup Flutter
- uses: actions/cache@v5            # pub cache
- run: flutter pub get              # install deps
```

This is extracted into a local composite action with two inputs:

| Input | Default | Purpose |
|-------|---------|---------|
| `working-directory` | `.` | Directory for `pub get` |
| `runner` | `flutter` | `flutter` or `dart` for `pub get` |

**Chicken-and-egg constraint:** Composite actions referenced via
`uses: ./.github/actions/...` require the repo to be checked out first. The
`actions/checkout@v6` step must remain as the first step in each job. The
composite action handles everything after checkout: Flutter setup, pub cache,
and dependency installation.

**Impact:** Reduces ~15 lines of boilerplate per job to 4 lines (checkout +
composite action call). Any future change to the setup sequence (e.g. bumping
`subosito/flutter-action`, changing cache key) only needs to happen in one place.

### 7. Parallelize build-web with tests

**File:** `.github/workflows/flutter.yaml`

**Before:**

```yaml
build-web:
  needs: [lint, test]
```

**After:**

```yaml
build-web:
  needs: [lint]
```

**Rationale:** The web build's purpose is to prove compilation — it doesn't
depend on test results. Decoupling it from the test matrix saves wall-clock time
by running build-web in parallel with the 4 test jobs.

**Trade-off:** If tests fail, the web build artifact is still produced. This is
acceptable because:

- The PR is blocked anyway (test is a required check)
- The artifact has 7-day retention and is never deployed from PRs
- Most Flutter projects decouple build from test for this reason

### 8. Fix Slack notification injection vulnerability

**Files:** `.github/workflows/flutter.yaml` (test + build-web jobs),
`.github/workflows/gitleaks.yaml`

**Problem (identified by Codex audit):** The `curl`-based Slack notifications
interpolate `${{ github.event.head_commit.message }}` directly into a shell
command. A crafted commit message containing quotes, newlines, or shell
metacharacters can break the JSON payload or inject commands. The Gitleaks
workflow also had a spurious `$GITHUB_OUTPUT` literal in its Slack message.

**Fix:** Replace all `curl`-based and `rtCamp/action-slack-notify` Slack
notifications with `slackapi/slack-github-action@v2.1.1` (the official Slack
action, already used by TruffleHog). Use `toJson(format(...))` to safely escape
all dynamic values:

```yaml
- name: Notify Slack on failure
  if: failure() && env.SLACK_NOTIFY_URL != ''
  uses: slackapi/slack-github-action@v2.1.1
  with:
    webhook: ${{ env.SLACK_NOTIFY_URL }}
    webhook-type: incoming-webhook
    payload: |
      {
        "channel": "#soliplex",
        "username": "flutter-ci",
        "text": ${{ toJson(format(':x: ...', ...)) }},
        "icon_emoji": ":flutter:"
      }
```

**Impact:** Eliminates injection risk, fixes the Gitleaks `$GITHUB_OUTPUT` bug,
and standardizes all workflows on a single Slack notification method
(`slackapi/slack-github-action@v2.1.1`).

### 9. Extend dart doc to sub-packages

**File:** `.github/workflows/flutter.yaml` (lint job)

**Problem (identified by Codex audit):** `dart doc --dry-run` only checks the
root package. The three sub-packages under `packages/` are skipped entirely.

**Fix:** Loop over `packages/*/` and run `dart doc --dry-run` in each:

```yaml
- name: Check documentation
  run: |
    dart doc --dry-run
    for dir in packages/*/; do
      echo "::group::dart doc $dir"
      (cd "$dir" && dart doc --dry-run)
      echo "::endgroup::"
    done
```

Using `::group::`/`::endgroup::` keeps CI logs collapsible per package.

### 10. Add permissions blocks to all workflows

**Files:** `.github/workflows/dcm.yaml`, `.github/workflows/gitleaks.yaml`,
`.github/workflows/trufflehog.yaml`

**Added to each:**

```yaml
permissions:
  contents: read
```

**Rationale:** Without an explicit `permissions` block, workflows inherit the
repository's default token permissions, which may include `write`. Adding
`contents: read` follows the principle of least privilege — none of these
workflows need to write to the repo.

## Changes — Phase 2 (Future PRs)

These are deferred to keep this PR focused but are documented as recommended
follow-ups based on the architectural review.

### Pin secret scanner versions

**Problem:** Gitleaks CI uses `docker://ghcr.io/gitleaks/gitleaks:latest`
(mutable tag) while pre-commit pins `v8.30.0`. TruffleHog uses `@main` (a
mutable branch ref on a security tool — dangerous).

**Recommendation:**

```yaml
# gitleaks.yaml — pin to match pre-commit
uses: docker://ghcr.io/gitleaks/gitleaks:v8.30.0

# trufflehog.yaml — pin to a release tag, not @main
uses: trufflesecurity/trufflehog@v3.88.0  # or latest stable
```

### DCM `continue-on-error` pattern

**Problem:** `continue-on-error: true` at the job level in `dcm.yaml` makes the
job show a green checkmark even when DCM analysis fails. Developers learn to
ignore green checks, defeating the purpose of informational reporting.

**Recommendation:** Move `continue-on-error: true` to the individual step level
instead of the job level. This way the job stays green (not a required check),
but the failing step shows a warning icon in the workflow run summary — visible
to anyone who clicks into the run.

```yaml
steps:
  - name: Run DCM Analyze
    continue-on-error: true  # Step-level, not job-level
    run: dcm analyze lib ...
```

**Alternative:** Remove `continue-on-error` entirely and let the job fail. As
long as DCM is not added as a Required Status Check in branch protection, the
red X won't block merges. The red X provides stronger visibility but may cause
"crying wolf" fatigue.

### Remove `.markdownlint.json` and `.markdownlintignore`

These files configured the now-removed `markdownlint-cli` (Node.js). Remove them
once the team confirms no local editor plugins depend on them.

### Continue coverage ratchet

Move the threshold toward the 85% CLAUDE.md target as tests are added (see
ratchet plan in Change 3).

### Consider official DCM action

Replace the manual `apt-get` + GPG key dance in `dcm.yaml` with
`dcm-dev/setup-dcm-action`, which is faster and handles caching natively.

## Workflow Inventory (After Phase 1)

| Workflow | Branch scope (PR) | Changes |
|----------|-------------------|---------|
| Flutter CI | `main`, `feat/**`, `fix/**`, `refactor/**`, `chore/**` | Expanded + composite action + parallel build + safe Slack |
| DCM Metrics | `main` | checkout@v6, permissions added |
| Gitleaks | `**` | permissions added, Slack standardized (injection fix) |
| TruffleHog | `**` | permissions added (Slack already used official action) |

## Lint Job Pipeline (After)

```text
Checkout
  -> Setup Dart environment (composite action)
     -> Setup Flutter (subosito/flutter-action@v2)
     -> Cache pub dependencies (actions/cache@v5)
     -> Install dependencies (flutter pub get)
  -> Check formatting (dart format --set-exit-if-changed)
  -> Analyze code (flutter analyze --fatal-infos)
  -> Check documentation (dart doc --dry-run + packages) [NEW]
  -> Lint markdown (pymarkdown scan docs/ *.md)        [CHANGED]
```

## CI Job Dependency Graph (After)

```text
              lint
             / | \
            /  |  \
           v   v   v
    test(4)  build-web     (parallel — build-web no longer waits for test)
```

Before this change, `build-web` waited for both `lint` AND all 4 `test` matrix
jobs. Now it starts as soon as `lint` passes. Estimated wall-clock savings:
2-5 minutes depending on test duration.

## Files Changed

| File | Change |
|------|--------|
| `.github/actions/setup-dart-env/action.yaml` | New composite action |
| `.github/workflows/flutter.yaml` | PR branches, composite action, dart doc (root + packages), pymarkdown, coverage 80%, parallel build-web, safe Slack notifications |
| `.github/workflows/dcm.yaml` | checkout@v6, permissions |
| `.github/workflows/gitleaks.yaml` | permissions, Slack standardized + injection fix |
| `.github/workflows/trufflehog.yaml` | permissions |

## Risk Assessment

| Change | Risk | Mitigation |
|--------|------|-----------|
| Stacked PR triggers | Low: additive | `push` still main-only; concurrency group cancels stale runs |
| Pymarkdown swap | Medium: different engine | Pinned version + identical disabled rules; validate locally first |
| Coverage 80% | Low: 0.2% buffer | If coverage dips, fix tests before merging |
| dart doc dry-run | Low: additive | Runs in existing lint job; fast (<30s) |
| DCM checkout bump | Negligible | Same action, newer version |
| Composite action | Low: refactor only | Same steps, just extracted; easy to revert |
| Parallel build-web | Low | PR still blocked if tests fail (required check) |
| Permissions blocks | Low: restrictive | Only adds constraints, doesn't remove any |
| Slack standardization | Low: same webhook | `toJson(format(...))` safely escapes all dynamic values |
| dart doc sub-packages | Low: additive | New check; loops over packages/ with `::group::` for readability |

## Verification Plan

### Pre-push (local)

1. Validate pymarkdown matches pre-commit locally:

   ```bash
   pip install pymarkdownlnt==0.9.35
   pymarkdown --set extensions.front-matter.enabled=\$!True \
     --disable-rules MD013,MD024,MD033,MD036,MD041,MD060 \
     scan docs/ *.md
   ```

2. Validate dart doc dry-run passes:

   ```bash
   dart doc --dry-run
   ```

3. Run pre-commit hooks:

   ```bash
   pre-commit run --all-files
   ```

### Post-push (CI)

1. Push `chore/ci-review`, open PR targeting `main`
2. Verify all required checks trigger and pass:
   - `lint` (format + analyze + dart doc + pymarkdown)
   - `test (app)` with coverage >= 80%
   - `test (soliplex_client)`
   - `test (soliplex_client_native)`
   - `test (soliplex_logging)`
   - `build-web` (should start before tests finish)
3. Verify DCM workflow runs with checkout@v6
4. Verify Gitleaks and TruffleHog pass with new permissions blocks

### Stacked PR validation (post-merge)

1. Create a test branch `feat/test-ci-trigger` off `main`
2. Open a PR targeting `feat/test-ci-trigger` from any sub-branch
3. Confirm Flutter CI triggers on the stacked PR
4. Delete test branches
