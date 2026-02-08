#!/bin/sh
# Workaround for Dart SDK resolution in git worktrees.
# See flutter-analyze.sh for details.
unset GIT_DIR
unset GIT_WORK_TREE
exec dart fix --apply "$@"
