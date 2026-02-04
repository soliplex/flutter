# M33 - Guidelines: Foundation

## Goal

Add "Contribution Guidelines" section to foundation component docs (6 components).

## Components

| # | Component | Doc File | Source Files |
|---|-----------|----------|--------------|
| 02 | Authentication Flow | components/02-authentication.md | 19 |
| 10 | Configuration | components/10-configuration.md | 8 |
| 11 | Design System | components/11-design-system.md | 10 |
| 12 | Shared Widgets | components/12-shared-widgets.md | 7 |
| 13 | Client: Domain Models | components/13-client-domain.md | 17 |
| 19 | Navigation & Routing | components/19-navigation-routing.md | 1 |

**Total: 6 component docs + 62 source files**

---

## Source File Inventory

### Component 02 - Authentication Flow (19 files)

```text
lib/core/auth/auth_flow.dart
lib/core/auth/auth_flow_native.dart
lib/core/auth/auth_flow_web.dart
lib/core/auth/auth_notifier.dart
lib/core/auth/auth_provider.dart
lib/core/auth/auth_state.dart
lib/core/auth/auth_storage.dart
lib/core/auth/auth_storage_native.dart
lib/core/auth/auth_storage_web.dart
lib/core/auth/callback_params.dart
lib/core/auth/oidc_issuer.dart
lib/core/auth/web_auth_callback.dart
lib/core/auth/web_auth_callback_native.dart
lib/core/auth/web_auth_callback_web.dart
lib/features/auth/auth_callback_screen.dart
lib/features/login/login_screen.dart
packages/soliplex_client/lib/src/domain/auth_provider_config.dart
packages/soliplex_client/lib/src/auth/oidc_discovery.dart
packages/soliplex_client/lib/src/auth/token_refresh_service.dart
```

### Component 10 - Configuration (8 files)

```text
lib/core/models/app_config.dart
lib/core/models/features.dart
lib/core/models/logo_config.dart
lib/core/models/route_config.dart
lib/core/models/soliplex_config.dart
lib/core/models/theme_config.dart
lib/core/providers/config_provider.dart
lib/core/providers/shell_config_provider.dart
```

### Component 11 - Design System (10 files)

```text
lib/design/design.dart
lib/design/color/color_scheme_extensions.dart
lib/design/theme/theme.dart
lib/design/theme/theme_extensions.dart
lib/design/tokens/breakpoints.dart
lib/design/tokens/colors.dart
lib/design/tokens/radii.dart
lib/design/tokens/spacing.dart
lib/design/tokens/typography.dart
lib/design/tokens/typography_x.dart
```

### Component 12 - Shared Widgets (7 files)

```text
lib/shared/widgets/app_shell.dart
lib/shared/widgets/async_value_handler.dart
lib/shared/widgets/empty_state.dart
lib/shared/widgets/error_display.dart
lib/shared/widgets/loading_indicator.dart
lib/shared/widgets/platform_adaptive_progress_indicator.dart
lib/shared/widgets/shell_config.dart
```

### Component 13 - Client: Domain Models (17 files)

```text
packages/soliplex_client/lib/src/domain/auth_provider_config.dart
packages/soliplex_client/lib/src/domain/backend_version_info.dart
packages/soliplex_client/lib/src/domain/chat_message.dart
packages/soliplex_client/lib/src/domain/chunk_visualization.dart
packages/soliplex_client/lib/src/domain/citation_formatting.dart
packages/soliplex_client/lib/src/domain/conversation.dart
packages/soliplex_client/lib/src/domain/domain.dart
packages/soliplex_client/lib/src/domain/message_state.dart
packages/soliplex_client/lib/src/domain/quiz.dart
packages/soliplex_client/lib/src/domain/rag_document.dart
packages/soliplex_client/lib/src/domain/room.dart
packages/soliplex_client/lib/src/domain/run_info.dart
packages/soliplex_client/lib/src/domain/source_reference.dart
packages/soliplex_client/lib/src/domain/thread_history.dart
packages/soliplex_client/lib/src/domain/thread_info.dart
packages/soliplex_client/lib/src/schema/agui_features/filter_documents.dart
packages/soliplex_client/lib/src/schema/agui_features/agui_features.dart
```

### Component 19 - Navigation & Routing (1 file)

```text
lib/core/router/app_router.dart
```

---

## Batching Strategy

### Batch 1: Component 02 (Gemini read_files)

**Files (20):**

```text
docs/planning/components/02-authentication.md
lib/core/auth/auth_flow.dart
lib/core/auth/auth_flow_native.dart
lib/core/auth/auth_flow_web.dart
lib/core/auth/auth_notifier.dart
lib/core/auth/auth_provider.dart
lib/core/auth/auth_state.dart
lib/core/auth/auth_storage.dart
lib/core/auth/auth_storage_native.dart
lib/core/auth/auth_storage_web.dart
lib/core/auth/callback_params.dart
lib/core/auth/oidc_issuer.dart
lib/core/auth/web_auth_callback.dart
lib/core/auth/web_auth_callback_native.dart
lib/core/auth/web_auth_callback_web.dart
lib/features/auth/auth_callback_screen.dart
lib/features/login/login_screen.dart
packages/soliplex_client/lib/src/domain/auth_provider_config.dart
packages/soliplex_client/lib/src/auth/oidc_discovery.dart
packages/soliplex_client/lib/src/auth/token_refresh_service.dart
```

### Batch 2: Components 10 + 11 (Gemini read_files)

**Files (20):**

```text
docs/planning/components/10-configuration.md
docs/planning/components/11-design-system.md
lib/core/models/app_config.dart
lib/core/models/features.dart
lib/core/models/logo_config.dart
lib/core/models/route_config.dart
lib/core/models/soliplex_config.dart
lib/core/models/theme_config.dart
lib/core/providers/config_provider.dart
lib/core/providers/shell_config_provider.dart
lib/design/design.dart
lib/design/color/color_scheme_extensions.dart
lib/design/theme/theme.dart
lib/design/theme/theme_extensions.dart
lib/design/tokens/breakpoints.dart
lib/design/tokens/colors.dart
lib/design/tokens/radii.dart
lib/design/tokens/spacing.dart
lib/design/tokens/typography.dart
lib/design/tokens/typography_x.dart
```

### Batch 3: Components 12 + 19 (Gemini read_files)

**Files (10):**

```text
docs/planning/components/12-shared-widgets.md
docs/planning/components/19-navigation-routing.md
lib/shared/widgets/app_shell.dart
lib/shared/widgets/async_value_handler.dart
lib/shared/widgets/empty_state.dart
lib/shared/widgets/error_display.dart
lib/shared/widgets/loading_indicator.dart
lib/shared/widgets/platform_adaptive_progress_indicator.dart
lib/shared/widgets/shell_config.dart
lib/core/router/app_router.dart
```

### Batch 4: Component 13 (Gemini read_files)

**Files (18):**

```text
docs/planning/components/13-client-domain.md
packages/soliplex_client/lib/src/domain/auth_provider_config.dart
packages/soliplex_client/lib/src/domain/backend_version_info.dart
packages/soliplex_client/lib/src/domain/chat_message.dart
packages/soliplex_client/lib/src/domain/chunk_visualization.dart
packages/soliplex_client/lib/src/domain/citation_formatting.dart
packages/soliplex_client/lib/src/domain/conversation.dart
packages/soliplex_client/lib/src/domain/domain.dart
packages/soliplex_client/lib/src/domain/message_state.dart
packages/soliplex_client/lib/src/domain/quiz.dart
packages/soliplex_client/lib/src/domain/rag_document.dart
packages/soliplex_client/lib/src/domain/room.dart
packages/soliplex_client/lib/src/domain/run_info.dart
packages/soliplex_client/lib/src/domain/source_reference.dart
packages/soliplex_client/lib/src/domain/thread_history.dart
packages/soliplex_client/lib/src/domain/thread_info.dart
packages/soliplex_client/lib/src/schema/agui_features/filter_documents.dart
packages/soliplex_client/lib/src/schema/agui_features/agui_features.dart
```

### Batch 5: MAINTENANCE.md Rules (Gemini read_files)

**Files (1):**

```text
docs/planning/MAINTENANCE.md
```

---

## Tasks

### Phase 1: Pattern Extraction

- [ ] **Task 1.1**: Gemini `read_files` Batch 1 (Component 02)
  - Model: `gemini-3-pro-preview`
  - Files: 20 files (1 .md + 19 .dart)
  - Prompt: "Extract authentication patterns: conditional imports, sealed classes,
    BFF pattern, strategy pattern, control flow exceptions. Identify DO/DON'T
    candidates for authentication components."

- [ ] **Task 1.2**: Gemini `read_files` Batch 2 (Components 10 + 11)
  - Model: `gemini-3-pro-preview`
  - Files: 20 files (2 .md + 18 .dart)
  - Prompt: "Extract configuration patterns: immutable value objects, forced DI,
    layered config. Extract design patterns: token-based design, ThemeExtension,
    barrel exports. Identify DO/DON'T candidates."

- [ ] **Task 1.3**: Gemini `read_files` Batch 3 (Components 12 + 19)
  - Model: `gemini-3-pro-preview`
  - Files: 10 files (2 .md + 8 .dart)
  - Prompt: "Extract shell patterns: wrapper/decorator, configuration object,
    exception mapping. Extract routing patterns: declarative routing, auth guards,
    deep linking. Identify DO/DON'T candidates."

- [ ] **Task 1.4**: Gemini `read_files` Batch 4 (Component 13)
  - Model: `gemini-3-pro-preview`
  - Files: 18 files (1 .md + 17 .dart)
  - Prompt: "Extract domain model patterns: sealed classes, immutable value objects,
    rich domain model, extension methods. Identify DO/DON'T candidates."

### Phase 2: Rules Cross-Reference

- [ ] **Task 2.1**: Gemini `read_files` MAINTENANCE.md
  - Model: `gemini-3-pro-preview`
  - Files: 1 file
  - Prompt: "Extract rules applicable to foundation components: immutability,
    initialization order, token patterns, config before auth, auth before providers."

### Phase 3: Guidelines Synthesis

- [ ] **Task 3.1**: Gemini synthesize guidelines for Component 02
  - Model: `gemini-3-pro-preview`
  - Input: Batch 1 analysis + MAINTENANCE.md rules
  - Output: DO (5 items), DON'T (5 items), Extending (3 items)
  - Focus: Conditional imports, sealed states, BFF pattern, security validation

- [ ] **Task 3.2**: Gemini synthesize guidelines for Component 10
  - Focus: Immutable config, forced DI, layered configuration, initialization order

- [ ] **Task 3.3**: Gemini synthesize guidelines for Component 11
  - Focus: Token-based design, ThemeExtension, barrel exports, platform adaptation

- [ ] **Task 3.4**: Gemini synthesize guidelines for Component 12
  - Focus: Shell pattern, AsyncValue handling, exception mapping, platform adaptation

- [ ] **Task 3.5**: Gemini synthesize guidelines for Component 13
  - Focus: Sealed classes, immutable value objects, extension methods, aggregate roots

- [ ] **Task 3.6**: Gemini synthesize guidelines for Component 19
  - Focus: Declarative routing, auth guards, deep linking, route guards

### Phase 4: Document Updates

- [ ] **Task 4.1**: Claude adds "Contribution Guidelines" to 02-authentication.md
- [ ] **Task 4.2**: Claude adds "Contribution Guidelines" to 10-configuration.md
- [ ] **Task 4.3**: Claude adds "Contribution Guidelines" to 11-design-system.md
- [ ] **Task 4.4**: Claude adds "Contribution Guidelines" to 12-shared-widgets.md
- [ ] **Task 4.5**: Claude adds "Contribution Guidelines" to 13-client-domain.md
- [ ] **Task 4.6**: Claude adds "Contribution Guidelines" to 19-navigation-routing.md

### Phase 5: Validation

- [ ] **Task 5.1**: Codex validation (10min timeout)
  - Prompt: "Verify these 6 component docs have Contribution Guidelines with
    DO/DON'T/Extending subsections: [list 6 .md paths]"
  - **If timeout**: Use Gemini `gemini-3-pro-preview` as CRITIC instead:
    - Prompt: "ACT AS A CODE REVIEWER / CRITIC. Review these component docs
      for quality of Contribution Guidelines. Verify each has DO/DON'T/Extending
      subsections with 3-5 specific items. Report PASS or FAIL with issues."
    - Document fallback in notes

- [ ] **Task 5.2**: Update TASK_LIST.md → M33 ✅ Complete

---

## Key Guidelines to Include

From MAINTENANCE.md applicable to foundation components:

### Immutability Rules

- Domain models are immutable (use copyWith for modifications)
- Tokens are constants (design tokens never change at runtime)
- Config is read-only after init (configuration loads once)

### Initialization Order

- Config before auth (backend URLs needed for auth endpoints)
- Auth before data providers (tokens needed for API calls)
- Router after auth (redirect rules depend on auth state)

### Foundation-Specific Patterns

- Token pattern: Centralized design constants
- Model pattern: Immutable with factory constructors and JSON serialization
- Auth pattern: Notifier with state machine (Unauthenticated → Authenticated)
- Platform abstraction: Conditional imports for Web/Native

---

## Section Format

Each component doc gets appended:

```markdown
## Contribution Guidelines

### DO

- [5 specific practices]

### DON'T

- [5 specific anti-patterns]

### Extending This Component

- [3 guidelines for new functionality]
```

---

## Verification Criteria

- All 6 component docs have "Contribution Guidelines" section
- Each section has: DO, DON'T, Extending This Component subsections
- Guidelines reflect DESIRED patterns (not current violations)
- No references to specific line numbers
