#!/usr/bin/env python3
"""Run dart analyze --fatal-infos on every sub-package in packages/.

Packages listed in .dart_analyze_skip (one per line) are skipped.
"""

import os
import subprocess
import sys


def _load_skip_list(repo_root: str) -> set[str]:
    """Read .dart_analyze_skip from repo root, return set of package names."""
    skip_path = os.path.join(repo_root, ".dart_analyze_skip")
    if not os.path.isfile(skip_path):
        return set()

    names: set[str] = set()
    with open(skip_path) as f:
        for line in f:
            stripped = line.strip()
            if stripped and not stripped.startswith("#"):
                names.add(stripped)

    return names


def main() -> int:
    # Remove GIT_DIR/GIT_WORK_TREE set by git hooks — they make flutter/dart
    # resolve version info from the wrong repo.
    env = {k: v for k, v in os.environ.items() if k not in ("GIT_DIR", "GIT_WORK_TREE")}

    repo_root = os.path.normpath(
        os.path.join(os.path.dirname(__file__), os.pardir),
    )
    packages_dir = os.path.join(repo_root, "packages")
    skip = _load_skip_list(repo_root)

    failed = []
    skipped = []
    for name in sorted(os.listdir(packages_dir)):
        pkg_path = os.path.join(packages_dir, name)
        if not os.path.isfile(os.path.join(pkg_path, "pubspec.yaml")):
            continue
        if name in skip:
            skipped.append(name)
            continue
        print(f"Analyzing {name}...")
        result = subprocess.run(
            ["dart", "analyze", "--fatal-infos", pkg_path],
            env=env,
        )
        if result.returncode != 0:
            failed.append(name)

    if skipped:
        print(f"Skipped: {', '.join(skipped)}")
    if failed:
        print(f"\nAnalysis failed for: {', '.join(failed)}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
