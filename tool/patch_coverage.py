#!/usr/bin/env python3
"""Compute patch coverage: % of new/changed lines that are covered by tests.

Parses a unified diff to find added lines, cross-references with lcov data
to determine which of those lines are executable and covered.

Usage:
    patch_coverage.py --diff pr.diff --lcov combined.info --threshold 90

Exit codes:
    0  Patch coverage meets threshold
    1  Patch coverage below threshold
    2  No executable lines in diff (auto-pass)
"""

import argparse
import re
import sys
from collections import defaultdict
from pathlib import Path


def parse_diff_added_lines(diff_path: str) -> dict[str, set[int]]:
    """Parse unified diff, return {filename: {line_numbers}} of added lines."""
    added: dict[str, set[int]] = defaultdict(set)
    current_file: str | None = None
    current_line = 0

    with open(diff_path) as f:
        for line in f:
            # Track file being modified
            if line.startswith("+++ b/"):
                current_file = line[6:].strip()
                continue
            if line.startswith("--- "):
                continue

            # Track hunk position
            hunk_match = re.match(r"^@@ -\d+(?:,\d+)? \+(\d+)(?:,\d+)? @@", line)
            if hunk_match:
                current_line = int(hunk_match.group(1))
                continue

            if current_file is None:
                continue

            # Count lines
            if line.startswith("+") and not line.startswith("+++"):
                added[current_file].add(current_line)
                current_line += 1
            elif line.startswith("-"):
                # Deleted lines don't advance the new-file line counter
                pass
            else:
                # Context line
                current_line += 1

    return dict(added)


def parse_lcov(lcov_path: str) -> dict[str, dict[int, int]]:
    """Parse lcov.info, return {filename: {line_number: hit_count}}."""
    coverage: dict[str, dict[int, int]] = defaultdict(dict)
    current_file: str | None = None

    with open(lcov_path) as f:
        for line in f:
            line = line.strip()
            if line.startswith("SF:"):
                # Source file — may be absolute or relative
                sf = line[3:]
                # Normalize: strip leading ./ or absolute prefix
                # We want paths relative to repo root
                current_file = sf.lstrip("./")
                # Handle absolute paths by finding common suffixes
                continue
            if line.startswith("DA:") and current_file is not None:
                parts = line[3:].split(",")
                if len(parts) >= 2:
                    line_num = int(parts[0])
                    hits = int(parts[1])
                    coverage[current_file][line_num] = hits
            if line == "end_of_record":
                current_file = None

    return dict(coverage)


def normalize_path(path: str) -> str:
    """Normalize a file path for comparison."""
    return str(Path(path).resolve()) if Path(path).is_absolute() else path


def find_coverage_for_file(
    diff_file: str, coverage: dict[str, dict[int, int]]
) -> dict[int, int] | None:
    """Find lcov coverage data matching a diff file path.

    Handles mismatches between diff paths (relative to repo) and lcov paths
    (may be absolute or package-relative).
    """
    # Direct match
    if diff_file in coverage:
        return coverage[diff_file]

    # Try suffix matching (lcov might use absolute paths)
    for cov_file, data in coverage.items():
        if cov_file.endswith(diff_file) or diff_file.endswith(cov_file):
            return data

    # Try matching just the lib/ portion
    parts = diff_file.split("/")
    for i, part in enumerate(parts):
        if part == "lib":
            suffix = "/".join(parts[i:])
            for cov_file, data in coverage.items():
                if cov_file.endswith(suffix):
                    return data
            break

    return None


def compute_patch_coverage(
    added_lines: dict[str, set[int]],
    coverage: dict[str, dict[int, int]],
) -> tuple[int, int, int, dict[str, dict]]:
    """Compute patch coverage.

    Returns:
        (covered, executable, total_added, per_file_details)
    """
    total_covered = 0
    total_executable = 0
    total_added = 0
    per_file: dict[str, dict] = {}

    for diff_file, lines in sorted(added_lines.items()):
        total_added += len(lines)

        # Skip non-dart files
        if not diff_file.endswith(".dart"):
            per_file[diff_file] = {
                "added": len(lines),
                "executable": 0,
                "covered": 0,
                "skipped": "non-dart file",
            }
            continue

        # Skip test files for coverage (we care about lib/ coverage)
        if "/test/" in diff_file or diff_file.startswith("test/"):
            per_file[diff_file] = {
                "added": len(lines),
                "executable": 0,
                "covered": 0,
                "skipped": "test file",
            }
            continue

        file_cov = find_coverage_for_file(diff_file, coverage)
        if file_cov is None:
            per_file[diff_file] = {
                "added": len(lines),
                "executable": 0,
                "covered": 0,
                "skipped": "no coverage data",
            }
            continue

        # Cross-reference: which added lines appear in lcov (= executable)?
        file_executable = 0
        file_covered = 0
        uncovered_lines = []

        for line_num in sorted(lines):
            if line_num in file_cov:
                file_executable += 1
                if file_cov[line_num] > 0:
                    file_covered += 1
                else:
                    uncovered_lines.append(line_num)

        total_executable += file_executable
        total_covered += file_covered

        per_file[diff_file] = {
            "added": len(lines),
            "executable": file_executable,
            "covered": file_covered,
            "uncovered_lines": uncovered_lines,
        }

    return total_covered, total_executable, total_added, per_file


def main() -> int:
    parser = argparse.ArgumentParser(description="Compute patch coverage")
    parser.add_argument("--diff", required=True, help="Path to unified diff file")
    parser.add_argument("--lcov", required=True, help="Path to lcov.info file")
    parser.add_argument(
        "--threshold", type=int, default=90, help="Minimum coverage %% (default: 90)"
    )
    parser.add_argument("--report", help="Write detailed report to file")
    args = parser.parse_args()

    # Parse inputs
    added_lines = parse_diff_added_lines(args.diff)
    coverage = parse_lcov(args.lcov)

    if not added_lines:
        print("No added lines in diff.")
        print("PATCH COVERAGE: PASS (no changes)")
        return 0

    # Compute
    covered, executable, total_added, per_file = compute_patch_coverage(
        added_lines, coverage
    )

    # Report
    lines = []
    lines.append(f"Total added lines: {total_added}")
    lines.append(f"Executable (in lcov): {executable}")
    lines.append(f"Covered: {covered}")
    if executable > 0:
        pct = (covered / executable) * 100
        lines.append(f"Patch coverage: {pct:.1f}%")
    else:
        pct = 100.0
        lines.append("Patch coverage: N/A (no executable lines in diff)")

    lines.append("")
    lines.append("Per-file breakdown:")
    for f, details in per_file.items():
        skip = details.get("skipped")
        if skip:
            lines.append(f"  {f}: {details['added']} added — {skip}")
        else:
            fc = details["covered"]
            fe = details["executable"]
            fpct = (fc / fe * 100) if fe > 0 else 0
            uncov = details.get("uncovered_lines", [])
            line = f"  {f}: {fc}/{fe} executable covered ({fpct:.0f}%)"
            if uncov:
                line += f" — uncovered: {uncov}"
            lines.append(line)

    report = "\n".join(lines)
    print(report)

    if args.report:
        with open(args.report, "w") as f:
            f.write(report + "\n")

    # Verdict
    if executable == 0:
        print("\nPATCH COVERAGE: PASS (no executable lines to cover)")
        return 0

    if pct >= args.threshold:
        print(f"\nPATCH COVERAGE: PASS ({pct:.1f}% >= {args.threshold}%)")
        return 0
    else:
        print(f"\nPATCH COVERAGE: FAIL ({pct:.1f}% < {args.threshold}%)")
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
