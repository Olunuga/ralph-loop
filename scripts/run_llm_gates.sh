#!/bin/bash
# LLM gate dispatcher — runs semantic review for each prompt in gates/llm/.
#
# Usage:
#   run_llm_gates.sh                          # run all LLM gate checks
#   run_llm_gates.sh --category code_quality  # run only one category
#
# Each .md file in gates/llm/ is a prompt template with frontmatter:
#   ---
#   category: code_quality
#   ---
#   [prompt body with structured questions]
#
# For each prompt, runs 1 Sonnet call with the branch diff.
# All gates run in PARALLEL — results collected after all complete.
# Exit 0 = all passed. Exit 1 = at least one failed.

set -euo pipefail

CATEGORY_FILTER=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --category) CATEGORY_FILTER="$2"; shift 2 ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

SCRIPT_DIR="$(CDPATH= cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_LLM_DIR="${RALPH_PLUGIN_DIR:-$SCRIPT_DIR/..}/scripts/gates/llm"
PROJECT_ROOT="${PROJECT_ROOT:-$(pwd)}"
PROJECT_LLM_DIR="$PROJECT_ROOT/ralph/gates/llm"

# Source shared diff utility
# shellcheck source=/dev/null
source "${RALPH_PLUGIN_DIR:-$SCRIPT_DIR/..}/scripts/prepare_diff.sh"

if [[ -z "$PREPARED_DIFF" ]]; then
    echo "LLM gates: No diff against main — nothing to review."
    exit 0
fi

# Read config for context (if available)
# shellcheck source=/dev/null
[[ -f "$PROJECT_ROOT/ralph/config.sh" ]] && source "$PROJECT_ROOT/ralph/config.sh"

PROTOCOLS=""
if [[ -n "${PROTOCOLS_DIR:-}" && -d "$PROTOCOLS_DIR" ]]; then
    PROTOCOLS=$(find "$PROTOCOLS_DIR" -name "*.swift" 2>/dev/null \
        | xargs cat 2>/dev/null || true)
fi

# Read project-specific gate calibration (if available)
GATE_CONTEXT=""
if [[ -f "$PROJECT_ROOT/ralph/gate_context.md" ]]; then
    GATE_CONTEXT=$(cat "$PROJECT_ROOT/ralph/gate_context.md")
fi

# Collect gate prompts (deduplicate: project overrides plugin by basename)
GATE_FILES=()
SEEN_GATES=""
for PROMPT_FILE in "$PLUGIN_LLM_DIR"/*.md "$PROJECT_LLM_DIR"/*.md; do
    [[ -f "$PROMPT_FILE" ]] || continue

    GATE_BASENAME=$(basename "$PROMPT_FILE")
    if echo "$SEEN_GATES" | grep -qx "$GATE_BASENAME" 2>/dev/null; then
        continue
    fi
    SEEN_GATES="$SEEN_GATES"$'\n'"$GATE_BASENAME"

    # Filter by category if specified
    if [[ -n "$CATEGORY_FILTER" ]]; then
        PROMPT_CATEGORY=$(awk '/^---$/ { if (++c == 2) exit } c == 1 && /^category:/ { gsub(/category:\s*/, ""); print }' "$PROMPT_FILE")
        [[ "$PROMPT_CATEGORY" != "$CATEGORY_FILTER" ]] && continue
    fi

    GATE_FILES+=("$PROMPT_FILE")
done

if [[ ${#GATE_FILES[@]} -eq 0 ]]; then
    echo "LLM gates: No prompts found${CATEGORY_FILTER:+ for category '$CATEGORY_FILTER'}."
    exit 0
fi

echo "LLM gates: launching ${#GATE_FILES[@]} reviews in parallel..."

# Build shared context header once
CONTEXT_HEADER=""
if [[ -n "$GATE_CONTEXT" || -n "${APP_NAME:-}" ]]; then
    CONTEXT_HEADER="PROJECT CONTEXT:
App: ${APP_NAME:-unknown} — ${APP_DESCRIPTION:-}
${GATE_CONTEXT}
---
"
fi

PROTOCOLS_SECTION=""
if [[ -n "$PROTOCOLS" ]]; then
    PROTOCOLS_SECTION="

PROTOCOLS (source of truth for data access):
$PROTOCOLS"
fi

# Temp dir for parallel results
RESULTS_DIR=$(mktemp -d)

# Launch gates in parallel with max concurrency
MAX_CONCURRENT=5
PIDS=()
for PROMPT_FILE in "${GATE_FILES[@]}"; do
    CATEGORY_NAME=$(basename "$PROMPT_FILE" .md)
    PROMPT_BODY=$(awk 'BEGIN{c=0} /^---$/{c++;next} c>=2{print}' "$PROMPT_FILE")

    FULL_PROMPT="${CONTEXT_HEADER}${PROMPT_BODY}

IMPORTANT — Convergence rules:
- Only flag concrete defects in the CODE CHANGES below. Do not flag stylistic preferences or suggestions for improvement.
- Evaluate ONLY the numbered checklist items above. Do not invent additional criteria.
- If a checklist item has no issues in the diff, it MUST be PASS. Do not search for marginal issues to fail.
- Be deterministic: the same diff with the same checklist should always produce the same result.

CODE CHANGES:
$PREPARED_DIFF${PROTOCOLS_SECTION}"

    # Wait if we've hit max concurrency
    while [[ ${#PIDS[@]} -ge $MAX_CONCURRENT ]]; do
        # Wait for any one PID to finish, then remove completed ones
        STILL_RUNNING=()
        for pid in "${PIDS[@]}"; do
            if kill -0 "$pid" 2>/dev/null; then
                STILL_RUNNING+=("$pid")
            fi
        done
        PIDS=("${STILL_RUNNING[@]}")
        [[ ${#PIDS[@]} -ge $MAX_CONCURRENT ]] && sleep 1
    done

    # Run in background — output to temp file
    (
        RESULT=$(echo "$FULL_PROMPT" | claude -p --model claude-sonnet-4-6 2>/dev/null || true)
        if echo "$RESULT" | grep -q "^OVERALL: PASS"; then
            echo "PASS" > "$RESULTS_DIR/$CATEGORY_NAME.status"
        else
            echo "FAIL" > "$RESULTS_DIR/$CATEGORY_NAME.status"
            echo "$RESULT" > "$RESULTS_DIR/$CATEGORY_NAME.output"
        fi
    ) &
    PIDS+=($!)
    echo "  [$CATEGORY_NAME] started (PID $!)"
done

# Wait for all remaining gates to complete
for pid in "${PIDS[@]}"; do
    wait "$pid" 2>/dev/null || true
done

# Collect results
FAIL=0
CHECKED=0
FAILED_CATEGORIES=""

for PROMPT_FILE in "${GATE_FILES[@]}"; do
    CATEGORY_NAME=$(basename "$PROMPT_FILE" .md)
    CHECKED=$((CHECKED + 1))

    STATUS=$(cat "$RESULTS_DIR/$CATEGORY_NAME.status" 2>/dev/null || echo "ERROR")

    if [[ "$STATUS" == "PASS" ]]; then
        echo "LLM gate [$CATEGORY_NAME]: PASS"
    elif [[ "$STATUS" == "FAIL" ]]; then
        echo "LLM gate [$CATEGORY_NAME]: FAIL"
        cat "$RESULTS_DIR/$CATEGORY_NAME.output" 2>/dev/null
        FAIL=1
        FAILED_CATEGORIES="$FAILED_CATEGORIES $CATEGORY_NAME"
    else
        echo "LLM gate [$CATEGORY_NAME]: ERROR (no result — timeout or crash)"
        FAIL=1
        FAILED_CATEGORIES="$FAILED_CATEGORIES $CATEGORY_NAME"
    fi
done

rm -rf "$RESULTS_DIR"

if [[ "$FAIL" -eq 1 ]]; then
    echo ""
    echo "LLM gates: FAIL —$FAILED_CATEGORIES"
    exit 1
fi

echo "LLM gates: PASS ($CHECKED reviews)"
exit 0
