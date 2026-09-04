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

See **OpenSpec change** under Workflows for how to use it.

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

---

## Documentation

Read in this order, or jump to what you need.

| | |
|---|---|
| **[Workflows](docs/workflows.md)** | Every way to get from an idea to merged code: single feature, OpenSpec change, PRD, SLC release, resume, doctor, cleanup |
| **[Gates](docs/gates.md)** | The 20 static and 5 LLM checks, writing your own, and blast radius analysis |
| **[Design](docs/design.md)** | Design references for the build agent, and the Claude Design handoff loop |
| **[Reference](docs/reference.md)** | Project files, workspace isolation, migrating from a file-copy install |

---

## Requirements

- macOS with Xcode
- [Claude Code](https://claude.ai/code) with plugin support
- `python3` (ships with Xcode Command Line Tools)
- `gh` CLI (optional, for draft PR creation and tech debt issues)
