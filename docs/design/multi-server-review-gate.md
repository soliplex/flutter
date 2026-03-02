# Multi-Server Support — Review Gate

> How to gate each milestone through Gemini review using
> `soliplex-plans/tool/slice_review.sh`.

## Prerequisites

- `soliplex-plans` repo cloned at `~/dev/soliplex-plans`
- `jq` installed
- `dart` on PATH

## Commit Convention

Each milestone's final commit **must** include `(M{N})` in the message:

```bash
git commit -m "feat(agent): add ServerConnection value object (M1)"
git commit -m "feat(agent): add ServerRegistry CRUD (M2)"
```

The tool uses this marker to auto-detect diff ranges between milestones.

## Running the Review

```bash
WT=~/dev/soliplex-flutter/.claude/worktrees/multi-server-support

bash ~/dev/soliplex-plans/tool/slice_review.sh {N} \
  --repo "$WT" \
  --marker M \
  --pkg packages/soliplex_agent \
  --plan "$WT/docs/design/multi-server-milestones.md" \
  --context "$WT/docs/design/multi-server-test-plan.md" \
  --context "$WT/docs/design/multi-server-support.md"
```

Replace `{N}` with the milestone number (1–6).

## What the Tool Does

1. **Tests** — runs `dart test` in `packages/soliplex_agent`
2. **Gate** — runs `dart format --set-exit-if-changed .` + `dart analyze --fatal-infos`
3. **Diff** — auto-detects commit range from `(M{N})` markers
4. **Spec extraction** — pulls the M{N} section from milestones file
5. **Prompt assembly** — builds review prompt + diff + changed files + context
6. **Output** — prints a `mcp__gemini__read_files` call to paste into Claude

## Sending to Gemini

The tool outputs a ready-to-use `mcp__gemini__read_files(...)` invocation.
Copy it and run with `model="gemini-3.1-pro-preview"`.

## Output Location

Review artifacts land in:
```
~/dev/soliplex-plans/ci-review/multi-server-support/slice-reviews/
  m{N}-prompt.md   # Review prompt
  m{N}.diff         # Unified diff
```

These are gitignored in `soliplex-plans` (generated output).

## Gate Pass Criteria

A milestone passes review when Gemini confirms:

1. **Scope adherence** — changes match spec deliverables
2. **Completeness** — all deliverables addressed
3. **Code quality** — naming, style, no dead code
4. **Test coverage** — new behaviors tested
5. **Error handling** — failure modes covered
6. **Documentation** — public interfaces documented

## First Milestone (No Prior Markers)

For M1 (first implementation commit), use `--full` to diff against `origin/main`:

```bash
bash ~/dev/soliplex-plans/tool/slice_review.sh 1 \
  --repo "$WT" \
  --marker M \
  --pkg packages/soliplex_agent \
  --plan "$WT/docs/design/multi-server-milestones.md" \
  --context "$WT/docs/design/multi-server-test-plan.md" \
  --context "$WT/docs/design/multi-server-support.md" \
  --full
```
