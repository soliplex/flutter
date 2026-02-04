# M25 - Cross-Reference Infrastructure

## Goal

Add "Depends on" / "Used by" sections to infrastructure component docs.

## Components

| # | Component | Directory |
|---|-----------|-----------|
| 11 | Design System | lib/design/ |
| 13 | Domain Models | packages/soliplex_client/.../domain/ |
| 14 | HTTP Layer | packages/soliplex_client/.../http/ |
| 15 | API Endpoints | packages/soliplex_client/.../api/ |
| 16 | Application | packages/soliplex_client/.../application/ |
| 17 | Utilities | lib/shared/utils/, packages/soliplex_client/.../errors/, utils/ |

## Tasks

- [x] Extract imports with grep for each component
- [x] Map cross-component imports to component numbers
- [x] Synthesize "Depends on" / "Used by" sections (Gemini)
- [x] Update 6 component docs
- [ ] Validate batch (Codex - 6 docs within 15-file limit)

## Extraction Commands

**Outbound (what this component imports):**

```bash
grep -rh "^import 'package:" <component-dir> --include="*.dart" | sort -u
```

**Inbound (what imports this component):**

```bash
grep -rl "<component-import-path>" lib/ packages/ --include="*.dart" | sort -u
```

## Component Files

### 11 - Design System

- lib/design/*.dart

### 13 - Domain Models

- packages/soliplex_client/lib/src/domain/*.dart

### 14 - HTTP Layer

- packages/soliplex_client/lib/src/http/*.dart
- packages/soliplex_client/lib/soliplex_client.dart

### 15 - API Endpoints

- packages/soliplex_client/lib/src/api/*.dart

### 16 - Application

- packages/soliplex_client/lib/src/application/*.dart

### 17 - Utilities

- lib/shared/utils/*.dart
- packages/soliplex_client/lib/src/errors/*.dart
- packages/soliplex_client/lib/src/utils/*.dart
