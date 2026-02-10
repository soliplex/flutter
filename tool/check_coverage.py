#!/usr/bin/env python3
"""Check that test coverage meets a minimum threshold by parsing lcov.info."""

import os
import sys

COVERAGE_FILE = os.path.join(
    os.path.dirname(__file__), os.pardir, "coverage", "lcov.info"
)
MIN_COVERAGE = 78.0


def parse_lcov(path: str) -> tuple[int, int, list[tuple[str, int, int]]]:
    """Parse an lcov.info file and return (total_hit, total_found, per_file)."""
    total_found = 0
    total_hit = 0
    per_file: list[tuple[str, int, int]] = []

    current_file = ""
    file_found = 0
    file_hit = 0

    with open(path, encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if line.startswith("SF:"):
                current_file = line[3:]
            elif line.startswith("LF:"):
                file_found = int(line[3:])
            elif line.startswith("LH:"):
                file_hit = int(line[3:])
            elif line == "end_of_record":
                total_found += file_found
                total_hit += file_hit
                per_file.append((current_file, file_hit, file_found))
                current_file = ""
                file_found = 0
                file_hit = 0

    return total_hit, total_found, per_file


def main() -> int:
    path = os.path.normpath(COVERAGE_FILE)

    if not os.path.isfile(path):
        print(f"Coverage file not found: {path}", file=sys.stderr)
        print("Run 'flutter test --coverage' first.", file=sys.stderr)
        return 1

    total_hit, total_found, per_file = parse_lcov(path)

    if total_found == 0:
        print("No lines found in coverage report.", file=sys.stderr)
        return 1

    coverage = (total_hit / total_found) * 100

    # Show files below threshold
    below = [
        (name, hit, found)
        for name, hit, found in per_file
        if found > 0 and (hit / found) * 100 < MIN_COVERAGE
    ]

    if below:
        below.sort(key=lambda x: (x[1] / x[2]) if x[2] else 0)
        print(f"\nFiles below {MIN_COVERAGE:.0f}% coverage:")
        for name, hit, found in below:
            pct = (hit / found) * 100
            print(f"  {pct:5.1f}%  {name}")

    print(f"\nOverall coverage: {coverage:.1f}% ({total_hit}/{total_found} lines)")

    if coverage < MIN_COVERAGE:
        print(
            f"\nFAILED: Coverage {coverage:.1f}% is below "
            f"the minimum threshold of {MIN_COVERAGE:.0f}%.",
            file=sys.stderr,
        )
        return 1

    print(f"PASSED: Coverage meets the {MIN_COVERAGE:.0f}% threshold.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
