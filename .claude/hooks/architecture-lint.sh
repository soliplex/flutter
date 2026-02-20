#!/bin/bash
# Architecture lint — runs after Write/Edit on Dart files.
#
# Checks for Clean Architecture violations across multiple directories:
# - Provider files: sealed classes, state machine patterns
# - Models files: domain types that should migrate to domain/
# - Domain/usecases files: forbidden imports (dependency rule purity)
#
# Non-blocking: warnings are returned as feedback to Claude via
# JSON stdout. Claude sees the feedback and can self-correct.

set -euo pipefail

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

if [[ -z "$FILE_PATH" ]]; then
  exit 0
fi

# Only check Dart files
if [[ "$FILE_PATH" != *.dart ]]; then
  exit 0
fi

WARNINGS=()

# --- Provider file checks ---
if [[ "$FILE_PATH" == */lib/core/providers/*.dart ]]; then
  # Strip comments to avoid false positives from documentation
  STRIPPED=$(sed 's|//.*||' "$FILE_PATH")

  # Sealed class in provider file
  if echo "$STRIPPED" | grep -q 'sealed class'; then
    WARNINGS+=("sealed class found in provider file. Sealed classes are domain types — move to lib/core/domain/.")
  fi

  # State machine pattern (multiple state assignments in conditional logic)
  STATE_ASSIGNMENTS=$(echo "$STRIPPED" | grep -c 'state =' || true)
  if (( STATE_ASSIGNMENTS > 3 )); then
    WARNINGS+=("$STATE_ASSIGNMENTS state assignments found. State transitions are domain logic — add methods to the domain object instead.")
  fi

# --- Models file checks ---
elif [[ "$FILE_PATH" == */lib/core/models/*.dart ]]; then
  STRIPPED=$(sed 's|//.*||' "$FILE_PATH")

  # Sealed class in models/ that should migrate to domain/
  if echo "$STRIPPED" | grep -q 'sealed class'; then
    WARNINGS+=("sealed class found in lib/core/models/. Domain types migrate to lib/core/domain/ during reworks.")
  fi

# --- Domain and usecases purity checks ---
elif [[ "$FILE_PATH" == */lib/core/domain/*.dart || "$FILE_PATH" == */lib/core/usecases/*.dart ]]; then
  # Check for forbidden imports (dependency rule violation)
  FORBIDDEN=$(grep -E "^import 'package:(flutter|flutter_riverpod|riverpod|go_router)/" "$FILE_PATH" || true)
  if [[ -n "$FORBIDDEN" ]]; then
    LAYER=$(basename "$(dirname "$FILE_PATH")")
    WARNINGS+=("Forbidden import in $LAYER/ file. Domain and use case files must be pure Dart — no Flutter, Riverpod, or GoRouter imports. This violates the dependency rule.")
  fi

else
  exit 0
fi

# No warnings? Exit clean.
if (( ${#WARNINGS[@]} == 0 )); then
  exit 0
fi

# Build feedback message
FILENAME=$(basename "$FILE_PATH")
DIRNAME=$(basename "$(dirname "$FILE_PATH")")
MESSAGE="Architecture lint warnings for $DIRNAME/$FILENAME:\\n"
for W in "${WARNINGS[@]}"; do
  MESSAGE+="  - $W\\n"
done
MESSAGE+="See PLANS/0006-clean-architecture/TARGET.md for guidance."

# Return as Claude feedback (non-blocking)
jq -n --arg reason "$MESSAGE" '{"reason": $reason}'
