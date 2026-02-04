# M30 - Guidelines: Infrastructure

## Goal

Add "Contribution Guidelines" section to infrastructure component docs (6 components).

## Components

| # | Component | Doc File | Source Files |
|---|-----------|----------|--------------|
| 03 | State Management Core | components/03-state-management-core.md | 5 |
| 14 | Client: HTTP Layer | components/14-client-http.md | 13 |
| 15 | Client: API Endpoints | components/15-client-api.md | 5 |
| 16 | Client: Application | components/16-client-application.md | 5 |
| 17 | Client: Utilities | components/17-client-utilities.md | 7 |
| 18 | Native Platform | components/18-native-platform.md | 11 |

**Total: 6 component docs + 46 source files**

---

## Source File Inventory

### Component 03 - State Management Core (5 files)

```text
lib/core/providers/api_provider.dart
lib/core/providers/backend_health_provider.dart
lib/core/providers/backend_version_provider.dart
lib/core/providers/infrastructure_providers.dart
lib/features/settings/backend_versions_screen.dart
```

### Component 14 - HTTP Layer (13 files)

```text
packages/soliplex_client/lib/soliplex_client.dart
packages/soliplex_client/lib/src/http/authenticated_http_client.dart
packages/soliplex_client/lib/src/http/dart_http_client.dart
packages/soliplex_client/lib/src/http/http.dart
packages/soliplex_client/lib/src/http/http_client_adapter.dart
packages/soliplex_client/lib/src/http/http_observer.dart
packages/soliplex_client/lib/src/http/http_redactor.dart
packages/soliplex_client/lib/src/http/http_response.dart
packages/soliplex_client/lib/src/http/http_transport.dart
packages/soliplex_client/lib/src/http/observable_http_client.dart
packages/soliplex_client/lib/src/http/refreshing_http_client.dart
packages/soliplex_client/lib/src/http/soliplex_http_client.dart
packages/soliplex_client/lib/src/http/token_refresher.dart
```

### Component 15 - API Endpoints (5 files)

```text
packages/soliplex_client/lib/src/api/agui_message_mapper.dart
packages/soliplex_client/lib/src/api/api.dart
packages/soliplex_client/lib/src/api/fetch_auth_providers.dart
packages/soliplex_client/lib/src/api/mappers.dart
packages/soliplex_client/lib/src/api/soliplex_api.dart
```

### Component 16 - Application (5 files)

```text
packages/soliplex_client/lib/src/application/agui_event_processor.dart
packages/soliplex_client/lib/src/application/application.dart
packages/soliplex_client/lib/src/application/citation_extractor.dart
packages/soliplex_client/lib/src/application/json_patch.dart
packages/soliplex_client/lib/src/application/streaming_state.dart
```

### Component 17 - Utilities (7 files)

```text
lib/shared/utils/date_formatter.dart
lib/shared/utils/format_utils.dart
packages/soliplex_client/lib/src/errors/errors.dart
packages/soliplex_client/lib/src/errors/exceptions.dart
packages/soliplex_client/lib/src/utils/cancel_token.dart
packages/soliplex_client/lib/src/utils/url_builder.dart
packages/soliplex_client/lib/src/utils/utils.dart
```

### Component 18 - Native Platform (11 files)

```text
lib/core/domain/interfaces/screen_wake_lock.dart
lib/core/infrastructure/platform/wakelock_plus_adapter.dart
lib/shared/utils/platform_resolver.dart
packages/soliplex_client_native/lib/soliplex_client_native.dart
packages/soliplex_client_native/lib/src/clients/clients.dart
packages/soliplex_client_native/lib/src/clients/cupertino_http_client.dart
packages/soliplex_client_native/lib/src/clients/cupertino_http_client_stub.dart
packages/soliplex_client_native/lib/src/platform/create_platform_client.dart
packages/soliplex_client_native/lib/src/platform/create_platform_client_io.dart
packages/soliplex_client_native/lib/src/platform/create_platform_client_stub.dart
packages/soliplex_client_native/lib/src/platform/platform.dart
```

---

## Batching Strategy

### Batch 1: Components 03 + 14 (Gemini read_files)

**Files (20):**

```text
docs/planning/components/03-state-management-core.md
docs/planning/components/14-client-http.md
lib/core/providers/api_provider.dart
lib/core/providers/backend_health_provider.dart
lib/core/providers/backend_version_provider.dart
lib/core/providers/infrastructure_providers.dart
lib/features/settings/backend_versions_screen.dart
packages/soliplex_client/lib/soliplex_client.dart
packages/soliplex_client/lib/src/http/authenticated_http_client.dart
packages/soliplex_client/lib/src/http/dart_http_client.dart
packages/soliplex_client/lib/src/http/http.dart
packages/soliplex_client/lib/src/http/http_client_adapter.dart
packages/soliplex_client/lib/src/http/http_observer.dart
packages/soliplex_client/lib/src/http/http_redactor.dart
packages/soliplex_client/lib/src/http/http_response.dart
packages/soliplex_client/lib/src/http/http_transport.dart
packages/soliplex_client/lib/src/http/observable_http_client.dart
packages/soliplex_client/lib/src/http/refreshing_http_client.dart
packages/soliplex_client/lib/src/http/soliplex_http_client.dart
packages/soliplex_client/lib/src/http/token_refresher.dart
```

### Batch 2: Components 15 + 16 + 17 (Gemini read_files)

**Files (19):**

```text
docs/planning/components/15-client-api.md
docs/planning/components/16-client-application.md
docs/planning/components/17-client-utilities.md
packages/soliplex_client/lib/src/api/agui_message_mapper.dart
packages/soliplex_client/lib/src/api/api.dart
packages/soliplex_client/lib/src/api/fetch_auth_providers.dart
packages/soliplex_client/lib/src/api/mappers.dart
packages/soliplex_client/lib/src/api/soliplex_api.dart
packages/soliplex_client/lib/src/application/agui_event_processor.dart
packages/soliplex_client/lib/src/application/application.dart
packages/soliplex_client/lib/src/application/citation_extractor.dart
packages/soliplex_client/lib/src/application/json_patch.dart
packages/soliplex_client/lib/src/application/streaming_state.dart
lib/shared/utils/date_formatter.dart
lib/shared/utils/format_utils.dart
packages/soliplex_client/lib/src/errors/errors.dart
packages/soliplex_client/lib/src/errors/exceptions.dart
packages/soliplex_client/lib/src/utils/cancel_token.dart
packages/soliplex_client/lib/src/utils/url_builder.dart
```

### Batch 3: Component 18 + Utilities remainder (Gemini read_files)

**Files (13):**

```text
docs/planning/components/18-native-platform.md
packages/soliplex_client/lib/src/utils/utils.dart
lib/core/domain/interfaces/screen_wake_lock.dart
lib/core/infrastructure/platform/wakelock_plus_adapter.dart
lib/shared/utils/platform_resolver.dart
packages/soliplex_client_native/lib/soliplex_client_native.dart
packages/soliplex_client_native/lib/src/clients/clients.dart
packages/soliplex_client_native/lib/src/clients/cupertino_http_client.dart
packages/soliplex_client_native/lib/src/clients/cupertino_http_client_stub.dart
packages/soliplex_client_native/lib/src/platform/create_platform_client.dart
packages/soliplex_client_native/lib/src/platform/create_platform_client_io.dart
packages/soliplex_client_native/lib/src/platform/create_platform_client_stub.dart
packages/soliplex_client_native/lib/src/platform/platform.dart
```

### Batch 4: MAINTENANCE.md Rules (Gemini read_files)

**Files (1):**

```text
docs/planning/MAINTENANCE.md
```

---

## Tasks

### Phase 1: Pattern Extraction

- [x] **Task 1.1**: Gemini `read_files` Batch 1 (Components 03 + 14)
  - Model: `gemini-3-pro-preview`
  - Files: 20 files (2 .md + 18 .dart)
  - Prompt: "Extract provider patterns, decorator patterns, resource management
    patterns. Identify DO/DON'T candidates for infrastructure components."

- [x] **Task 1.2**: Gemini `read_files` Batch 2 (Components 15 + 16 + 17)
  - Model: `gemini-3-pro-preview`
  - Files: 19 files (3 .md + 16 .dart)
  - Prompt: "Extract API facade patterns, event processing patterns, error
    handling patterns. Identify DO/DON'T candidates."

- [x] **Task 1.3**: Gemini `read_files` Batch 3 (Component 18)
  - Model: `gemini-3-pro-preview`
  - Files: 13 files (1 .md + 12 .dart)
  - Prompt: "Extract platform abstraction patterns, factory patterns, conditional
    import patterns. Identify DO/DON'T candidates."

### Phase 2: Rules Cross-Reference

- [x] **Task 2.1**: Gemini `read_files` MAINTENANCE.md
  - Model: `gemini-3-pro-preview`
  - Files: 1 file
  - Prompt: "Extract rules applicable to infrastructure components: decorator
    ordering, resource lifecycle, Ref rule, provider naming, one responsibility."

### Phase 3: Guidelines Synthesis

- [x] **Task 3.1**: Gemini synthesize guidelines for Component 03
  - Model: `gemini-3-pro-preview`
  - Input: Batch 1 analysis + MAINTENANCE.md rules
  - Output: DO (5 items), DON'T (5 items), Extending (3 items)

- [x] **Task 3.2**: Gemini synthesize guidelines for Component 14
  - Same as 3.1 but focused on HTTP decorator patterns

- [x] **Task 3.3**: Gemini synthesize guidelines for Component 15
  - Focus: API facade, response mapping, caching

- [x] **Task 3.4**: Gemini synthesize guidelines for Component 16
  - Focus: Event processing, state reducers, sealed classes

- [x] **Task 3.5**: Gemini synthesize guidelines for Component 17
  - Focus: Error hierarchy, cancellation, URL building

- [x] **Task 3.6**: Gemini synthesize guidelines for Component 18
  - Focus: Platform abstraction, factory pattern, conditional imports

### Phase 4: Document Updates

- [x] **Task 4.1**: Claude adds "Contribution Guidelines" to 03-state-management-core.md
- [x] **Task 4.2**: Claude adds "Contribution Guidelines" to 14-client-http.md
- [x] **Task 4.3**: Claude adds "Contribution Guidelines" to 15-client-api.md
- [x] **Task 4.4**: Claude adds "Contribution Guidelines" to 16-client-application.md
- [x] **Task 4.5**: Claude adds "Contribution Guidelines" to 17-client-utilities.md
- [x] **Task 4.6**: Claude adds "Contribution Guidelines" to 18-native-platform.md

### Phase 5: Validation

- [x] **Task 5.1**: Codex validation (10min timeout)
  - Prompt: "Verify these 6 component docs have Contribution Guidelines with
    DO/DON'T/Extending subsections: [list 6 .md paths]"
  - **Result**: All 6 files PASS

- [x] **Task 5.2**: Update TASK_LIST.md → M30 ✅ Complete

---

## Key Guidelines to Include

From MAINTENANCE.md applicable to infrastructure:

### Universal Rules

- Provider naming: `<domain><Type>Provider`
- One responsibility per provider
- Accept `Ref`, never `WidgetRef` in business logic

### HTTP Layer Specific (14)

- Decorator order: Base → Observable → Authenticated → Refreshing
- Resource ownership: Use `_NonClosingHttpClient` pattern
- Error mapping at transport layer

### API Layer Specific (15, 16)

- Facade hides endpoint complexity
- Event sourcing: State reconstructed from events
- LRU caching for immutable completed data

### Platform Specific (18)

- Conditional imports for Web/Native
- Factory pattern for platform clients
- Stubs ensure Web compilation

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
