# Changelog

## 0.3.0

- Wire `ChatFnLlmProvider` + MCP tools into `AgentRuntime` (#142).
- Add `mergeWithMcpTools()` for bridging MCP server tools into `ToolRegistry`.
- LLM provider and MCP wiring are independent of `--monty` flag.
- New `--llm-provider`, `--llm-model`, `--llm-url`, `--llm-api-key`, `--mcp` flags.

## 0.2.0

- Updated for `ServerConnection` unification (#57).
- Updated for `AgUiStreamClient` migration (#62).

## 0.1.0

- Initial release.
