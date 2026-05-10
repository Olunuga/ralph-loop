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
LLM_GATES_DIR="${SCRIPT_DIR}/gates/llm"

# Source shared diff utility
# shellcheck source=/dev/null
source "$SCRIPT_DIR/prepare_diff.sh"

if [[ -z "$PREPARED_DIFF" ]]; then
    echo "LLM gates: No diff against main — nothing to review."
    exit 0
fi

# Read protocols for context (if available)
PROJECT_ROOT="$(CDPATH= cd "$SCRIPT_DIR/../.." && pwd)"
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

FAIL=0
CHECKED=0
FAILED_CATEGORIES=""

for PROMPT_FILE in "$LLM_GATES_DIR"/*.md; do
    [[ -f "$PROMPT_FILE" ]] || continue

    # Parse frontmatter for category
    PROMPT_CATEGORY=$(awk '/^---$/ { if (++c == 2) exit } c == 1 && /^category:/ { gsub(/category:\s*/, ""); print }' "$PROMPT_FILE")

    # Filter by category if specified
    if [[ -n "$CATEGORY_FILTER" && "$PROMPT_CATEGORY" != "$CATEGORY_FILTER" ]]; then
        continue
    fi

    CATEGORY_NAME=$(basename "$PROMPT_FILE" .md)

    # Build the full prompt: template body + diff + protocols
    PROMPT_BODY=$(awk 'BEGIN{c=0} /^---$/{c++;next} c>=2{print}' "$PROMPT_FILE")

    # Prepend project context if available
    CONTEXT_HEADER=""
    if [[ -n "$GATE_CONTEXT" || -n "${APP_NAME:-}" ]]; then
        CONTEXT_HEADER="PROJECT CONTEXT:
App: ${APP_NAME:-unknown} — ${APP_DESCRIPTION:-}
${GATE_CONTEXT}
---
"
    fi

    FULL_PROMPT="${CONTEXT_HEADER}${PROMPT_BODY}

IMPORTANT — Convergence rules:
- Only flag concrete defects in the CODE CHANGES below. Do not flag stylistic preferences or suggestions for improvement.
- Evaluate ONLY the numbered checklist items above. Do not invent additional criteria.
- If a checklist item has no issues in the diff, it MUST be PASS. Do not search for marginal issues to fail.
- Be deterministic: the same diff with the same checklist should always produce the same result.

CODE CHANGES:
$PREPARED_DIFF"

    if [[ -n "$PROTOCOLS" ]]; then
        FULL_PROMPT="$FULL_PROMPT

PROTOCOLS (source of truth for data access):
$PROTOCOLS"
    fi

    # Run 1 Sonnet call
    echo "LLM gate [$CATEGORY_NAME]: reviewing..."
    RESULT=$(echo "$FULL_PROMPT" | claude -p --model claude-sonnet-4-6 2>/dev/null || true)

    if echo "$RESULT" | grep -q "^OVERALL: PASS"; then
        echo "LLM gate [$CATEGORY_NAME]: PASS"
    else
        echo "LLM gate [$CATEGORY_NAME]: FAIL"
        echo "$RESULT"
        FAIL=1
        FAILED_CATEGORIES="$FAILED_CATEGORIES $CATEGORY_NAME"
    fi
    CHECKED=$((CHECKED + 1))
done

if [[ "$CHECKED" -eq 0 ]]; then
    echo "LLM gates: No prompts found${CATEGORY_FILTER:+ for category '$CATEGORY_FILTER'}."
    exit 0
fi

if [[ "$FAIL" -eq 1 ]]; then
    echo ""
    echo "LLM gates: FAIL —$FAILED_CATEGORIES"
    exit 1
fi

echo "LLM gates: PASS ($CHECKED reviews)"
exit 0
