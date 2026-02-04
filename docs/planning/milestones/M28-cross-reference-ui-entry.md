# M28 - Cross-Reference UI & Entry

## Goal

Add "Depends on" / "Used by" sections to UI and entry point component docs.

## Components

| # | Component | Directory |
|---|-----------|-----------|
| 01 | App Shell | lib/app.dart, lib/main.dart, lib/run_soliplex_app.dart |
| 06 | Rooms | lib/core/providers/rooms*, lib/features/room/, rooms/ |
| 08 | Chat UI | lib/core/providers/chunk*, citations*, lib/features/chat/ |
| 19 | Router | lib/core/router/ |
| 20 | Quiz | lib/core/providers/quiz*, lib/features/quiz/ |

## Tasks

- [x] Extract imports with grep for each component
- [x] Map cross-component imports to component numbers
- [x] Synthesize "Depends on" / "Used by" sections (Gemini)
- [x] Update 5 component docs
- [ ] Validate batch (Codex - 5 docs within 15-file limit)

## Component Files

### 01 - App Shell

- lib/app.dart
- lib/main.dart
- lib/run_soliplex_app.dart
- lib/features/home/*.dart
- lib/features/settings/settings_screen.dart

### 06 - Rooms

- lib/core/providers/rooms*.dart
- lib/features/room/*.dart
- lib/features/rooms/*.dart

### 08 - Chat UI

- lib/core/providers/chunk*.dart
- lib/core/providers/citations*.dart
- lib/core/providers/source_ref*.dart
- lib/features/chat/*.dart

### 19 - Router

- lib/core/router/*.dart

### 20 - Quiz

- lib/core/providers/quiz*.dart
- lib/features/quiz/*.dart
