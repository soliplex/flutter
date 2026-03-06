# Changelog

## 0.2.0

- Updated for `ServerConnection` unification (#57).
- Updated for `AgUiStreamClient` migration (#62, #63).

## 0.1.0

- Initial release.
- Interactive REPL with thread-aware conversational model.
- Commands: bare text, `/spawn`, `/room`, `/new`, `/thread`,
  `/sessions`, `/waitall`, `/waitany`, `/cancel`, `/rooms`,
  `/examples`, `/clear`, `/help`, `/quit`.
- Built-in demo tools: `secret_number`, `echo`.
- Parallel agent support via `/spawn` + `/waitall` / `/waitany`.
- SIGINT handling: first cancels sessions, second force-exits.
- Example: `parallel_agents.dart`.
