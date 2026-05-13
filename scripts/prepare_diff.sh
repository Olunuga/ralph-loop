#!/bin/bash
# Shared diff preparation utility.
# Sources config.sh if available, computes branch diff, exports variables.
#
# Usage: source this script, then use the exported variables.
#   source ralph/scripts/prepare_diff.sh
#   echo "$PREPARED_DIFF"
#
# Exported variables:
#   PREPARED_DIFF       — the diff content (full or summarized)
#   DIFF_STATS          — diffstat summary
#   DIFF_TOKEN_ESTIMATE — approximate token count
#   CHANGED_FILES       — newline-separated list of changed file paths
#   DIFF_BASE_REF       — the merge-base commit used

set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${PROJECT_ROOT:-$(pwd)}"

# Source config if available
# shellcheck source=/dev/null
[[ -f "$PROJECT_ROOT/ralph/config.sh" ]] && source "$PROJECT_ROOT/ralph/config.sh"

SRC="${SOURCE_DIR:-.}"

DIFF_BASE_REF=$(git merge-base main HEAD 2>/dev/null || echo "HEAD~1")

PREPARED_DIFF=$(git diff "$DIFF_BASE_REF"...HEAD -- "$SRC/" 2>/dev/null || true)
DIFF_STATS=$(git diff --stat "$DIFF_BASE_REF"...HEAD -- "$SRC/" 2>/dev/null || true)
CHANGED_FILES=$(git diff --name-only "$DIFF_BASE_REF"...HEAD -- "$SRC/" 2>/dev/null || true)

# Approximate token count (1 token ≈ 4 chars)
DIFF_CHARS=$(echo "$PREPARED_DIFF" | wc -c | tr -d ' ')
DIFF_TOKEN_ESTIMATE=$((DIFF_CHARS / 4))

# Safety valve — warn if diff is unusually large
DIFF_LINES=$(echo "$PREPARED_DIFF" | wc -l | tr -d ' ')
if [[ "$DIFF_LINES" -gt 3000 ]]; then
    echo "WARNING: Branch diff is $DIFF_LINES lines (~$DIFF_TOKEN_ESTIMATE tokens)." >&2
    echo "  This is larger than expected for an incremental feature." >&2
    echo "  Jury and UI routing may produce less reliable results." >&2
fi

export DIFF_BASE_REF PREPARED_DIFF DIFF_STATS DIFF_TOKEN_ESTIMATE CHANGED_FILES
