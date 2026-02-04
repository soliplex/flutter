# M26 - Cross-Reference Auth & Config

## Goal

Add "Depends on" / "Used by" sections to authentication and configuration component docs.

## Components

| # | Component | Directory |
|---|-----------|-----------|
| 02 | Authentication | lib/core/auth/, lib/features/auth/, lib/features/login/ |
| 03 | State Core | lib/core/providers/api_*, backend_*, infrastructure_* |
| 07 | Documents | lib/core/providers/documents*, selected_documents* |
| 10 | Configuration | lib/core/models/*config*, lib/core/providers/config* |
| 18 | Native Platform | lib/core/infrastructure/, packages/soliplex_client_native/ |

## Tasks

- [x] Extract imports with grep for each component
- [x] Map cross-component imports to component numbers
- [x] Synthesize "Depends on" / "Used by" sections (Gemini)
- [x] Update 5 component docs
- [ ] Validate batch (Codex - 5 docs within 15-file limit)

## Component Files

### 02 - Authentication

- lib/core/auth/*.dart
- lib/features/auth/*.dart
- lib/features/login/*.dart
- packages/soliplex_client/lib/src/auth/*.dart (if exists)

### 03 - State Core

- lib/core/providers/api_provider.dart
- lib/core/providers/backend_provider.dart
- lib/core/providers/infrastructure_providers.dart

### 07 - Documents

- lib/core/providers/documents_provider.dart
- lib/core/providers/selected_documents_provider.dart

### 10 - Configuration

- lib/core/models/app_config*.dart
- lib/core/models/features*.dart
- lib/core/models/*_config*.dart
- lib/core/providers/config*.dart
- lib/core/providers/shell_config*.dart

### 18 - Native Platform

- lib/core/domain/interfaces/*.dart
- lib/core/infrastructure/*.dart
- packages/soliplex_client_native/lib/*.dart
