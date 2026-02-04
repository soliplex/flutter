# M29 - Cross-Reference Validation

## Goal

Validate all 20 component docs have accurate "Depends on" / "Used by" sections.

## Tasks

- [x] Gemini: Verify all 20 components have "Cross-Component Dependencies" sections
- [x] Codex: Final consistency check (batched, max 15 files per call)
- [x] Update TASK_LIST.md

## Validation Checklist

| # | Component | Has Depends On | Has Used By | Verified |
|---|-----------|----------------|-------------|----------|
| 01 | App Shell | [x] | [x] | [x] |
| 02 | Authentication | [x] | [x] | [x] |
| 03 | State Core | [x] | [x] | [x] |
| 04 | Active Run | [x] | [x] | [x] |
| 05 | Threads | [x] | [x] | [x] |
| 06 | Rooms | [x] | [x] | [x] |
| 07 | Documents | [x] | [x] | [x] |
| 08 | Chat UI | [x] | [x] | [x] |
| 09 | Inspector | [x] | [x] | [x] |
| 10 | Configuration | [x] | [x] | [x] |
| 11 | Design System | [x] | [x] | [x] |
| 12 | Shared Widgets | [x] | [x] | [x] |
| 13 | Domain Models | [x] | [x] | [x] |
| 14 | HTTP Layer | [x] | [x] | [x] |
| 15 | API Endpoints | [x] | [x] | [x] |
| 16 | Application | [x] | [x] | [x] |
| 17 | Utilities | [x] | [x] | [x] |
| 18 | Native Platform | [x] | [x] | [x] |
| 19 | Router | [x] | [x] | [x] |
| 20 | Quiz | [x] | [x] | [x] |

## Verification Criteria

1. Every component doc has a "Cross-Component Dependencies" section
2. "Depends On" lists are accurate (verified by grep)
3. "Used By" lists are complete (verified by reverse grep)
4. No missing cross-references
5. Component numbers and names match FILE_INVENTORY.md
