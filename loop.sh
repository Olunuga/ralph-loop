#!/bin/bash
set -euo pipefail

# ── Usage ──────────────────────────────────────────────────────────────────────
# ./ralph/loop.sh                          # build loop, unlimited iterations
# ./ralph/loop.sh 15                       # build loop, max 15 iterations
# ./ralph/loop.sh bootstrap                # one-time: discover codebase → ralph/AGENTS.md
# ./ralph/loop.sh plan                     # gap analysis: all specs vs codebase
# ./ralph/loop.sh plan-work "desc" [N]     # scoped plan for one feature
# ./ralph/loop.sh post-loop                # re-run post-loop gates after manual fix

# ── Prevent sleep ──────────────────────────────────────────────────────────────
# caffeinate -i keeps the system awake (idle sleep inhibited) while the loop runs.
# Re-execs itself under caffeinate if not already wrapped.
if [[ -z "${RALPH_CAFFEINATED:-}" ]] && command -v caffeinate &>/dev/null; then
    export RALPH_CAFFEINATED=1
    exec caffeinate -i "$0" "$@"
fi

# ── Resolve paths ──────────────────────────────────────────────────────────────
RALPH_DIR="$(CDPATH= cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(CDPATH= cd "$RALPH_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

# ── Mode ───────────────────────────────────────────────────────────────────────
MODE="build"
MAX_ITERATIONS=0
WORK_DESCRIPTION=""
MAX_FIX_ITERATIONS=4

case "${1:-}" in
    bootstrap)  MODE="bootstrap" ;;
    plan)       MODE="plan";      MAX_ITERATIONS="${2:-0}" ;;
    plan-work)
        [[ -z "${2:-}" ]] && { echo "Usage: ./ralph/loop.sh plan-work \"description\" [N]"; exit 1; }
        MODE="plan-work"; WORK_DESCRIPTION="$2"; MAX_ITERATIONS="${3:-3}"
        ;;
    post-loop)  MODE="post-loop" ;;
    "" | [0-9]*) MODE="build"; [[ "${1:-}" =~ ^[0-9]+$ ]] && MAX_ITERATIONS="$1" ;;
    *) echo "Usage: ./ralph/loop.sh [bootstrap|plan|plan-work \"desc\"|post-loop|N]"; exit 1 ;;
esac

# ── Config (not needed for bootstrap) ─────────────────────────────────────────
if [[ "$MODE" != "bootstrap" ]]; then
    [[ ! -f "ralph/config.sh" ]] && {
        echo "ERROR: ralph/config.sh not found."
        echo "Run: ./ralph/loop.sh bootstrap"
        exit 1
    }
    # shellcheck source=/dev/null
    source "ralph/config.sh"
fi

# ── Runtime state ──────────────────────────────────────────────────────────────
BRANCH=$(git branch --show-current)
SLACK_WEBHOOK="${SLACK_WEBHOOK:-}"
SPEC_TITLE=$(find ralph/specs -name "*.md" 2>/dev/null \
    | xargs grep -h "^# " 2>/dev/null | head -1 | sed 's/^# //' \
    || echo "$BRANCH")

# ── Helpers ────────────────────────────────────────────────────────────────────

file_hash() {
    md5 -q "$1" 2>/dev/null || md5sum "$1" 2>/dev/null | awk '{print $1}'
}

# Run a command silently; on failure print relevant lines to stderr.
run_quietly() {
    local CMD="$1"
    local TMPOUT
    TMPOUT=$(mktemp)
    if eval "$CMD" > "$TMPOUT" 2>&1; then
        rm -f "$TMPOUT"
        return 0
    else
        grep -E "error:|FAILED|failed" "$TMPOUT" | head -20 >&2 \
            || tail -20 "$TMPOUT" >&2
        rm -f "$TMPOUT"
        return 1
    fi
}

# Run a Claude agent instance (Sonnet — planning, bootstrap, post-loop gates).
claude_run() {
    claude -p \
        --dangerously-skip-permissions \
        --output-format text \
        --model claude-sonnet-4-6 \
        "$@"
}

# Run a Claude agent instance (Haiku — iterative build/lint fixes).
claude_run_fast() {
    claude -p \
        --dangerously-skip-permissions \
        --output-format text \
        --model claude-haiku-4-5-20251001 \
        "$@"
}

# Run a Claude agent instance (Opus — hard problems that Sonnet can't solve).
claude_run_deep() {
    claude -p \
        --dangerously-skip-permissions \
        --output-format text \
        --model claude-opus-4-6 \
        "$@"
}

notify_failure() {
    local GATE="$1"
    local DETAILS="$2"

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "STOPPED: $GATE failed after $MAX_FIX_ITERATIONS attempts."
    echo "Branch:  $BRANCH"
    echo "Fix manually, then run: ./ralph/loop.sh post-loop"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    if [[ -n "$SLACK_WEBHOOK" ]]; then
        local MSG="ralph needs human on $BRANCH\n\nGate: $GATE\nLast: $(git log -1 --format='%s')\n\n$DETAILS\n\nFix, then: ./ralph/loop.sh post-loop"
        curl -s -X POST "$SLACK_WEBHOOK" \
            -H "Content-Type: application/json" \
            -d "{\"text\":\"$(echo -e "$MSG" | sed 's/"/\\"/g')\"}" > /dev/null || true
    fi

    echo "$GATE failed after $MAX_FIX_ITERATIONS attempts: $DETAILS" >> progress.txt
    exit 1
}

# Rollback all changes (build/test failures — can't attribute to single files).
rollback_all() {
    git checkout -- . 2>/dev/null || true
    git clean -fd 2>/dev/null || true
}

# Rollback specific files (gate failures that identify offending files).
# Falls back to full rollback if no files specified.
rollback_files() {
    local files="$1"
    if [[ -z "$files" ]]; then
        rollback_all
        return
    fi
    while IFS= read -r f; do
        [[ -n "$f" && -f "$f" ]] && git checkout HEAD -- "$f" 2>/dev/null || true
    done <<< "$files"
}

# Append failure context for next iteration (Cluster 1: iteration intelligence).
append_failure_context() {
    local gate="$1"
    local details="$2"
    local iter="$3"
    local ctx_file="iteration_context.md"

    # Append structured failure block with verbatim error output (last 30 lines)
    {
        echo ""
        echo "## Iteration $iter — FAILED ($gate)"
        echo "Error output:"
        echo '```'
        echo "$details" | tail -30
        echo '```'
        echo "- Rolled back: yes"
    } >> "$ctx_file"

    # Cap to last 5 entries
    local count
    count=$(grep -c "^## Iteration" "$ctx_file" 2>/dev/null || echo 0)
    if [[ "$count" -gt 5 ]]; then
        # Keep only the last 5 blocks
        python3 -c "
import re, sys
text = open('$ctx_file').read()
blocks = re.split(r'(?=\n## Iteration)', text)
blocks = [b for b in blocks if b.strip()]
open('$ctx_file', 'w').write('\n'.join(blocks[-5:]))
" 2>/dev/null || true
    fi
}

# Capture a lesson when the agent breaks through a struggle (CONSEC_FAIL >= 2 → green).
# Appends the error pattern and fix diff to ralph/lessons.md for future sessions.
capture_lesson() {
    local gate="$1"
    local consec="$2"
    local lessons_file="ralph/lessons.md"

    # Extract last failure block from iteration context
    local last_error
    last_error=$(awk '/^## Iteration.*FAILED/{found=1; block=""} found{block=block"\n"$0} END{print block}' iteration_context.md 2>/dev/null || true)
    [[ -z "$last_error" ]] && return 0

    # Get the fix diff (last commit)
    local fix_diff
    fix_diff=$(git diff HEAD~1..HEAD -- "${SOURCE_DIR:-.}/" 2>/dev/null | head -30)

    # Generate one-line summary via Haiku (cheap)
    local summary
    summary=$(printf "Summarise this fix in one sentence. Gate: %s\nError:\n%s\nFix:\n%s" \
        "$gate" "$last_error" "$fix_diff" \
        | claude -p --model claude-haiku-4-5-20251001 --output-format text 2>/dev/null | head -1 || echo "fix for $gate")

    # Append to lessons file
    {
        echo ""
        echo "## [$gate] $summary"
        echo "Failures before fix: $consec"
        echo "Error pattern:"
        echo '```'
        echo "$last_error" | grep -E "Error output:|error:|FAIL" | head -5
        echo '```'
        echo "Fix:"
        echo '```'
        echo "$fix_diff"
        echo '```'
    } >> "$lessons_file"

    echo "LESSON: Captured to $lessons_file"
}

# Write structured status for orchestrator to poll.
write_loop_status() {
    local iter="$1"
    cat > ralph/.loop_status <<STAT
iteration=$iter
result=$(tail -1 progress.txt 2>/dev/null | sed 's/^- Iter [0-9]*: //')
consec_fail=$CONSEC_FAIL
last_fail_gate=$LAST_FAIL_GATE
tasks_remaining=$(grep -c '^\- \[ \]' IMPLEMENTATION_PLAN.md 2>/dev/null || echo 0)
STAT
}

# Run a post-loop gate, giving the agent up to MAX_FIX_ITERATIONS to fix it.
# Validates that fixes don't break hard gates before committing.
# For LLM gates, applies fixes one issue at a time to prevent cascading breakage.
run_gate_with_fix() {
    local GATE="$1"
    local GATE_CMD="$2"
    local MAX_ATTEMPTS="${3:-$MAX_FIX_ITERATIONS}"
    local ATTEMPT=0
    local OUTPUT

    while [[ "$ATTEMPT" -lt "$MAX_ATTEMPTS" ]]; do
        local GATE_EXIT=0
        OUTPUT=$(eval "$GATE_CMD" 2>&1) || GATE_EXIT=$?
        if [[ "$GATE_EXIT" -eq 0 ]]; then
            echo "GATE $GATE: PASS"
            echo "- Post-loop $GATE: PASS" >> progress.txt
            return 0
        fi

        ATTEMPT=$((ATTEMPT + 1))
        echo "GATE $GATE: FAIL (attempt $ATTEMPT/$MAX_ATTEMPTS)"

        # Extract the first individual failure for focused fixing.
        # LLM gates output "N: FAIL — reason" lines; pick the first one.
        FIRST_FAIL=$(echo "$OUTPUT" | grep -m1 "FAIL" || echo "$OUTPUT" | tail -10)

        printf "Fix ONLY this single issue. Do not refactor or change anything else.\n\nGate: %s\nIssue:\n%s\n\nFull context:\n%s" \
            "$GATE" "$FIRST_FAIL" "$OUTPUT" \
        | claude_run 2>/dev/null

        # Ensure the fix didn't break hard gates
        if ! bash ralph/scripts/run_static_gates.sh fast > /dev/null 2>&1; then
            echo "Fix broke gates — reverting."
            rollback_all
            continue
        fi
        run_quietly "$BUILD_CMD" || {
            echo "Fix broke build — reverting."
            rollback_all
            continue
        }
        run_quietly "$UNIT_TEST_CMD" || {
            echo "Fix broke unit tests — reverting."
            rollback_all
            continue
        }

        git add -A && git reset HEAD IMPLEMENTATION_PLAN.md progress.txt iteration_context.md 2>/dev/null
        git -c commit.gpgsign=false commit -m "ralph: fix $GATE attempt $ATTEMPT" 2>/dev/null || true
    done

    notify_failure "$GATE" "$OUTPUT"
}

# ── Bootstrap ──────────────────────────────────────────────────────────────────
if [[ "$MODE" == "bootstrap" ]]; then
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Bootstrap — generating ralph/AGENTS.md"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    cat ralph/PROMPT_bootstrap.md | claude_run

    if [[ ! -f "ralph/AGENTS.md" ]]; then
        echo ""
        echo "WARNING: ralph/AGENTS.md was not created."
        echo "Check the output above and run bootstrap again."
        exit 1
    fi

    echo ""
    echo "Done. Next steps:"
    echo "  1. Review ralph/AGENTS.md"
    echo "  2. Update BUILD_CMD / UNIT_TEST_CMD in ralph/config.sh with the discovered commands"
    echo "  3. Create ralph/specs/[ticket].md from your L3 session"
    echo "  4. Create a worktree: git worktree add .worktrees/[id] -b ralph/[id]"
    echo "  5. cd .worktrees/[id] && ./ralph/loop.sh plan-work \"[feature]\" 3"
    exit 0
fi

# ── Print header ───────────────────────────────────────────────────────────────
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Mode:   $MODE | Branch: $BRANCH"
[[ "$MAX_ITERATIONS" -gt 0 ]] && echo "Max:    $MAX_ITERATIONS iterations"
[[ -n "$WORK_DESCRIPTION" ]] && echo "Scope:  $WORK_DESCRIPTION"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# ── Planning loops ─────────────────────────────────────────────────────────────
if [[ "$MODE" == "plan" ]]; then
    ITER=0
    while true; do
        [[ "$MAX_ITERATIONS" -gt 0 && "$ITER" -ge "$MAX_ITERATIONS" ]] && break
        echo "=== Plan iteration $((ITER + 1)) ==="
        cat ralph/PROMPT_plan.md | claude_run
        ITER=$((ITER + 1))
    done
    exit 0
fi

if [[ "$MODE" == "plan-work" ]]; then
    ITER=0
    PREV_HASH="none"
    while true; do
        [[ "$MAX_ITERATIONS" -gt 0 && "$ITER" -ge "$MAX_ITERATIONS" ]] && break
        echo "=== Plan-work iteration $((ITER + 1)) ==="

        if [[ "$ITER" -eq 0 ]]; then
            # First iteration: generate from scratch
            sed "s|\${WORK_DESCRIPTION}|$WORK_DESCRIPTION|g" ralph/PROMPT_plan_work.md \
                | claude_run
        else
            # Subsequent iterations: refine, don't rewrite
            PREV_PLAN=$(cat IMPLEMENTATION_PLAN.md 2>/dev/null || true)
            {
                echo "Previous plan iteration:"
                echo "$PREV_PLAN"
                echo "---"
                echo "Refine the plan above. Do not restart from scratch."
                echo "Preserve tasks that are already well-specified. Focus on gaps and improvements."
                echo "---"
                sed "s|\${WORK_DESCRIPTION}|$WORK_DESCRIPTION|g" ralph/PROMPT_plan_work.md
            } | claude_run
        fi

        # Convergence detection: exit early if plan stopped changing
        NEW_HASH=$(file_hash IMPLEMENTATION_PLAN.md 2>/dev/null || echo "none")
        if [[ "$ITER" -ge 1 && "$NEW_HASH" == "$PREV_HASH" ]]; then
            echo "Plan converged after $((ITER + 1)) iterations."
            break
        fi
        PREV_HASH="$NEW_HASH"

        ITER=$((ITER + 1))
    done
    exit 0
fi

# ── Build pre-flight ───────────────────────────────────────────────────────────
if [[ "$MODE" == "build" ]]; then
    [[ "$BRANCH" == "main" ]] && {
        echo "ERROR: On main branch. Create a worktree:"
        echo "  git worktree add .worktrees/[id] -b ralph/[id]"
        exit 1
    }

    [[ ! -f "IMPLEMENTATION_PLAN.md" ]] && {
        echo "ERROR: IMPLEMENTATION_PLAN.md not found."
        echo "Run first: ./ralph/loop.sh plan-work \"[feature]\" 3"
        exit 1
    }

    echo "Checking xcode-cli bridge..."
    XCODE_HEALTH=$(curl -s --max-time 3 http://127.0.0.1:48321/health 2>/dev/null || echo "{}")
    XCODE_OK=$(echo "$XCODE_HEALTH" | python3 -c \
        "import sys,json; d=json.load(sys.stdin); print(d.get('ok') and d.get('connected'))" \
        2>/dev/null || echo "False")
    if [[ "$XCODE_OK" != "True" ]]; then
        echo "WARNING: xcode-cli bridge unavailable — agent will use xcodeproj gem for new files."
        export XCODE_CLI_AVAILABLE=false
    else
        echo "xcode-cli: OK"
        export XCODE_CLI_AVAILABLE=true
    fi

    # Validate simulator exists
    SIM_NAME=$(echo "$BUILD_CMD" | sed -n "s/.*name=\([^'\"]*\).*/\1/p")
    if [[ -n "$SIM_NAME" ]] && ! xcrun simctl list devices available 2>/dev/null | grep -q "$SIM_NAME"; then
        BASE_MODEL=$(echo "$SIM_NAME" | grep -oE 'iPhone [0-9]+|iPad [A-Za-z]+')
        CLOSEST=$(xcrun simctl list devices available 2>/dev/null \
            | grep -oE 'iPhone [0-9]+ ?[A-Za-z ]*|iPad [A-Za-z ]+' \
            | sed 's/ *$//' | sort -u \
            | grep -i "$BASE_MODEL" | head -1 || true)
        if [[ -n "$CLOSEST" ]]; then
            echo "WARNING: Simulator '$SIM_NAME' not found. Using '$CLOSEST'."
            BUILD_CMD="${BUILD_CMD//$SIM_NAME/$CLOSEST}"
            UNIT_TEST_CMD="${UNIT_TEST_CMD//$SIM_NAME/$CLOSEST}"
            UI_TEST_CMD="${UI_TEST_CMD//$SIM_NAME/$CLOSEST}"
        else
            echo "ERROR: Simulator '$SIM_NAME' not found. Available:"
            xcrun simctl list devices available 2>/dev/null | grep -E 'iPhone|iPad' | head -10
            exit 1
        fi
    fi

    # Detect new gates not yet calibrated in gate_context.md
    if [[ -f "ralph/gate_context.md" ]]; then
        for GATE_FILE in ralph/scripts/gates/static/*/*.sh; do
            [[ -f "$GATE_FILE" ]] || continue
            GATE_NAME=$(basename "$GATE_FILE" .sh)
            if ! grep -q "$GATE_NAME" ralph/gate_context.md 2>/dev/null; then
                echo "WARNING: New gate '$GATE_NAME' not in gate_context.md — build agent will calibrate."
            fi
        done
    fi

    echo "Checking baseline build..."
    run_quietly "$BUILD_CMD" || {
        echo "ERROR: Baseline build is failing. Fix before running the loop."
        exit 1
    }
    echo "Baseline: OK"
fi

# ── Build loop ─────────────────────────────────────────────────────────────────
if [[ "$MODE" == "build" ]]; then
    echo "=== Pipeline started: $(date '+%Y-%m-%d %H:%M:%S') ===" >> progress.txt

    # Detect prior progress — if ralph: commits exist, reconcile the plan
    PRIOR_COMMITS=$(git log --oneline --grep="^ralph:" 2>/dev/null | wc -l | tr -d ' ')
    if [[ "$PRIOR_COMMITS" -gt 0 && -f "IMPLEMENTATION_PLAN.md" ]]; then
        echo "Detected $PRIOR_COMMITS prior ralph commits — reconciling plan with code state..."
        COMMIT_LOG=$(git log --oneline --grep="^ralph:" 2>/dev/null)
        printf "These commits have already been made on this branch:\n%s\n\nUpdate IMPLEMENTATION_PLAN.md: mark any task as [x] done if the commit log shows it was implemented. Do not uncheck tasks. Do not change task descriptions. Only update checkboxes.\n\nIMPLEMENTATION_PLAN.md:\n%s" \
            "$COMMIT_LOG" "$(cat IMPLEMENTATION_PLAN.md)" \
        | claude_run_fast 2>/dev/null
        echo "Plan reconciled."
    fi

    ITER=0
    CONSEC_FAIL=0
    LAST_FAIL_GATE=""

    while true; do
        [[ "$MAX_ITERATIONS" -gt 0 && "$ITER" -ge "$MAX_ITERATIONS" ]] && break

        # Stop if all tasks are done
        if ! grep -q '^\- \[ \]' IMPLEMENTATION_PLAN.md 2>/dev/null; then
            echo "All tasks in IMPLEMENTATION_PLAN.md are done."
            break
        fi

        echo ""
        echo "=== Build iteration $((ITER + 1)) ==="

        # Build the prompt, prepending context if available
        PROMPT=$(sed "s|\${XCODEPROJ}|$XCODEPROJ|g" ralph/PROMPT_build.md)
        if [[ -f iteration_context.md ]]; then
            PROMPT="$(cat iteration_context.md)
---
$PROMPT"
        fi
        # Load persistent lessons when struggling
        if [[ "$CONSEC_FAIL" -ge 2 && -f "ralph/lessons.md" ]]; then
            PROMPT="Lessons from previous sessions (follow these):
$(cat ralph/lessons.md)
---
$PROMPT"
        fi

        # Model escalation: Haiku → Sonnet (after 2 fails) → Opus (after 4 fails)
        AGENT_OK=true
        if [[ "$CONSEC_FAIL" -ge 4 ]]; then
            echo "  (escalating to Opus after $CONSEC_FAIL consecutive failures on $LAST_FAIL_GATE)"
            echo "$PROMPT" | claude_run_deep || AGENT_OK=false
        elif [[ "$CONSEC_FAIL" -ge 2 ]]; then
            echo "  (escalating to Sonnet after $CONSEC_FAIL consecutive failures on $LAST_FAIL_GATE)"
            echo "$PROMPT" | claude_run || AGENT_OK=false
        else
            echo "$PROMPT" | claude_run_fast || AGENT_OK=false
        fi

        if [[ "$AGENT_OK" == false ]]; then
            echo "WARN: Agent call failed — retrying next iteration."
            echo "- Iter $((ITER+1)): agent error (API timeout or crash)" >> progress.txt
            [[ "$LAST_FAIL_GATE" == "agent" ]] && CONSEC_FAIL=$((CONSEC_FAIL+1)) || { CONSEC_FAIL=1; LAST_FAIL_GATE="agent"; }
            write_loop_status "$((ITER+1))"
            ITER=$((ITER + 1)) && continue
        fi

        # ── 1. Build ─────────────────────────────────────────────────────────────
        BUILD_OUTPUT=""
        if ! BUILD_OUTPUT=$(eval "$BUILD_CMD" 2>&1); then
            echo "HARD: Build failed — rolling back."
            append_failure_context "build" "$BUILD_OUTPUT" "$((ITER+1))"
            rollback_all
            echo "- Iter $((ITER+1)): build failed" >> progress.txt
            [[ "$LAST_FAIL_GATE" == "build" ]] && CONSEC_FAIL=$((CONSEC_FAIL+1)) || { CONSEC_FAIL=1; LAST_FAIL_GATE="build"; }
            write_loop_status "$((ITER+1))"
            ITER=$((ITER + 1)) && continue
        fi

        # ── 2. Unit tests ─────────────────────────────────────────────────────────
        TEST_OUTPUT=""
        if ! TEST_OUTPUT=$(eval "$UNIT_TEST_CMD" 2>&1); then
            echo "HARD: Unit tests failed."
            append_failure_context "tests" "$TEST_OUTPUT" "$((ITER+1))"
            # Selective rollback: only revert test files, keep passing source changes.
            # Test files are identified by *Tests/ or *Spec/ directories.
            TEST_FILES=$(git diff --name-only HEAD 2>/dev/null | grep -E 'Tests/|Spec/' || true)
            if [[ -n "$TEST_FILES" ]]; then
                echo "Rolling back test files only — keeping source changes."
                rollback_files "$TEST_FILES"
            else
                rollback_all
            fi
            echo "- Iter $((ITER+1)): tests failed" >> progress.txt
            [[ "$LAST_FAIL_GATE" == "tests" ]] && CONSEC_FAIL=$((CONSEC_FAIL+1)) || { CONSEC_FAIL=1; LAST_FAIL_GATE="tests"; }
            write_loop_status "$((ITER+1))"
            ITER=$((ITER + 1)) && continue
        fi

        # ── 3. Code quality + architecture gates (fast tier) ────────────────────
        GATE_OUTPUT=""
        if ! GATE_OUTPUT=$(bash ralph/scripts/run_static_gates.sh fast 2>&1); then
            echo "GATES: Violation detected."
            echo "$GATE_OUTPUT"

            # Only roll back files the agent changed this iteration that are also flagged
            OFFENDING_FILES=$(echo "$GATE_OUTPUT" | grep -oE '[A-Za-z0-9_./]+\.swift' | sort -u || true)
            AGENT_CHANGED=$(git diff --name-only HEAD 2>/dev/null | sort -u || true)
            if [[ -n "$OFFENDING_FILES" && -n "$AGENT_CHANGED" ]]; then
                # Intersect: only roll back files the agent touched AND the gate flagged
                ROLLBACK_FILES=$(comm -12 <(echo "$OFFENDING_FILES") <(echo "$AGENT_CHANGED") || true)
                if [[ -n "$ROLLBACK_FILES" ]]; then
                    echo "Rolling back agent-changed files that failed gates."
                    rollback_files "$ROLLBACK_FILES"
                else
                    echo "Gate flagged pre-existing code only — skipping rollback."
                fi
            else
                rollback_all
            fi

            append_failure_context "gates" "$GATE_OUTPUT" "$((ITER+1))"
            echo "- Iter $((ITER+1)): gate violation" >> progress.txt
            [[ "$LAST_FAIL_GATE" == "gates" ]] && CONSEC_FAIL=$((CONSEC_FAIL+1)) || { CONSEC_FAIL=1; LAST_FAIL_GATE="gates"; }
            write_loop_status "$((ITER+1))"
            ITER=$((ITER + 1)) && continue
        fi

        # ── 4. Lint fix loop ──────────────────────────────────────────────────────
        if [[ -n "${LINT_CMD:-}" ]]; then
            LINT_PASS=false
            for lint_attempt in 1 2 3 4; do
                LINT_OUTPUT=$(eval "$LINT_CMD" 2>&1) && { LINT_PASS=true; break; }

                echo "LINT: Fix attempt $lint_attempt/4"
                printf "Fix these SwiftLint violations.\n%s" "$LINT_OUTPUT" \
                | claude_run_fast 2>/dev/null

                run_quietly "$BUILD_CMD" || {
                    rollback_all; break
                }
                run_quietly "$UNIT_TEST_CMD" || {
                    rollback_all; break
                }
            done

            if [[ "$LINT_PASS" == false ]]; then
                echo "LINT: Could not fix in 4 attempts — rolling back."
                append_failure_context "lint" "$LINT_OUTPUT" "$((ITER+1))"
                rollback_all
                echo "- Iter $((ITER+1)): lint unfixable" >> progress.txt
                [[ "$LAST_FAIL_GATE" == "lint" ]] && CONSEC_FAIL=$((CONSEC_FAIL+1)) || { CONSEC_FAIL=1; LAST_FAIL_GATE="lint"; }
                write_loop_status "$((ITER+1))"
            ITER=$((ITER + 1)) && continue
            fi
        fi

        # ── Verify commit landed ──────────────────────────────────────────────────
        # The build agent should have committed. If there are uncommitted changes,
        # the commit silently failed (e.g., permission blocked, signing error).
        if [[ -n "$(git status --porcelain -- "${SOURCE_DIR:-.}/" 2>/dev/null)" ]]; then
            echo "HARD: Build agent marked tasks done but did not commit."
            echo "  Uncommitted changes detected — commit may have been blocked."
            echo "  Attempting commit on behalf of agent..."
            git add -A && git reset HEAD IMPLEMENTATION_PLAN.md progress.txt iteration_context.md ralph/.loop_status 2>/dev/null
            git -c commit.gpgsign=false commit -m "ralph: auto-commit (agent commit was blocked)" 2>/dev/null || {
                echo "  Auto-commit also failed — rolling back."
                append_failure_context "commit" "Agent completed tasks but commit failed. Check git/SSH permissions." "$((ITER+1))"
                rollback_all
                echo "- Iter $((ITER+1)): commit failed" >> progress.txt
                [[ "$LAST_FAIL_GATE" == "commit" ]] && CONSEC_FAIL=$((CONSEC_FAIL+1)) || { CONSEC_FAIL=1; LAST_FAIL_GATE="commit"; }
                write_loop_status "$((ITER+1))"
                ITER=$((ITER + 1)) && continue
            }
        fi

        # ── Push ──────────────────────────────────────────────────────────────────
        git push origin "$BRANCH" 2>/dev/null || true
        echo "- Iter $((ITER+1)): green" >> progress.txt
        # Capture lesson if we broke through a struggle
        if [[ "$CONSEC_FAIL" -ge 2 ]]; then
            capture_lesson "$LAST_FAIL_GATE" "$CONSEC_FAIL"
        fi
        CONSEC_FAIL=0
        LAST_FAIL_GATE=""
        rm -f iteration_context.md
        write_loop_status "$((ITER+1))"
        ITER=$((ITER + 1))
    done
fi

# ── Post-loop gates ────────────────────────────────────────────────────────────
if [[ "$MODE" == "build" || "$MODE" == "post-loop" ]]; then

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Post-loop gates"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    # Gate 1: Precise-tier static gates (cheap, deterministic — run first to fail fast)
    run_gate_with_fix "GATES_PRECISE" "bash ralph/scripts/run_static_gates.sh precise"

    # Gate 2: LLM gates — semantic review (max 2 retries — more retries cause divergence)
    run_gate_with_fix "LLM_GATES" "bash ralph/scripts/run_llm_gates.sh" 2

    # Gate 3: UI routing decision (agent classifies the full branch diff)
    echo ""
    echo "=== UI routing ==="
    BASE=$(git merge-base main HEAD 2>/dev/null || echo "HEAD~1")
    CUMULATIVE_DIFF=$(git diff "$BASE"...HEAD -- "$SOURCE_DIR/" 2>/dev/null)

    UI_ROUTE=$(printf \
        "Classify the UI impact of these changes.\n\nDiff:\n%s\n\nRespond with EXACTLY one of these three words, nothing else:\nNO_UI\nVIEW_LEVEL\nFLOW_LEVEL\n\nDefinitions:\n- NO_UI: changes only in models, repositories, services, viewmodels, utilities, or tests\n- VIEW_LEVEL: changes confined to Views/ or Components/ only\n- FLOW_LEVEL: changes touching navigation, multi-view flows, or spanning more than one layer" \
        "$CUMULATIVE_DIFF" \
    | claude -p --model claude-sonnet-4-6 2>/dev/null \
    | grep -oE 'NO_UI|VIEW_LEVEL|FLOW_LEVEL' | head -1)

    UI_ROUTE="${UI_ROUTE:-NO_UI}"
    echo "UI route: $UI_ROUTE"

    case "$UI_ROUTE" in
        NO_UI)
            echo "No UI changes — skipping UI tests."
            ;;
        VIEW_LEVEL)
            echo "View-level changes."
            if [[ -n "${SNAPSHOT_TEST_CMD:-}" ]]; then
                run_gate_with_fix "SNAPSHOT" "$SNAPSHOT_TEST_CMD"
            else
                echo "SNAPSHOT_TEST_CMD not configured — skipping."
            fi
            ;;
        FLOW_LEVEL)
            echo "Flow-level changes."
            if [[ -n "${SNAPSHOT_TEST_CMD:-}" ]]; then
                run_gate_with_fix "SNAPSHOT" "$SNAPSHOT_TEST_CMD"
            else
                echo "SNAPSHOT_TEST_CMD not configured — skipping."
            fi
            run_gate_with_fix "UI_TESTS" "$UI_TEST_CMD"
            ;;
    esac

    # Gate 4: Open draft PR
    SNAPSHOT_LINE=""
    UI_LINE=""
    [[ "$UI_ROUTE" == "VIEW_LEVEL" && -n "${SNAPSHOT_TEST_CMD:-}" ]] && SNAPSHOT_LINE="- Snapshot tests: PASS"
    [[ "$UI_ROUTE" == "FLOW_LEVEL" ]] && UI_LINE="- UI tests: PASS"
    [[ "$UI_ROUTE" == "FLOW_LEVEL" && -n "${SNAPSHOT_TEST_CMD:-}" ]] && SNAPSHOT_LINE="- Snapshot tests: PASS"

    PR_BODY="## Autonomous Implementation

**Branch:** \`$BRANCH\`
**UI scope:** $UI_ROUTE

### Build log
\`\`\`
$(cat progress.txt 2>/dev/null || echo "(no progress log)")
\`\`\`

### Gates passed
- Build + unit tests: PASS (per-iteration)
- Static gates (code quality + architecture + security + accessibility): PASS (per-iteration)
- Static gates precise: PASS (post-loop)
- LLM gates (semantic review): PASS (post-loop)
- UI route: $UI_ROUTE
${SNAPSHOT_LINE}
${UI_LINE}

### Reviewer checklist
- [ ] Run on simulator or device
- [ ] Dark mode
- [ ] API surface matches ralph/specs/
- [ ] Build log has no unexpected rollbacks"

    echo "=== Pipeline finished: $(date '+%Y-%m-%d %H:%M:%S') ===" >> progress.txt

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "All gates passed."
    if command -v gh &>/dev/null; then
        gh pr create \
            --draft \
            --title "[$BRANCH] $SPEC_TITLE" \
            --body "$PR_BODY" \
        && echo "Draft PR opened." || echo "PR creation failed — push branch and open manually."
    else
        echo "gh not installed — push branch and open PR manually."
        echo "  git push origin $BRANCH"
    fi

    # Remove worktree — branch is kept, only the working directory is deleted
    WORKTREE_PATH=$(git worktree list | grep "\[$BRANCH\]" | awk '{print $1}')
    if [[ -n "$WORKTREE_PATH" && "$WORKTREE_PATH" != "$PROJECT_ROOT" ]]; then
        echo "Removing worktree: $WORKTREE_PATH"
        git -C "$PROJECT_ROOT" worktree remove "$WORKTREE_PATH" --force 2>/dev/null \
            && echo "Worktree removed. Branch $BRANCH is intact." \
            || echo "Worktree removal failed — run: git worktree remove $WORKTREE_PATH"
    fi
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
fi
