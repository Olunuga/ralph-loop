# Ralph-Loop — Operational Knowledge

This file documents known issues, fixes, and gotchas discovered through test runs. Read this before modifying the pipeline to avoid re-fixing solved problems.

## Workspace Boundary Hook (`scripts/hooks/workspace_boundary.sh`)

### Fixed: URLs matched as filesystem paths
The `check_paths` regex extracts tokens starting with `/` from command strings. URLs like `https://github.com/Olunuga/ralph-loop` caused `/github.com/...` to be flagged as an absolute path outside the workspace.

**Fix:** Lookbehind `(?<![\w:/])` — the `/` after `://` is preceded by `/`, so URL paths are skipped.

**Chicken-and-egg problem:** When running `/ralph-update`, the target project's copy of the hook is the OLD version. The update tries to clone from GitHub, the old hook blocks the URL, and the update fails before it can install the fixed hook. Workaround: the user must manually copy the updated `workspace_boundary.sh` first, or use a shell variable to hide the URL (`GH="github.com"`).

### Fixed: Glob patterns matched as paths
Tokens containing `*` or `?` (e.g. `/scripts/gates/static/*/*.sh`) were flagged as absolute paths. Fix: skip tokens with glob characters.

### Fixed: $TMPDIR blocked
Temp directory paths (`/var/folders/...`) needed for `git clone` and temp operations were blocked. Fix: allow `$TMPDIR` and `/private/tmp/*` paths.

### Fixed: Worktree-to-main-repo operations blocked
The hook only allowed paths in `.worktrees/*` siblings, not the main project root itself. Operations like `git worktree remove` reference the main repo path and were blocked. Fix: allow all paths within `$PROJECT_WORKSPACE` (the git common dir root).

### Sandbox vs Hook
The Claude Code sandbox and the workspace boundary hook are different layers:
- **Sandbox**: OS-level write restrictions. Controlled by `dangerouslyDisableSandbox: true` on the Bash tool. Blocks `.worktrees/` creation, `git clone` hook template copies, `xcrun simctl`.
- **Hook**: PreToolUse script that inspects command text before execution. Blocks paths outside workspace in Write/Edit/Bash tool calls.

Both can block the same operation for different reasons. When debugging, check which one fired.

## Build Loop (`loop.sh`)

### Nested `claude -p` doesn't work
`loop.sh` spawns `claude -p` subprocesses. These cannot run inside an existing Claude Code session. The `/ralph` skill must use the Bash tool's `run_in_background: true` parameter — NOT shell backgrounding (`&`).

### `set -euo pipefail` kills the loop
Any uncaught error in a `claude -p` call, `git push`, or API timeout kills the entire script. Agent calls are wrapped with `|| AGENT_OK=false` (build loop) and `|| echo "WARN: ..."` (run_gate_with_fix) to catch failures and continue.

### Rollback must undo commits, not just uncommitted changes
The build agent commits its work before gates run. `git checkout HEAD -- <file>` only reverts uncommitted changes — committed code is untouched. `rollback_all` and `rollback_files` now detect agent commits from the current iteration (via `git log --grep="^ralph:" --since="5 minutes ago"`) and `git reset HEAD~N` to undo them before reverting files.

### Branch must be pushed before PR creation
The per-iteration push (line ~719) only fires after a green iteration. If gates fail after the agent committed, the branch is never pushed. A `git push` is now added before `gh pr create` in the post-loop section.

### `caffeinate -i` prevents idle sleep
The script re-execs itself under `caffeinate -i` on macOS to prevent the system from sleeping during long pipeline runs. Uses `RALPH_CAFFEINATED` env var to avoid re-wrapping.

### Loop restart loses state
When the loop is restarted, the iteration counter resets and `IMPLEMENTATION_PLAN.md` may not reflect prior commits. Fix: on startup, detect existing `ralph:` commits and reconcile plan checkboxes with a fast claude call.

### `git rev-parse --show-toplevel` vs `--git-common-dir`
`--show-toplevel` returns the worktree root when run inside a worktree. This causes double-nested paths like `.worktrees/ref/.worktrees/ref`. Always use `git rev-parse --path-format=absolute --git-common-dir | sed 's|/\.git$||'` to get the main repo root.

## Gates

### LLM gates diverge on retry
Each LLM gate retry can invent new complaints instead of re-checking the same criteria. Mitigations:
- Convergence rules in the prompt: "only flag concrete defects against the numbered checklist"
- Max retries reduced to 2 (more retries cause more divergence)

### Blast radius analysis for LLM gate fixes
`run_gate_with_fix` runs blast radius analysis (`scripts/blast_radius.sh`) before attempting LLM gate fixes. The script measures 4 dimensions of a type's impact surface:

| Dimension | Low (0) | Medium (1) | High (2) |
|-----------|---------|------------|----------|
| File fan-out | <= 5 | 6-15 | > 15 |
| Type coupling (Ca) | <= 3 | 4-10 | > 10 |
| Layers crossed | 1 | 2 | >= 3 |
| Infrastructure reach | 1-2 dirs | 3-4 dirs | 5+ dirs |
| Test coupling | <= 1 | 2-3 | > 3 |

Based on the composite score (0-10):
- **Score 0-3**: Escalate to Opus for careful, contained fix
- **Score 4-6**: Escalate to Opus, but only if change stays within one layer — otherwise defer
- **Score 7-10**: Defer — create GitHub issue as tech debt, don't fail the gate

Thresholds are configurable per-project via `ralph/gate_context.md`.

LLM gates that exhaust retries without a fix also don't fail the pipeline — they log for manual review. This prevents architectural suggestions from blocking feature delivery.

Based on Martin's coupling metrics, Google's LSC sharding practice, and Feathers' seam analysis.
- `run_gate_with_fix` accepts an optional max-attempts parameter

### Static gates must be diff-scoped
Gates that scan the entire file (e.g. `missing_labels`, `color_only`) flag pre-existing violations unrelated to the feature. These gates must only check added lines from the branch diff, not the full file.

### Smart rollback on gate failure
When a static gate fails, only roll back files the agent changed in this iteration that ALSO failed the gate. If the gate flagged pre-existing code only, skip rollback entirely. This prevents valid new code from being reverted due to unrelated violations.

### Gate ordering: static before LLM
Post-loop gates run static (deterministic, cheap) before LLM (non-deterministic, expensive). Fail fast on cheap checks.

## `/ralph` Skill (Orchestrator)

### Orchestrator must NOT edit files directly
The orchestrator's only roles are: monitoring, diagnosing, writing to `iteration_context.md`, and restarting the loop. All code changes go through the build agent via `loop.sh`.

If stuck: write diagnosis to `iteration_context.md` in the worktree, then restart the loop. The build agent reads it as context for the next iteration.

### Worktree creation needs `dangerouslyDisableSandbox: true`
ALL `git worktree add` commands must use `dangerouslyDisableSandbox: true`. The sandbox write allowlist does not cover `.worktrees/`. Try commands in fallback order:
1. `git worktree add .worktrees/$ref -b ralph/$ref spec/$ref` (new branch from spec)
2. `git worktree add .worktrees/$ref -b ralph/$ref` (new branch from main)
3. `git worktree add .worktrees/$ref ralph/$ref` (checkout existing branch, no -b)
4. If worktree directory already exists, continue

### Monitoring reads from worktree, not $TMPDIR
`run_in_background` output goes to `$TMPDIR` which the workspace boundary hook blocks. Read `ralph/.loop_status` and `ralph/.loop_output` inside the worktree instead.

## `/ralph-init` and `/ralph-update` Skills

### Must commit ralph/ after setup/update
Ralph files must be tracked in git for worktrees to include them. Both skills commit ralph/ after copying files. Without this, worktrees created by `/ralph` won't have the pipeline.

### `/ralph-update` chicken-and-egg
If the target project's `workspace_boundary.sh` is the old version, `/ralph-update` may fail before it can install the fix. Workaround: manually copy the updated hook first.

## Post-Mortem

The `/ralph` skill runs a post-mortem (Step 5a) before worktree cleanup. It reads `progress.txt`, `ralph/.loop_status`, `ralph/lessons.md`, and git log to compile a summary. Operational learnings are committed to `ralph/AGENTS.md` on the feature branch.

`progress.txt` includes pipeline start/end timestamps for duration tracking.
