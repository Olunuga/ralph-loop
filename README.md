# ralph-loop

An autonomous development pipeline for iOS projects, powered by Claude Code. You describe a feature, the pipeline builds it — writing code, running tests, and enforcing quality gates in a git worktree, iteration by iteration.

## How it works

1. `/spec` — structured JTBD conversation produces a spec committed to a `spec/<slug>` branch
2. `/ralph` — orchestrates the pipeline: creates a worktree, plans the work, runs the build loop, gates the output
3. Build loop runs Claude (Haiku for iterations, Sonnet on escalation) autonomously: build → unit tests → static gates (code quality, architecture, security, accessibility) → lint → commit
4. Post-loop gates: precise static gates → LLM gates (semantic review) → UI tests → opens a draft PR via `gh` (fails gracefully if `gh` is not installed) → worktree cleanup
5. You review the branch and merge

Human decisions: spec approval and branch review. Everything else is automated.

### Model usage

The Claude Code session you run `/ralph` from acts as the **orchestrator** — it finds the spec, creates the worktree, and kicks off `loop.sh`. The build loop and post-loop gates run entirely inside `loop.sh` as a subprocess. The orchestrator monitors the output and only steps in when something goes wrong (e.g. worktree not cleaned up, loop exits with an error). Use a capable model for this session (Sonnet or Opus recommended).

The build loop spawns subagents for each iteration using **Haiku** by default — fast and cheap for the repetitive write-build-fix cycle.

---

## Setup

### 1. Install skills

```bash
npx skills add Olunuga/ralph-loop
```

Installs `/ralph-init`, `/ralph-install`, `/ralph-update`, `/spec`, and `/ralph` into Claude Code globally.

### 2. Install pipeline into your project

Open a Claude Code session in your project root, then run:

```
/ralph-install
```

This pulls ralph-loop into `ralph/` automatically. Pass a tag or branch to pin a version:

```
/ralph-install v1.2.0
```

Or copy the directory manually if you prefer.

### 3. Run setup

Open Claude Code in the project root:

```
/ralph-init
```

This auto-discovers your Xcode scheme, simulator, and test targets, then writes `ralph/config.sh`, `.claude/settings.json`, and generates `ralph/AGENTS.md` via bootstrap.

---

## Daily workflow

```
/spec my-feature        # describe what to build, get a spec
/ralph my-feature       # run the pipeline autonomously
```

A draft PR is opened automatically when all gates pass. Review the `ralph/my-feature` branch and mark it ready when satisfied.

---

## Updating ralph-loop in a project

Open a Claude Code session in your project root and run:

```
/ralph-update
```

The skill fetches available tags and branches from the repo, shows your current version, and asks you to choose. It then shows a diff of what changed and asks for confirmation before copying anything.

If you already know the version, pass it upfront to skip the selection step:

```
/ralph-update v1.2.0
/ralph-update some-branch
```

Only generic pipeline files are updated. `config.sh`, `AGENTS.md`, and `specs/` are never touched.

---

## Workspace isolation

Each feature runs in its own **git worktree** (`.worktrees/<slug>`) branched off the spec, keeping all in-progress changes isolated from the main working tree. The worktree is removed automatically after the post-loop gates pass.

`/ralph-init` also writes a `PreToolUse` hook into `.claude/settings.json` that blocks any agent from reading or writing files outside the project directory. This prevents the build agent from accidentally touching files elsewhere on your machine.

It also pre-approves a set of read-only commands (git status, git diff, git log, find, ls, etc.) so the orchestrator can run without prompting you for every command. These are in the `permissions.allow` array in `.claude/settings.json`.

**To tighten permissions** — remove entries from `permissions.allow` in `.claude/settings.json`. You will be prompted to approve those commands manually each time they run.

**To disable the workspace boundary hook entirely** — remove the `hooks` block from `.claude/settings.json`. Not recommended for autonomous runs.

> **Future improvement:** for stronger sandboxing, running the build loop inside a Docker container (with the worktree mounted as a volume) would fully isolate filesystem and network access from the host. Contributions welcome.

---

## Gates

The pipeline enforces quality through **gates** — checks that code must pass before it can be committed or merged. Gates are organized into categories (code quality, architecture, security, accessibility) and come in two types:

### Static gates (`scripts/gates/static/`)

Deterministic checks (grep, awk, lint, AST analysis) that run automatically. Fast-tier checks run every iteration; precise-tier checks run once post-loop.

```
scripts/gates/static/
├── code_quality/          # force unwraps, @Observable, stubs, access control, print(), etc.
├── architecture/          # layer boundaries, dependency direction, modelContext ownership
├── security/              # hardcoded secrets, insecure HTTP, NSLog, UserDefaults credentials
├── accessibility/         # missing labels, hardcoded fonts, color-only differentiation
└── org/                   # org-specific checks (optional)
```

### LLM gates (`scripts/gates/llm/`)

Semantic checks that require LLM judgment — things static analysis can't catch. One Sonnet call per category, post-loop only.

```
scripts/gates/llm/
├── code_quality.md        # naming clarity, SRP, feature envy, error handling, test quality
├── architecture.md        # DI compliance, god objects, pattern consistency
├── security.md            # data sensitivity, auth flow correctness, input validation
└── accessibility.md       # label quality, nav order, custom component a11y
```

### Creating a new static gate check

Drop a `.sh` file into the appropriate `scripts/gates/static/<category>/` directory. Each script must export 4 functions:

```bash
#!/bin/bash
set -euo pipefail

gate_name()     { echo "My check name"; }
gate_category() { echo "code_quality"; }   # code_quality | architecture | security | accessibility
gate_tier()     { echo "fast"; }           # fast (per-iteration) | precise (post-loop only)

gate_check() {
    # Your check logic here.
    # $SOURCE_DIR and $LAYER_MAP are available from config.sh.
    # Use git diff to check only new/changed lines.
    # Exit 0 = pass. Exit 1 = fail. Print details + offending filenames to stdout.

    BASE_REF=$(git merge-base main HEAD 2>/dev/null || echo "HEAD~1")
    HITS=$(git diff "$BASE_REF"..HEAD -- "${SOURCE_DIR:-.}/" \
        | grep '^+' | grep -v '^+++' \
        | grep 'your_pattern' || true)

    [[ -z "$HITS" ]] && return 0
    echo "Found violations:"
    echo "$HITS"
    return 1
}
```

No changes to `loop.sh` or any other file required. The dispatcher discovers checks by scanning the directory.

### Blast radius analysis

When an LLM gate flags an architectural issue, the pipeline measures the **blast radius** of the affected type before attempting a fix. This prevents invasive multi-file refactors from breaking the build.

The analysis (`scripts/blast_radius.sh`) measures four dimensions:

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

Deferred issues are always saved to `ralph/deferred_issues.md` as a backup (in case `gh` is unavailable). Duplicate GitHub issues are detected via search before creation.

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
bash ralph/scripts/blast_radius.sh WorkoutSession Geyns/
```

Based on Robert C. Martin's coupling metrics, Google's Large-Scale Change sharding practice, and Michael Feathers' seam analysis from *Working Effectively with Legacy Code*.

### Creating a new LLM gate check

Drop a `.md` file into `scripts/gates/llm/`. Use this format:

```markdown
---
category: security
---

You are reviewing Swift code changes for [description].

[Structured questions — only things static analysis cannot catch]

Respond with exactly:
1: PASS|FAIL — [reason]
...
OVERALL: PASS|FAIL
[One sentence summary]
```

### Adding a new gate category

To add an entirely new category (e.g., `performance`):

1. Create `scripts/gates/static/performance/` with `.sh` check files
2. Optionally create `scripts/gates/llm/performance.md`
3. No changes to the loop or dispatchers needed

---

## Project-specific files (not in this repo)

These are generated per-project and live in your project's `ralph/` directory:

| File | Generated by | Purpose |
|---|---|---|
| `ralph/config.sh` | `/ralph-init` | Build commands, paths, simulator |
| `ralph/AGENTS.md` | `loop.sh bootstrap` | Architecture and conventions |
| `ralph/specs/` | `/spec` | Feature specifications |
| `ralph/lessons.md` | Manual | Persistent lessons for hard problems (loaded when agent struggles) |
| `ralph/gate_context.md` | Manual | Project-specific calibration for LLM gate prompts |

---

## Requirements

- macOS with Xcode
- [Claude Code](https://claude.ai/code) (`npm install -g @anthropic-ai/claude-code`)
- `python3` (ships with Xcode Command Line Tools — used for path resolution and JSON parsing in hooks)
- `gh` CLI (for draft PR creation)
