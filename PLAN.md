# Soliplex Flutter Development Plan

## Current Branch: `feat/appshell-extraction`

### Status: Ready for Review

Extracted a configurable app shell enabling white-label deployments.

---

## Completed Work

### Appshell Extraction

| Component | File | Description |
|-----------|------|-------------|
| SoliplexConfig | `lib/core/models/soliplex_config.dart` | Root configuration aggregating all options |
| Features | `lib/core/models/features.dart` | Feature flags (HTTP inspector, quizzes, settings) |
| ThemeConfig | `lib/core/models/theme_config.dart` | Light/dark color palette wrapper |
| RouteConfig | `lib/core/models/route_config.dart` | Route visibility and initial route |
| ShellConfigProvider | `lib/core/providers/shell_config_provider.dart` | Riverpod provider for shell config |
| SoliplexRegistry | `lib/core/extension/soliplex_registry.dart` | Extension point for panels, commands, routes |
| runSoliplexApp | `lib/run_soliplex_app.dart` | Unified entry point with initialization |
| Barrel export | `lib/soliplex_frontend.dart` | Public API surface |
| Example app | `example/main.dart` | White-label usage demonstration |

### Test Coverage

- `test/core/models/` - Unit tests for all config models
- `test/core/providers/` - Provider tests
- `test/core/extension/` - Registry tests
- 818 tests passing

---

## Known Issues (Backlog)

### Appshell-Extraction Specific

| Issue | File | Priority | Notes |
|-------|------|----------|-------|
| Global mutable state | `shell_config_provider.dart` | Medium | Should use ProviderScope.overrides |
| Mutable List returns | `soliplex_registry.dart` | Low | Wrap in List.unmodifiable() |
| Invalid RouteConfig | `route_config.dart` | Low | Add debug assertion |

### Pre-existing (Out of Scope)

- Theme light/dark duplication
- ThemeMode hardcoded to light
- Room screen async race conditions
- Router capturedParams timing

---

## Future Work

### Phase 1: Appshell Refinements

- [ ] Replace globals with ProviderScope.overrides
- [ ] Add RouteConfig validation assertions
- [ ] Make registry lists unmodifiable
- [ ] Add ThemeMode to config (light/dark/system)

### Phase 2: Enterprise MDM

See `docs/planning/enterprise-mdm-plan.md` for full details.

| Phase | Scope | Duration |
|-------|-------|----------|
| 2.1 | MDM Foundation (runtime config) | 2 weeks |
| 2.2 | Security Services (pinning, jailbreak, DLP) | 2 weeks |
| 2.3 | Audit Logging | 1 week |
| 2.4 | Remote Wipe | 1 week |
| 2.5 | Enterprise Auth (SAML, multi-tenant) | 2 weeks |

### Phase 3: Rich Chat Features

See `docs/planning/rich-chat-specs/` for specifications:

- Thinking tags visualization
- Smart copy chips
- Interactive citations
- PDF source viewer
- Tool call visualizer

---

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    White-label App                       │
│  ┌─────────────────────────────────────────────────┐    │
│  │ main.dart                                        │    │
│  │   runSoliplexApp(config: SoliplexConfig(...))   │    │
│  └─────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────┐
│                  soliplex_frontend                       │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐   │
│  │ SoliplexConfig│  │ Features     │  │ ThemeConfig  │   │
│  └──────────────┘  └──────────────┘  └──────────────┘   │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐   │
│  │ RouteConfig  │  │ Registry     │  │ Providers    │   │
│  └──────────────┘  └──────────────┘  └──────────────┘   │
└─────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────┐
│                    soliplex_client                       │
│              (Pure Dart - no Flutter)                    │
└─────────────────────────────────────────────────────────┘
```

---

## Code Review Summary

### Gemini 3 Pro Findings

1. Global mutable state bypasses Riverpod (medium)
2. Theme duplication could be factored (low, pre-existing)
3. Models are well-structured with proper immutability

### Codex Findings

1. `library;` directive fixed
2. Registry mutability noted
3. RouteConfig validation suggested
4. Public API is minimal and clean

---

## CI Validation

```bash
# Required checks before merge
dart format --set-exit-if-changed .
dart analyze                          # 0 errors, 0 warnings
flutter test                          # All pass
cd example && flutter build apk       # Example compiles
```

---

## Branch History

| Branch | Status | Description |
|--------|--------|-------------|
| `feat/appshell-extraction` | Active | White-label framework |
| `main` | Stable | Production |

---

## Contact

- Planning docs: `docs/planning/`
- Enterprise MDM: `docs/planning/enterprise-mdm-plan.md`
- Proposed features: `docs/planning/proposed_features/`
