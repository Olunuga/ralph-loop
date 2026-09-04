#!/bin/bash
set -euo pipefail

# ── Usage ──────────────────────────────────────────────────────────────────────
# loop.sh                          # build loop, unlimited iterations
# loop.sh 15                       # build loop, max 15 iterations
# loop.sh bootstrap                # one-time: discover codebase → ralph/AGENTS.md
# loop.sh plan                     # gap analysis: all specs vs codebase
# loop.sh plan-slc [N]            # SLC-aware plan: reads AUDIENCE_JTBD.md, recommends slice
# loop.sh plan-parallel [N]       # multi-spec: decompose into shared deps + per-spec tasks
# loop.sh plan-work "desc" [N]     # scoped plan for one feature
# loop.sh post-loop                # re-run post-loop gates after manual fix

# ── Prevent sleep ──────────────────────────────────────────────────────────────
# caffeinate -i keeps the system awake (idle sleep inhibited) while the loop runs.
# Re-execs itself under caffeinate if not already wrapped.
if [[ -z "${RALPH_CAFFEINATED:-}" ]] && command -v caffeinate &>/dev/null; then
    export RALPH_CAFFEINATED=1
    exec caffeinate -i "$0" "$@"
fi

# ── Resolve paths ──────────────────────────────────────────────────────────────
# RALPH_PLUGIN_DIR = where pipeline code lives (prompts, gates, scripts)
# PROJECT_ROOT = the target project (config.sh, AGENTS.md, specs/)
SCRIPT_SELF="$(CDPATH= cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export RALPH_PLUGIN_DIR="$(CDPATH= cd "$SCRIPT_SELF/.." && pwd)"
PROJECT_ROOT="$(pwd)"
cd "$PROJECT_ROOT"

# ── PID lockfile ──────────────────────────────────────────────────────────────
# Prevent multiple loop instances from running in the same worktree.
LOCKFILE="$PROJECT_ROOT/ralph/.loop.pid"
if [[ -f "$LOCKFILE" ]]; then
    OLD_PID=$(cat "$LOCKFILE" 2>/dev/null || true)
    if [[ -n "$OLD_PID" ]] && kill -0 "$OLD_PID" 2>/dev/null; then
        echo "ERROR: Another loop.sh (PID $OLD_PID) is already running in this worktree."
        echo "Kill it first: kill $OLD_PID"
        exit 1
    fi
    # Stale lockfile — previous loop died without cleanup
    rm -f "$LOCKFILE"
fi
echo $$ > "$LOCKFILE"

# Master cleanup function — called on exit, kill, or interrupt.
# Consolidates all cleanup: lockfile, simulator, Xcode window.
ralph_cleanup() {
    rm -f "$LOCKFILE" 2>/dev/null || true
    [[ -n "${RALPH_SIM_UDID:-}" ]] && xcrun simctl shutdown "$RALPH_SIM_UDID" 2>/dev/null || true
    if [[ -n "${EXPECTED_XCODE_PATH:-}" ]]; then
        osascript -e "
            tell application \"Xcode\"
                repeat with doc in (every workspace document)
                    if path of doc contains \"$PROJECT_ROOT\" then
                        close doc
                    end if
                end repeat
            end tell
        " 2>/dev/null || true
    fi
}
trap ralph_cleanup EXIT INT TERM

# ── Mode ───────────────────────────────────────────────────────────────────────
MODE="build"
MAX_ITERATIONS=0
WORK_DESCRIPTION=""
MAX_FIX_ITERATIONS=4

case "${1:-}" in
    bootstrap)  MODE="bootstrap" ;;
    plan)       MODE="plan";      MAX_ITERATIONS="${2:-0}" ;;
    plan-slc)      MODE="plan-slc";      MAX_ITERATIONS="${2:-0}" ;;
    plan-parallel) MODE="plan-parallel"; MAX_ITERATIONS="${2:-3}" ;;
    plan-work)
        [[ -z "${2:-}" ]] && { echo "Usage: loop.sh plan-work \"description\" [N]"; exit 1; }
        MODE="plan-work"; WORK_DESCRIPTION="$2"; MAX_ITERATIONS="${3:-3}"
        ;;
    post-loop)  MODE="post-loop" ;;
    "" | [0-9]*) MODE="build"; [[ "${1:-}" =~ ^[0-9]+$ ]] && MAX_ITERATIONS="$1" ;;
    *) echo "Usage: loop.sh [bootstrap|plan|plan-slc|plan-parallel|plan-work \"desc\"|post-loop|N]"; exit 1 ;;
esac

# ── Config (not needed for bootstrap) ─────────────────────────────────────────
if [[ "$MODE" != "bootstrap" ]]; then
    [[ ! -f "$PROJECT_ROOT/ralph/config.sh" ]] && {
        echo "ERROR: ralph/config.sh not found."
        echo "Run: loop.sh bootstrap"
        exit 1
    }
    # shellcheck source=/dev/null
    source "$PROJECT_ROOT/ralph/config.sh"
fi

# ── Runtime state ──────────────────────────────────────────────────────────────
BRANCH=$(git branch --show-current)
SLACK_WEBHOOK="${SLACK_WEBHOOK:-}"
# Base branch for diff comparisons. Resolved in order:
# 1. DIFF_BASE_BRANCH env var (if already set)
# 2. ralph/.diff_base file (written by spec skills when branching from non-main)
# 3. Defaults to main
if [[ -z "${DIFF_BASE_BRANCH:-}" && -f "$PROJECT_ROOT/ralph/.diff_base" ]]; then
    DIFF_BASE_BRANCH=$(cat "$PROJECT_ROOT/ralph/.diff_base" | tr -d '[:space:]')
fi
export DIFF_BASE_BRANCH="${DIFF_BASE_BRANCH:-main}"

# ── Intent source slots ───────────────────────────────────────────────────────
# RALPH_BRIEF_DIR = where the build agent reads the feature brief
# RALPH_PLAN_FILE = the task ledger the loop marks off
# Both default to the legacy locations. /ralph-loop:run points them at an
# OpenSpec change when it resolves one.
export RALPH_BRIEF_DIR="${RALPH_BRIEF_DIR:-$PROJECT_ROOT/ralph/specs}"
export RALPH_PLAN_FILE="${RALPH_PLAN_FILE:-IMPLEMENTATION_PLAN.md}"
SPEC_TITLE=$(find "$PROJECT_ROOT/ralph/specs" -name "*.md" 2>/dev/null \
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

# Max time (seconds) for a single claude -p call before it's killed.
CLAUDE_TIMEOUT="${CLAUDE_TIMEOUT:-600}"

# Run a Claude agent instance (Sonnet — planning, bootstrap, post-loop gates).
claude_run() {
    timeout "$CLAUDE_TIMEOUT" claude -p \
        --dangerously-skip-permissions \
        --output-format text \
        --model claude-sonnet-4-6 \
        "$@"
}

# Run a Claude agent instance (Haiku — iterative build/lint fixes).
claude_run_fast() {
    timeout "$CLAUDE_TIMEOUT" claude -p \
        --dangerously-skip-permissions \
        --output-format text \
        --model claude-haiku-4-5-20251001 \
        "$@"
}

# Run a Claude agent instance (Opus — hard problems that Sonnet can't solve).
claude_run_deep() {
    timeout "$CLAUDE_TIMEOUT" claude -p \
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
    echo "Fix manually, then run: loop.sh post-loop"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    if [[ -n "$SLACK_WEBHOOK" ]]; then
        local MSG="ralph needs human on $BRANCH\n\nGate: $GATE\nLast: $(git log -1 --format='%s')\n\n$DETAILS\n\nFix, then: loop.sh post-loop"
        curl -s -X POST "$SLACK_WEBHOOK" \
            -H "Content-Type: application/json" \
            -d "{\"text\":\"$(echo -e "$MSG" | sed 's/"/\\"/g')\"}" > /dev/null || true
    fi

    echo "$GATE failed after $MAX_FIX_ITERATIONS attempts: $DETAILS" >> progress.txt
    exit 1
}

# Rollback all changes (build/test failures — can't attribute to single files).
# Also undoes any uncommitted agent commits from this iteration.
rollback_all() {
    # Preserve pipeline state files across rollback — these track progress
    # and must survive even if they were accidentally tracked by git.
    local tmpdir
    tmpdir=$(mktemp -d)
    local preserved=()
    for f in IMPLEMENTATION_PLAN*.md iteration_context.md progress.txt "$RALPH_PLAN_FILE"; do
        [[ -f "$f" ]] || continue
        # keep the relative path: RALPH_PLAN_FILE may sit in a subdirectory
        mkdir -p "$tmpdir/$(dirname "$f")" 2>/dev/null || true
        cp "$f" "$tmpdir/$f" 2>/dev/null && preserved+=("$f") || true
    done

    # Undo agent commits from this iteration (commits since last known-good state)
    local agent_commits
    agent_commits=$(git log --oneline --grep="^ralph:" --since="5 minutes ago" 2>/dev/null | wc -l | tr -d ' ')
    if [[ "$agent_commits" -gt 0 ]]; then
        echo "Undoing $agent_commits agent commit(s) from this iteration."
        git reset HEAD~"$agent_commits" 2>/dev/null || true
    fi
    git checkout -- . 2>/dev/null || true
    git clean -fd -e 'IMPLEMENTATION_PLAN*.md' -e 'iteration_context.md' -e 'progress.txt' -e "$RALPH_PLAN_FILE" 2>/dev/null || true

    # Restore pipeline state files to their original relative paths
    for f in "${preserved[@]:-}"; do
        [[ -n "$f" && -f "$tmpdir/$f" ]] || continue
        mkdir -p "$(dirname "$f")" 2>/dev/null || true
        cp "$tmpdir/$f" "$f" 2>/dev/null || true
    done
    rm -rf "$tmpdir"
}

# Rollback specific files (gate failures that identify offending files).
# Falls back to full rollback if no files specified.
rollback_files() {
    local files="$1"
    if [[ -z "$files" ]]; then
        rollback_all
        return
    fi
    # Check if agent committed this iteration — if so, need to undo commits first
    local agent_commits
    agent_commits=$(git log --oneline --grep="^ralph:" --since="5 minutes ago" 2>/dev/null | wc -l | tr -d ' ')
    if [[ "$agent_commits" -gt 0 ]]; then
        echo "Undoing $agent_commits agent commit(s) before selective rollback."
        git reset HEAD~"$agent_commits" 2>/dev/null || true
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
    count=$(grep -c "^## Iteration" "$ctx_file" 2>/dev/null) || count=0
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
# Appends the error pattern and fix diff to $PROJECT_ROOT/ralph/lessons.md for future sessions.
capture_lesson() {
    local gate="$1"
    local consec="$2"
    local lessons_file="$PROJECT_ROOT/ralph/lessons.md"

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

# Run the diagnostician agent after every failure.
# First pass (consec_fail < 2): lightweight Sonnet call with local context only.
# Second pass (consec_fail >= 2): signal the orchestrator to spawn the full Opus
# diagnostician agent with tool access (Read, Grep, Bash) for deeper investigation.
run_diagnostician() {
    local iter="$1"
    local gate="$2"

    if [[ "$CONSEC_FAIL" -ge 2 ]]; then
        echo "  Sonnet diagnostician failed to resolve after $CONSEC_FAIL attempts — escalating to orchestrator."
        {
            echo ""
            echo "## Deep Diagnosis Needed (iter $iter, gate: $gate)"
            echo "consec_fail=$CONSEC_FAIL"
            echo "last_fail_gate=$gate"
            echo "The lightweight diagnostician has not resolved this. The orchestrator should spawn the full diagnostician agent (Opus, with tool access) to read source files and investigate."
        } >> iteration_context.md
        NEEDS_DEEP_DIAGNOSIS=true
        return
    fi

    echo "  Running diagnostician for $gate failure (iter $iter)..."
    local diag_prompt
    diag_prompt=$(awk 'BEGIN{n=0} /^---$/{n++; next} n>=2' "$RALPH_PLUGIN_DIR/agents/diagnostician.md")
    local diag_output
    diag_output=$(printf "%s\n\n---\n\nCurrent iteration_context.md:\n%s" \
        "$diag_prompt" \
        "$(cat iteration_context.md 2>/dev/null)" \
    | claude_run 2>/dev/null) || diag_output=""

    if [[ -n "$diag_output" ]]; then
        {
            echo ""
            echo "## Diagnostician (iter $iter, gate: $gate)"
            echo "$diag_output"
        } >> iteration_context.md
        echo "  Diagnostician: analysis appended to iteration_context.md"
    else
        echo "  Diagnostician: no output (timeout or error)"
    fi
}

# Write structured status for orchestrator to poll.
write_loop_status() {
    local iter="$1"
    local total_tasks; total_tasks=$(grep -c '^\- \[' "$RALPH_PLAN_FILE" 2>/dev/null) || total_tasks=0
    local tasks_done; tasks_done=$(grep -c '^\- \[x\]' "$RALPH_PLAN_FILE" 2>/dev/null) || tasks_done=0
    local tasks_remaining=$((total_tasks - tasks_done))
    local commits=$(git log --oneline --grep="^ralph:" 2>/dev/null | wc -l | tr -d ' ')
    local green_iters; green_iters=$(grep -c ': green$' progress.txt 2>/dev/null) || green_iters=0
    local failed_iters; failed_iters=$(grep -c ': \(build\|tests\|gate\|lint\|agent\|commit\) failed\|: gate violation' progress.txt 2>/dev/null) || failed_iters=0

    cat > "$PROJECT_ROOT/ralph/.loop_status" <<STAT
iteration=$iter
result=$(tail -1 progress.txt 2>/dev/null | sed 's/^- Iter [0-9]*: //')
consec_fail=$CONSEC_FAIL
last_fail_gate=$LAST_FAIL_GATE
needs_deep_diagnosis=${NEEDS_DEEP_DIAGNOSIS:-false}
tasks_total=$total_tasks
tasks_done=$tasks_done
tasks_remaining=$tasks_remaining
commits=$commits
green_iters=$green_iters
failed_iters=$failed_iters
STAT
}

# Run a post-loop gate, giving the agent up to MAX_FIX_ITERATIONS to fix it.
# Validates that fixes don't break hard gates before committing.
# For LLM gates, runs blast radius analysis to decide: auto-fix or defer to GitHub issue.
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

        # ── Blast radius analysis for LLM gates ──────────────────────────────
        # Extract the affected type from the failure output and measure impact.
        if [[ "$GATE" == "LLM_GATES" ]]; then
            # Extract type names mentioned in the failure (PascalCase identifiers)
            AFFECTED_TYPE=$(echo "$FIRST_FAIL" \
                | grep -oE '[A-Z][a-z]+([A-Z][a-z]+)+' \
                | awk 'NR==1{print; exit}') || true

            if [[ -n "$AFFECTED_TYPE" ]]; then
                echo "Blast radius analysis for $AFFECTED_TYPE..."
                BR_OUTPUT=$(bash $RALPH_PLUGIN_DIR/scripts/blast_radius.sh "$AFFECTED_TYPE" "${SOURCE_DIR:-.}" 2>/dev/null || true)

                if [[ -n "$BR_OUTPUT" ]]; then
                    BR_SCORE=$(echo "$BR_OUTPUT" | grep "^BLAST_SCORE=" | cut -d= -f2)
                    BR_VERDICT=$(echo "$BR_OUTPUT" | grep "^BLAST_VERDICT=" | cut -d= -f2)
                    BR_LAYERS=$(echo "$BR_OUTPUT" | grep "^AFFECTED_LAYERS=" | cut -d= -f2)

                    echo "$BR_OUTPUT"

                    if [[ "$BR_VERDICT" == "defer" ]]; then
                        echo "GATE $GATE: HIGH BLAST RADIUS (score $BR_SCORE) — deferring to tech debt."
                        echo "- Post-loop $GATE: DEFERRED (blast radius $BR_SCORE, layers: $BR_LAYERS)" >> progress.txt

                        ISSUE_TITLE="Tech Debt: $AFFECTED_TYPE — $(echo "$FIRST_FAIL" | head -1 | sed 's/^[0-9]*: FAIL — //')"
                        ISSUE_BODY="## Architectural Improvement (Deferred by Ralph Pipeline)

**Branch:** \`$BRANCH\`
**Gate:** $GATE
**Affected type:** \`$AFFECTED_TYPE\`
**Blast radius score:** $BR_SCORE/10

### Blast Radius Analysis
\`\`\`
$BR_OUTPUT
\`\`\`

### Gate Feedback
\`\`\`
$FIRST_FAIL
\`\`\`

### Why deferred
The blast radius score ($BR_SCORE) exceeds the auto-fix threshold. This change touches $BR_LAYERS and would require a multi-file refactor that risks breaking the build if done automatically.

### Recommended approach
Use Branch by Abstraction (Fowler): introduce a protocol/abstraction, migrate callers incrementally across multiple PRs, then remove the old path."

                        # Always write to file as backup
                        {
                            echo ""
                            echo "---"
                            echo "## $ISSUE_TITLE"
                            echo "Date: $(date '+%Y-%m-%d')"
                            echo ""
                            echo "$ISSUE_BODY"
                        } >> "$PROJECT_ROOT/ralph/deferred_issues.md"

                        # Try GitHub issue — check for duplicates first
                        if command -v gh &>/dev/null; then
                            EXISTING=$(gh issue list --search "Tech Debt: $AFFECTED_TYPE" --state open --limit 1 --json number --jq '.[0].number' 2>/dev/null || true)
                            if [[ -n "$EXISTING" ]]; then
                                echo "Existing issue #$EXISTING found — skipping duplicate."
                                echo "- Deferred issue: existing #$EXISTING" >> progress.txt
                            else
                                gh issue create \
                                    --title "$ISSUE_TITLE" \
                                    --body "$ISSUE_BODY" \
                                    --label "tech-debt" 2>/dev/null \
                                || gh issue create \
                                    --title "$ISSUE_TITLE" \
                                    --body "$ISSUE_BODY" 2>/dev/null \
                                && echo "GitHub issue created." \
                                || echo "Issue creation failed — saved to $PROJECT_ROOT/ralph/deferred_issues.md."
                            fi
                        else
                            echo "gh not installed — issue saved to $PROJECT_ROOT/ralph/deferred_issues.md."
                        fi

                        return 0  # Don't fail the gate — deferred as tech debt
                    fi

                    # Low/medium blast radius — escalate to Opus for careful fix
                    echo "Blast radius score $BR_SCORE — escalating to Opus for careful fix."
                    printf "Fix ONLY this single issue. Change as few files as possible. Do not refactor broadly.\nAffected type: %s (blast radius score: %s, layers: %s)\n\nGate: %s\nIssue:\n%s\n\nFull context:\n%s" \
                        "$AFFECTED_TYPE" "$BR_SCORE" "$BR_LAYERS" "$GATE" "$FIRST_FAIL" "$OUTPUT" \
                    | claude_run_deep 2>>"$PROJECT_ROOT/ralph/.fix_agent.log" || echo "WARN: Fix agent call failed (timeout or crash) — retrying."
                else
                    # Blast radius script failed — fall back to standard fix
                    printf "Fix ONLY this single issue. Do not refactor or change anything else.\n\nGate: %s\nIssue:\n%s\n\nFull context:\n%s" \
                        "$GATE" "$FIRST_FAIL" "$OUTPUT" \
                    | claude_run 2>>"$PROJECT_ROOT/ralph/.fix_agent.log" || echo "WARN: Fix agent call failed (timeout or crash) — retrying."
                fi
            else
                # Could not extract type — fall back to standard fix
                printf "Fix ONLY this single issue. Do not refactor or change anything else.\n\nGate: %s\nIssue:\n%s\n\nFull context:\n%s" \
                    "$GATE" "$FIRST_FAIL" "$OUTPUT" \
                | claude_run 2>>"$PROJECT_ROOT/ralph/.fix_agent.log" || echo "WARN: Fix agent call failed (timeout or crash) — retrying."
            fi
        else
            # Non-LLM gates — standard fix with Sonnet
            printf "Fix ONLY this single issue. Do not refactor or change anything else.\n\nGate: %s\nIssue:\n%s\n\nFull context:\n%s" \
                "$GATE" "$FIRST_FAIL" "$OUTPUT" \
            | claude_run 2>>"$PROJECT_ROOT/ralph/.fix_agent.log" || echo "WARN: Fix agent call failed (timeout or crash) — retrying."
        fi

        # Ensure the fix didn't break hard gates.
        # Both tiers: post-loop Gate 1 runs precise, so fast alone lets a precise
        # violation through a gate fix and on to the PR.
        if ! bash $RALPH_PLUGIN_DIR/scripts/run_static_gates.sh fast > /dev/null 2>&1 \
           || ! bash $RALPH_PLUGIN_DIR/scripts/run_static_gates.sh precise > /dev/null 2>&1; then
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

        git add -A && git reset HEAD $RALPH_PLAN_FILE progress.txt iteration_context.md 2>/dev/null
        git -c commit.gpgsign=false commit --no-verify -m "ralph: fix $GATE attempt $ATTEMPT" 2>/dev/null \
            || echo "WARN: commit failed for $GATE fix attempt $ATTEMPT. Changes left staged."
    done

    # For LLM gates, pause the pipeline — let the orchestrator ask the user
    if [[ "$GATE" == "LLM_GATES" ]]; then
        echo "GATE $GATE: Could not auto-fix after $MAX_ATTEMPTS attempts — waiting for user decision."
        echo "- Post-loop $GATE: UNFIXED after $MAX_ATTEMPTS attempts (user decision needed)" >> progress.txt
        echo "$OUTPUT" > "$PROJECT_ROOT/ralph/.llm_gate_failures"
        echo "LLM_GATES_BLOCKED" > "$PROJECT_ROOT/ralph/.loop_status"
        return 1
    fi

    notify_failure "$GATE" "$OUTPUT"
}

# ── Bootstrap ──────────────────────────────────────────────────────────────────
if [[ "$MODE" == "bootstrap" ]]; then
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Bootstrap — generating ralph/AGENTS.md"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    {
        echo "Gate scripts (plugin): $RALPH_PLUGIN_DIR/scripts/gates/static/"
        echo "LLM gates (plugin): $RALPH_PLUGIN_DIR/scripts/gates/llm/"
        echo "Gate scripts (project): $PROJECT_ROOT/ralph/gates/static/"
        echo "LLM gates (project): $PROJECT_ROOT/ralph/gates/llm/"
        echo "---"
        cat "$RALPH_PLUGIN_DIR/prompts/PROMPT_bootstrap.md"
    } | claude_run

    if [[ ! -f "$PROJECT_ROOT/ralph/AGENTS.md" ]]; then
        echo ""
        echo "WARNING: ralph/AGENTS.md was not created. Check the output above."
        echo "Check the output above and run bootstrap again."
        exit 1
    fi

    echo ""
    echo "Done. Next steps:"
    echo "  1. Review ralph/AGENTS.md"
    echo "  2. Update BUILD_CMD / UNIT_TEST_CMD in ralph/config.sh"
    echo "  3. Run /ralph-loop:spec [ticket] to create a spec"
    echo "  4. Run /ralph-loop:run [ticket] to start the pipeline"
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
        cat "$RALPH_PLUGIN_DIR/prompts/PROMPT_plan.md" | claude_run
        ITER=$((ITER + 1))
    done
    exit 0
fi

if [[ "$MODE" == "plan-slc" ]]; then
    [[ ! -f "$PROJECT_ROOT/ralph/AUDIENCE_JTBD.md" ]] && {
        echo "ERROR: ralph/AUDIENCE_JTBD.md not found."
        echo "Run /ralph-loop:req-slc first to define audience, JTBDs, and activities."
        exit 1
    }
    ITER=0
    while true; do
        [[ "$MAX_ITERATIONS" -gt 0 && "$ITER" -ge "$MAX_ITERATIONS" ]] && break
        echo "=== Plan-SLC iteration $((ITER + 1)) ==="
        cat "$RALPH_PLUGIN_DIR/prompts/PROMPT_plan_slc.md" | claude_run
        ITER=$((ITER + 1))
    done
    exit 0
fi

if [[ "$MODE" == "plan-parallel" ]]; then
    SPEC_COUNT=$(find "$PROJECT_ROOT/ralph/specs" -name "*.md" -not -path "*/done/*" 2>/dev/null | wc -l | tr -d ' ')
    [[ "$SPEC_COUNT" -lt 2 ]] && {
        echo "ERROR: plan-parallel requires 2+ specs. Found $SPEC_COUNT."
        echo "Use plan-work for single-spec planning."
        exit 1
    }
    # Clean stale plan artifacts before planning
    rm -f IMPLEMENTATION_PLAN*.md 2>/dev/null || true

    # Scale timeout with spec count — planning 10 specs takes much longer than 2
    PLAN_TIMEOUT=$((SPEC_COUNT * 120))
    [[ "$PLAN_TIMEOUT" -lt "$CLAUDE_TIMEOUT" ]] && PLAN_TIMEOUT="$CLAUDE_TIMEOUT"
    echo "Planning parallel build for $SPEC_COUNT specs (timeout: ${PLAN_TIMEOUT}s)..."
    CLAUDE_TIMEOUT="$PLAN_TIMEOUT"
    ITER=0
    PREV_HASH="none"
    while true; do
        [[ "$MAX_ITERATIONS" -gt 0 && "$ITER" -ge "$MAX_ITERATIONS" ]] && break
        echo "=== Plan-parallel iteration $((ITER + 1)) ==="
        cat "$RALPH_PLUGIN_DIR/prompts/PROMPT_plan_parallel.md" | claude_run
        NEW_HASH=$(file_hash "$RALPH_PLAN_FILE" 2>/dev/null || echo "none")
        if [[ "$ITER" -ge 1 && "$NEW_HASH" == "$PREV_HASH" ]]; then
            echo "Plan converged after $((ITER + 1)) iterations."
            break
        fi
        PREV_HASH="$NEW_HASH"
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
            sed "s|\${WORK_DESCRIPTION}|$WORK_DESCRIPTION|g" $RALPH_PLUGIN_DIR/prompts/PROMPT_plan_work.md \
                | claude_run
        else
            # Subsequent iterations: refine, don't rewrite
            PREV_PLAN=$(cat "$RALPH_PLAN_FILE" 2>/dev/null || true)
            {
                echo "Previous plan iteration:"
                echo "$PREV_PLAN"
                echo "---"
                echo "Refine the plan above. Do not restart from scratch."
                echo "Preserve tasks that are already well-specified. Focus on gaps and improvements."
                echo "---"
                sed "s|\${WORK_DESCRIPTION}|$WORK_DESCRIPTION|g" $RALPH_PLUGIN_DIR/prompts/PROMPT_plan_work.md
            } | claude_run
        fi

        # Convergence detection: exit early if plan stopped changing
        NEW_HASH=$(file_hash "$RALPH_PLAN_FILE" 2>/dev/null || echo "none")
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

    # Disable GPG signing in this worktree so commits work without 1Password agent
    git config commit.gpgsign false 2>/dev/null || true

    [[ ! -f "$RALPH_PLAN_FILE" ]] && {
        echo "ERROR: $RALPH_PLAN_FILE not found."
        echo "Run first: loop.sh plan-work \"[feature]\" 3"
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

    # Ensure Xcode has the correct project open from this directory.
    # The Xcode MCP server targets whatever project/workspace is frontmost.
    # If Xcode has the main repo open while we're in a worktree, MCP edits
    # (add file to target, etc.) go to the wrong project.
    if [[ "$XCODE_CLI_AVAILABLE" == "true" ]]; then
        # Determine what to open: workspace if available, otherwise xcodeproj
        EXPECTED_XCODE_PATH=""
        if [[ -n "${XCWORKSPACE:-}" && -d "$PROJECT_ROOT/$XCWORKSPACE" ]]; then
            EXPECTED_XCODE_PATH="$PROJECT_ROOT/$XCWORKSPACE"
        elif [[ -n "${XCODEPROJ:-}" && -d "$PROJECT_ROOT/$XCODEPROJ" ]]; then
            EXPECTED_XCODE_PATH="$PROJECT_ROOT/$XCODEPROJ"
        fi

        if [[ -n "$EXPECTED_XCODE_PATH" ]]; then
            ACTIVE_WORKSPACE=$(osascript -e 'tell application "Xcode" to get path of active workspace document' 2>/dev/null || true)
            # Check if the active workspace/project is from our directory
            if [[ -n "$ACTIVE_WORKSPACE" && "$ACTIVE_WORKSPACE" != *"$PROJECT_ROOT"* ]]; then
                echo "WARNING: Xcode has '$ACTIVE_WORKSPACE' open, not from $PROJECT_ROOT"
                echo "Opening correct project..."
                open "$EXPECTED_XCODE_PATH"
                for _i in {1..30}; do
                    LOADED=$(osascript -e 'tell application "Xcode" to get path of active workspace document' 2>/dev/null || true)
                    [[ "$LOADED" == *"$PROJECT_ROOT"* ]] && break
                    sleep 1
                done
                echo "Xcode project: OK"
            elif [[ -z "$ACTIVE_WORKSPACE" ]]; then
                echo "Xcode not running — opening $(basename "$EXPECTED_XCODE_PATH")"
                open "$EXPECTED_XCODE_PATH"
                for _i in {1..30}; do
                    LOADED=$(osascript -e 'tell application "Xcode" to get path of active workspace document' 2>/dev/null || true)
                    [[ -n "$LOADED" ]] && break
                    sleep 1
                done
                echo "Xcode project: OK"
            else
                echo "Xcode project: OK"
            fi
        fi
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

    # Pre-boot the simulator so iterations reuse a single instance.
    # Without this, each xcodebuild call can spawn a new Simulator window.
    if [[ -n "$SIM_NAME" ]]; then
        SIM_UDID=$(xcrun simctl list devices available -j 2>/dev/null \
            | python3 -c "
import sys, json
data = json.load(sys.stdin)
for runtime, devices in data.get('devices', {}).items():
    for d in devices:
        if d.get('name') == '$SIM_NAME' and d.get('isAvailable'):
            print(d['udid']); sys.exit(0)
" 2>/dev/null || true)
        if [[ -n "$SIM_UDID" ]]; then
            SIM_STATE=$(xcrun simctl list devices -j 2>/dev/null \
                | python3 -c "
import sys, json
data = json.load(sys.stdin)
for runtime, devices in data.get('devices', {}).items():
    for d in devices:
        if d.get('udid') == '$SIM_UDID':
            print(d.get('state', 'Unknown')); sys.exit(0)
" 2>/dev/null || echo "Unknown")
            if [[ "$SIM_STATE" != "Booted" ]]; then
                echo "Booting simulator '$SIM_NAME' ($SIM_UDID)..."
                xcrun simctl boot "$SIM_UDID" 2>/dev/null || true
            else
                echo "Simulator '$SIM_NAME' already booted."
            fi
            export RALPH_SIM_UDID="$SIM_UDID"
            # Ensure simulator and Xcode window shut down on exit, kill, or interrupt
            cleanup_on_exit() {
                xcrun simctl shutdown "$RALPH_SIM_UDID" 2>/dev/null || true
                # Close the Xcode window for this worktree's project
                if [[ -n "${EXPECTED_XCODE_PATH:-}" ]]; then
                    osascript -e "
                        tell application \"Xcode\"
                            repeat with doc in (every workspace document)
                                if path of doc contains \"$PROJECT_ROOT\" then
                                    close doc
                                end if
                            end repeat
                        end tell
                    " 2>/dev/null || true
                fi
            }
            trap cleanup_on_exit EXIT INT TERM
        fi
    fi

    # Detect new gates (static + LLM) not yet calibrated in gate_context.md
    if [[ -f "$PROJECT_ROOT/ralph/gate_context.md" ]]; then
        # Static gates (plugin + project)
        for GATE_FILE in "$RALPH_PLUGIN_DIR/scripts/gates/static"/*/*.sh "$PROJECT_ROOT/ralph/gates/static"/*/*.sh; do
            [[ -f "$GATE_FILE" ]] || continue
            GATE_NAME=$(basename "$GATE_FILE" .sh)
            if ! grep -q "$GATE_NAME" "$PROJECT_ROOT/ralph/gate_context.md" 2>/dev/null; then
                echo "WARNING: New static gate '$GATE_NAME' not in gate_context.md — build agent will calibrate."
            fi
        done
        # LLM gates (plugin + project)
        for GATE_FILE in "$RALPH_PLUGIN_DIR/scripts/gates/llm"/*.md "$PROJECT_ROOT/ralph/gates/llm"/*.md; do
            [[ -f "$GATE_FILE" ]] || continue
            GATE_NAME=$(basename "$GATE_FILE" .md)
            if ! grep -q "$GATE_NAME" "$PROJECT_ROOT/ralph/gate_context.md" 2>/dev/null; then
                echo "WARNING: New LLM gate '$GATE_NAME' not in gate_context.md — build agent will calibrate."
            fi
        done
    fi

    echo "Checking baseline build..."
    run_quietly "$BUILD_CMD" || {
        echo "ERROR: Baseline build is failing. Fix before running the loop."
        exit 1
    }
    echo "Baseline: OK"

    # Record baseline test failures so pre-existing failures don't trigger rollbacks
    echo "Checking baseline tests..."
    BASELINE_TEST_OUTPUT=""
    BASELINE_TEST_FAILURES=""
    if ! BASELINE_TEST_OUTPUT=$(eval "$UNIT_TEST_CMD" 2>&1); then
        BASELINE_TEST_FAILURES=$(echo "$BASELINE_TEST_OUTPUT" | grep -E 'FAIL|failed|error:' | sort -u || true)
        echo "WARNING: Baseline tests have pre-existing failures (will not rollback for these):"
        echo "$BASELINE_TEST_FAILURES" | head -10
    else
        echo "Baseline tests: OK"
    fi
fi

# ── Build loop ─────────────────────────────────────────────────────────────────
if [[ "$MODE" == "build" ]]; then
    # Reset stale state from prior runs to prevent false exits
    > "$PROJECT_ROOT/ralph/.loop_status"
    > iteration_context.md

    echo "=== Pipeline started: $(date '+%Y-%m-%d %H:%M:%S') ===" >> progress.txt

    # Detect prior progress — if ralph: commits exist, reconcile the plan
    PRIOR_COMMITS=$(git log --oneline --grep="^ralph:" 2>/dev/null | wc -l | tr -d ' ')
    if [[ "$PRIOR_COMMITS" -gt 0 && -f "$RALPH_PLAN_FILE" ]]; then
        echo "Detected $PRIOR_COMMITS prior ralph commits — reconciling plan with code state..."
        COMMIT_LOG=$(git log --oneline --grep="^ralph:" 2>/dev/null)
        printf "These commits have already been made on this branch:\n%s\n\nUpdate $RALPH_PLAN_FILE: mark any task as [x] done if the commit log shows it was implemented. Do not uncheck tasks. Do not change task descriptions. Only update checkboxes.\n\n$RALPH_PLAN_FILE:\n%s" \
            "$COMMIT_LOG" "$(cat "$RALPH_PLAN_FILE")" \
        | claude_run_fast 2>/dev/null
        echo "Plan reconciled."
    fi

    ITER=0
    CONSEC_FAIL=0
    LAST_FAIL_GATE=""
    NEEDS_DEEP_DIAGNOSIS=false

    while true; do
        [[ "$MAX_ITERATIONS" -gt 0 && "$ITER" -ge "$MAX_ITERATIONS" ]] && break

        # Stop if all tasks are done
        if ! grep -q '^\- \[ \]' "$RALPH_PLAN_FILE" 2>/dev/null; then
            echo "All tasks in $RALPH_PLAN_FILE are done."
            break
        fi

        # Clear deep diagnosis flag at the start of each iteration
        NEEDS_DEEP_DIAGNOSIS=false

        echo ""
        echo "=== Build iteration $((ITER + 1)) ==="

        # Build the prompt, prepending context if available
        PROMPT=$(sed "s|\${XCODEPROJ}|$XCODEPROJ|g" "$RALPH_PLUGIN_DIR/prompts/PROMPT_build.md")
        # Inject gate locations so build agent knows where to find them
        PROMPT="Gate scripts (plugin): $RALPH_PLUGIN_DIR/scripts/gates/static/
LLM gates (plugin): $RALPH_PLUGIN_DIR/scripts/gates/llm/
Gate scripts (project): $PROJECT_ROOT/ralph/gates/static/
LLM gates (project): $PROJECT_ROOT/ralph/gates/llm/
---
$PROMPT"
        if [[ -f iteration_context.md ]]; then
            PROMPT="$(cat iteration_context.md)
---
$PROMPT"
        fi
        # Load persistent lessons when struggling
        if [[ "$CONSEC_FAIL" -ge 2 && -f "$PROJECT_ROOT/ralph/lessons.md" ]]; then
            PROMPT="Lessons from previous sessions (follow these):
$(cat "$PROJECT_ROOT/ralph/lessons.md")
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

        # ── 1. Build (with inline fix attempts) ─────────────────────────────────
        # Instead of immediately rolling back on build failure, give the agent
        # up to 2 chances to fix compile errors in-place. Only files the agent
        # touched this iteration are allowed to be modified.
        AGENT_FILES=$(git diff --name-only HEAD 2>/dev/null || true)
        BUILD_PASS=false
        BUILD_OUTPUT=""
        for BUILD_ATTEMPT in 1 2 3; do
            if BUILD_OUTPUT=$(eval "$BUILD_CMD" 2>&1); then
                BUILD_PASS=true
                break
            fi

            # First attempt is the original build — attempts 2-3 are fix attempts
            if [[ "$BUILD_ATTEMPT" -ge 3 ]]; then
                break
            fi

            echo "  Build failed (attempt $BUILD_ATTEMPT/3) — attempting inline fix..."

            # Extract error lines for the fix prompt
            BUILD_ERRORS=$(echo "$BUILD_OUTPUT" | grep -E 'error:|cannot |no member|missing|undeclared|expected ' | head -20 || true)

            # Build the fix prompt — scoped to agent's files only
            FIX_PROMPT="The build failed with these errors:

$BUILD_ERRORS

You may ONLY modify these files (the ones you changed this iteration):
$AGENT_FILES

Fix the compile errors. Do NOT modify any other files. Do NOT add new features or refactor.
Read the error messages carefully — check the actual type signatures and initializers in the source before writing fixes.
After fixing, do nothing else — the loop will re-run the build."

            echo "$FIX_PROMPT" | claude_run_fast 2>/dev/null || true
        done

        if [[ "$BUILD_PASS" == false ]]; then
            echo "HARD: Build failed after 3 attempts — rolling back."
            append_failure_context "build" "$BUILD_OUTPUT" "$((ITER+1))"
            rollback_all
            run_diagnostician "$((ITER+1))" "build"
            echo "- Iter $((ITER+1)): build failed (3 attempts)" >> progress.txt
            [[ "$LAST_FAIL_GATE" == "build" ]] && CONSEC_FAIL=$((CONSEC_FAIL+1)) || { CONSEC_FAIL=1; LAST_FAIL_GATE="build"; }
            write_loop_status "$((ITER+1))"
            ITER=$((ITER + 1)) && continue
        fi

        # ── 2. Unit tests ─────────────────────────────────────────────────────────
        TEST_OUTPUT=""
        if ! TEST_OUTPUT=$(eval "$UNIT_TEST_CMD" 2>&1); then
            # Check if failures are only pre-existing baseline failures
            CURRENT_FAILURES=$(echo "$TEST_OUTPUT" | grep -E 'FAIL|failed|error:' | sort -u || true)
            if [[ -n "$BASELINE_TEST_FAILURES" ]]; then
                NEW_FAILURES=$(comm -23 <(echo "$CURRENT_FAILURES") <(echo "$BASELINE_TEST_FAILURES") || true)
                if [[ -z "$NEW_FAILURES" ]]; then
                    echo "Tests failed but only with pre-existing baseline failures — continuing."
                    echo "- Iter $((ITER+1)): tests failed (pre-existing only, skipped rollback)" >> progress.txt
                else
                    echo "Unit tests have NEW failures — attempting inline fix..."

                    # Inline test fix: give the agent 1 attempt to fix test failures
                    # scoped to files it touched this iteration
                    TEST_ERRORS=$(echo "$NEW_FAILURES" | head -20)
                    TEST_FIX_PROMPT="Unit tests failed with these NEW errors (not pre-existing):

$TEST_ERRORS

You may ONLY modify these files (the ones you changed this iteration):
$AGENT_FILES

Fix the test failures. Read the actual method signatures and types before fixing.
Do NOT modify any other files. Do NOT add new features."

                    echo "$TEST_FIX_PROMPT" | claude_run_fast 2>/dev/null || true

                    # Re-run tests after fix attempt
                    if TEST_RETRY=$(eval "$UNIT_TEST_CMD" 2>&1); then
                        echo "  Inline test fix succeeded."
                    else
                        RETRY_FAILURES=$(echo "$TEST_RETRY" | grep -E 'FAIL|failed|error:' | sort -u || true)
                        STILL_NEW=$(comm -23 <(echo "$RETRY_FAILURES") <(echo "$BASELINE_TEST_FAILURES") || true)
                        if [[ -z "$STILL_NEW" ]]; then
                            echo "  Inline test fix resolved new failures (pre-existing remain)."
                        else
                            echo "HARD: Unit tests still failing after inline fix."
                            append_failure_context "tests" "$TEST_RETRY" "$((ITER+1))"
                            run_diagnostician "$((ITER+1))" "tests"
                            TEST_FILES=$(git diff --name-only HEAD 2>/dev/null | grep -E 'Tests/|Spec/' || true)
                            if [[ -n "$TEST_FILES" ]]; then
                                echo "Rolling back test files only — keeping source changes."
                                rollback_files "$TEST_FILES"
                            else
                                rollback_all
                            fi
                            echo "- Iter $((ITER+1)): tests failed (after inline fix)" >> progress.txt
                            [[ "$LAST_FAIL_GATE" == "tests" ]] && CONSEC_FAIL=$((CONSEC_FAIL+1)) || { CONSEC_FAIL=1; LAST_FAIL_GATE="tests"; }
                            write_loop_status "$((ITER+1))"
                            ITER=$((ITER + 1)) && continue
                        fi
                    fi
                fi
            else
                echo "Unit tests failed — attempting inline fix..."

                TEST_ERRORS=$(echo "$TEST_OUTPUT" | grep -E 'FAIL|failed|error:' | head -20 || true)
                TEST_FIX_PROMPT="Unit tests failed:

$TEST_ERRORS

You may ONLY modify these files (the ones you changed this iteration):
$AGENT_FILES

Fix the test failures. Read the actual method signatures and types before fixing.
Do NOT modify any other files. Do NOT add new features."

                echo "$TEST_FIX_PROMPT" | claude_run_fast 2>/dev/null || true

                if eval "$UNIT_TEST_CMD" >/dev/null 2>&1; then
                    echo "  Inline test fix succeeded."
                else
                    echo "HARD: Unit tests still failing after inline fix."
                    append_failure_context "tests" "$TEST_OUTPUT" "$((ITER+1))"
                    run_diagnostician "$((ITER+1))" "tests"
                    TEST_FILES=$(git diff --name-only HEAD 2>/dev/null | grep -E 'Tests/|Spec/' || true)
                    if [[ -n "$TEST_FILES" ]]; then
                        echo "Rolling back test files only — keeping source changes."
                        rollback_files "$TEST_FILES"
                    else
                        rollback_all
                    fi
                    echo "- Iter $((ITER+1)): tests failed (after inline fix)" >> progress.txt
                    [[ "$LAST_FAIL_GATE" == "tests" ]] && CONSEC_FAIL=$((CONSEC_FAIL+1)) || { CONSEC_FAIL=1; LAST_FAIL_GATE="tests"; }
                    write_loop_status "$((ITER+1))"
                    ITER=$((ITER + 1)) && continue
                fi
            fi
        fi

        # ── 3. Code quality + architecture gates (fast tier) ────────────────────
        GATE_OUTPUT=""
        if ! GATE_OUTPUT=$(bash $RALPH_PLUGIN_DIR/scripts/run_static_gates.sh fast 2>&1); then
            echo "GATES: Violation detected."
            echo "$GATE_OUTPUT"

            # Only roll back files the agent changed this iteration that are also flagged
            OFFENDING_FILES=$(echo "$GATE_OUTPUT" | grep -oE '[A-Za-z0-9_./]+\.swift' | sort -u || true)
            AGENT_CHANGED=$(git diff --name-only HEAD 2>/dev/null | sort -u || true)
            PRE_EXISTING_ONLY=false
            if [[ -n "$OFFENDING_FILES" && -n "$AGENT_CHANGED" ]]; then
                # Intersect: only roll back files the agent touched AND the gate flagged
                ROLLBACK_FILES=$(comm -12 <(echo "$OFFENDING_FILES") <(echo "$AGENT_CHANGED") || true)
                if [[ -n "$ROLLBACK_FILES" ]]; then
                    echo "Rolling back agent-changed files that failed gates."
                    rollback_files "$ROLLBACK_FILES"
                else
                    echo "Gate flagged pre-existing code only — skipping rollback, diagnostician, and failure count."
                    PRE_EXISTING_ONLY=true
                fi
            else
                rollback_all
            fi

            if [[ "$PRE_EXISTING_ONLY" == "true" ]]; then
                echo "- Iter $((ITER+1)): gate violation (pre-existing only, skipped)" >> progress.txt
                write_loop_status "$((ITER+1))"
                ITER=$((ITER + 1)) && continue
            fi

            append_failure_context "gates" "$GATE_OUTPUT" "$((ITER+1))"
            run_diagnostician "$((ITER+1))" "gates"
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
                run_diagnostician "$((ITER+1))" "lint"
                rollback_all
                echo "- Iter $((ITER+1)): lint unfixable" >> progress.txt
                [[ "$LAST_FAIL_GATE" == "lint" ]] && CONSEC_FAIL=$((CONSEC_FAIL+1)) || { CONSEC_FAIL=1; LAST_FAIL_GATE="lint"; }
                write_loop_status "$((ITER+1))"
            ITER=$((ITER + 1)) && continue
            fi
        fi

        # ── Verify commit landed ──────────────────────────────────────────────────
        # The build agent should have committed. If there are uncommitted changes,
        # the commit silently failed (e.g., sandbox blocked .git writes in worktree).
        if [[ -n "$(git status --porcelain -- "${SOURCE_DIR:-.}/" 2>/dev/null)" ]]; then
            echo "WARN: Agent did not commit — committing on its behalf."
            TASK_DESC=$(grep '^\- \[x\]' "$RALPH_PLAN_FILE" 2>/dev/null | tail -1 | sed 's/^\- \[x\] //' | head -c 72)
            [[ -z "$TASK_DESC" ]] && TASK_DESC="iteration $((ITER+1)) changes"
            git add -A && git reset HEAD $RALPH_PLAN_FILE progress.txt iteration_context.md "$PROJECT_ROOT/ralph/.loop_status" 2>/dev/null
            git commit --no-verify -m "ralph: $TASK_DESC" 2>/dev/null || {
                echo "HARD: Backup commit also failed — rolling back."
                append_failure_context "commit" "Agent and loop commit both failed. Check git permissions." "$((ITER+1))"
                run_diagnostician "$((ITER+1))" "commit"
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

# ── Shutdown simulator and close Xcode window ────────────────────────────────
if [[ -n "${RALPH_SIM_UDID:-}" ]]; then
    echo "Shutting down simulator..."
    xcrun simctl shutdown "$RALPH_SIM_UDID" 2>/dev/null || true
fi
if [[ -n "${EXPECTED_XCODE_PATH:-}" ]]; then
    echo "Closing Xcode window for $(basename "$EXPECTED_XCODE_PATH")..."
    osascript -e "
        tell application \"Xcode\"
            repeat with doc in (every workspace document)
                if path of doc contains \"$PROJECT_ROOT\" then
                    close doc
                end if
            end repeat
        end tell
    " 2>/dev/null || true
fi

# ── Post-loop gates ────────────────────────────────────────────────────────────
if [[ "$MODE" == "build" || "$MODE" == "post-loop" ]]; then

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Post-loop gates"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    # Gate 1: Precise-tier static gates (cheap, deterministic — run first to fail fast)
    run_gate_with_fix "GATES_PRECISE" "bash $RALPH_PLUGIN_DIR/scripts/run_static_gates.sh precise"

    # Gate 2: LLM gates — semantic review (max 2 retries — more retries cause divergence)
    # If LLM gates fail and can't be auto-fixed, the loop exits here.
    # The orchestrator reads .llm_gate_failures and asks the user to decide.
    run_gate_with_fix "LLM_GATES" "bash $RALPH_PLUGIN_DIR/scripts/run_llm_gates.sh" 2 || {
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "LLM gates blocked — waiting for user decision."
        echo "Failures saved to ralph/.llm_gate_failures"
        echo "Re-run with: loop.sh post-loop"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        exit 7
    }

    # Gate 3: Full static sweep over the final tree.
    # Gates 1 and 2 each ran before the other's fixes landed. A fix applied during
    # the LLM stage can break a static gate that passed in the static stage, and
    # nothing else re-checks it. The tree that opens the PR must be the tree that passed.
    echo ""
    echo "=== Full static sweep ==="
    SWEEP_OK=true
    SWEEP_OUT=$(bash $RALPH_PLUGIN_DIR/scripts/run_static_gates.sh fast 2>&1) || SWEEP_OK=false
    if [[ "$SWEEP_OK" == "true" ]]; then
        SWEEP_OUT=$(bash $RALPH_PLUGIN_DIR/scripts/run_static_gates.sh precise 2>&1) || SWEEP_OK=false
    fi
    if [[ "$SWEEP_OK" != "true" ]]; then
        echo "GATE FULL_SWEEP: FAIL"
        echo "$SWEEP_OUT"
        echo "- Post-loop FULL_SWEEP: FAIL (a later fix broke a gate that passed earlier)" >> progress.txt
        echo "FULL_SWEEP_FAILED" > "$PROJECT_ROOT/ralph/.loop_status"
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "Full static sweep failed. Not opening a PR."
        echo "Fix, then run: loop.sh post-loop"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        exit 8
    fi
    echo "GATE FULL_SWEEP: PASS"
    echo "- Post-loop FULL_SWEEP: PASS" >> progress.txt

    # Gate 4: UI routing decision (agent classifies the full branch diff)
    echo ""
    echo "=== UI routing ==="
    BASE=$(git merge-base "$DIFF_BASE_BRANCH" HEAD 2>/dev/null || echo "HEAD~1")
    CUMULATIVE_DIFF=$(git diff "$BASE"...HEAD -- "$SOURCE_DIR/" 2>/dev/null)

    UI_ROUTE=$(printf \
        "Classify the UI impact of these changes.\n\nDiff:\n%s\n\nRespond with EXACTLY one of these three words, nothing else:\nNO_UI\nVIEW_LEVEL\nFLOW_LEVEL\n\nDefinitions:\n- NO_UI: changes only in models, repositories, services, viewmodels, utilities, or tests\n- VIEW_LEVEL: changes confined to Views/ or Components/ only\n- FLOW_LEVEL: changes touching navigation, multi-view flows, or spanning more than one layer" \
        "$CUMULATIVE_DIFF" \
    | claude -p --model claude-sonnet-4-6 2>/dev/null \
    | grep -oE 'NO_UI|VIEW_LEVEL|FLOW_LEVEL' | awk 'NR==1{print; exit}') || true

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

    # Commit deferred issues before worktree cleanup so they aren't lost
    if [[ -f "$PROJECT_ROOT/ralph/deferred_issues.md" ]]; then
        git add "$PROJECT_ROOT/ralph/deferred_issues.md" 2>/dev/null
        git -c commit.gpgsign=false commit --no-verify -m "ralph: record deferred gate issues" 2>/dev/null \
            || echo "WARN: could not commit deferred issues. See $PROJECT_ROOT/ralph/deferred_issues.md"
    fi

    # Gate 5: Open draft PR
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
- Full static sweep: PASS (post-loop, final tree)
- UI route: $UI_ROUTE
${SNAPSHOT_LINE}
${UI_LINE}

### Reviewer checklist
- [ ] Run on simulator or device
- [ ] Dark mode
- [ ] API surface matches spec
- [ ] Build log has no unexpected rollbacks"

    echo "=== Pipeline finished: $(date '+%Y-%m-%d %H:%M:%S') ===" >> progress.txt

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "All gates passed."
    # Ensure branch is pushed before creating PR
    git push -u origin "$BRANCH" 2>/dev/null || true
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
