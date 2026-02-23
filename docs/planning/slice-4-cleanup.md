# Slice 4: Cleanup Stale Branches and PRs

**Branch:** `feat/client-tool-calling-v3/slice-4` (stacked on `slice-3`)
**PR:** `feat/client-tool-calling-v3/slice-4` -> `feat/client-tool-calling-v3/slice-3`

---

## Goal

Close stale PRs with rationale, delete remote branches, verify the full test
suite passes on the final stacked branch.

## Deliverable

Clean git history. No orphan branches. All tool-calling work consolidated
under the v3 slice stack. PR #290 assessed independently.

---

## Actions

| Action | Target | Rationale |
|--------|--------|-----------|
| Close PR | #291 (test/patrol-tool-calling) | Replaced by mock-LLM tests in Slice 2 |
| Close PR | #294 (refactor/notifier-stream-setup) | Superseded by Slice 3's `_establishSubscription` extraction |
| Review PR | #290 (refactor/notifier-test-container) | Independent test cleanup -- keep separate, merge if still useful |
| Delete branch | `feat/client-tool-calling-v2` | Stale, 25+ commits behind main |
| Delete branch | `test/patrol-tool-calling` | PR closed |
| Delete branch | `refactor/notifier-stream-setup` | PR closed |

---

## Files Changed

No code changes. This slice is purely git/GitHub housekeeping.

Optional: update `docs/planning/client-tool-calling-v3-plan.md` to mark
all slices as complete.

---

## Testing

### Autonomous verification

Since this slice has no code changes, testing is verification-only:

```bash
# Verify full suite passes on the complete stack
flutter test
dart test packages/soliplex_client/

# Verify analysis clean
flutter analyze --fatal-infos

# Verify format clean
dart format --set-exit-if-changed .
```

### PR closure verification

```bash
# Verify PRs are closed
gh pr view 291 --json state --jq '.state'  # expect: CLOSED
gh pr view 294 --json state --jq '.state'  # expect: CLOSED

# Verify branches deleted
gh api repos/{owner}/{repo}/branches/feat/client-tool-calling-v2 2>&1 | grep -q "Not Found"
gh api repos/{owner}/{repo}/branches/test/patrol-tool-calling 2>&1 | grep -q "Not Found"
gh api repos/{owner}/{repo}/branches/refactor/notifier-stream-setup 2>&1 | grep -q "Not Found"
```

---

## Acceptance Criteria

- [ ] PR #291 closed with comment linking to Slice 2 PR
- [ ] PR #294 closed with comment linking to Slice 3 PR
- [ ] PR #290 reviewed (keep or close with rationale)
- [ ] Remote branch `feat/client-tool-calling-v2` deleted
- [ ] Remote branch `test/patrol-tool-calling` deleted
- [ ] Remote branch `refactor/notifier-stream-setup` deleted
- [ ] Full test suite passes on the complete stacked branch
- [ ] `flutter analyze --fatal-infos` -- 0 issues

---

## Review Gate

After implementation, before merging:

1. **Codex review** -- verify PR closure comments are accurate
2. **Gemini review** (`gemini-3.1-pro-preview`) -- verify no useful work is lost from closed PRs
3. Both reviews addressed before final merge to main
