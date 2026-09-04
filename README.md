# ralph-loop

An autonomous development pipeline for iOS projects, powered by Claude Code. You describe a feature, the pipeline builds it — writing code, running tests, and enforcing quality gates in a git worktree, iteration by iteration.

Distributed as a **Claude Code plugin**.

## How it works

1. `/ralph-loop:spec` — structured JTBD conversation produces a spec committed to a `spec/<slug>` branch
2. `/ralph-loop:run` — orchestrates the pipeline: creates a worktree, plans the work, runs the build loop, gates the output
3. The build loop runs iteration by iteration, one worktree per spec. See **Parallel builds** below when a branch carries two or more specs.
4. Post-loop gates: precise static gates → LLM gates (with blast radius analysis) → UI tests → draft PR
5. You review the branch and merge

Human decisions: spec approval and branch review. Everything else is automated.

### Parallel builds

When 2+ specs are on a branch, the orchestrator automatically switches to parallel mode:

```
Phase 1: Plan — decompose into shared deps + per-spec tasks
Phase 2: Build shared deps (sequential, ~3 iterations)
Phase 3: Parallel spec builds (one agent per spec, ~7 iterations each)
Phase 4: Merge + resolve conflicts
Phase 5: Final gates on merged branch + draft PR
```

Each spec-builder agent runs in its own worktree with independent iteration budget, failure tracking, and model escalation. The orchestrator monitors all agents and spawns the diagnostician when any agent is struggling.

### Model usage

| Role | Model | Runs |
|---|---|---|
| Orchestrator | Sonnet or Opus | Your `/ralph-loop:run` session. Finds the spec, creates the worktree, starts `loop.sh`, monitors it |
| Build iteration | Haiku, escalating to Sonnet then Opus | Inside `loop.sh` |
| Gates and diagnostics | Sonnet, Opus on deep diagnosis | Inside `loop.sh` |

---

## Setup

### 1. Install the plugin

```bash
claude plugin install Olunuga/ralph-loop
```

Or test locally during development:

```bash
claude --plugin-dir /path/to/ralph-loop
```

### 2. Initialize your project

Open a Claude Code session in your iOS project root:

```
/ralph-loop:init
```

This auto-discovers your Xcode scheme, simulator, and test targets, then writes:
- `ralph/config.sh` — build commands
- `ralph/AGENTS.md` — codebase architecture (via bootstrap)
- `ralph/gates/` — directory for custom project gates
- `.claude/settings.json` — workspace boundary hook + permissions

### 3. Optional: OpenSpec planning and enforced gates

`ralph-bridge` lets OpenSpec own planning while ralph owns the gates. Planning becomes
gate-aware, and git hooks enforce the gates for anything the loop did not build.

```bash
npm i -g openspec
```
```
/ralph-loop:init --openspec
```

That adds, on top of the normal setup:
- `openspec/schemas/ralph-bridge/` : planning schema, set active
- `ralph/gate_context.md` : gate overrides and hook tiers
- `.git/hooks/pre-commit` : fast static gates
- `.git/hooks/pre-push` : precise static gates, then LLM gates

The flag is also the upgrade command. Re-run it after `claude plugin update ralph-loop`
to refresh the schema. It never modifies `ralph/config.sh`, `ralph/gates/`,
`ralph/gate_context.md`, `.diff_base`, or `ralph/specs/`, so an existing project keeps
working and existing gate calibration carries over.

Then plan with `/opsx:propose` and build with either `/opsx:apply` (you) or
`/ralph-loop:run <change-name>` (autonomous). Both mark the same `tasks.md`, so you can
do part of a change and hand the rest over.

**Bypassing a hook.** `git commit --no-verify` and `git push --no-verify` skip the check.
When a gate flags something you accept, record it in `ralph/gate_context.md` instead:

```
- color_only: SKIP — pre-existing violations on this branch
```

`bin/loop.sh` always commits with `--no-verify`, because it runs the gate engine itself.

### Migrating from file-copy installation

If you previously used `/ralph-install` to copy pipeline files into `ralph/`:

```
/ralph-loop:migrate
```

This preserves your config, AGENTS.md, and specs, moves any custom gates to `ralph/gates/`, and removes pipeline files now served by the plugin.

---

## Workflows

### Single feature (quick)

```
/ralph-loop:spec my-feature        # describe what to build, get a spec
/ralph-loop:run my-feature         # run the pipeline autonomously
```

### Multi-topic PRD (multiple specs from one JTBD)

```
/ralph-loop:req-prd my-project     # decompose JTBD into topics, one spec per topic
/ralph-loop:run my-project         # pipeline plans across all specs
```

### SLC release planning (incremental delivery)

```
/ralph-loop:req-slc my-product     # capture audience, JTBDs, activities at all depths
/ralph-loop:run my-product         # auto-detects SLC mode, recommends thin slice
```

SLC mode captures the **full activity space** upfront (basic → enhanced → advanced depths per activity). Planning then recommends the narrowest **Simple, Lovable, Complete** slice. Deferred activities stay visible as backlog. `ralph/AUDIENCE_JTBD.md` persists across releases — no re-interviews needed.

### Resuming an incomplete run

If the loop exits early (iteration budget exhausted, laptop slept, session ended), re-run the same command:

```
/ralph-loop:run my-feature         # detects existing commits, picks up remaining tasks
```

The pipeline detects prior `ralph:` commits on the branch, reconciles the plan (marks completed tasks), and continues from where it left off. No work is lost — committed code survives across runs.

### Baseline health check

```
/ralph-loop:doctor                 # diagnose build, test, and gate failures
```

Runs the full baseline: build, unit tests, static gates (fast + precise), and LLM gates. Groups findings by root cause and classifies them as **critical** (blocks the pipeline) or **tech debt** (from gate analysis — magic numbers, raw colors, etc.). You pick what to fix, and it delegates to `/ralph-loop:spec` or `/ralph-loop:req-prd` to create the fix specs.

### Post-merge cleanup

```
/ralph-loop:cleanup my-feature     # archive specs to done/, delete spec branch
```

---

## Workspace isolation

Each feature runs in its own **git worktree** (`.worktrees/<slug>`) branched off the spec, keeping all in-progress changes isolated from the main working tree. The worktree is removed automatically after the post-loop gates pass.

The init skill writes a `PreToolUse` hook into `.claude/settings.json` that blocks any agent from reading or writing files outside the project directory.

---

## Gates

Gates are checks code must pass before it lands. They come from two places, and are
discovered automatically: the plugin's `scripts/gates/`, and your project's `ralph/gates/`.

### Static gates

Deterministic checks (grep, awk, lint, AST analysis). Fast-tier checks run every iteration; precise-tier checks run once post-loop.

```
scripts/gates/static/
├── code_quality/          # force unwraps, @Observable, stubs, access control, print(), etc.
├── architecture/          # layer boundaries, dependency direction, modelContext ownership
├── security/              # hardcoded secrets, insecure HTTP, NSLog, UserDefaults credentials
├── accessibility/         # missing labels, hardcoded fonts, color-only differentiation
└── code_quality/missing_tests.sh   # function added with no test change
```

`missing_tests` reads `TEST_DIR`, `TEST_FILE_PATTERN`, and `FUNCTION_DECL_PATTERN` from
`ralph/config.sh`, written by `init`. Leave any empty and the gate passes with a notice
rather than failing.

### LLM gates

Semantic checks that require LLM judgment — one Sonnet call per category, post-loop only.

```
scripts/gates/llm/
├── code_quality.md        # naming clarity, SRP, feature envy, error handling, test quality
├── architecture.md        # DI compliance, god objects, pattern consistency
├── security.md            # data sensitivity, auth flow correctness, input validation
├── accessibility.md       # label quality, nav order, custom component a11y
└── test_adequacy.md       # do added tests assert, and call the new behaviour?
```

The two test gates enforce test-exists-with-code, not test-first. The loop commits once
per iteration, so write ordering is not observable.

### Adding custom gates

Drop files into your project's `ralph/gates/` directory:

**Static gate** (`ralph/gates/static/<category>/my_check.sh`):
```bash
#!/bin/bash
set -euo pipefail

gate_name()     { echo "My custom check"; }
gate_category() { echo "org"; }
gate_tier()     { echo "fast"; }

gate_check() {
    BASE_REF=$(git merge-base "${DIFF_BASE_BRANCH:-main}" HEAD 2>/dev/null || echo "HEAD~1")
    # Your check logic — exit 0 = pass, exit 1 = fail
}
```

**LLM gate** (`ralph/gates/llm/compliance.md`):
```markdown
---
category: compliance
---

You are reviewing Swift code changes for [your criteria].

Respond with exactly:
1: PASS|FAIL — [reason]
OVERALL: PASS|FAIL
```

No pipeline changes needed. A project gate with the same filename as a plugin gate replaces it.

### Blast radius analysis

When an LLM gate flags an architectural issue, the pipeline measures the **blast radius** of the affected type before attempting a fix.

| Dimension | What it measures | Low (0) | Medium (1) | High (2) |
|-----------|-----------------|---------|------------|----------|
| File fan-out | Files referencing the type | <= 5 | 6-15 | > 15 |
| Type coupling | Distinct types that depend on it | <= 3 | 4-10 | > 10 |
| Layers crossed | Architectural layers (dirs) affected | 1 | 2 | >= 3 |
| Infra reach | Directories containing references | 1-2 | 3-4 | 5+ |
| Test coupling | Test files referencing the type | <= 1 | 2-3 | > 3 |

The composite score (0-10) determines the action:

- **Score 0-3 (auto)**: Escalate to Opus for a careful, contained fix
- **Score 4-6 (conditional)**: Escalate to Opus, but only if the change stays within one architectural layer — otherwise defer
- **Score 7-10 (defer)**: Create a GitHub issue labeled `tech-debt` with the gate feedback, blast radius report, and recommended refactoring approach. The gate passes — architectural improvements don't block feature delivery

Deferred issues are always saved to `ralph/deferred_issues.md` as a backup. Duplicate GitHub issues are detected via search before creation.

Every threshold is tunable in `ralph/gate_context.md` with keys named
`blast_radius_fanout_thresholds`, `..._coupling_...`, `..._layer_...`, `..._infra_...`,
`..._test_...`, plus `blast_radius_auto_max` and `blast_radius_conditional_max`.

Run it by hand with `blast_radius.sh <TypeName> <source-dir>`.

---

## Project-specific files

These live in your project's `ralph/` directory (not in the plugin):

| File | Created by | Purpose |
|---|---|---|
| `ralph/config.sh` | `/ralph-loop:init` | Build commands, paths, simulator |
| `ralph/AGENTS.md` | `loop.sh bootstrap` | Architecture and conventions |
| `ralph/specs/` | `/ralph-loop:spec`, `req-prd`, `req-slc` | Feature specifications |
| `ralph/specs/done/` | `/ralph-loop:cleanup` | Archived completed specs |
| `ralph/AUDIENCE_JTBD.md` | `/ralph-loop:req-slc` | Permanent audience context (spans releases) |
| `ralph/gates/` | `/ralph-loop:init` | Custom project gates |
| `ralph/gate_context.md` | Bootstrap / manual | Gate calibration and blast radius thresholds |
| `ralph/lessons.md` | `loop.sh` | Persistent lessons for hard problems |
| `ralph/deferred_issues.md` | `loop.sh` | Tech debt deferred by blast radius analysis |

---

## Requirements

- macOS with Xcode
- [Claude Code](https://claude.ai/code) with plugin support
- `python3` (ships with Xcode Command Line Tools)
- `gh` CLI (optional, for draft PR creation and tech debt issues)
