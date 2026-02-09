#!/usr/bin/env python3
"""Run dart analyze --fatal-infos on every sub-package in packages/."""

import os
import subprocess
import sys


def main() -> int:
    packages_dir = os.path.join(os.path.dirname(__file__), os.pardir, "packages")
    packages_dir = os.path.normpath(packages_dir)

    failed = []
    for name in sorted(os.listdir(packages_dir)):
        pkg_path = os.path.join(packages_dir, name)
        if not os.path.isfile(os.path.join(pkg_path, "pubspec.yaml")):
            continue
        print(f"Analyzing {name}...")
        result = subprocess.run(
            ["dart", "analyze", "--fatal-infos", pkg_path],
        )
        if result.returncode != 0:
            failed.append(name)

    if failed:
        print(f"\nAnalysis failed for: {', '.join(failed)}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
