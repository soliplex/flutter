#!/bin/sh
# Workaround for Flutter SDK version resolution in git worktrees.
# Git sets GIT_DIR in worktrees, which confuses Flutter's version detection
# (reports 0.0.0-unknown). Unsetting it restores correct behavior.
unset GIT_DIR
unset GIT_WORK_TREE
exec flutter analyze "$@"
