# Architecture Documentation - Backlog

## Purpose

This file captures refactoring ideas and observations discovered during architecture documentation. These are captured but NOT acted upon during the documentation process.

---

## Observations

_No observations yet. Items will be added as documentation progresses._

---

## Format

When adding items, use this format:

```markdown
### [Component Name] - [Brief Title]

**Source:** [component doc file]
**Severity:** Low | Medium | High
**Type:** Refactoring | Tech Debt | Enhancement | Bug

**Description:**
Brief description of the observation.

**Suggested Action:**
What could be done to address this.
```

---

## Items

### App Shell - Brittle OAuth Capture Sequence

**Source:** components/01-app-shell.md
**Severity:** High
**Type:** Tech Debt

**Description:**
The comment in `run_soliplex_app.dart` states "Capture OAuth callback params BEFORE
GoRouter initializes" indicating high-risk temporal coupling. If GoRouter initialization
moves or changes, Web Auth could break silently.

**Suggested Action:**
Document this coupling explicitly or refactor to make the dependency explicit rather
than relying on call order.

---

### App Shell - Complex _connect() Method

**Source:** components/01-app-shell.md
**Severity:** Medium
**Type:** Refactoring

**Description:**
The `_connect()` method in `HomeScreen` (~80 lines) is a "God Method" mixing UI state
(`setState`), async logic, error handling, and navigation in one method.

**Suggested Action:**
Refactor `_connect` into a Riverpod `AsyncNotifier` or Controller class to separate
orchestration from the View.

---

### App Shell - Hardcoded Route Strings

**Source:** components/01-app-shell.md
**Severity:** Low
**Type:** Tech Debt

**Description:**
`SettingsScreen` contains hardcoded strings `'/settings/backend-versions'` and
`'/settings/network'` rather than using centralized route constants.

**Suggested Action:**
Move route strings to centralized Route Config/Constants file.

---

### App Shell - Duplicated Error Handling

**Source:** components/01-app-shell.md
**Severity:** Low
**Type:** Refactoring

**Description:**
`HomeScreen` manually catches 5 different exception types to format error messages.
This pattern likely repeats elsewhere.

**Suggested Action:**
Create a shared `ErrorHandler` or `ExceptionMapper` utility.

---

### Authentication - AuthNotifier God Class

**Source:** components/02-authentication.md
**Severity:** Medium
**Type:** Refactoring

**Description:**
`AuthNotifier` handles: state machine management, storage persistence orchestration,
refresh logic, and error handling policy. Approaching "God Class" status.

**Suggested Action:**
Extract storage orchestration logic into an `AuthenticationRepository` class.

---

### Authentication - WebAuthStorage XSS Vulnerability

**Source:** components/02-authentication.md
**Severity:** Medium
**Type:** Tech Debt

**Description:**
`WebAuthStorage` uses `localStorage` which is vulnerable to XSS. Comments acknowledge
this ("acceptable for this internal tool") but it remains security debt.

**Suggested Action:**
Document risk acceptance or migrate to HttpOnly cookies via BFF.

---

### Authentication - Brittle Reinstall Detection

**Source:** components/02-authentication.md
**Severity:** Low
**Type:** Tech Debt

**Description:**
`NativeAuthStorage` uses `shared_preferences` "first_run" flag for iOS Keychain
cleanup on reinstall. Heuristic may misfire if user clears app data without reinstall.

**Suggested Action:**
Document edge cases or investigate alternative detection methods.

---

### Authentication - Hardcoded BFF Login Path

**Source:** components/02-authentication.md
**Severity:** Low
**Type:** Tech Debt

**Description:**
`WebAuthFlow` hardcodes backend login path: `/api/login/${issuer.id}?return_to=...`.
Contract should be defined in `soliplex_client` or `OidcIssuer` configuration.

**Suggested Action:**
Move URL construction to configuration or client package.

---

### Authentication - Unclear exitNoAuthMode Semantics

**Source:** components/02-authentication.md
**Severity:** Low
**Type:** Enhancement

**Description:**
`AuthNotifier.exitNoAuthMode()` docs say "transition to less privileged state without
token cleanup" but implications of leaving tokens in storage while Unauthenticated are vague.

**Suggested Action:**
Clarify documentation or consider clearing tokens on exit.

---

### Authentication - Duplicate Refresh Logic

**Source:** components/02-authentication.md
**Severity:** Low
**Type:** Refactoring

**Description:**
`AuthNotifier._tryRefreshStoredTokens` and `AuthNotifier.tryRefresh` have similar logic
(refresh -> apply result) but different error handling (startup vs runtime).

**Suggested Action:**
Consolidate into strategy within `TokenRefreshService`.

---

### Authentication - AuthCallbackScreen Mixed Concerns

**Source:** components/02-authentication.md
**Severity:** Medium
**Type:** Refactoring

**Description:**
`AuthCallbackScreen` mixes UI with complex auth flow logic (error parsing, notifier calls,
navigation). View should be dumb.

**Suggested Action:**
Move `_processCallback` logic to `AuthNotifier` or dedicated `CallbackLogic` class.

---

### Authentication - LoginScreen Ephemeral State

**Source:** components/02-authentication.md
**Severity:** Low
**Type:** Tech Debt

**Description:**
`LoginScreen` uses local `setState` for `_errorMessage` and `_isAuthenticating`. State
is lost if user navigates away during async gap.

**Suggested Action:**
Move loading/error state to `authProvider` state.

---

### Authentication - TokenRefreshService Swallows Exceptions

**Source:** components/02-authentication.md
**Severity:** Low
**Type:** Tech Debt

**Description:**
`TokenRefreshService.refresh` catches generic exceptions and returns `unknownError`
without logging stack trace.

**Suggested Action:**
Add logging or rethrow specific critical errors for observability.

---

### State Management - api_provider.dart High Coupling

**Source:** components/03-state-management-core.md
**Severity:** Medium
**Type:** Refactoring

**Description:**
`api_provider.dart` defines base client, auth client, transport, API instance, AND
AG-UI client. Changing AG-UI logic requires editing core API provider file.

**Suggested Action:**
Move `agUiClientProvider` to dedicated `ag_ui_providers.dart`. Move `httpClientProvider`
adapter to separate infrastructure file.

---

### State Management - BackendVersionsScreen Embedded Logic

**Source:** components/03-state-management-core.md
**Severity:** Low
**Type:** Refactoring

**Description:**
Package filtering logic (`_filterPackages`) and state (`_searchQuery`) embedded in
widget state rather than extracted provider.

**Suggested Action:**
Extract to `backendVersionsControllerProvider` (autoDispose StateNotifier) for
testability.

---

### State Management - Manual Dependency Graph in Comments

**Source:** components/03-state-management-core.md
**Severity:** Low
**Type:** Tech Debt

**Description:**
`apiProvider` doc comment contains manual ASCII dependency graph that will drift
from reality as imports change.

**Suggested Action:**
Remove manual diagram, rely on code structure or generated diagrams.

---

### Active Run - Mixed Concerns in Notifier

**Source:** components/04-active-run-streaming.md
**Severity:** Medium
**Type:** Refactoring

**Description:**
`ActiveRunNotifier` handles API creation, stream management, state mapping, AND
citation extraction logic. Too many responsibilities in one class.

**Suggested Action:**
Extract citation correlation and cache sync into `RunCompletionService`.

---

### Active Run - Brittle Cache Assumption

**Source:** components/04-active-run-streaming.md
**Severity:** Medium
**Type:** Tech Debt

**Description:**
`startRun` comments note relying on "normal UI flow" to ensure cache is populated
rather than explicit data guarantees. Risky if deep-linking introduced.

**Suggested Action:**
Add safety fetch from backend when cache is empty.

---

### Active Run - Inconsistent DI Style

**Source:** components/04-active-run-streaming.md
**Severity:** Low
**Type:** Tech Debt

**Description:**
`ActiveRunNotifier` reads `agUiClientProvider` in `build()` but reads `apiProvider`
and `threadHistoryCacheProvider` dynamically inside methods. Inconsistent pattern.

**Suggested Action:**
Standardize on one DI approach (all in build vs all dynamic).

---

### Thread Management - Manual Equality Implementation

**Source:** components/05-thread-management.md
**Severity:** Low
**Type:** Tech Debt

**Description:**
Sealed classes `ThreadSelection` and `LastViewed` manually implement `==` and `hashCode`.
Brittle and error-prone as fields are added.

**Suggested Action:**
Migrate to `freezed` or `equatable`, or add unit tests covering equality.

---

### Thread Management - ThreadHistoryCache Mixed Concerns

**Source:** components/05-thread-management.md
**Severity:** Low
**Type:** Refactoring

**Description:**
`ThreadHistoryCache` mixes fetching logic (API calls), state holding (Map), and
concurrency management (_inFlightFetches).

**Suggested Action:**
Monitor complexity; extract API fetching strategy if caching grows complex.

---

### Room Management - Brittle Thread Selection

**Source:** components/06-room-management.md
**Severity:** Medium
**Type:** Refactoring

**Description:**
`RoomScreen._initializeThreadSelection` mixes UI lifecycle (initState, mounted checks)
with complex business logic (thread selection priority).

**Suggested Action:**
Move to `ThreadAutoSelector` controller or FutureProvider returning initialThreadId.

---

### Room Management - Quiz Logic in RoomScreen

**Source:** components/06-room-management.md
**Severity:** Low
**Type:** Refactoring

**Description:**
`_showQuizPicker` and `_buildQuizButton` add unrelated domain logic to layout screen.

**Suggested Action:**
Move to dedicated `RoomAppBarActions` widget.

---

### Room Management - Large LayoutBuilder Closure

**Source:** components/06-room-management.md
**Severity:** Low
**Type:** Tech Debt

**Description:**
`RoomsScreen` LayoutBuilder contains large anonymous closure for grid/list switching.

**Suggested Action:**
Extract to separate `RoomListBuilder` widget.

---

### Document Selection - No State Persistence

**Source:** components/07-document-selection.md
**Severity:** Low
**Type:** Enhancement

**Description:**
`SelectedDocumentsNotifier` is in-memory only. Selections lost on app restart.

**Suggested Action:**
Consider if persistence is required for draft states.

---

### Document Selection - No Automatic Cleanup

**Source:** components/07-document-selection.md
**Severity:** Low
**Type:** Tech Debt

**Description:**
While `clearForRoom` exists, no automatic trigger to call it. Long sessions may
accumulate stale entries if threads deleted.

**Suggested Action:**
Add cleanup trigger on thread deletion or room exit.

---

### Chat UI - ChatPanel God Class

**Source:** components/08-chat-ui.md
**Severity:** Medium
**Type:** Refactoring

**Description:**
`ChatPanel` handles UI layout, thread creation, error handling, pending documents,
and routing. Too many responsibilities.

**Suggested Action:**
Extract thread creation + document transfer logic to `ThreadController`.

---

### Chat UI - Private Result Type

**Source:** components/08-chat-ui.md
**Severity:** Low
**Type:** Refactoring

**Description:**
`Result<T>` sealed class defined privately in `chat_panel.dart`. Useful pattern
but not reusable.

**Suggested Action:**
Move to `core/utils` or `core/types` for reuse across app.

---

### Chat UI - Embedded DocumentPickerDialog

**Source:** components/08-chat-ui.md
**Severity:** Low
**Type:** Refactoring

**Description:**
`ChatInput` contains private `_DocumentPickerDialog` class. Complex enough for
extraction.

**Suggested Action:**
Extract to `features/chat/widgets/document_picker_dialog.dart`.

---

### Chat UI - Brittle Citation Index Math

**Source:** components/08-chat-ui.md
**Severity:** Medium
**Type:** Tech Debt

**Description:**
Citation correlation relies on `index - 1` to find User Message ID. Will break
if message list structure changes (date separators, system alerts).

**Suggested Action:**
Link citations directly to Assistant message ID or make lookup more robust.

---

### HTTP Inspector - Inefficient Grouping

**Source:** components/09-http-inspector.md
**Severity:** Medium
**Type:** Refactoring

**Description:**
`groupHttpEvents` is O(N) and runs on every build. With 500 items, causes main-thread
jank during high-traffic periods.

**Suggested Action:**
Move grouping logic to Provider<List<HttpEventGroup>> watching log provider.

---

### HTTP Inspector - No Search/Filtering

**Source:** components/09-http-inspector.md
**Severity:** Low
**Type:** Enhancement

**Description:**
No mechanism to filter requests by method, status, or URL text.

**Suggested Action:**
Add filter controls to NetworkInspectorScreen.

---

### HTTP Inspector - No Body Truncation

**Source:** components/09-http-inspector.md
**Severity:** Medium
**Type:** Tech Debt

**Description:**
No logic to handle massive response bodies. JsonEncoder on 5MB response will freeze UI.

**Suggested Action:**
Add body size limits and truncation with "show full" option.

---

### Configuration - SharedPreferences Direct Access

**Source:** components/10-configuration.md
**Severity:** Low
**Type:** Tech Debt

**Description:**
`ConfigNotifier` directly calls `SharedPreferences.getInstance()` in `setBaseUrl`.
Makes unit testing persistence logic difficult.

**Suggested Action:**
Inject a StorageService or PersistenceInterface.

---

### Configuration - SoliplexConfig God Object Risk

**Source:** components/10-configuration.md
**Severity:** Low
**Type:** Tech Debt

**Description:**
`SoliplexConfig` may become bloated as more subsystems (Auth, Push, Analytics) added.

**Suggested Action:**
Monitor size; consider breaking into CoreConfig and ModuleConfig maps.

---

### Design System - Layer Violation in Typography

**Source:** components/11-design-system.md
**Severity:** Low
**Type:** Tech Debt

**Description:**
`typography_x.dart` imports `shared/utils/platform_resolver.dart`. Design System
should be lowest layer; creates potential circular dependency risk.

**Suggested Action:**
Move platform detection to Design layer or inject via parameter.

---

### Design System - Hardcoded Font Names

**Source:** components/11-design-system.md
**Severity:** Low
**Type:** Tech Debt

**Description:**
`typography_x.dart` has hardcoded strings for SF Mono and Roboto Mono.

**Suggested Action:**
Make font names configurable tokens.

---

### Shared Widgets - ErrorDisplay Layer Violation

**Source:** components/12-shared-widgets.md
**Severity:** Medium
**Type:** Refactoring

**Description:**
`error_display.dart` imports `thread_history_cache.dart`. Shared widgets should not
know about specific feature exceptions like `HistoryFetchException`.

**Suggested Action:**
Create generic `WrapperException` interface in core for ErrorDisplay to inspect.

---

### Shared Widgets - AppShell Feature Dependency

**Source:** components/12-shared-widgets.md
**Severity:** Medium
**Type:** Refactoring

**Description:**
`app_shell.dart` imports `HttpInspectorPanel` from features. Shared depends on features.

**Suggested Action:**
Pass inspector widget builder via provider or DI to invert dependency.

---

### Shared Widgets - Magic Numbers in AppShell

**Source:** components/12-shared-widgets.md
**Severity:** Low
**Type:** Tech Debt

**Description:**
`_getDrawerWidth` contains hardcoded magic numbers (600, 400).

**Suggested Action:**
Move to SoliplexBreakpoints or layout constants.

---

### Client Domain - Schema Export Leak

**Source:** components/13-client-domain.md
**Severity:** Low
**Type:** Tech Debt

**Description:**
`domain.dart` exports generated schema files. Domain layer should not leak
implementation details (schemas) directly. Marked with TODO comment in code.

**Suggested Action:**
Remove schema exports after AG-UI state management refactor.

---

### Client Domain - Weak aguiState Typing

**Source:** components/13-client-domain.md
**Severity:** Low
**Type:** Tech Debt

**Description:**
`Conversation.aguiState` is `Map<String, dynamic>`. Lacks type safety present
in rest of domain.

**Suggested Action:**
Consider typed AG-UI state representation.

---

### Client HTTP - Hardcoded Redaction Keys

**Source:** components/14-client-http.md
**Severity:** Medium
**Type:** Tech Debt

**Description:**
`HttpRedactor` contains hardcoded sensitive field lists. If backend API schema
changes, fields may be logged in plaintext.

**Suggested Action:**
Move sensitive keys to configuration object injected at startup.

---

### Client HTTP - Inconsistent Auth Abstractions

**Source:** components/14-client-http.md
**Severity:** Low
**Type:** Refactoring

**Description:**
`AuthenticatedHttpClient` uses raw callback for tokens while `RefreshingHttpClient`
uses `TokenRefresher` interface. Inconsistent patterns.

**Suggested Action:**
Unify both to use `TokenRefresher` interface.

---

### Client HTTP - Brittle Refresh Concurrency

**Source:** components/14-client-http.md
**Severity:** Medium
**Type:** Tech Debt

**Description:**
`RefreshingHttpClient._tryRefreshOnce` uses Completer with implicit single-threaded
assumptions. Brittle critical sequence; could cause refresh storms if modified.

**Suggested Action:**
Ensure high test coverage for concurrency scenarios.

---

### Client API - Synthetic User Message Events

**Source:** components/15-client-api.md
**Severity:** Medium
**Type:** Tech Debt

**Description:**
`_extractUserMessageEvents` synthesizes TEXT_MESSAGE events from `run_input`
because backend separates input from event stream. Brittle if run_input changes.

**Suggested Action:**
Document backend contract or request unified event stream.

---

### Client API - LRU Cache Implementation

**Source:** components/15-client-api.md
**Severity:** Low
**Type:** Tech Debt

**Description:**
`_runEventsCache` relies on LinkedHashMap iteration order for LRU eviction.
Implicit assumption on map implementation.

**Suggested Action:**
Consider explicit LRU tracking or use dedicated cache package.

---

### Client Application - Incomplete JSON Patch

**Source:** components/16-client-application.md
**Severity:** Low
**Type:** Tech Debt

**Description:**
`json_patch.dart` only implements add/replace/remove. Ignores move/copy/test
from RFC 6902.

**Suggested Action:**
Implement remaining operations or document limitations.

---

### Client Application - Duplicate Streaming Guard

**Source:** components/16-client-application.md
**Severity:** Low
**Type:** Refactoring

**Description:**
`_processTextContent` and `_processTextEnd` share streaming guard pattern.
TODO comment in code suggests extraction.

**Suggested Action:**
Extract shared guard logic.

---

### Native Platform - Missing Lifecycle Handling

**Source:** components/18-native-platform.md
**Severity:** Low
**Type:** Enhancement

**Description:**
`WakelockPlusAdapter` comments mention app lifecycle handling (re-enable on
foreground) but code does not implement WidgetsBindingObserver.

**Suggested Action:**
Implement lifecycle observer or remove comment.

---

### Native Platform - Exception-Based Test Fallback

**Source:** components/18-native-platform.md
**Severity:** Low
**Type:** Tech Debt

**Description:**
`createPlatformClientImpl` uses try-catch around CupertinoHttpClient as fallback
for testing. Relies on runtime exceptions.

**Suggested Action:**
Use explicit DI or distinct testing entry point.

---

### Quiz Feature - QuizScreen God Widget

**Source:** components/20-quiz-feature.md
**Severity:** Medium
**Type:** Refactoring

**Description:**
`QuizScreen` is ~400 lines. `_buildQuestionScreen`, `_buildMultipleChoice`,
`_buildResultsScreen` should be extracted.

**Suggested Action:**
Extract to `QuizQuestionView`, `QuizResultsView` widgets.

---

### Quiz Feature - Complex Color Logic

**Source:** components/20-quiz-feature.md
**Severity:** Low
**Type:** Refactoring

**Description:**
`_buildMultipleChoice` contains complex color state logic (Correct, Wrong, Selected).

**Suggested Action:**
Move to helper function or view-model.

---

### Quiz Feature - View-Layer Error Handling

**Source:** components/20-quiz-feature.md
**Severity:** Low
**Type:** Tech Debt

**Description:**
`_submitAnswer` handles specific exception subtypes in View layer. Extensive
error handling in View can become brittle.

**Suggested Action:**
Consider consolidating error mapping in provider layer.
