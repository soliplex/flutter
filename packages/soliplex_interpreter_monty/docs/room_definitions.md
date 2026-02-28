# Room Definitions

Test scenarios organized by layer. Each room defines registered tools,
sample Python code, and expected event sequences. These serve as:

- **Integration test fixtures** in this package
- **M7 backend room definitions** for real server testing

## Layer 0 — Pure Python Execution

No host functions registered (except `__console_write__` for print).

### calculator

- **Tools:** none
- **Scenario:** LLM writes arithmetic Python
- **Python:** `result = sum(range(1, 101))`
- **Expected value:** 5050
- **Events:** `RunStarted → RunFinished`
- **Validates:** code execution, return value propagation

### formatter

- **Tools:** none
- **Scenario:** Python formats text and prints output
- **Python:** `print(f"Total: ${42 * 1.08:.2f}")`
- **Expected output:** `Total: $45.36`
- **Events:** `RunStarted → TextMessageStart → TextMessageContent → TextMessageEnd → RunFinished`
- **Validates:** print capture and flush, string formatting

### error_room

- **Tools:** none
- **Scenario:** Python raises an exception
- **Python:** `raise ValueError("invalid input")`
- **Events:** `RunStarted → RunError`
- **Validates:** error propagation, MontyException fields

---

## Layer 1 — Client-Side Tool Calls

Python calls registered Dart host functions. The bridge intercepts
`MontyPending`, dispatches to handler, resumes with result.

### clock

- **Tools:** `get_current_time() → string`
- **Scenario:** Single tool call, format result
- **Events:** `RunStarted → Step → ToolCall sequence → TextMessage → RunFinished`
- **Validates:** single host function dispatch, result flows back to Python

Python:

```python
t = get_current_time()
print(f"The time is {t}")
```

### weather

- **Tools:** `get_temperature(city: string) → number`, `get_forecast(city: string, days: integer) → string`
- **Scenario:** Multiple sequential tool calls
- **Events:** 2x (Step + ToolCall sequence) + TextMessage + RunFinished
- **Validates:** multiple sequential dispatches, typed params (string + integer)

Python:

```python
temp = get_temperature("NYC")
forecast = get_forecast("NYC", 3)
print(f"NYC: {temp}°F — {forecast}")
```

### converter

- **Tools:** `get_exchange_rate(from_currency: string, to_currency: string) → number`
- **Scenario:** Tool call with computation on result
- **Events:** Step + ToolCall sequence + TextMessage + RunFinished
- **Validates:** number return type, Python arithmetic on host function result

Python:

```python
rate = get_exchange_rate("USD", "EUR")
converted = 1000 * rate
print(f"$1000 = €{converted:.2f}")
```

### multi_tool

- **Tools:** `add(a: integer, b: integer) → integer`, `multiply(a: integer, b: integer) → integer`
- **Scenario:** Chained tool calls where second depends on first
- **Events:** 2x tool call sequences + RunFinished
- **Validates:** return value used as input to next call, integer types

Python:

```python
s = add(3, 4)
result = multiply(s, 10)
```

### error_handling

- **Tools:** `risky_call() → string` (handler throws Exception)
- **Scenario:** Host function handler fails
- **Python:** `result = risky_call()`
- **Events:** Step + ToolCall + ToolCallResult(error) + StepFinished + RunFinished
- **Validates:** handler exception → `resumeWithError()`, Python sees the error

### unknown_function

- **Tools:** `known_fn() → string` (registered)
- **Scenario:** Python calls a function that isn't registered
- **Python:** `unknown_fn()` (not registered)
- **Events:** RunStarted → RunError (after resumeWithError)
- **Validates:** unknown function → error resume, bridge doesn't crash

### introspection

- **Tools:** registry with `get_price(symbol: string) → number` in category "finance"
- **Scenario:** Python calls `list_functions()` and `help("get_price")`
- **Events:** 2x tool call sequences + RunFinished
- **Validates:** HostFunctionRegistry + introspection builtins work end-to-end

Python:

```python
funcs = list_functions()
info = help("get_price")
```

---

## Layer 2 — Agentic Orchestration (Simulated)

Full tool-call → Python → host-function → resume round-trip with
registry-based wiring. Simulates the agentic loop where an LLM yields
`execute_python`, the app calls `bridge.execute(code)`, and Python
orchestrates host functions.

### research_assistant

- **Tools (registry):** `search(query: string) → string`, `summarize(text: string, max_words: integer) → string`
- **Scenario:** Python orchestrates a search + summarize pipeline
- **Events:** 2x tool calls + TextMessage + RunFinished
- **Validates:** multi-step pipeline via host functions, string args and returns

Python:

```python
raw = search("quantum computing breakthroughs 2026")
summary = summarize(raw, 50)
print(summary)
```

### data_analysis

- **Tools (registry):** `fetch_sales(region: string) → list`, `chart_bar(title: string, data: list) → map`
- **Scenario:** Fetch data, process in Python, render chart
- **Events:** 2x tool calls + RunFinished
- **Validates:** list/map param types, Python data processing between calls, complex object passing

Python:

```python
sales = fetch_sales("northeast")
totals = {}
for entry in sales:
    totals[entry["month"]] = totals.get(entry["month"], 0) + entry["amount"]
chart_bar("NE Sales by Month", list(totals.items()))
```

### multi_step_with_print

- **Tools (registry):** `get_data(key: string) → map`, `store_result(key: string, value: string) → boolean`
- **Scenario:** Fetch, transform, store, with progress prints
- **Events:** Tool calls interleaved with print buffer (prints flushed at end) + RunFinished
- **Validates:** print interleaving with tool calls, boolean return type

Python:

```python
print("Fetching data...")
data = get_data("user_prefs")
print(f"Got {len(data)} fields")
result = ", ".join(f"{k}={v}" for k, v in data.items())
stored = store_result("summary", result)
print(f"Stored: {stored}")
```

---

## Room Counts by Layer

| Layer | Rooms | Purpose |
|-------|-------|---------|
| 0 | 3 | Pure Python — no host functions |
| 1 | 7 | Client-side tool calls |
| 2 | 3 | Agentic orchestration pipelines |
| **Total** | **13** | |
