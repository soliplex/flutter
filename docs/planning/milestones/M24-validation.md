# M24: Final Validation

## Tasks

### Coverage Verification (batched)

For each batch, pass the ACTUAL COMPONENT .md FILES to Gemini `read_files`:

- [ ] Claude: Collect component docs 01-05 paths
- [ ] Gemini (`gemini-3-pro-preview`): `read_files` with THIS MILESTONE .md + 5 component doc files
  - Prompt: "For each component doc, list all files mentioned. Cross-check against FILE_INVENTORY.md sections 01-05."
- [ ] Claude: Collect component docs 06-10 paths
- [ ] Gemini (`gemini-3-pro-preview`): `read_files` with THIS MILESTONE .md + 5 component doc files
  - Prompt: "For each component doc, list all files mentioned. Cross-check against FILE_INVENTORY.md sections 06-10."
- [ ] Claude: Collect component docs 11-15 paths
- [ ] Gemini (`gemini-3-pro-preview`): `read_files` with THIS MILESTONE .md + 5 component doc files
  - Prompt: "For each component doc, list all files mentioned. Cross-check against FILE_INVENTORY.md sections 11-15."
- [ ] Claude: Collect component docs 16-20 paths
- [ ] Gemini (`gemini-3-pro-preview`): `read_files` with THIS MILESTONE .md + 5 component doc files
  - Prompt: "For each component doc, list all files mentioned. Cross-check against FILE_INVENTORY.md sections 16-20."

### Cross-reference

- [ ] Claude: Update each component doc with "Depends on" / "Used by" sections based on import analysis

### Final Review

- [ ] Codex (`gpt-5.2`, 10min timeout): Final gap analysis
  - Pass: FILE_INVENTORY.md + list of all component doc paths
  - Fallback: Gemini review if timeout
- [ ] Claude: Mark M24 complete in TASK_LIST.md

## Output

All component docs updated with cross-references. Documentation complete.
