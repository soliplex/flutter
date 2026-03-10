# Changelog

## 0.3.0

### Breaking Changes

- **Removed `HostFunctionWiring`** — replaced by `PluginRegistry` + individual
  plugin classes (`DfPlugin`, `ChartPlugin`, `PlatformPlugin`, `StreamPlugin`,
  `FormPlugin`, `AgentPlugin`, `BlackboardPlugin`). Consumers that imported
  `HostFunctionWiring` directly must migrate to the plugin-based factory.
  `createMontyScriptEnvironmentFactory()` handles this automatically.

### Added

- **`LegacyUnprefixedPlugin` mixin** — allows legacy plugins with function
  names that predate the `namespace_` prefix convention.
- **`PluginRegistry.attachTo(bridge)`** — registers all plugin functions
  (plus introspection builtins) onto a `MontyBridge`.
- **`PluginRegistry.disposeAll()`** — calls `onDispose` on all plugins.
- **`LlmPlugin`** — `llm_complete` and `llm_chat` for LLM completions
  via `AgentApi`.
- **`McpPlugin`** — `mcp_call_tool`, `mcp_list_tools`, `mcp_list_servers`
  for MCP tool discovery and invocation via injected callbacks.
- **`extraPlugins` parameter** on `createMontyScriptEnvironmentFactory()`.
- **MCP parameters** on `createMontyScriptEnvironmentFactory()`:
  `mcpExecutor`, `mcpToolLister`, `mcpServerLister`.

## 0.2.0

- Added `PluginRegistry` for discovering and loading `MontyPlugin` instances (#76).

## 0.1.0

- Initial release.
