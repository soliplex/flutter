# Gemini 3.1 Pro Analysis: Monty Process Optimization & Novel Capabilities

**Date:** 2026-03-06
**Model:** gemini-3.1-pro-preview
**Context:** 8 files including prompt.txt, experiment results, df_functions.dart, host_function_wiring.dart

## Round 1: Process Optimization

### 1. Prompt Improvements for Error Patterns

Replace negative constraints with positive workarounds. Change the NOT Supported section to:

```text
## CRITICAL LIMITATIONS & WORKAROUNDS (Failure to follow = crash)
1. IMPORTS ARE FORBIDDEN.
   -> Instead of `math.sqrt(x)`, use `x ** 0.5`.
   -> Instead of `collections.Counter`, use pure dictionary loops.
2. TUPLES WILL CRASH THE PARSER.
   -> `sorted([(1, 'a'), (2, 'b')])` WILL CRASH.
   -> Workaround: Convert to list of dicts and sort manually.
3. NESTED DICT ASSIGNMENT WILL CRASH.
   -> `d[k1][k2] = val` WILL CRASH.
   -> Workaround: `temp = d[k1]; temp[k2] = val; d[k1] = temp`
4. NO `.format()`. Use f-strings or string concatenation.
5. DICT KEY INITIALIZATION: `d[key] += 1` will crash if key is variable.
   -> Workaround: Use flat counter variables instead.
```

### 2. Fix 120B Ambiguity Failures

Add to Rules section:

```text
5. ZERO CLARIFICATION RULE: If the user's prompt is vague, lacks specific
   requirements, or does not provide data, DO NOT ask for clarification.
   You MUST invent reasonable sample data and provide a representative
   analysis or script immediately.
```

### 3. Unaddressed Monty Parser Limitations

- Variable keys in dict subscript store (`d[key] += 1`) -- use flat counters
- Already addressed by existing prompt but models still hit it

## Round 2: Novel Capabilities Within Reach

### 1. Multi-Agent Orchestration via Python

- `ask_llm`, `spawn_agent`, `wait_all` already exist in host wiring
- LLM writes Python that spawns sub-agents, waits, aggregates
- Use case: chunk-and-summarize workflows

### 2. Network / API Integration

- Add `host_fetch(url, method, headers_dict, body_dict) -> dict`
- LLM pulls live data, parses JSON, creates DataFrames, charts
- All in one zero-shot prompt

### 3. State Persistence (Multi-Turn Workflows)

- Add `kv_set(key, val_dict)` and `kv_get(key) -> val_dict`
- Prompt 1 processes data, saves results
- Prompt 2 builds on saved state

## Round 3: Flutter Widget Tree Generation

### Architecture: Redux-like Unidirectional Data Flow

#### Schema Format (Python dict -> widget tree)

```python
ui_schema = {
    "id": "main_view",
    "type": "Column",
    "props": {"spacing": 10},
    "children": [
        {"type": "Text", "props": {"text": "Click Counter", "style": "heading"}},
        {"type": "Text", "bind": "counter_val"},
        {
            "type": "Button",
            "props": {"label": "Increment"},
            "action": {"intent": "INCREMENT_COUNTER", "payload": {"step": 1}}
        }
    ]
}
```

#### Host Function API

- `ui_render(schema_dict)` -> parse dict into Flutter widgets
- `state_init(key_str, initial_val)` -> create reactive ValueNotifier
- `state_update(key_str, new_val)` -> push new value to notifier

#### State Bridge (Python -> Flutter)

- `state_init("counter_val", 0)` creates `ValueNotifier<dynamic>(0)`
- `ui_render` with `"bind": "counter_val"` wraps Text in `ValueListenableBuilder`
- `state_update("counter_val", 1)` triggers only that widget to rebuild

#### Interaction Bridge (Flutter -> Python)

Intent/Reducer pattern:
1. LLM generates Python calling `state_init` + `ui_render`
2. User taps button -> Flutter catches `"action": {"intent": "INCREMENT_COUNTER"}`
3. Dart triggers `execute_python` with reducer code
4. Python reads state, computes new state, calls `state_update`

### Most Impactful Application

LLM-generated internal tooling dashboards. Prompt: "admin panel to view users
with search bar and ban button." Python generates UI schema, hooks up intents,
handles data fetching via host_fetch, and pushes state updates to Flutter ListView.
