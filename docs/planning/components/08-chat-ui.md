# 08 - Chat UI

## Overview

Primary chat interface including message display, composition input, citations,
code blocks, and streaming state visualization. Implements synthetic state merging
to fuse immutable history with volatile streaming data.

## Files

| File | Purpose |
|------|---------|
| `lib/core/providers/chunk_visualization_provider.dart` | PDF chunk image fetching |
| `lib/core/providers/citations_expanded_provider.dart` | Citation expand/collapse state |
| `lib/core/providers/source_references_provider.dart` | Citation resolution |
| `lib/features/chat/chat_panel.dart` | Main chat controller view |
| `lib/features/chat/widgets/chat_input.dart` | Composition bar |
| `lib/features/chat/widgets/chat_message_widget.dart` | Message bubble rendering |
| `lib/features/chat/widgets/chunk_visualization_page.dart` | PDF chunk viewer |
| `lib/features/chat/widgets/citations_section.dart` | Reference display |
| `lib/features/chat/widgets/code_block_builder.dart` | Syntax highlighting |
| `lib/features/chat/widgets/message_list.dart` | Scrollable conversation |
| `lib/features/chat/widgets/status_indicator.dart` | LLM state feedback |

## Public API

### Providers

| Provider | Type | Purpose |
|----------|------|---------|
| `chunkVisualizationProvider` | `FutureProvider.family` | Fetches chunk images |
| `citationsExpandedProvider` | `NotifierProvider.family` | Expand/collapse state per thread |
| `sourceReferencesForUserMessageProvider` | `Provider.family` | Resolves citations |

### Widgets

**`ChatPanel`** - Controller view

- `_handleSend` - Orchestrates thread creation, document filtering, run start
- `_updateSelectedDocuments` - Manages pending → provider state transition

**`MessageList`** - Scrollable conversation

- `computeDisplayMessages` - Pure function merging history with streaming state
- `_scrollToBottom` - Auto-scroll management

**`ChatInput`** - Composition bar

- `onSend` - Text submission callback
- `_showDocumentPicker` - Document selection dialog
- `formatDocumentTitle` - URI truncation utility

**`ChatMessageWidget`** - Message bubble

- Handles markdown, thinking sections, citations
- `ThinkingSection` - Collapsible LLM reasoning view

**`CitationsSection`** - Reference display

- Integrates with `citationsExpandedProvider`

**`ChunkVisualizationPage`** - PDF chunk viewer

- `show` - Static navigation helper

**`StatusIndicator`** - Visual LLM state feedback

**`CodeBlockBuilder`** - Markdown syntax highlighting extension

## Dependencies

### External Packages

- `flutter_riverpod` - State management
- `flutter_markdown` - Markdown rendering
- `flutter_highlight` - Syntax highlighting
- `go_router` - Navigation
- `soliplex_client` - Domain models

### Internal Dependencies

| Domain | Imports |
|--------|---------|
| Core/Providers | `active_run_provider`, `api_provider`, `threads_provider`, `documents_provider`, `thread_history_cache` |
| Design | Tokens, theme extensions |
| Shared | `ErrorDisplay`, `EmptyState` |

## Data Flow

### Sending a Message

```text
1. User types in ChatInput, hits send
2. ChatPanel checks thread existence:
   ├─ New Thread: api.createThread → update URL → transfer pending docs → startRun
   └─ Existing: directly call startRun on activeRunNotifier
```

### Streaming & Rendering

```text
1. activeRunNotifier emits StreamingState updates
2. MessageList calls computeDisplayMessages
3. Function appends synthetic message (streaming text/thinking) to history
4. ChatMessageWidget renders with ThinkingSection if appropriate
```

### Citation Flow

```text
1. Run completes (or history loads)
2. ChatMessageWidget looks at preceding User Message ID
3. Calls sourceReferencesForUserMessageProvider
4. Provider checks Active Run first, then Thread History Cache
5. CitationsSection renders if citations exist
6. PDF click opens ChunkVisualizationPage
```

## Architectural Patterns

### Synthetic State Merging

`MessageList` acts as view model layer, fusing immutable history with volatile
streaming state into single renderable list.

### Scoped Interaction State

`CitationsExpandedNotifier` uses `NotifierProvider.family` scoped by thread ID
for UI state cleanup on thread close.

### Pending Object Pattern

`ChatPanel._pendingDocuments` gathers configuration locally before parent entity
(Thread) is persisted to backend.

### Result Pattern

Local `Result<T>` sealed class (Ok/Err) handles functional error flow without
throwing exceptions up widget tree.

### Selector Pattern

Extensive use of `ref.watch(...).select(...)` to prevent unnecessary rebuilds.

## Cross-Component Dependencies

### Depends On

- **03 - State Core**: API provider access
- **04 - Active Run**: Execution state visualization
- **05 - Threads**: Thread history and cache management
- **06 - Rooms**: Room state and provider context
- **07 - Documents**: Document references and selection state
- **11 - Design System**: Theme and styling tokens
- **12 - Shared Widgets**: Common UI components
- **14 - HTTP Layer**: Client integration via barrel file

### Used By

- **06 - Rooms**: Embeds Chat UI components into Room screens

## Contribution Guidelines

### DO

- **Use `.select()` for List Items:** In `MessageList` and `CitationsSection`, always use `ref.watch(provider.select(...))` to listen to specific boolean states. This prevents the entire list from rebuilding when one item changes.
- **Scope UI State by Thread:** Use `NotifierProvider.family` (e.g., `citationsExpandedProvider`) for UI state that belongs to a specific conversation. This ensures automatic memory cleanup when the user navigates away.
- **Merge History and Stream in Providers:** Logic that combines historical messages with the incoming streaming chunk should live in a Provider/ViewModel, not in the Widget's `build` method.
- **Handle "Pending" Contexts:** When a user is typing in a room with no thread, use the **Pending Object Pattern** (local state) until the thread is created, then transfer that state to the persistent provider.
- **Extract Complex Workflows:** Use a Controller provider for multi-step actions (Create Thread → Upload Docs → Start Run).

### DON'T

- **No Fat Widget Methods:** Do not implement business logic in widget methods. Logic must move to a Controller provider.
- **Don't Directly Instantiate API Clients:** Never call `ref.read(apiProvider).createThread(...)` inside a widget. Delegate to a controller notifier.
- **No Domain State in Widgets:** Do not store the "Running" state or "Message List" in the Widget. These must come from providers.
- **Don't Block UI during Generation:** Ensure the UI remains responsive. The `activeRunNotifier` must handle background execution while the UI simply watches the stream.
- **No Hardcoded Message Rendering:** Do not use `if/else` chains for message types in the main list. Delegate to specific widgets to keep the list code clean.

### Extending This Component

- **New Message Types:** To support a new message type (e.g., "ImageMessage"), add the type to the `ChatMessage` union in the client, and add a new branch in `ChatMessageWidget.build`.
- **New Citation Sources:** Update `sourceReferencesForUserMessageProvider` to look up the new source location. Update `CitationsSection` to render the new format.
- **Input Actions:** To add a new input action (e.g., "Voice Input"), add the button to `ChatInput` and route the action through a Controller provider.
