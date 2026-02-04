# Architecture Documentation Maintenance

This document defines how to keep architecture documentation synchronized with
code changes and how to validate architectural patterns programmatically.

---

## Problem Statement

Architecture documentation drifts from code because:

1. **File inventory changes** - Files are added, removed, renamed, or moved
2. **Provider landscape shifts** - New providers added, existing ones changed
3. **Cross-references break** - Import relationships change silently
4. **Pattern violations creep in** - Consistency degrades over time

But documentation drift is a **symptom**. The deeper problems are:

- **Logic Leaks ("Fat UI")** - Business orchestration lives in Widget methods
  instead of providers. Example: `ChatPanel._handleSend` contains ~60 lines
  of thread creation, state sync, persistence, and navigation logic.

- **WidgetRef Pollution** - Helper functions accept `WidgetRef` instead of `Ref`,
  coupling business logic to the Flutter widget layer. Example:
  `selectAndPersistThread(WidgetRef ref)` in `threads_provider.dart:274`.

- **Missing Controller Layer** - No dedicated providers own multi-step workflows
  (create thread → start run → navigate). UI fills this gap poorly.

Manual synchronization is error-prone. We need automated validation AND
architectural rules that prevent these violations.

---

## Documentation Layers

| Layer | Source of Truth | Validation Method |
|-------|-----------------|-------------------|
| File Inventory | `lib/**/*.dart`, `packages/**/*.dart` | Script: glob vs FILE_INVENTORY.md |
| Provider Registry | `*_provider.dart` files | Script: AST extraction |
| Cross-References | `import` statements | Script: import graph analysis |
| Pattern Compliance | Code structure | Dart analyzer + custom lint rules |
| API Surface | `///` doc comments | `dart doc` generation |

---

## Dart Doc vs Manual Documentation

### Current State

- `analysis_options.yaml` has `public_member_api_docs: false`
- No `dartdoc_options.yaml` exists
- 772 doc comment instances exist across provider files

### Recommendation: Hybrid Approach

**Use `dart doc` for:**

- Public API surface (exported classes, methods, parameters)
- Package boundaries (`soliplex_client`, `soliplex_client_native`)
- Contract documentation (interfaces, abstract classes)

**Use manual docs for:**

- High-level architecture (component relationships)
- Cross-cutting patterns (decorator chain, state machine flows)
- Rationale and trade-offs (why decisions were made)
- Operational knowledge (error handling strategies)

### Why Not Pure dart doc?

`dart doc` excels at **what** but not **why** or **how components relate**:

```dart
/// Provides the authenticated HTTP client with token injection.
final authenticatedClientProvider = Provider<SoliplexHttpClient>(...);
```

This tells you what it does but not:

- Where it fits in the decorator chain
- Why it exists separate from `baseHttpClientProvider`
- How it interacts with `tokenRefreshServiceProvider`

Component docs capture these relationships.

### Migration Path

1. Enable `public_member_api_docs: true` for `soliplex_client` package (pure Dart)
2. Keep it disabled for Flutter app (too noisy for internal code)
3. Generate dart doc for packages: `dart doc packages/soliplex_client`
4. Link from component docs to generated API docs

---

## DCM (Dart Code Metrics) Integration

DCM is a static analysis plugin that enforces metrics and architectural rules
beyond what the standard Dart analyzer provides. It directly automates many
of the pattern rules defined in this document.

### Installation

```yaml
# pubspec.yaml
dev_dependencies:
  dcm: ^1.0.0  # Check https://dcm.dev for latest version
```

### Configuration

Add to `analysis_options.yaml`:

```yaml
analyzer:
  plugins:
    - dcm

dcm:
  # Complexity thresholds
  metrics:
    cyclomatic-complexity: 15
    lines-of-code: 50
    number-of-parameters: 5
    maximum-nesting-level: 4

  rules:
    # Rule 7: No Fat UI - limit widget build method size
    - lines-of-code-in-widget-build:
        threshold: 40

    # Rule 7: Detect long methods (like _handleSend)
    - long-method:
        lines-of-code: 50
        cyclomatic-complexity: 15

    # Rule 6: Prevent WidgetRef in provider layer
    - avoid-banned-imports:
        entries:
          # Providers should not import flutter_riverpod (only riverpod)
          - from: "package:soliplex_frontend/core/providers/**"
            banned: "package:flutter_riverpod/flutter_riverpod.dart"
            reason: "Providers must use Ref, not WidgetRef. Import riverpod instead."

          # Domain layer must be framework-agnostic
          - from: "package:soliplex_frontend/core/domain/**"
            banned: "package:flutter/**"
            reason: "Domain layer must not depend on Flutter."

          # Client package must stay pure Dart
          - from: "package:soliplex_client/**"
            banned: "package:flutter/**"
            reason: "soliplex_client must be pure Dart with no Flutter dependencies."

    # Additional quality rules
    - prefer-immediate-return
    - avoid-redundant-async
    - avoid-unnecessary-type-assertions
```

### DCM Rules Mapped to MAINTENANCE.md

| MAINTENANCE.md Rule | DCM Rule | Threshold |
|---------------------|----------|-----------|
| Rule 6: The Ref Rule | `avoid-banned-imports` | Block `flutter_riverpod` in providers |
| Rule 7: No Business Logic in Widgets | `lines-of-code-in-widget-build` | 40 lines |
| Rule 7: No Fat Methods | `long-method` | 50 lines, complexity 15 |
| (General) | `cyclomatic-complexity` | 15 |
| (General) | `maximum-nesting-level` | 4 |

### Running DCM

```bash
# Check all files
dcm check lib

# Check specific path
dcm check lib/features/chat

# Generate report
dcm check lib --reporter=html --output=dcm_report.html
```

### CI Integration

Add to your CI pipeline:

```yaml
# .github/workflows/ci.yml
- name: Run DCM
  run: |
    dart pub global activate dcm
    dcm check lib --fatal-style --fatal-performance --fatal-warnings
```

### Current Violations (Baseline)

When DCM is first enabled, expect these violations from known issues:

| File | Rule | Violation |
|------|------|-----------|
| `chat_panel.dart` | `long-method` | `_handleSend` exceeds 50 lines |
| `room_screen.dart` | `long-method` | `_initializeThreadSelection` complexity |
| `threads_provider.dart` | `avoid-banned-imports` | Uses `flutter_riverpod` |
| `quiz_screen.dart` | `lines-of-code-in-widget-build` | Build method too long |

These should be remediated as part of Phase 1 (Fix Architectural Violations).

---

## Automated Validation Scripts

### 1. File Inventory Validator

**Purpose:** Detect files added/removed/moved since last documentation update.

**Script location:** `tool/validate_file_inventory.dart`

```dart
// tool/validate_file_inventory.dart
import 'dart:io';

void main() async {
  final inventoryFiles = parseFileInventory('docs/planning/FILE_INVENTORY.md');
  final actualFiles = await globDartFiles(['lib', 'packages']);

  final missing = actualFiles.difference(inventoryFiles);
  final orphaned = inventoryFiles.difference(actualFiles);

  if (missing.isNotEmpty) {
    print('FILES NOT IN INVENTORY:');
    missing.forEach(print);
  }

  if (orphaned.isNotEmpty) {
    print('ORPHANED INVENTORY ENTRIES:');
    orphaned.forEach(print);
  }

  exit(missing.isEmpty && orphaned.isEmpty ? 0 : 1);
}
```

**Run:** `dart run tool/validate_file_inventory.dart`

### 2. Provider Registry Extractor

**Purpose:** Extract all provider definitions for documentation comparison.

**Output format:**

```yaml
providers:
  - name: apiProvider
    file: lib/core/providers/api_provider.dart
    line: 157
    type: Provider<SoliplexApi>
    pattern: infrastructure
  - name: activeRunNotifierProvider
    file: lib/core/providers/active_run_notifier.dart
    line: 31
    type: NotifierProvider<ActiveRunNotifier, ActiveRunState>
    pattern: state-machine
```

**Extraction approach:**

```dart
// Use analyzer package to parse AST
final collection = AnalysisContextCollection(includedPaths: [libPath]);
for (final context in collection.contexts) {
  for (final file in context.contextRoot.analyzedFiles()) {
    final result = await context.currentSession.getResolvedUnit(file);
    // Find top-level variables with Provider type annotations
    // Extract name, type, line number
  }
}
```

### 3. Cross-Reference Validator

**Purpose:** Verify documented dependencies match actual imports.

**Approach:**

1. Parse component doc "Depends On" / "Used By" sections
2. Extract actual imports from source files
3. Map imports to component numbers
4. Report mismatches

---

## Provider Pattern Guidelines

### Current Provider Count: 45+

Based on analysis, providers fall into these categories:

| Category | Count | Pattern |
|----------|-------|---------|
| Infrastructure (HTTP, API) | 10 | Decorator chain |
| Feature State (Active Run, Quiz) | 8 | NotifierProvider with state machine |
| Data Fetch (Rooms, Threads, Docs) | 6 | FutureProvider or FutureProvider.family |
| Computed/Derived | 12 | Provider watching other providers |
| Selection/UI State | 5 | Simple Notifier with set/clear |
| Services | 4 | Provider returning service instance |

### Pattern Rules

#### Rule 1: Provider Naming Convention

```text
<domain><Type>Provider

Examples:
- apiProvider (infrastructure)
- roomsProvider (data fetch)
- currentRoomProvider (computed)
- activeRunNotifierProvider (state machine - includes "Notifier")
```

**Validation:** Regex pattern matching on provider names.

#### Rule 2: One Responsibility Per Provider

Providers should do ONE thing:

| Good | Bad |
|------|-----|
| `roomsProvider` - fetches rooms | `roomsAndThreadsProvider` - fetches both |
| `currentRoomIdProvider` - holds ID | `currentRoomWithThreadsProvider` - fetches and combines |

**Exception:** Decorator providers (e.g., `authenticatedClientProvider`) add ONE concern.

#### Rule 3: Business Logic Location

| Logic Type | Location | Example |
|------------|----------|---------|
| API calls | FutureProvider or Notifier method | `roomsProvider` |
| State transitions | NotifierProvider | `ActiveRunNotifier.startRun()` |
| Computed values | Provider with `ref.watch()` | `canSendMessageProvider` |
| Side effects | Notifier methods | `AuthNotifier.login()` |

**Anti-pattern:** Business logic in widgets (`_connect()` method in HomeScreen).

#### Rule 4: Derived Providers Use `select()` or Separate Provider

When you need a subset of state:

```dart
// Option A: select() for simple projections
final tokenProvider = Provider<String?>((ref) {
  return ref.watch(authProvider.select((s) => s.accessToken));
});

// Option B: Separate provider for complex derivation
final canSendMessageProvider = Provider<bool>((ref) {
  final room = ref.watch(currentRoomProvider);
  final run = ref.watch(activeRunNotifierProvider);
  final thread = ref.watch(threadSelectionProvider);
  // Complex logic combining multiple sources
  return ...;
});
```

**Avoid:** Creating providers that just extract a field.

#### Rule 5: Family Providers for Parameterized Access

```dart
// Correct: Family for per-entity data
final threadsProvider = FutureProvider.family<List<Thread>, String>((ref, roomId) async {
  return ref.watch(apiProvider).getThreads(roomId);
});

// Incorrect: Storing room-specific data in non-family provider
final threadsProvider = FutureProvider<List<Thread>>((ref) async {
  final roomId = ref.watch(currentRoomIdProvider); // Coupling!
  return ref.watch(apiProvider).getThreads(roomId!);
});
```

#### Rule 6: The Ref Rule (CRITICAL)

**Business logic functions must accept `Ref`, never `WidgetRef`.**

`WidgetRef` is a UI-layer type. Functions requiring `WidgetRef` cannot be called
by other providers (which use `Ref`), forcing orchestration into widgets.

```dart
// WRONG: Couples business logic to widget layer
void selectAndPersistThread(WidgetRef ref, String roomId, String threadId) {
  // This function CANNOT be called from another provider
  ref.read(threadSelectionProvider.notifier).set(...);
}

// CORRECT: Move logic into the Notifier itself
class ThreadSelectionNotifier extends Notifier<ThreadSelection> {
  Future<void> selectAndPersist(String roomId, String threadId) async {
    state = ThreadSelected(threadId);
    // Handle persistence via ref.read() internally
  }
}
```

**Current violations:**

| Function | File | Line |
|----------|------|------|
| `selectAndPersistThread` | `threads_provider.dart` | 256 |
| `selectThread` | `threads_provider.dart` | 277 |

#### Rule 7: No Business Logic in Widgets

Widgets should only:

- Watch providers and render state
- Dispatch actions to providers
- Handle navigation (but not decide WHEN to navigate)

**Anti-patterns found:**

| Widget | Method | Lines | Violation |
|--------|--------|-------|-----------|
| `ChatPanel` | `_handleSend` | 164-255 | Creates thread, syncs state, persists, navigates, starts run |
| `RoomScreen` | `_initializeThreadSelection` | 60-99 | Thread selection fallback logic |
| `HomeScreen` | `_connect` | ~80 lines | Connection orchestration |

**Solution:** Create Controller providers for multi-step workflows.

```dart
// Instead of ChatPanel._handleSend doing everything:
final chatControllerProvider = NotifierProvider<ChatController, void>(() => ChatController());

class ChatController extends Notifier<void> {
  Future<void> sendMessage({
    required String text,
    required String roomId,
    required ThreadSelection selection,
    void Function(String threadId)? onThreadCreated,
  }) async {
    // 1. Create thread if needed
    // 2. Update selection state
    // 3. Persist last viewed
    // 4. Start run
    // 5. Call onThreadCreated for navigation (side effect only)
  }
}

// Widget becomes thin:
Future<void> _handleSend(String text) async {
  await ref.read(chatControllerProvider.notifier).sendMessage(
    text: text,
    roomId: roomId,
    selection: ref.read(threadSelectionProvider),
    onThreadCreated: (id) => context.go('/rooms/$roomId?thread=$id'),
  );
}
```

---

## Known Architectural Violations

These are the current violations of the pattern rules. Track remediation progress.

### Fat UI Violations (Rule 7)

| Priority | Widget | Method | Issue | Remediation |
|----------|--------|--------|-------|-------------|
| P0 | `ChatPanel` | `_handleSend` | 60+ lines of orchestration | Extract to `ChatController` |
| P1 | `RoomScreen` | `_initializeThreadSelection` | Selection fallback logic | Extract to `ThreadResolver` provider |
| P1 | `HomeScreen` | `_connect` | Connection flow logic | Extract to `ConnectionController` |

### WidgetRef Violations (Rule 6)

| Priority | Function | File | Remediation |
|----------|----------|------|-------------|
| P0 | `selectAndPersistThread` | `threads_provider.dart:256` | Move to `ThreadSelectionNotifier` |
| P0 | `selectThread` | `threads_provider.dart:277` | Move to `ThreadSelectionNotifier` |

### Missing Controller Layer

| Workflow | Current Location | Proposed Provider |
|----------|------------------|-------------------|
| Send Message | `ChatPanel._handleSend` | `chatControllerProvider` |
| Initialize Room | `RoomScreen._initializeThreadSelection` | `roomInitializerProvider` |
| Connect to Backend | `HomeScreen._connect` | `connectionControllerProvider` |

---

## Provider Questions Answered

### Q: Are providers solely performing UI work?

**No.** Analysis shows heavy business logic:

- `ActiveRunNotifier` (506 lines) - orchestrates AG-UI streaming
- `QuizSessionNotifier` (184 lines) - full quiz state machine
- `authenticatedClientProvider` - handles 401 retry, token refresh
- `ThreadHistoryCache` - manages fetch deduplication, cache sync

Only 5 providers are pure UI state (selection, expand/collapse).

### Q: Are we excessively using providers?

**Borderline.** 45+ providers is substantial but justified by:

- Clear separation of concerns (each does one thing)
- Decorator pattern for HTTP (necessary layering)
- Family providers for per-entity access

**Consolidation opportunities:**

1. Auth-derived providers (5 providers) could use `.select()`
2. Room/Thread selection pattern duplicated
3. `quiz_provider.dart` (621 lines) should split into 3 files

### Q: Do we have a clear pattern that is being consistent?

**Yes, with exceptions:**

**Consistent patterns:**

- NotifierProvider for stateful features
- FutureProvider for API calls
- Decorator chain for HTTP
- Family for parameterized data

**Inconsistent areas:**

- URL building (3 different approaches)
- Message fallback logic (2 different patterns)
- DI style in ActiveRunNotifier (mixed build() vs dynamic)

---

## Component 03 Deep Dive: State Management Core

Selected as the focal example because it contains the provider infrastructure.

**Note:** While this component has file organization issues (api_provider.dart
overloaded), these are **lower priority** than the Fat UI violations in
ChatPanel, RoomScreen, and HomeScreen. Fix architectural violations first.

### Current Structure (5 files)

```text
lib/core/providers/
├── api_provider.dart           # 220 lines, 8 providers
├── backend_health_provider.dart # 50 lines, 1 provider
├── backend_version_provider.dart # 25 lines, 1 provider
├── infrastructure_providers.dart # 15 lines, 2 providers
lib/features/settings/
└── backend_versions_screen.dart  # UI (misplaced in component?)
```

### Issues Identified

1. **api_provider.dart is overloaded** (8 providers, 220 lines)
   - HTTP clients, transport, API, AG-UI client all in one file

2. **backend_versions_screen.dart doesn't belong** in State Management Core
   - It's a UI screen, not state infrastructure

3. **No separation between concerns:**
   - Core infrastructure (clients, transport)
   - API access (apiProvider, urlBuilder)
   - Streaming (agUiClientProvider)

### Recommended Refactor

```text
lib/core/providers/
├── http/
│   ├── http_client_provider.dart      # base + observable + authenticated
│   └── http_transport_provider.dart   # transport + url builder
├── api/
│   ├── api_provider.dart              # apiProvider only
│   └── ag_ui_provider.dart            # agUiClientProvider
├── health/
│   ├── backend_health_provider.dart
│   └── backend_version_provider.dart
└── infrastructure_providers.dart       # wake lock, lifecycle
```

### Documentation Sync Points

For Component 03, track changes at:

| Change Type | Detection | Update Required |
|-------------|-----------|-----------------|
| New provider added | Provider registry script | Add to Public API table |
| Provider renamed | Provider registry diff | Update Public API + references |
| File moved | File inventory validator | Update Files table |
| Import changed | Cross-reference validator | Update Dependencies section |
| Pattern changed | Manual review | Update Flow/Patterns section |

---

## Maintenance Workflow

### On Every PR

1. Run file inventory validator
2. Run provider registry extractor (diff against last known)
3. If changes detected, update relevant component doc

### Weekly

1. Regenerate cross-reference graph
2. Compare against documented "Depends On" / "Used By"
3. Review BACKLOG.md for items now addressed

### On Major Refactor

1. Re-run full documentation generation (M01-M24 workflow)
2. Update FILE_INVENTORY.md
3. Archive old component docs with date suffix

---

## Implementation Priority

### Phase 0: Enable DCM (IMMEDIATE)

DCM automates enforcement of architectural rules. Enable it first.

| Priority | Task | Effort | Impact |
|----------|------|--------|--------|
| P0 | Add `dcm` to dev_dependencies | Low | Enables static analysis |
| P0 | Configure `analysis_options.yaml` with DCM rules | Low | Immediate feedback |
| P0 | Run `dcm check lib` to establish baseline | Low | Know current violations |

### Phase 1: Fix Architectural Violations (HIGH PRIORITY)

These directly impact code quality and testability. Fix DCM violations.

| Priority | Task | Effort | Impact |
|----------|------|--------|--------|
| P0 | Extract `ChatController` from `ChatPanel._handleSend` | Medium | Testable send workflow |
| P0 | Fix `WidgetRef` violations in `threads_provider.dart` | Low | Composable logic |
| P1 | Extract `RoomInitializer` from `RoomScreen` | Medium | Testable initialization |
| P1 | Extract `ConnectionController` from `HomeScreen` | Medium | Testable connection flow |

### Phase 2: Documentation Tooling

| Priority | Task | Effort |
|----------|------|--------|
| 2 | Create file inventory validator script | Low |
| 3 | Create provider registry extractor | Medium |
| 4 | Add validation to CI/pre-commit | Low |

### Phase 3: Documentation Quality

| Priority | Task | Effort |
|----------|------|--------|
| 5 | Enable dart doc for `soliplex_client` | Low |
| 6 | Create import graph validator (JSON baseline) | Medium |
| 7 | Refactor `api_provider.dart` into subdirectories | Medium |

---

## Maintenance Workflow (Updated)

### On Every PR

1. Run file inventory validator
2. Run provider registry extractor (diff against last known)
3. **NEW:** Check for `WidgetRef` in provider files (grep pattern)
4. **NEW:** Check for methods >50 lines in feature widgets
5. If changes detected, update relevant component doc

### Validation Script: WidgetRef Check

```bash
# Fail if WidgetRef appears in provider files
grep -r "WidgetRef" lib/core/providers/ && exit 1 || exit 0
```

### Validation Script: Fat Widget Check

```bash
# Warn if widget methods exceed threshold
dart run tool/check_widget_method_size.dart --max-lines=50
```

---

## Roles and Responsibilities

| Role | Responsibility |
|------|----------------|
| PR Author | Update component docs if file inventory changes |
| PR Author | Fix validation script failures before merge |
| Reviewer | Verify architectural violations are not introduced |
| Weekly Rotation | Regenerate cross-reference graph, review BACKLOG.md |

---

## Summary

1. **Enable DCM first:** Automated enforcement of architectural rules via static analysis
2. **Fix violations:** Extract Controllers before documenting more
3. **Use hybrid approach:** dart doc for API surface, manual docs for architecture
4. **Automate validation:** DCM + scripts to detect inventory, provider, and pattern drift
5. **Define patterns:** 7 provider rules for consistency (including Ref Rule)
6. **Track violations:** Known violations table with remediation plan
7. **Integrate with workflow:** DCM in CI, validation on PR, deep review weekly
