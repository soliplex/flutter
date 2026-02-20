---
name: rework-sharpen
description: Evaluate feedback about the architectural tooling (rework skill, architect agent, Claude hooks, CLAUDE.md rules) against Clean Architecture principles. Patch tools if the feedback reveals a genuine gap; educate the developer if it reveals a misunderstanding.
argument-hint: "<feedback about a tool gap or false positive>"
---

# Rework-Sharpen Skill

A developer has used one of the architectural tools — `/rework`, the
architect agent, the architecture-lint hook, or the CLAUDE.md rules — and
encountered a problem. Your job is to determine whether the feedback
reveals a gap in the tools or a gap in understanding, and act accordingly.

## Step 0: Ground Yourself in Principles

Before evaluating anything, do these two things:

1. **Fetch and read the Clean Architecture blog post** at
   <https://blog.cleancoder.com/uncle-bob/2012/08/13/the-clean-architecture.html>
   — internalize the dependency rule, the four layers, and the distinction
   between entities (rich business rules) and use cases (orchestration).

2. **Read the project's target architecture** at
   `PLANS/0006-clean-architecture/TARGET.md` — this shows how the
   principles apply to this codebase.

The principles are the source of truth. Every evaluation below is
grounded in them.

## Step 1: Understand the Feedback

The user invoked `/rework-sharpen $ARGUMENTS`.

Parse the feedback to identify:
- **Which tool** is involved (rework skill, architect agent, hook, CLAUDE.md)
- **What happened** (false positive, missing check, bad advice, ambiguity)
- **What the developer expected** to happen instead

If the feedback is unclear, ask clarifying questions. You need a concrete
scenario — not a vague complaint — before you can evaluate.

## Step 2: Read All Tool Surfaces

Read every file in the architectural toolkit so you understand the
current state before proposing changes:

- `.claude/skills/rework/SKILL.md` — the rework skill
- `.claude/skills/rework/diagnosis-checklist.md` — the diagnostic checks
- `.claude/agents/architect.md` — the architect agent
- `.claude/hooks/architecture-lint.sh` — the architecture lint hook
- `.claude/settings.json` — the hook configuration
- `CLAUDE.md` — the project rules (Clean Architecture section)
- `PLANS/0006-clean-architecture/TARGET.md` — the target architecture
- `PLANS/0006-clean-architecture/ADR.md` — the architectural decision

## Step 3: Evaluate Against Principles

This is the critical step. Ask yourself:

**Does the feedback align with the Clean Architecture principles?**

### If YES — the tools have a genuine gap

The feedback reveals something the tools should handle but don't. Examples:
- The hook doesn't catch a real anti-pattern (missing check)
- The rework skill misses a category of domain logic leaking into providers
- The architect agent doesn't explore an important part of the codebase
- The CLAUDE.md rules are ambiguous about a legitimate edge case
- TARGET.md examples are misleading or outdated

Proceed to Step 4A.

### If NO — the feedback reveals a misunderstanding

The developer expects the tools to allow something that violates the
dependency rule. Examples:
- "The hook shouldn't flag sealed classes in providers — it's convenient
  to keep them co-located" (violates: entities own business rules)
- "The architect agent shouldn't require use cases for simple CRUD"
  (misunderstands: use cases orchestrate I/O, even simple I/O)
- "This domain object doesn't need a method for that — the provider can
  just check the state directly" (misunderstands: domain objects own their
  business rules, providers only delegate)

Proceed to Step 4B.

### If PARTIALLY — the feedback mixes valid and invalid concerns

Separate the wheat from the chaff. Address the valid part with patches
and the invalid part with education. This is the most common case.

## Step 4A: Propose Patches (Genuine Gap)

For each tool surface affected by the gap, propose a specific edit:

| Surface | File | Change |
|---------|------|--------|
| Rework skill | `.claude/skills/rework/SKILL.md` | ... |
| Diagnosis checklist | `.claude/skills/rework/diagnosis-checklist.md` | ... |
| Architect agent | `.claude/agents/architect.md` | ... |
| Architecture lint hook | `.claude/hooks/architecture-lint.sh` | ... |
| CLAUDE.md rules | `CLAUDE.md` | ... |
| Target architecture | `PLANS/0006-clean-architecture/TARGET.md` | ... |

Not every gap affects every surface. Only propose changes where the gap
is relevant. But always check all surfaces — a gap in one tool often
implies a gap in others because they encode the same principles.

For each proposed change:
- **What**: describe the edit
- **Why**: cite the Clean Architecture principle that justifies it
- **Risk**: could this change cause false positives or weaken another check?

Present the patches to the user. Do NOT apply them without approval.

## Step 4B: Educate (Misunderstanding)

Do not patch the tools. Instead:

1. **Acknowledge** the developer's frustration — the friction they
   experienced is real even if the tools are correct.

2. **Explain** which Clean Architecture principle applies, citing the
   blog post directly. Use the codebase's own examples from TARGET.md
   to make it concrete.

3. **Show** what the correct approach looks like for their specific
   scenario. Don't just say "that's wrong" — show the right way.

4. **Check for ambiguity** — if the developer's misunderstanding is
   reasonable given how the tools are worded, that IS a gap (in clarity,
   not in substance). Propose a wording improvement to make the principle
   clearer. This is a Step 4A patch.

## Step 5: Apply Approved Patches

After the user approves the patches:

1. Apply each edit
2. Verify consistency — do the tools still tell a coherent story?
3. If TARGET.md was updated, note that it's illustrative and may need
   refreshing as the codebase evolves

## Constraints

- **Principles are immutable.** The Clean Architecture dependency rule
  is not up for debate. The tools encode it; feedback refines how they
  encode it, not whether they should.
- **All surfaces must stay consistent.** A patch to one tool that
  contradicts another is worse than no patch at all.
- **Education is not condescension.** A developer who misunderstands the
  architecture is a developer who will understand it after this
  conversation. Be direct, cite sources, show examples.
- **Present patches before applying.** The user reviews and approves
  every change.
