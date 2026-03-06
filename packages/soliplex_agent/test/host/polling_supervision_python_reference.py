"""
Reference Python supervision patterns for CLAW kernel.

These are the Python equivalents of the Dart tests in
polling_supervision_test.dart. An LLM should be able to generate
code equivalent to these patterns using the host functions:

  spawn_agent(room, prompt) -> handle (int)
  agent_status(handle) -> str  ("spawning"|"running"|"completed"|"failed"|"cancelled")
  get_result(handle) -> str
  cancel_agent(handle) -> bool
  blackboard_write(key, value) -> None
  blackboard_read(key) -> value
  blackboard_keys() -> list[str]
  sleep(ms) -> None
"""


# ---------------------------------------------------------------------------
# Pattern 1: Spawn + poll + collect (happy path)
# ---------------------------------------------------------------------------
def fan_out_poll_collect():
    """Spawn 2 workers, poll until done, collect results."""
    h1 = spawn_agent("chat", "do task A")
    h2 = spawn_agent("chat", "do task B")

    # Poll both until terminal.
    for handle in [h1, h2]:
        while True:
            status = agent_status(handle)
            if status in ("completed", "failed", "cancelled"):
                break
            sleep(500)

    r1 = get_result(h1)
    r2 = get_result(h2)
    return f"Results: {r1}, {r2}"


# ---------------------------------------------------------------------------
# Pattern 2: Blackboard coordination
# ---------------------------------------------------------------------------
def blackboard_aggregation():
    """Workers produce data, supervisor aggregates via blackboard."""
    h1 = spawn_agent("chat", "fetch the current BTC price")
    h2 = spawn_agent("chat", "fetch the current ETH price")

    for handle in [h1, h2]:
        while agent_status(handle) not in ("completed", "failed"):
            sleep(500)

    blackboard_write("btc_price", get_result(h1))
    blackboard_write("eth_price", get_result(h2))
    blackboard_write("summary", f"BTC={blackboard_read('btc_price')}, ETH={blackboard_read('eth_price')}")
    return blackboard_read("summary")


# ---------------------------------------------------------------------------
# Pattern 3: Failure detection + retry
# ---------------------------------------------------------------------------
def retry_on_failure(max_retries=3):
    """Spawn a worker, retry on failure up to max_retries."""
    for attempt in range(max_retries + 1):
        handle = spawn_agent("chat", "flaky task that sometimes fails")

        while True:
            status = agent_status(handle)
            if status in ("completed", "failed", "cancelled"):
                break
            sleep(500)

        if status == "completed":
            return get_result(handle)

        # Failed — cancel and retry.
        cancel_agent(handle)

    return "ERROR: all retries exhausted"


# ---------------------------------------------------------------------------
# Pattern 4: Timeout + cancel
# ---------------------------------------------------------------------------
def timeout_cancel(max_polls=10):
    """Cancel a worker that takes too long."""
    handle = spawn_agent("chat", "potentially slow task")

    for _ in range(max_polls):
        status = agent_status(handle)
        if status in ("completed", "failed"):
            break
        sleep(500)
    else:
        # Exhausted all polls — cancel.
        cancel_agent(handle)
        return "TIMEOUT: cancelled worker"

    if status == "completed":
        return get_result(handle)
    return f"FAILED: {status}"


# ---------------------------------------------------------------------------
# Pattern 5: Mixed outcomes with partial results
# ---------------------------------------------------------------------------
def mixed_outcomes():
    """Handle mix of success, failure, timeout across workers."""
    tasks = ["task-ok", "task-fail", "task-slow"]
    handles = [spawn_agent("chat", t) for t in tasks]

    results = {}
    failures = []
    timeouts = []

    for h in handles:
        polls = 0
        while polls < 10:
            status = agent_status(h)
            if status in ("completed", "failed", "cancelled"):
                break
            sleep(500)
            polls += 1
        else:
            timeouts.append(h)
            cancel_agent(h)
            continue

        if status == "completed":
            results[h] = get_result(h)
        else:
            failures.append(h)

    blackboard_write("successes", len(results))
    blackboard_write("failures", len(failures))
    blackboard_write("timeouts", len(timeouts))
    return results


# ---------------------------------------------------------------------------
# Pattern 6: Nested supervision (2-level)
# ---------------------------------------------------------------------------
def nested_supervisor():
    """L1 supervisor polls an L2 sub-supervisor."""
    sub = spawn_agent(
        "chat",
        "You are a sub-supervisor. Spawn 2 workers, aggregate their outputs, "
        "and return the combined result.",
    )

    while True:
        status = agent_status(sub)
        if status in ("completed", "failed"):
            break
        sleep(1000)

    if status == "completed":
        result = get_result(sub)
        blackboard_write("l2_result", result)
        return result
    return "Sub-supervisor failed"
