# M31 - Guidelines: UI Features

## Goal

Add "Contribution Guidelines" section to UI feature component docs (6 components).

## Components

| # | Component | Doc File | Source Files |
|---|-----------|----------|--------------|
| 01 | App Shell & Entry | components/01-app-shell.md | 8 |
| 05 | Thread Management | components/05-thread-management.md | 5 |
| 06 | Room Management | components/06-room-management.md | 6 |
| 08 | Chat UI | components/08-chat-ui.md | 11 |
| 09 | HTTP Inspector | components/09-http-inspector.md | 8 |
| 20 | Quiz Feature | components/20-quiz-feature.md | 2 |

**Total: 6 component docs + 40 source files**

---

## Source File Inventory

### Component 01 - App Shell & Entry (8 files)

```text
lib/main.dart
lib/run_soliplex_app.dart
lib/app.dart
lib/soliplex_frontend.dart
lib/version.dart
lib/features/home/home_screen.dart
lib/features/home/connection_flow.dart
lib/features/settings/settings_screen.dart
```

### Component 05 - Thread Management (5 files)

```text
lib/core/providers/thread_history_cache.dart
lib/core/providers/threads_provider.dart
lib/features/history/history_panel.dart
lib/features/history/widgets/new_conversation_button.dart
lib/features/history/widgets/thread_list_item.dart
```

### Component 06 - Room Management (6 files)

```text
lib/core/providers/rooms_provider.dart
lib/features/room/room_screen.dart
lib/features/rooms/rooms_screen.dart
lib/features/rooms/widgets/room_grid_card.dart
lib/features/rooms/widgets/room_list_tile.dart
lib/features/rooms/widgets/room_search_toolbar.dart
```

### Component 08 - Chat UI (11 files)

```text
lib/core/providers/chunk_visualization_provider.dart
lib/core/providers/citations_expanded_provider.dart
lib/core/providers/source_references_provider.dart
lib/features/chat/chat_panel.dart
lib/features/chat/widgets/chat_input.dart
lib/features/chat/widgets/chat_message_widget.dart
lib/features/chat/widgets/chunk_visualization_page.dart
lib/features/chat/widgets/citations_section.dart
lib/features/chat/widgets/code_block_builder.dart
lib/features/chat/widgets/message_list.dart
lib/features/chat/widgets/status_indicator.dart
```

### Component 09 - HTTP Inspector (8 files)

```text
lib/core/providers/http_log_provider.dart
lib/features/inspector/http_inspector_panel.dart
lib/features/inspector/models/http_event_group.dart
lib/features/inspector/models/http_event_grouper.dart
lib/features/inspector/network_inspector_screen.dart
lib/features/inspector/widgets/http_event_tile.dart
lib/features/inspector/widgets/http_status_display.dart
lib/features/inspector/widgets/request_detail_view.dart
```

### Component 20 - Quiz Feature (2 files)

```text
lib/core/providers/quiz_provider.dart
lib/features/quiz/quiz_screen.dart
```

---

## Batching Strategy

### Batch 1: Components 01 + 05 (Gemini read_files)

**Files (15):**

```text
docs/planning/components/01-app-shell.md
docs/planning/components/05-thread-management.md
lib/main.dart
lib/run_soliplex_app.dart
lib/app.dart
lib/soliplex_frontend.dart
lib/version.dart
lib/features/home/home_screen.dart
lib/features/home/connection_flow.dart
lib/features/settings/settings_screen.dart
lib/core/providers/thread_history_cache.dart
lib/core/providers/threads_provider.dart
lib/features/history/history_panel.dart
lib/features/history/widgets/new_conversation_button.dart
lib/features/history/widgets/thread_list_item.dart
```

### Batch 2: Components 06 + 08 (part 1) (Gemini read_files)

**Files (17):**

```text
docs/planning/components/06-room-management.md
docs/planning/components/08-chat-ui.md
lib/core/providers/rooms_provider.dart
lib/features/room/room_screen.dart
lib/features/rooms/rooms_screen.dart
lib/features/rooms/widgets/room_grid_card.dart
lib/features/rooms/widgets/room_list_tile.dart
lib/features/rooms/widgets/room_search_toolbar.dart
lib/core/providers/chunk_visualization_provider.dart
lib/core/providers/citations_expanded_provider.dart
lib/core/providers/source_references_provider.dart
lib/features/chat/chat_panel.dart
lib/features/chat/widgets/chat_input.dart
lib/features/chat/widgets/chat_message_widget.dart
lib/features/chat/widgets/chunk_visualization_page.dart
lib/features/chat/widgets/citations_section.dart
lib/features/chat/widgets/code_block_builder.dart
```

### Batch 3: Component 08 (part 2) + 09 + 20 (Gemini read_files)

**Files (14):**

```text
docs/planning/components/09-http-inspector.md
docs/planning/components/20-quiz-feature.md
lib/features/chat/widgets/message_list.dart
lib/features/chat/widgets/status_indicator.dart
lib/core/providers/http_log_provider.dart
lib/features/inspector/http_inspector_panel.dart
lib/features/inspector/models/http_event_group.dart
lib/features/inspector/models/http_event_grouper.dart
lib/features/inspector/network_inspector_screen.dart
lib/features/inspector/widgets/http_event_tile.dart
lib/features/inspector/widgets/http_status_display.dart
lib/features/inspector/widgets/request_detail_view.dart
lib/core/providers/quiz_provider.dart
lib/features/quiz/quiz_screen.dart
```

### Batch 4: MAINTENANCE.md Rules (Gemini read_files)

**Files (1):**

```text
docs/planning/MAINTENANCE.md
```

---

## Tasks

### Phase 1: Pattern Extraction

- [x] **Task 1.1**: Gemini `read_files` Batch 1 (Components 01 + 05)
  - Model: `gemini-3-pro-preview`
  - Files: 15 files (2 .md + 13 .dart)
  - Prompt: "Extract widget patterns, state management patterns, initialization
    patterns. Identify DO/DON'T candidates for UI feature components."

- [x] **Task 1.2**: Gemini `read_files` Batch 2 (Components 06 + 08 part 1)
  - Model: `gemini-3-pro-preview`
  - Files: 17 files (2 .md + 15 .dart)
  - Prompt: "Extract responsive layout patterns, provider watching patterns,
    synthetic state merging. Identify DO/DON'T candidates."

- [x] **Task 1.3**: Gemini `read_files` Batch 3 (Components 08 part 2 + 09 + 20)
  - Model: `gemini-3-pro-preview`
  - Files: 14 files (2 .md + 12 .dart)
  - Prompt: "Extract observer patterns, state machine patterns, quiz flow
    patterns. Identify DO/DON'T candidates."

### Phase 2: Rules Cross-Reference

- [x] **Task 2.1**: Gemini `read_files` MAINTENANCE.md
  - Model: `gemini-3-pro-preview`
  - Files: 1 file
  - Prompt: "Extract rules applicable to UI features: widget method size (<50
    lines), dispatch vs watch, no business logic in widgets, select() usage."

### Phase 3: Guidelines Synthesis

- [x] **Task 3.1**: Gemini synthesize guidelines for Component 01
  - Model: `gemini-3-pro-preview`
  - Input: Batch 1 analysis + MAINTENANCE.md rules
  - Output: DO (5 items), DON'T (5 items), Extending (3 items)
  - Focus: Initialization sequencing, auth gating, connection flow

- [x] **Task 3.2**: Gemini synthesize guidelines for Component 05
  - Focus: Cache patterns, request deduplication, sealed state machines

- [x] **Task 3.3**: Gemini synthesize guidelines for Component 06
  - Focus: Responsive layouts, computed state, imperative initialization

- [x] **Task 3.4**: Gemini synthesize guidelines for Component 08
  - Focus: Synthetic state merging, selector pattern, scoped UI state

- [x] **Task 3.5**: Gemini synthesize guidelines for Component 09
  - Focus: Observer pattern, ephemeral state, master-detail layout

- [x] **Task 3.6**: Gemini synthesize guidelines for Component 20
  - Focus: Finite state machines, family providers, optimistic updates

### Phase 4: Document Updates

- [x] **Task 4.1**: Claude adds "Contribution Guidelines" to 01-app-shell.md
- [x] **Task 4.2**: Claude adds "Contribution Guidelines" to 05-thread-management.md
- [x] **Task 4.3**: Claude adds "Contribution Guidelines" to 06-room-management.md
- [x] **Task 4.4**: Claude adds "Contribution Guidelines" to 08-chat-ui.md
- [x] **Task 4.5**: Claude adds "Contribution Guidelines" to 09-http-inspector.md
- [x] **Task 4.6**: Claude adds "Contribution Guidelines" to 20-quiz-feature.md

### Phase 5: Validation

- [x] **Task 5.1**: Codex validation (10min timeout)
  - Prompt: "Verify these 6 component docs have Contribution Guidelines with
    DO/DON'T/Extending subsections: [list 6 .md paths]"
  - **Result**: All 6 files PASS

- [x] **Task 5.2**: Update TASK_LIST.md → M31 ✅ Complete

---

## Key Guidelines to Include

From MAINTENANCE.md applicable to UI features:

### Universal Widget Rules

- Widget methods under 50 lines
- Dispatch actions to providers, don't implement logic
- Use `ref.watch(...).select(...)` to prevent unnecessary rebuilds

### State Management Rules

- NotifierProvider for stateful features
- FutureProvider.family for parameterized data
- Use sealed classes for exhaustive matching

### UI-Specific Patterns

- Synthetic state merging: Fuse immutable history with streaming state
- Scoped interaction state: `NotifierProvider.family` for per-thread/room UI state
- Pending object pattern: Gather config locally before persistence

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
