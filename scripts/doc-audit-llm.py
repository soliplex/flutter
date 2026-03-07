#!/usr/bin/env python3
"""Stage 2: LLM-powered documentation evaluation.

Reads the deterministic report from Stage 1 and each doc file, sends them
to OpenAI for evaluation against the readiness gate criteria from
MAINTENANCE.md, and outputs structured findings as JSON.
"""

import json
import os
import sys
from pathlib import Path

try:
    from openai import OpenAI
except ImportError:
    print("ERROR: openai package not installed. Run: pip install openai", file=sys.stderr)
    sys.exit(1)

SYSTEM_PROMPT = """\
You are a documentation auditor for the Soliplex Flutter monorepo. Your job is
to evaluate documentation against the maintenance protocol's readiness gate.

## Governing Principle: Fail by Default

All documentation is assumed stale until proven current. The burden of proof is
on the document, not the reviewer. No effort = fail. Evidence required.

## Your Evaluation Process

For each document you are given:
1. Check if the deterministic assertions relevant to it passed or failed
2. Evaluate the document content against these criteria:
   - Are factual claims verifiable by running a command or reading source?
   - Do code examples look correct (classes/methods exist, signatures match)?
   - Is the content consistent with other docs and the assertion report?
   - Are there signs of staleness (references to deleted code, old patterns)?
3. Produce a verdict: PASS or FAIL
4. For FAIL: describe exactly what is wrong with specific evidence

## Anti-Sycophancy Rules (MANDATORY)

- You MUST attempt to FALSIFY each document, not confirm it
- You MUST report at least one concern or gap per document, even if minor
- If you genuinely find zero issues, state: "I found no issues. This is
  unusual — a human should double-check."
- "Looks good" or "appears complete" is NOT evidence
- "I could not find a counterexample" is NOT evidence of correctness

## Output Format

Return a JSON array of findings. Each finding is an object:
{
  "file": "path/to/doc.md",
  "verdict": "PASS" or "FAIL",
  "score": "N/6",
  "concerns": ["specific concern 1", "specific concern 2"],
  "evidence": "raw evidence supporting concerns",
  "suggested_fix": "concrete action to resolve (for FAIL only)"
}

Return ONLY the JSON array, no markdown fences, no preamble.
"""


def load_report(report_path: str) -> dict:
    with open(report_path) as f:
        return json.load(f)


def collect_docs(repo_root: str) -> list[tuple[str, str]]:
    """Collect all non-archived markdown docs with their content."""
    docs_dir = Path(repo_root) / "docs"
    docs = []
    for md_file in sorted(docs_dir.rglob("*.md")):
        if "archive" in md_file.parts:
            continue
        rel_path = str(md_file.relative_to(repo_root))
        try:
            content = md_file.read_text(encoding="utf-8")
            # Skip very large files (> 50KB) to stay within token limits
            if len(content) > 50_000:
                content = content[:50_000] + "\n\n[TRUNCATED — file exceeds 50KB]"
            docs.append((rel_path, content))
        except Exception as e:
            print(f"WARNING: Could not read {md_file}: {e}", file=sys.stderr)
    return docs


def build_user_prompt(report: dict, docs: list[tuple[str, str]]) -> str:
    """Build the user prompt with the deterministic report and doc contents."""
    parts = [
        "## Deterministic Audit Report (Stage 1)\n",
        "```json",
        json.dumps(report, indent=2),
        "```\n",
        f"## Documents to Evaluate ({len(docs)} files)\n",
    ]
    for path, content in docs:
        parts.append(f"### {path}\n")
        parts.append(f"```markdown\n{content}\n```\n")

    return "\n".join(parts)


def run_evaluation(report: dict, docs: list[tuple[str, str]]) -> list[dict]:
    """Send docs to OpenAI for evaluation."""
    api_key = os.environ.get("OPENAI_API_KEY")
    if not api_key:
        print("ERROR: OPENAI_API_KEY not set", file=sys.stderr)
        sys.exit(1)

    client = OpenAI(api_key=api_key)
    user_prompt = build_user_prompt(report, docs)

    # Estimate tokens — bail if too large
    estimated_chars = len(SYSTEM_PROMPT) + len(user_prompt)
    if estimated_chars > 500_000:
        print(
            f"WARNING: Input is ~{estimated_chars // 1000}K chars. "
            "Splitting into batches.",
            file=sys.stderr,
        )
        return run_batched_evaluation(client, report, docs)

    print(f"Sending {len(docs)} docs to OpenAI for evaluation...", file=sys.stderr)

    response = client.chat.completions.create(
        model="gpt-4o",
        temperature=0.1,
        response_format={"type": "json_object"},
        messages=[
            {"role": "system", "content": SYSTEM_PROMPT},
            {"role": "user", "content": user_prompt},
        ],
    )

    content = response.choices[0].message.content
    try:
        result = json.loads(content)
        # Handle both {"findings": [...]} and bare [...]
        if isinstance(result, list):
            return result
        if isinstance(result, dict) and "findings" in result:
            return result["findings"]
        return [result]
    except json.JSONDecodeError as e:
        print(f"ERROR: Failed to parse LLM response as JSON: {e}", file=sys.stderr)
        print(f"Raw response: {content[:500]}", file=sys.stderr)
        sys.exit(1)


def run_batched_evaluation(
    client: OpenAI, report: dict, docs: list[tuple[str, str]]
) -> list[dict]:
    """Split docs into batches and evaluate each separately."""
    BATCH_SIZE = 5
    all_findings = []

    for i in range(0, len(docs), BATCH_SIZE):
        batch = docs[i : i + BATCH_SIZE]
        batch_num = (i // BATCH_SIZE) + 1
        total_batches = (len(docs) + BATCH_SIZE - 1) // BATCH_SIZE
        print(
            f"  Batch {batch_num}/{total_batches}: {len(batch)} docs...",
            file=sys.stderr,
        )

        user_prompt = build_user_prompt(report, batch)
        response = client.chat.completions.create(
            model="gpt-4o",
            temperature=0.1,
            response_format={"type": "json_object"},
            messages=[
                {"role": "system", "content": SYSTEM_PROMPT},
                {"role": "user", "content": user_prompt},
            ],
        )
        content = response.choices[0].message.content
        try:
            result = json.loads(content)
            if isinstance(result, list):
                all_findings.extend(result)
            elif isinstance(result, dict) and "findings" in result:
                all_findings.extend(result["findings"])
            else:
                all_findings.append(result)
        except json.JSONDecodeError as e:
            print(
                f"WARNING: Batch {batch_num} response not valid JSON: {e}",
                file=sys.stderr,
            )

    return all_findings


def main():
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} <report.json> [repo_root]", file=sys.stderr)
        sys.exit(1)

    report_path = sys.argv[1]
    repo_root = sys.argv[2] if len(sys.argv) > 2 else "."

    report = load_report(report_path)
    docs = collect_docs(repo_root)
    print(f"Collected {len(docs)} docs for evaluation", file=sys.stderr)

    findings = run_evaluation(report, docs)

    # Add summary stats
    fail_count = sum(1 for f in findings if f.get("verdict") == "FAIL")
    pass_count = sum(1 for f in findings if f.get("verdict") == "PASS")

    output = {
        "findings": findings,
        "summary": {
            "total": len(findings),
            "pass": pass_count,
            "fail": fail_count,
        },
    }

    print(json.dumps(output, indent=2))
    print(
        f"\nEvaluation complete: {pass_count} pass, {fail_count} fail",
        file=sys.stderr,
    )


if __name__ == "__main__":
    main()
