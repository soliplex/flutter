# soliplex_cli

Interactive REPL for exercising `soliplex_agent` against a live Soliplex
backend. Thread-aware conversational model with parallel agent support.

## Quick start

```bash
cd packages/soliplex_cli
dart pub get
dart run bin/soliplex_cli.dart

# With options:
dart run bin/soliplex_cli.dart --soliplex http://localhost:8000 --room plain
```

## Options

| Flag | Env var | Default |
|------|---------|---------|
| `--soliplex`, `-s` | `SOLIPLEX_BASE_URL` | `http://localhost:8000` |
| `--room`, `-r` | `SOLIPLEX_ROOM_ID` | `plain` |
| `--help`, `-h` | | |

## Commands

| Command | Description |
|---------|-------------|
| `<text>` | Send prompt (continues current thread) |
| `/new [roomId] [prompt]` | Start fresh thread; optionally send prompt |
| `/room <roomId> <text>` | Send prompt to a specific room |
| `/spawn <text>` | Spawn background session (new ephemeral thread) |
| `/thread` | Show active threads per room |
| `/sessions` | List active background sessions |
| `/waitall` | Wait for all background sessions |
| `/waitany` | Wait for first to complete |
| `/cancel` | Cancel all sessions |
| `/rooms` | List available backend rooms |
| `/examples` | Show usage walkthrough |
| `/clear` | Clear terminal |
| `/help` | Show command reference |
| `/quit` | Exit |

## Thread model

Bare text reuses the current thread for the default room. Each `/room`
target maintains its own thread. Use `/new` to start fresh:

```text
> Hello                             # creates thread in default room
> What did I just say?              # continues same thread
> /new                              # clears thread for default room
> Hello again                       # new thread
> /new plain Tell me a joke         # clear + send in one step
```

Use `/thread` to see active threads per room.

## Built-in tools

The CLI registers two demo client-side tools that the agent can call:

| Tool | Params | Returns |
|------|--------|---------|
| `secret_number` | none | `"42"` |
| `echo` | `text` (string) | the `text` value |

## Architecture

```text
bin/soliplex_cli.dart        Entry point
lib/src/
  cli_runner.dart            REPL loop, command dispatch, _CliContext
  client_factory.dart        Creates SoliplexApi + AgUiClient from host URL
  tool_definitions.dart      Demo tool registry (secret_number, echo)
  result_printer.dart        Formats AgentResult for terminal output
example/
  parallel_agents.dart       Programmatic parallel session example
```

The CLI creates an `AgentRuntime` (from `soliplex_agent`) which manages
sessions. Each session spawns an AG-UI thread on the backend, streams
events via SSE, and auto-executes any client-side tool calls.

## Example session

```text
$ dart run bin/soliplex_cli.dart

soliplex-cli connected to http://localhost:8000 (room: plain)
tools: [secret_number, echo]

> Hello, how are you?
Starting new thread...
[abc123abcdef...] SUCCESS: Hello! I'm doing well...

> What did I just say?
Continuing thread abc123abcdef...
[abc123abcdef...] SUCCESS: You said "Hello, how are you?"

> /new plain What is the meaning of life?
New thread in room "plain".
Starting new thread...
[def456def456...] SUCCESS: That's a deep question...

> /spawn Tell me a joke
Spawned session joke12345678... (1 tracked)
> /spawn What is 2+2?
Spawned session math98765432... (2 tracked)
> /waitall
Waiting for 2 session(s)...
[joke12345678...] SUCCESS: Why did the chicken...
[math98765432...] SUCCESS: 2+2 = 4.

> /thread
  plain -> def456def456...

> /quit
```

## Scenario rooms

Use `/room` to target backend scenario rooms:

```text
> /room echo-room Say hello                  # basic lifecycle
> /room tool-call-room Call secret_number     # single tool call
> /room multi-tool-room Chain the tools       # multi-tool chaining
> /room error-room Trigger an error           # mid-stream error
> /room cancel-room Start a long task         # then /cancel or Ctrl+C
```
