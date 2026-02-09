#!/usr/bin/env python3
"""Cross-platform wrapper for flutter analyze (workaround for git worktrees).

Git sets GIT_DIR in worktrees, which confuses Flutter's version detection
(reports 0.0.0-unknown). Unsetting it restores correct behavior. This
replaces flutter-analyze.sh so pre-commit works on both Windows and Linux.
"""

import os
import subprocess
import sys


def main() -> int:
    env = os.environ.copy()
    env.pop("GIT_DIR", None)
    env.pop("GIT_WORK_TREE", None)

    cmd = ["flutter", "analyze", *sys.argv[1:]]
    # Windows needs shell=True to resolve flutter.bat via cmd.exe
    result = subprocess.run(cmd, env=env, shell=(sys.platform == "win32"))
    return result.returncode


if __name__ == "__main__":
    raise SystemExit(main())
