# Milestone 12.7 — Error Fingerprinting (Backend)

**Phase:** 2 — Enhanced Context (P1)\
**Status:** Pending\
**Blocked by:** 12.4\
**PR:** —

> **Note:** This is a **backend (Python)** milestone. See
> [BACKEND.md](./BACKEND.md) for the full specification.
> No frontend gates apply.

---

## Goal

Group identical errors on the backend so operators see "Top 5 errors"
rather than thousands of individual log entries.

---

## Changes (Python)

- Hash: `sha256(exception_type + top_3_stack_frames)` → fingerprint
- Store fingerprint + count in database
- Logfire attributes include fingerprint for grouping
- Optional: alerting when error count exceeds threshold

---

## Acceptance Criteria

- [ ] Errors grouped by fingerprint
- [ ] Count tracked per fingerprint per time window
- [ ] Fingerprint visible in Logfire attributes
