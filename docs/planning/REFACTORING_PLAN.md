# Refactoring Plan

Prioritized action items from architecture documentation analysis.

## Priority Legend

| Priority | Criteria |
|----------|----------|
| **P0** | Security risk or data loss potential |
| **P1** | God classes blocking testability/maintainability |
| **P2** | Tech debt that compounds over time |
| **P3** | Nice-to-have improvements |

---

## P0 - Security & Stability

### 1. WebAuthStorage XSS Vulnerability

**Source:** BACKLOG.md - Authentication
**Files:** `lib/features/login/services/web_auth_storage.dart`

`localStorage` is vulnerable to XSS. Currently accepted for "internal tool" but
remains security debt.

**Options:**

- A) Document risk acceptance formally in code/ADR
- B) Migrate to HttpOnly cookies via BFF pattern
- C) Use `flutter_secure_storage` web adapter (limited browser support)

**Recommendation:** Option A for now, Option B if app becomes external-facing.

---

### 2. Brittle OAuth Capture Sequence

**Source:** BACKLOG.md - App Shell
**Files:** `lib/core/run_soliplex_app.dart`

OAuth callback params must be captured BEFORE GoRouter initializes. Temporal
coupling that can break silently.

**Action:**

- Extract to `OAuthParamsCapture` service initialized at app start
- Add integration test that verifies capture works after GoRouter init changes

---

### 3. Brittle Citation Index Math

**Source:** BACKLOG.md - Chat UI
**Files:** `lib/features/chat/widgets/message_list.dart`

Citation correlation uses `index - 1` to find User Message. Breaks if message
list structure changes (date separators, system messages).

**Action:**

- Link citations directly to Assistant message ID
- Add explicit `userMessageId` field to citation data

---

## P1 - God Classes & Mixed Concerns

### 4. AuthNotifier God Class

**Source:** BACKLOG.md - Authentication
**Files:** `lib/features/login/providers/auth_notifier.dart`

Handles: state machine, storage persistence, refresh logic, error handling.

**Action:**
Extract `AuthenticationRepository` for storage orchestration:

```text
AuthNotifier (state machine only)
    └── AuthenticationRepository (storage + refresh coordination)
            ├── AuthStorage (platform-specific)
            └── TokenRefreshService
```

**Estimated scope:** 3 files, ~200 lines moved

---

### 5. ActiveRunNotifier Mixed Concerns

**Source:** BACKLOG.md - Active Run
**Files:** `lib/core/providers/active_run_notifier.dart`

Handles: API creation, stream management, state mapping, citation extraction.

**Action:**
Extract `RunCompletionService` for citation correlation and cache sync:

```text
ActiveRunNotifier (stream orchestration)
    └── RunCompletionService (citation extraction, cache updates)
```

**Estimated scope:** 1 new file, ~100 lines extracted

---

### 6. ChatPanel God Class

**Source:** BACKLOG.md - Chat UI
**Files:** `lib/features/chat/chat_panel.dart`

Handles: UI layout, thread creation, error handling, pending documents, routing.

**Action:**
Extract `ThreadController` for thread creation + document transfer:

```text
ChatPanel (UI layout only)
    └── ThreadController (creation logic, document transfer)
```

**Estimated scope:** 1 new file, ~150 lines extracted

---

### 7. QuizScreen God Widget (~400 lines)

**Source:** BACKLOG.md - Quiz Feature
**Files:** `lib/features/quiz/quiz_screen.dart`

**Action:**
Extract to separate widgets:

- `QuizQuestionView` - question display + multiple choice
- `QuizResultsView` - results screen
- `QuizController` - state management (if not already in provider)

**Estimated scope:** 2 new files, ~250 lines moved

---

### 8. api_provider.dart High Coupling

**Source:** BACKLOG.md - State Management
**Files:** `lib/core/providers/api_provider.dart`

Defines: base client, auth client, transport, API instance, AG-UI client.

**Action:**

- Move `agUiClientProvider` to `ag_ui_providers.dart`
- Move `httpClientProvider` to `http_providers.dart`

**Estimated scope:** 2 new files, ~60 lines each

---

## P2 - Tech Debt

### 9. Layer Violations in Shared Widgets

**Files:**

- `lib/shared/widgets/error_display.dart` → imports `thread_history_cache.dart`
- `lib/shared/widgets/app_shell.dart` → imports `HttpInspectorPanel`

**Action:**

- Create `WrapperException` interface in `core/` for ErrorDisplay
- Pass inspector widget via provider/DI to invert dependency

---

### 10. Hardcoded Route Strings

**Files:** `lib/features/settings/settings_screen.dart`

**Action:**
Create `lib/core/router/routes.dart` with route constants:

```dart
abstract class AppRoutes {
  static const backendVersions = '/settings/backend-versions';
  static const network = '/settings/network';
  // ...
}
```

---

### 11. HTTP Inspector Performance

**Files:** `lib/features/inspector/`

Issues:

- `groupHttpEvents` is O(N) on every build - jank at 500+ items
- No body truncation - 5MB response freezes UI

**Action:**

- Move grouping to dedicated provider (computed once on change)
- Add body size limit (100KB default) with "show full" option

---

### 12. Inconsistent DI Patterns

**Files:** Multiple providers

Some read dependencies in `build()`, others read dynamically in methods.

**Action:**
Standardize: all dependencies read in `build()` and stored as fields.

---

### 13. Manual Equality Implementations

**Files:**

- `lib/core/providers/thread_selection_notifier.dart`
- Other sealed classes with manual `==`/`hashCode`

**Action:**

- Add `equatable` package OR
- Add unit tests covering equality for all sealed class variants

---

### 14. Duplicate Error Handling Patterns

**Files:** `lib/features/home/home_screen.dart` and others

Multiple places manually catch 5+ exception types for error messages.

**Action:**
Create `lib/core/utils/error_mapper.dart`:

```dart
String mapExceptionToMessage(Object error) {
  return switch (error) {
    SocketException _ => 'Network unavailable',
    TimeoutException _ => 'Request timed out',
    // ...
  };
}
```

---

### 15. Hardcoded Redaction Keys

**Files:** `packages/soliplex_client/lib/src/http/http_redactor.dart`

Sensitive field list hardcoded. Schema changes = plaintext logging.

**Action:**
Inject sensitive keys via configuration at client initialization.

---

## P3 - Enhancements

### 16. HTTP Inspector Search/Filter

Add filter controls: method, status code, URL text search.

### 17. Document Selection Persistence

Consider persisting draft selections across app restart.

### 18. Result<T> Type Extraction

Move private `Result<T>` from `chat_panel.dart` to `core/types/` for reuse.

### 19. Incomplete JSON Patch

Implement RFC 6902 move/copy/test operations or document limitations.

### 20. WakelockPlus Lifecycle

Implement `WidgetsBindingObserver` for foreground re-enable, or remove comment.

---

## Execution Strategy

### Phase 1: Foundation (P0 + P1 God Classes)

Focus on security issues and the 4 main god classes that block testability.

| Item | Est. Scope | Dependencies |
|------|------------|--------------|
| OAuth capture refactor | Small | None |
| Citation ID linking | Small | None |
| AuthNotifier extraction | Medium | None |
| ActiveRunNotifier extraction | Medium | AuthNotifier (pattern) |
| ChatPanel extraction | Medium | None |
| QuizScreen extraction | Medium | None |

### Phase 2: Architecture (Layer Violations)

Fix dependency direction issues in shared widgets and providers.

### Phase 3: Polish (Tech Debt)

Incremental cleanup: route constants, error mapping, DI consistency.

---

## Tracking

Use GitHub issues or project board. Tag with:

- `refactor:p0`, `refactor:p1`, `refactor:p2`, `refactor:p3`
- `god-class`, `layer-violation`, `tech-debt`, `security`

---

## Notes

- **Do not refactor during feature work** - schedule dedicated refactoring sprints
- **Test coverage first** - add tests before extracting classes
- **One PR per item** - keep changes reviewable
