# M23: Test Documentation

## Sub-tasks

Each follows same workflow: Pass ACTUAL TEST FILES to Gemini `read_files` → Claude draft → Codex/Gemini review

### T1 - Auth Tests

- [ ] Claude: Gather auth test file paths from TEST_INVENTORY.md
- [ ] Gemini (`gemini-3-pro-preview`): `read_files` with THIS MILESTONE .md + the actual test files
  - Prompt: "List all test cases, what they verify, and any test utilities used."
- [ ] Claude: Draft `tests/T1-auth-tests.md`
- [ ] Review (Codex or Gemini)

### T2 - Provider Tests

- [ ] Claude: Gather provider test file paths from TEST_INVENTORY.md
- [ ] Gemini (`gemini-3-pro-preview`): `read_files` with THIS MILESTONE .md + the actual test files (batch if >20)
  - Prompt: "List all test cases, what they verify, and any test utilities used."
- [ ] Claude: Draft `tests/T2-provider-tests.md`
- [ ] Review (Codex or Gemini)

### T3 - Feature Tests

- [ ] Claude: Gather feature test file paths from TEST_INVENTORY.md
- [ ] Gemini (`gemini-3-pro-preview`): `read_files` with THIS MILESTONE .md + the actual test files (batch if >20)
  - Prompt: "List all test cases, what they verify, and any test utilities used."
- [ ] Claude: Draft `tests/T3-feature-tests.md`
- [ ] Review (Codex or Gemini)

### T4 - Client Tests

- [ ] Claude: Gather client test file paths from TEST_INVENTORY.md
- [ ] Gemini (`gemini-3-pro-preview`): `read_files` with THIS MILESTONE .md + the actual test files (batch if >20)
  - Prompt: "List all test cases, what they verify, and any test utilities used."
- [ ] Claude: Draft `tests/T4-client-tests.md`
- [ ] Review (Codex or Gemini)

### T5 - Integration Tests

- [ ] Claude: Gather integration test file paths from TEST_INVENTORY.md
- [ ] Gemini (`gemini-3-pro-preview`): `read_files` with THIS MILESTONE .md + the actual test files
  - Prompt: "List all contract tests, what they verify, and any test utilities used."
- [ ] Claude: Draft `tests/T5-integration-tests.md`
- [ ] Review (Codex or Gemini)

- [ ] Claude: Mark M23 complete in TASK_LIST.md

## Output

- `tests/T1-auth-tests.md`
- `tests/T2-provider-tests.md`
- `tests/T3-feature-tests.md`
- `tests/T4-client-tests.md`
- `tests/T5-integration-tests.md`
