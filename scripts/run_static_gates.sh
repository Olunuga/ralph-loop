#!/bin/bash
# Static gate dispatcher — sources check definitions from gates/static/ and runs them.
#
# Usage:
#   run_gates.sh fast                          # run all fast-tier checks
#   run_gates.sh precise                       # run all precise-tier checks
#   run_gates.sh fast --category code_quality  # run fast checks for one category only
#
# Each check file in gates/static/<category>/ exports:
#   gate_name()      — human label
#   gate_category()  — "code_quality" | "architecture" | "security" | "accessibility"
#   gate_tier()      — "fast" | "precise"
#   gate_check()     — exit 0 = pass, exit 1 = fail; stdout = details + offending files
#
# Exit 0 = all checks passed. Exit 1 = at least one failed.

set -euo pipefail

TIER="${1:?Usage: run_gates.sh <fast|precise> [--category <category>]}"
shift

CATEGORY_FILTER=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --category) CATEGORY_FILTER="$2"; shift 2 ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GATES_DIR="${SCRIPT_DIR}/gates/static"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Source config if available (provides SOURCE_DIR, LAYER_MAP, etc.)
# shellcheck source=/dev/null
[[ -f "$PROJECT_ROOT/ralph/config.sh" ]] && source "$PROJECT_ROOT/ralph/config.sh"

FAIL=0
CHECKED=0
FAILED_NAMES=""

# Find all check scripts across gate subdirectories
for CHECK_FILE in "$GATES_DIR"/*/*.sh; do
    [[ -f "$CHECK_FILE" ]] || continue

    # Source the check to load its functions
    (
        # Run in subshell to isolate function definitions between checks
        source "$CHECK_FILE"

        # Filter by tier
        CHECK_TIER=$(gate_tier 2>/dev/null || echo "fast")
        [[ "$CHECK_TIER" != "$TIER" ]] && exit 0

        # Filter by category if specified
        if [[ -n "$CATEGORY_FILTER" ]]; then
            CHECK_CATEGORY=$(gate_category 2>/dev/null || echo "unknown")
            [[ "$CHECK_CATEGORY" != "$CATEGORY_FILTER" ]] && exit 0
        fi

        CHECK_NAME=$(gate_name 2>/dev/null || basename "$CHECK_FILE" .sh)

        # Run the check
        OUTPUT=$(gate_check 2>&1) && {
            exit 0
        } || {
            echo "FAIL: $CHECK_NAME"
            [[ -n "$OUTPUT" ]] && echo "$OUTPUT"
            exit 1
        }
    ) || {
        FAIL=1
        CHECK_BASENAME=$(basename "$CHECK_FILE" .sh)
        FAILED_NAMES="$FAILED_NAMES $CHECK_BASENAME"
    }
    CHECKED=$((CHECKED + 1))
done

if [[ "$CHECKED" -eq 0 ]]; then
    echo "No $TIER-tier checks found${CATEGORY_FILTER:+ for category '$CATEGORY_FILTER'}."
    exit 0
fi

if [[ "$FAIL" -eq 1 ]]; then
    echo ""
    echo "Static gates ($TIER): FAIL —$FAILED_NAMES"
    exit 1
fi

echo "Static gates ($TIER): PASS ($CHECKED checks)"
exit 0
