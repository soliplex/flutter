# T3 - Feature Tests

## Overview

Comprehensive test coverage for Flutter feature screens, shared widgets, utility functions,
design system, and HTTP inspector components.

## Test Files (25)

| Location | File | Test Count |
|----------|------|------------|
| App | `test/features/home/home_screen_test.dart` | 16 |
| App | `test/features/home/connection_flow_test.dart` | 14 |
| App | `test/features/rooms/rooms_screen_test.dart` | 6 |
| App | `test/features/room/room_screen_test.dart` | 18 |
| App | `test/features/history/history_panel_test.dart` | 6 |
| App | `test/features/chat/chat_panel_test.dart` | 20 |
| App | `test/features/chat/widgets/chat_input_test.dart` | 35 |
| App | `test/features/chat/widgets/chat_message_widget_test.dart` | 18 |
| App | `test/features/chat/widgets/message_list_test.dart` | 14 |
| App | `test/features/chat/widgets/citations_section_test.dart` | 10 |
| App | `test/features/chat/widgets/chunk_visualization_page_test.dart` | 10 |
| App | `test/features/settings/settings_screen_test.dart` | 14 |
| App | `test/features/settings/backend_versions_screen_test.dart` | 9 |
| App | `test/features/quiz/quiz_screen_test.dart` | 12 |
| App | `test/features/inspector/http_inspector_panel_test.dart` | 8 |
| App | `test/features/inspector/models/http_event_group_test.dart` | 45 |
| App | `test/features/inspector/models/http_event_grouper_test.dart` | 13 |
| App | `test/features/inspector/widgets/http_event_tile_test.dart` | 10 |
| App | `test/features/inspector/widgets/http_status_display_test.dart` | 11 |
| App | `test/design/theme/theme_test.dart` | 7 |
| App | `test/shared/widgets/async_value_handler_test.dart` | 5 |
| App | `test/shared/widgets/error_display_test.dart` | 12 |
| App | `test/shared/widgets/app_shell_test.dart` | 12 |
| App | `test/shared/utils/date_formatter_test.dart` | 8 |
| App | `test/shared/utils/format_utils_test.dart` | 9 |

## Test Utilities

| Utility | Purpose |
|---------|---------|
| `createTestApp` | Generic widget test wrapper |
| `_MockAuthNotifier` | Auth state simulation |
| `_createAppWithRouter` | GoRouter + ProviderScope wrapper |
| `MockSoliplexApi` | API call simulation |
| `MockHttpTransport` | Network call mocking |
| `TestData` | Factory for test fixtures |
| `SharedPreferences.setMockInitialValues` | Storage mocking |
| `_TrackingActiveRunNotifier` | Run state spy |
| `_TrackingThreadSelectionNotifier` | Selection spy |
| `_TrackingSoliplexApi` | API call spy |

## Test Coverage by Domain

### Home Screen (`home_screen_test.dart`)

**UI:**

| Test Case | Verifies |
|-----------|----------|
| displays header and URL input | Soliplex header, instructions, Connect button |
| displays logo from config | Image widget from LogoConfig |
| loads initial URL from config | Pre-filled TextFormField |

**Validation:**

| Test Case | Verifies |
|-----------|----------|
| validates URL format | Error for non-http/https |
| validates empty URL | Error for empty field |
| accepts valid http/https URL | No validation errors |

**Connection Errors:**

| Test Case | Verifies |
|-----------|----------|
| shows timeout error | NetworkException with isTimeout |
| shows network error | General NetworkException message |
| shows server error (no/with msg) | 500 error display |
| shows generic error | Unknown exception message |

**Connection Flow:**

| Test Case | Verifies |
|-----------|----------|
| enters no-auth mode | No providers → NoAuthRequired → /rooms |
| navigates to login | Providers + unauthenticated → /login |
| navigates to rooms (auth) | Providers + authenticated → /rooms |
| exits no-auth mode | Switching backend exits no-auth first |

### Connection Flow Logic (`connection_flow_test.dart`)

**Pre-Connect Action:**

| Test Case | Verifies |
|-----------|----------|
| returns none (same backend) | No action if URL unchanged |
| returns signOut | Backend changed + Authenticated → signOut |
| returns exitNoAuthMode | Backend changed + NoAuthRequired → exit |
| returns none (unauth/loading) | No action needed |

**Post-Connect Result:**

| Test Case | Verifies |
|-----------|----------|
| returns EnterNoAuthModeResult | No providers → no-auth mode |
| returns AlreadyAuthenticatedResult | Providers + authenticated |
| returns RequireLoginResult | Providers + unauthenticated |

**URL Normalization:**

| Test Case | Verifies |
|-----------|----------|
| removes trailing slash | Normalization logic |
| handles paths/ports | Edge cases |
| equality check | Slash-only difference = equal |

### Rooms Screen (`rooms_screen_test.dart`)

| Test Case | Verifies |
|-----------|----------|
| displays loading indicator | LoadingIndicator while fetching |
| displays room list | Room names rendered |
| displays empty state | EmptyState widget |
| displays error state | ErrorDisplay + Retry |
| displays/hides description | Conditional description text |

### Room Screen (`room_screen_test.dart`)

**Layout:**

| Test Case | Verifies |
|-----------|----------|
| shows desktop layout | HistoryPanel + ChatPanel |
| shows mobile layout | ChatPanel only |

**Sidebar:**

| Test Case | Verifies |
|-----------|----------|
| toggle button hides/shows sidebar | Menu icon behavior |
| toggle icon changes | menu ↔ menu_open |

**Thread Selection:**

| Test Case | Verifies |
|-----------|----------|
| selects thread from query | ?thread= takes precedence |
| falls back to last viewed | Storage fallback |
| falls back to first thread | Default selection |
| sets NoThreadSelected | Empty room handling |
| ignores invalid query | Invalid ID fallback |

**Room Picker:**

| Test Case | Verifies |
|-----------|----------|
| shows current room name | Dropdown display |
| opens dialog | Room selection dialog |
| navigates to selected | Route update |
| shows checkmark | Current room indicator |

### History Panel (`history_panel_test.dart`)

| Test Case | Verifies |
|-----------|----------|
| shows EmptyState | Empty thread list |
| shows NewConversationButton | Button presence |
| displays threads | ThreadListItem rendering |
| highlights selected | Visual state |
| shows activity indicator | Streaming indicator |
| navigates when tapped | URL update |

### Chat Panel (`chat_panel_test.dart`)

**Layout:**

| Test Case | Verifies |
|-----------|----------|
| displays message list/input | Core widgets |
| message list expanded | Vertical space |
| chat input at bottom | Positioning |

**Streaming:**

| Test Case | Verifies |
|-----------|----------|
| shows/hides cancel button | RunningState vs IdleState |

**Input State:**

| Test Case | Verifies |
|-----------|----------|
| input disabled/enabled | Room selection dependency |

**New Thread:**

| Test Case | Verifies |
|-----------|----------|
| creates thread (intent) | NewThreadIntent → API call |
| creates thread (no current) | Null selection → new thread |
| uses existing thread | ThreadSelected → existing ID |

**Suggestions:**

| Test Case | Verifies |
|-----------|----------|
| shows/hides suggestions | Empty/idle vs history/streaming |
| tapping sends message | Chip → startRun |

**Document Selection:**

| Test Case | Verifies |
|-----------|----------|
| persists after submit | Chips remain |
| switching threads restores | Thread-scoped selection |
| new thread empty | Clean selection |
| switching rooms clears | Room-scoped cleanup |

### Chat Input (`chat_input_test.dart`)

**Send Button:**

| Test Case | Verifies |
|-----------|----------|
| enabled/disabled logic | Text + room dependency |
| shows stop button | Active run indicator |
| stop calls cancel | Cancellation trigger |

**Text Input:**

| Test Case | Verifies |
|-----------|----------|
| placeholders | Hint text states |
| allows text entry | Input acceptance |

**Send Action:**

| Test Case | Verifies |
|-----------|----------|
| calls callback | onSend receives text |
| clears input | Post-send cleanup |
| trims whitespace | Input sanitization |
| no empty send | Validation |
| enter key | Keyboard trigger |

**Shortcuts:**

| Test Case | Verifies |
|-----------|----------|
| Shift+Enter | Newline insertion |
| Escape | Focus clear |

**Document Picker:**

| Test Case | Verifies |
|-----------|----------|
| attach button visibility | Room dependency |
| displays selected | Chips above input |
| remove document | X button |
| opens dialog | AlertDialog |
| select/done logic | Checkbox updates |
| disabled state | No documents tooltip |
| search filtering | Case-insensitive filter |
| persist selection | Maintains across filter |

### Chat Message Widget (`chat_message_widget_test.dart`)

**User Message:**

| Test Case | Verifies |
|-----------|----------|
| right alignment | End alignment |
| blue background | Primary container color |
| streaming indicator | Spinner visibility |

**Assistant Message:**

| Test Case | Verifies |
|-----------|----------|
| left alignment | Start alignment |
| grey background | Surface container color |
| markdown rendering | MarkdownBody widget |
| code blocks | Syntax highlighting |

**System Message:**

| Test Case | Verifies |
|-----------|----------|
| centered | Center alignment |
| subtle styling | Smaller font |

**Actions:**

| Test Case | Verifies |
|-----------|----------|
| copy button | Presence for user/agent |
| hide on stream | Hidden during generation |
| snackbar | "Copied" feedback |

### Message List (`message_list_test.dart`)

| Test Case | Verifies |
|-----------|----------|
| shows loading/error | State handling |
| shows empty state | Zero messages UI |
| displays list | Widget rendering |
| unique keys | ValueKey usage |
| streaming display | Synthetic message logic |
| auto-scroll | Bottom scroll on new message |
| computeDisplayMessages | Pure logic unit tests |

### Citations Section (`citations_section_test.dart`)

| Test Case | Verifies |
|-----------|----------|
| shows count | "X sources" text |
| expansion toggle | Header tap behavior |
| persistence | Provider-backed state |
| row expansion | Chevron toggle |
| breadcrumbs | Heading display |
| PDF button | Eye icon for PDFs |
| opens dialog | ChunkVisualizationPage |

### Chunk Visualization (`chunk_visualization_page_test.dart`)

| Test Case | Verifies |
|-----------|----------|
| shows loading indicator | API loading spinner |
| shows images | Base64 image rendering |
| shows empty state | No images UI |
| shows error state | 404/Network error messages |
| retry button | Refresh trigger |
| zoom support | InteractiveViewer widget |

### Settings Screen (`settings_screen_test.dart`)

**Info:**

| Test Case | Verifies |
|-----------|----------|
| frontend version | Version display |
| backend URL | Config URL display |

**Auth States:**

| Test Case | Verifies |
|-----------|----------|
| unauthenticated | "Not signed in" |
| no-auth/disconnect | "No Authentication" + button |
| authenticated | Issuer ID + Sign Out |
| sign out dialog | Confirmation flow |
| loading | "Loading..." text |

**Backend Versions:**

| Test Case | Verifies |
|-----------|----------|
| displays version | Version string |
| View All nav | Navigation to details |

### Backend Versions Screen (`backend_versions_screen_test.dart`)

| Test Case | Verifies |
|-----------|----------|
| displays all versions | Package list |
| shows loading/error | State handling |
| search filtering | Text filter |
| search case-insensitive | Filter logic |
| package count | "X packages" text |
| sort order | Alphabetical |
| empty data | Graceful handling |

### Quiz Screen (`quiz_screen_test.dart`)

**Load:**

| Test Case | Verifies |
|-----------|----------|
| shows loading | Spinner logic |
| start screen | Title, count, Start button |
| error display | 404 handling |

**Interaction:**

| Test Case | Verifies |
|-----------|----------|
| starts quiz | Question view |
| multiple choice | Radio buttons |
| submit disabled | Empty input validation |
| submits answer | API call + feedback |
| submit error | Snackbar logic |

**Flow:**

| Test Case | Verifies |
|-----------|----------|
| navigation | Next vs Results |
| results | Score display |
| retake | Reset logic |

### HTTP Inspector Panel (`http_inspector_panel_test.dart`)

| Test Case | Verifies |
|-----------|----------|
| empty state | "No HTTP activity yet" |
| events displayed | Grouped tiles |
| scrollable list | ListView existence |
| clear button | Trash icon + notifier.clear() |
| request count | "Requests (N)" header |

### HTTP Event Group (`http_event_group_test.dart`)

**Property Access:**

| Test Case | Verifies |
|-----------|----------|
| isStream | StreamStart presence |
| methodLabel | SSE vs HTTP method |
| method precedence | Request > Error > StreamStart |
| uri precedence | Request > Error > StreamStart |
| pathWithQuery | Path extraction |
| timestamp precedence | Request > StreamStart > Error |

**Status Logic:**

| Test Case | Verifies |
|-----------|----------|
| pending | No response |
| success | 2xx codes |
| clientError | 4xx codes |
| serverError | 5xx codes |
| networkError | Error event |
| streaming | Started not ended |
| streamComplete | Ended without error |
| streamError | Ended with error |

**Utility Methods:**

| Test Case | Verifies |
|-----------|----------|
| semanticLabel | Accessibility strings |
| hasSpinner | Pending/streaming = true |
| statusDescription | Human-readable status |
| formatBody | JSON/text/null handling |
| toCurl | CURL command generation |
| copyWith | Immutable updates |

### HTTP Event Grouper (`http_event_grouper_test.dart`)

| Test Case | Verifies |
|-----------|----------|
| empty input | Empty list return |
| single event | Single group |
| request/response grouping | By requestId |
| distinct requests | Separate groups |
| timestamp sorting | Chronological order |
| out-of-order events | Correct grouping |
| error/streaming events | Group association |
| orphan responses/errors | Handled gracefully |
| event overwriting | Later events replace earlier |

### HTTP Event Tile (`http_event_tile_test.dart`)

| Test Case | Verifies |
|-----------|----------|
| request display | Method, path, timestamp, query |
| pending state | "pending..." text |
| success response | Status, duration, size |
| client/server error | Status code display |
| network error | Exception type display |
| SSE streaming | Streaming indicator |
| accessibility | Semantic labels |

### HTTP Status Display (`http_status_display_test.dart`)

| Test Case | Verifies |
|-----------|----------|
| pending status | Spinner + italic |
| success status | 200 OK + success color |
| client error | Warning color |
| server error | Error color |
| network error | Exception type |
| streaming | Spinner + secondary color |
| stream complete | Success color |
| stream error | Error color |
| spinner layout | Size 12x12, stroke 2 |

### Theme (`theme_test.dart`)

| Test Case | Verifies |
|-----------|----------|
| light theme defaults | Default light colors |
| light theme custom | Custom colors applied |
| dark theme defaults | Default dark colors |
| dark theme custom | Custom colors applied |
| Material 3 enabled | M3 flag |
| SoliplexTheme extension | Extension included |
| theme consistency | Light/dark structure match |

### Async Value Handler (`async_value_handler_test.dart`)

| Test Case | Verifies |
|-----------|----------|
| loading state | LoadingIndicator shown |
| custom loading | Custom widget used |
| data state | Data widget shown |
| error state | ErrorDisplay shown |
| retry button | Callback triggered |

### Error Display (`error_display_test.dart`)

| Test Case | Verifies |
|-----------|----------|
| network error | Message + wifi off icon |
| 401 Auth error | Session expired |
| 403 Auth error | Permission denied |
| Not Found error | Resource name handling |
| API error | Status text |
| generic error | Message display |
| retry button | Visibility + callback |
| collapsible details | Show/hide toggle |
| HistoryFetchException | Unwrapping logic |

### App Shell (`app_shell_test.dart`)

| Test Case | Verifies |
|-----------|----------|
| renders body/title/leading/actions | Widget composition |
| HTTP inspector button | AppBar presence |
| inspector tooltip | Accessibility |
| inspector opens drawer | endDrawer behavior |
| start drawer | Optional drawer |
| feature flags | enableHttpInspector toggle |
| custom end drawer | Replacement logic |
| ShellConfig model | Defaults and values |

### Date Formatter (`date_formatter_test.dart`)

| Test Case | Verifies |
|-----------|----------|
| formatRelativeTime | Just now, minutes, hours, days, weeks, months, years |
| getShortId | Truncation to 8 chars |

### Format Utils (`format_utils_test.dart`)

| Test Case | Verifies |
|-----------|----------|
| toHttpTimeString | Zero padding, midnight, EOD |
| toHttpDurationString | ms, s, m formatting |
| toHttpBytesString | B, KB, MB formatting |

## Testing Patterns

- **Widget Tests**: Full widget tree with ProviderScope and GoRouter
- **Tracking Notifiers**: Spy objects to verify method calls
- **State Machine Tests**: UI response to IdleState, RunningState, CompletedState
- **Accessibility**: Semantic labels and tooltips verified
- **Pure Logic Tests**: computeDisplayMessages, formatBody, etc. tested in isolation
- **Error Boundary Tests**: Network, Auth, NotFound, Generic errors all verified
