# M27 - Cross-Reference Business Logic

## Goal

Add "Depends on" / "Used by" sections to business logic component docs.

## Components

| # | Component | Directory |
|---|-----------|-----------|
| 04 | Active Run | lib/core/models/active_run*, lib/core/providers/active_run* |
| 05 | Threads | lib/core/providers/thread*, lib/features/history/ |
| 09 | Inspector | lib/core/providers/http_log*, lib/features/inspector/ |
| 12 | Shared Widgets | lib/shared/widgets/ |

## Tasks

- [x] Extract imports with grep for each component
- [x] Map cross-component imports to component numbers
- [x] Synthesize "Depends on" / "Used by" sections (Gemini)
- [x] Update 4 component docs
- [ ] Validate batch (Codex - 4 docs within 15-file limit)

## Component Files

### 04 - Active Run

- lib/core/models/active_run*.dart
- lib/core/providers/active_run*.dart
- lib/core/application/*.dart
- lib/core/domain/*.dart

### 05 - Threads

- lib/core/providers/thread*.dart
- lib/features/history/*.dart

### 09 - Inspector

- lib/core/providers/http_log*.dart
- lib/features/inspector/*.dart

### 12 - Shared Widgets

- lib/shared/widgets/*.dart
