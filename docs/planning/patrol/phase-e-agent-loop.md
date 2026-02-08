# Phase E: Agent-in-the-Loop Testing

**Status:** draft
**Depends on:** Phase D (Log Hardening)

## Objective

Enable an AI agent to run, observe, diagnose, and fix Patrol E2E tests
through Soliplex's own chat UI. The app tests itself through a "Test Runner"
room backed by the same pydantic\_ai agent infrastructure that powers all
other rooms.

## Soliplex Room Architecture (Context)

Every Soliplex room is defined in `~/dev/soliplex/example/rooms/<id>/`:

```yaml
# room_config.yaml
id: "patrol"
name: "Patrol Test Runner"
agent:
  template_id: "default_chat"
  system_prompt: "./prompt.txt"
tools:
  - tool_name: "soliplex.tools.run_patrol_test"   # native Python tool
  - tool_name: "soliplex.tools.read_test_file"
mcp_client_toolsets:
  dart_tools:                                       # dart-tools MCP server
    kind: "stdio"
    command: "dart"
    args: ["run", "dart_mcp_server"]
```

Tools are async Python functions registered via `tool_name` paths. The agent
(pydantic\_ai) calls them during conversation and streams results via AG-UI
`text_delta` events. MCP toolsets are wired in directly — the dart-tools
server becomes available as tools the agent can call.

## Key Architectural Decision: Skill-First, Room-Second

The **Patrol skill** (`.claude/skills/patrol/SKILL.md`) documents the
patterns. The room's system prompt references the same knowledge. This means:

- The skill works standalone (Claude Code CLI) when the app is broken
- The room adds AG-UI chat streaming on top
- Both share the same test patterns and troubleshooting knowledge

```text
+-------------------+     +--------------------+
| Claude Code CLI   |     | Patrol Room (UI)   |
| (skill-first)     |     | (AG-UI streaming)  |
+--------+----------+     +--------+-----------+
         |                          |
         v                          v
+--------+----------+     +--------+-----------+
| patrol CLI        |     | pydantic_ai Agent  |
| dart-tools MCP    |     |  + native tools    |
| file edit         |     |  + dart-tools MCP  |
+-------------------+     +--------------------+
         |                          |
         v                          v
+------------------------------------------------+
|              Test App Instance                  |
|        (spawned by patrol / MCP launch)         |
+------------------------------------------------+
```

## Two-App Model

Patrol owns the test app's VM service during execution. Concurrent MCP
attachment would create contention. Therefore:

- **Control App**: Instance the user chats in
- **Test App**: Ephemeral instance spawned by `patrol test`
- **MCP inspection is post-mortem**: After failure, agent launches a fresh
  app via `test_driver/app.dart` for interactive debugging

## Milestones

### v1 — Run and Report (MVP)

Agent runs tests and streams results to the chat room.

**Room config:**

```yaml
# ~/dev/soliplex/example/rooms/patrol/room_config.yaml
id: "patrol"
name: "Patrol Test Runner"
description: "Run and debug E2E tests from chat"
suggestions:
  - "Run the settings test"
  - "Run all no-auth tests"
  - "What tests are available?"
agent:
  template_id: "default_chat"
  system_prompt: "./prompt.txt"
tools:
  - tool_name: "soliplex.tools.patrol_run"
```

**Native tool** (`soliplex/tools.py` or dedicated module):

```python
async def patrol_run(
    ctx: pydantic_ai.RunContext[AgentDependencies],
    target: str,
    backend_url: str = "http://localhost:8000",
) -> str:
    """Run a Patrol E2E test and return results.

    Args:
        target: Test file name (e.g., "settings_test.dart")
        backend_url: Backend URL for the test app
    """
    cmd = [
        "/Users/runyaga/.pub-cache/bin/patrol", "test",
        "--device", "macos",
        "--target", f"integration_test/{target}",
    ]
    if backend_url != "http://localhost:8000":
        cmd.extend(["--dart-define", f"SOLIPLEX_BACKEND_URL={backend_url}"])

    proc = await asyncio.create_subprocess_exec(
        *cmd,
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.STDOUT,
        cwd="/Users/runyaga/dev/soliplex-flutter-patrol",
    )
    stdout, _ = await proc.communicate()
    output = stdout.decode()

    if proc.returncode == 0:
        return f"All tests in {target} PASSED.\n\n{output[-500:]}"
    else:
        return f"FAILED (exit {proc.returncode}).\n\n{output[-1000:]}"
```

The agent receives the tool result and streams it to chat via AG-UI. The
pydantic\_ai framework handles the `text_delta` streaming automatically —
the tool just returns a string.

**System prompt** (`prompt.txt`):

```text
You are the Patrol Test Runner for the Soliplex Flutter app.

Available tests:
- smoke_test.dart — app boot, log harness (no-auth, localhost:8000)
- live_chat_test.dart — rooms, chat send/receive (no-auth, localhost:8000)
- settings_test.dart — settings tiles, network log viewer (no-auth)
- oidc_test.dart — OIDC auth via ROPC (requires credentials)

When asked to run a test, use the patrol_run tool with the target filename.
Report results clearly: which tests passed, which failed, and why.
```

**Example interaction:**

```text
User: run the settings test
Agent: Running settings_test.dart... [calls patrol_run tool]
Agent: Both tests in settings_test.dart PASSED:
  - settings - navigate and verify tiles (6.1s)
  - settings - network log viewer tabs (8.3s)
```

### v2 — Diagnose via MCP

Wire the dart-tools MCP server into the room for post-mortem inspection.

**Room config addition:**

```yaml
mcp_client_toolsets:
  dart_tools:
    kind: "stdio"
    command: "dart"
    args: ["run", "dart_mcp_server"]
    env:
      DART_TOOLING_DAEMON_PORT: "0"
```

This gives the agent access to `launch_app`, `flutter_driver` (screenshot,
tap, get\_widget\_tree), `hot_reload`, and `get_runtime_errors` — all as
callable tools during conversation.

**New deliverables:**

1. **Post-mortem inspection** — on failure, agent uses MCP to launch app
   via `test_driver/app.dart`, navigates to the failure point, takes a
   screenshot, and sends the image in chat
2. **Widget tree analysis** — agent inspects `get_widget_tree` to diagnose
   finder mismatches (e.g., "the Back button tooltip matches the
   inspector's back-to-settings, not a detail page back")
3. **Log correlation** — agent reads MemorySink dump from test output and
   identifies where behavior diverged

### v3 — Self-Healing

Add file read/write tools and guardrails for autonomous fixes.

**Additional tools:**

```yaml
tools:
  - tool_name: "soliplex.tools.patrol_run"
  - tool_name: "soliplex.tools.patrol_read_file"
  - tool_name: "soliplex.tools.patrol_write_file"
```

**Guardrails:**

1. `patrol_write_file` restricted to `integration_test/` and
   `.claude/skills/` paths only
2. Agent shows diff in chat, waits for user confirmation
3. Max 2 fix-and-retry attempts per session
4. Rollback if other tests regress after a fix

## Risks

| Risk | Severity | Mitigation |
|------|----------|------------|
| App broken, room UI fails | High | Skill-first: CLI fallback works standalone |
| Infinite fix-fail loop | Medium | Max 2 retries per command |
| Port conflicts | Medium | Test app uses `--dart-define` isolation |
| MCP contention during test | High | Post-mortem only (v2) |
| Unsafe code mutation | High | Scope restriction + diff preview + rollback |
| Shell injection via chat | High | `patrol_run` tool validates `target` against allowlist |
| Dev-only feature leaks | Low | Room only loaded when `SOLIPLEX_DEV_MODE=true` |

## Review Gates

### v1 Gate

| Gate | Criteria |
|------|----------|
| **Room loads** | Patrol room appears in room list, agent responds to messages |
| **Tool call** | "Run smoke test" triggers `patrol_run` tool, output streams to chat |
| **Pass/Fail** | Agent correctly reports pass/fail status from tool result |

### v2 Gate

| Gate | Criteria |
|------|----------|
| **MCP wired** | dart-tools MCP toolset available in room agent |
| **Screenshot** | Agent takes screenshot of running app and shows in chat |
| **Diagnosis** | Agent uses widget tree to explain a finder mismatch |

### v3 Gate

| Gate | Criteria |
|------|----------|
| **Diff preview** | Agent shows proposed edit before writing |
| **Scope guard** | Agent refuses to modify `lib/` without explicit approval |
| **Green** | Agent fixes a finder error and re-runs to green |

## Open Questions

1. **dart-tools MCP stdio launch**: What is the exact command to start
   the dart-tools MCP server in stdio mode? Need to verify the package
   path and args for `mcp_client_toolsets`.
2. **AG-UI image support**: Can AG-UI stream inline images from MCP
   screenshots? Or must they be saved as files and linked?
3. **Tool output streaming**: pydantic\_ai tools return strings after
   completion. For long-running `patrol test` (30-60s), can we stream
   partial output via AG-UI state deltas instead of waiting for the
   full result?
4. **OIDC room credentials**: How does the patrol room pass
   `--dart-define SOLIPLEX_OIDC_USERNAME` securely? Use
   `secret:PATROL_OIDC_USERNAME` from installation config.
