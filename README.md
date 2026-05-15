# ralph-loop

An autonomous development pipeline for iOS projects, powered by Claude Code. You describe a feature, the pipeline builds it — writing code, running tests, and enforcing quality gates in a git worktree, iteration by iteration.

Distributed as a **Claude Code plugin**.

## How it works

1. `/ralph-loop:spec` — structured JTBD conversation produces a spec committed to a `spec/<slug>` branch
2. `/ralph-loop:run` — orchestrates the pipeline: creates a worktree, plans the work, runs the build loop, gates the output
3. Build loop runs Claude (Haiku for iterations, Sonnet on escalation) autonomously: build → unit tests → static gates (code quality, architecture, security, accessibility) → lint → commit
4. Post-loop gates: precise static gates → LLM gates (semantic review with blast radius analysis) → UI tests → opens a draft PR via `gh` → worktree cleanup
5. You review the branch and merge

Human decisions: spec approval and branch review. Everything else is automated.

### Model usage

The Claude Code session you run `/ralph-loop:run` from acts as the **orchestrator** — it finds the spec, creates the worktree, and kicks off `loop.sh`. The build loop and post-loop gates run entirely inside `loop.sh` as a subprocess. The orchestrator monitors the output and only steps in when something goes wrong. Use a capable model for this session (Sonnet or Opus recommended).

The build loop spawns subagents for each iteration using **Haiku** by default — fast and cheap for the repetitive write-build-fix cycle.

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

### Post-merge cleanup

```
/ralph-loop:cleanup my-feature     # archive specs to done/, delete spec branch
```

A draft PR is opened automatically when all gates pass. Review the `ralph/my-feature` branch and mark it ready when satisfied.

---

## Workspace isolation

Each feature runs in its own **git worktree** (`.worktrees/<slug>`) branched off the spec, keeping all in-progress changes isolated from the main working tree. The worktree is removed automatically after the post-loop gates pass.

The init skill writes a `PreToolUse` hook into `.claude/settings.json` that blocks any agent from reading or writing files outside the project directory.

---

## Gates

The pipeline enforces quality through **gates** — checks that code must pass before it can be committed or merged. Gates come from two sources:

1. **Plugin gates** — default checks shipped with the plugin (`scripts/gates/`)
2. **Project gates** — custom checks in your project's `ralph/gates/` directory

Project gates override plugin gates with the same filename.

### Static gates

Deterministic checks (grep, awk, lint, AST analysis). Fast-tier checks run every iteration; precise-tier checks run once post-loop.

```
scripts/gates/static/
├── code_quality/          # force unwraps, @Observable, stubs, access control, print(), etc.
├── architecture/          # layer boundaries, dependency direction, modelContext ownership
├── security/              # hardcoded secrets, insecure HTTP, NSLog, UserDefaults credentials
└── accessibility/         # missing labels, hardcoded fonts, color-only differentiation
```

### LLM gates

Semantic checks that require LLM judgment — one Sonnet call per category, post-loop only.

```
scripts/gates/llm/
├── code_quality.md        # naming clarity, SRP, feature envy, error handling, test quality
├── architecture.md        # DI compliance, god objects, pattern consistency
├── security.md            # data sensitivity, auth flow correctness, input validation
└── accessibility.md       # label quality, nav order, custom component a11y
```

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
    BASE_REF=$(git merge-base main HEAD 2>/dev/null || echo "HEAD~1")
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

No changes to any pipeline code needed. The dispatchers auto-discover gates from both directories.

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

All thresholds are configurable per-project via `ralph/gate_context.md`:

```
blast_radius_fanout_thresholds: 5,15
blast_radius_coupling_thresholds: 3,10
blast_radius_layer_thresholds: 1,2
blast_radius_infra_thresholds: 2,4
blast_radius_test_thresholds: 1,3
blast_radius_auto_max: 3
blast_radius_conditional_max: 6
```

You can run the analysis manually:

```bash
blast_radius.sh WorkoutSession Geyns/
```

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
