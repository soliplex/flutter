# soliplex_tui

Rich terminal user interface for interacting with the Soliplex agent backend. It serves as the primary pure-Dart client for developers and headless environments.

## Quick Start

```bash
cd packages/soliplex_tui
dart pub get
dart test
dart format . --set-exit-if-changed
dart analyze --fatal-infos
```

## Architecture

### Entry Points

- `launchTui()` -- Start the interactive TUI application.
- `runHeadless()` -- Send a single message, print the final response, and exit.
- `listRooms()` -- List available rooms on the server.

### State Management

- `TuiChatCubit` -- Manages the chat state by listening to the `RunOrchestrator` and handling user input.
- `TuiChatState` -- Abstract base class for all chat UI states.
- `TuiIdleState` -- The application is awaiting user input.
- `TuiStreamingState` -- An AG-UI response is actively being streamed.
- `TuiExecutingToolsState` -- The client is executing tool calls yielded by the agent.
- `TuiErrorState` -- Displays a fatal error.

### UI Components

- `SoliplexTuiApp` -- The root `nocterm` component that sets up the theme and initial page.
- `ChatPage` -- The main screen component, containing the header, chat body, input row, and footer.
- `ChatBody` -- A scrollable component that displays the list of chat messages.
- `InputRow` -- The text input field with a prompt for the user to type messages.
- `MessageItem` -- Renders a single, finalized `ChatMessage`.
- `StreamingMessageItem` -- Renders the in-progress assistant message as it streams.

### Utilities

- `Loggers` -- A namespace providing static access to pre-configured loggers for different subsystems.
- `FileSink` -- A `LogSink` implementation that writes log records to a specified file.

## Dependencies

- `nocterm` -- The core terminal UI framework used to build the entire interface.
- `nocterm_bloc` -- `BlocProvider` and `BlocBuilder` components for integrating state management with the UI.
- `soliplex_agent` -- Core agent interaction logic, including `RunOrchestrator` and data models.
- `soliplex_logging` -- Shared logging framework.
- `bloc` -- State management library used by `TuiChatCubit`.
- `args` -- Command-line argument parsing.

## Example

```dart
import 'package:soliplex_tui/soliplex_tui.dart';

Future<void> main() async {
  // Launch the interactive terminal UI.
  await launchTui(
    serverUrl: 'http://localhost:8080',
    logFile: 'soliplex_tui.log',
  );
}
```
