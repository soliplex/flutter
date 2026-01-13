# Soliplex Flutter Documentation

*Last updated: January 2026*

This documentation covers the Soliplex Flutter frontend - a cross-platform chat application with AG-UI streaming protocol support.

## Quick Links

| Area | Description |
|------|-------------|
| [Developer Setup](guides/developer-setup.md) | Environment setup and getting started |
| [Roadmap](planning/ROADMAP.md) | Version overview, milestones, and release planning |
| [Codebase Analysis](planning/architecture/CODEBASE_ANALYSIS.md) | Architecture overview and code structure |
| [Client Package](summary/client.md) | Pure Dart client library documentation |

---

## Documentation Sections

### Guides

Developer-focused documentation for getting started and day-to-day development.

- [Developer Setup](guides/developer-setup.md) - Environment setup, dependencies, and build instructions

### Architecture

Technical design documents and codebase analysis.

- [Codebase Analysis](planning/architecture/CODEBASE_ANALYSIS.md) - Project structure, architecture, and key components
- [Reverse Engineered Architecture](planning/architecture/REVERSE_ENGINEERED.md) - Detailed architecture documentation
- [Branding Approach](planning/architecture/BRANDING-APPROACH.md) - White-label and branding strategy

### Specifications

Detailed specifications for core functionality and UI components.

**Core Systems:**

- [Client Specification](planning/specs/client.md) - soliplex_client package design
- [Core Frontend](planning/specs/core_frontend.md) - Frontend architecture and state management
- [OIDC Authentication](planning/specs/oidc_authentication.md) - OAuth/OIDC integration specification
- [External Backend Service](planning/specs/external_backend_service.md) - Backend API integration
- [Web Platform Support](planning/specs/web_platform_support.md) - Web deployment considerations

**UI Components:**

- [Chat](planning/specs/ui/chat.md) - Chat messaging UI specification
- [History](planning/specs/ui/history.md) - Thread history sidebar
- [Detail](planning/specs/ui/detail.md) - Detail/inspector panel
- [Current Canvas](planning/specs/ui/current_canvas.md) - Runtime state visualization
- [Permanent Canvas](planning/specs/ui/permanent_canvas.md) - Pinned items and artifacts
- [HTTP Inspector](planning/specs/ui/http_inspector.md) - Network traffic debugging UI

### Planning & Design

Design documents, bug tracking, and feature planning.

- [Backend-Frontend Integration](planning/backend-frontend-integration.md) - API integration patterns
- [No-Auth Mode](planning/no-auth-mode.md) - Development mode without authentication

**Bug Fixes:**

- [Stale Messages on Thread Switch](planning/fix-stale-messages-on-thread-switch.md) - Thread switching bug fix
- [Backend Errno-2 Thread Messages](planning/bugs/backend-errno-2-thread-messages.md) - Backend error handling

**Refactoring:**

- [HTTP Layer Naming](planning/refactoring/http-layer-naming.md) - HTTP client naming conventions
- [Navigation Refactoring](planning/refactoring/navigation-refactoring.md) - Navigation system improvements
- [Null Removal](planning/refactoring/null-removal.md) - Null safety improvements

### Worklogs

Development progress tracking and completed milestones.

- [AM2 Complete](planning/worklogs/AM2-COMPLETE.md) - Connected Data milestone completion
- [Client Worklog](planning/worklogs/client-worklog.md) - Client package development progress
- [Core Frontend Worklog](planning/worklogs/core-frontend-worklog.md) - Frontend development progress

### Rules & Standards

Development guidelines and coding standards.

- [Flutter Rules](rules/flutter_rules.md) - Flutter development conventions and best practices

### Package Summaries

- [Client Package Summary](summary/client.md) - soliplex_client architecture and usage

---

## Project Overview

### Architecture

The project follows a three-layer architecture:

```
┌─────────────────────────────────────────────┐
│              UI Components                   │
│  (Chat, History, Detail, Canvas)            │
└──────────────────┬──────────────────────────┘
                   │
┌──────────────────▼──────────────────────────┐
│              Core Frontend                   │
│  Providers │ Navigation │ AG-UI Processing  │
└──────────────────┬──────────────────────────┘
                   │
┌──────────────────▼──────────────────────────┐
│      soliplex_client (Pure Dart package)    │
└─────────────────────────────────────────────┘
```

### Packages

| Package | Type | Status | Description |
|---------|------|--------|-------------|
| `soliplex_client` | Pure Dart | Implemented | HTTP/AG-UI client, models, sessions |
| `soliplex_client_native` | Flutter | Implemented | Native HTTP adapters (iOS/macOS via Cupertino) |
| `soliplex_core` | Flutter | Planned (AM8) | Core frontend extraction (providers, config, registries) |

### Current Status

**Version 1.0 - Core Functionality** (In Progress)

| Milestone | Description | Status |
|-----------|-------------|--------|
| AM1 | App Shell | ✅ Done |
| AM2 | Connected Data | ✅ Done |
| AM3 | Working Chat | ✅ Done |
| AM4 | Full Chat | ✅ Done |
| AM5 | Inspector (HTTP) | ✅ Done |
| AM6 | Canvas | Pending |
| AM7 | Authentication | ✅ Done |
| AM8 | Polish | Pending |

See the [Roadmap](planning/ROADMAP.md) for complete version planning and milestone details.
