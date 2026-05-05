# ralph-loop

An autonomous development pipeline for iOS projects, powered by Claude Code. You describe what to build, the pipeline builds it — writing code, running tests, and enforcing architecture guardrails in a git worktree, iteration by iteration.

## How it works

1. **Requirements** — choose the right skill based on your context (see table below), run an interview, get specs committed to a `spec/<slug>` branch
2. `/ralph` — orchestrates the pipeline: creates a worktree, plans the work, runs the build loop, gates the output
3. Build loop runs Claude (Haiku for iterations, Sonnet for gates) autonomously: build → unit tests → force-unwrap check → architecture check → lint → commit
4. Post-loop gates: LLM consensus judge → UI tests → opens a draft PR via `gh` (fails gracefully if `gh` is not installed) → worktree cleanup
5. You review the branch and merge

Human decisions: spec approval and branch review. Everything else is automated.

### Which requirements skill to use

| Skill | When to use | Output |
|---|---|---|
| `/spec` | Single scoped feature on an existing codebase | One `specs/<slug>.md` |
| `/req-prd` | Larger-scoped JTBD spanning multiple topics of concern | Multiple `specs/<topic>.md` |
| `/req-slc` | Full product planning with SLC release boundaries | `AUDIENCE_JTBD.md` + multiple `specs/<activity>.md` |

**`/req-slc`** follows the JTBD → Story Map → SLC approach: it captures the full activity space (all activities × all capability depths), and the planning prompt recommends the narrowest Simple/Lovable/Complete slice to build first. Re-run `/ralph` after each release — the planner picks the next slice from what's still unbuilt.

`/ralph` detects which mode to use automatically from the branch contents:
- 1 spec file → scoped `plan-work`
- multiple specs + `AUDIENCE_JTBD.md` → SLC-aware `plan-slc`
- multiple specs, no `AUDIENCE_JTBD.md` → full gap analysis `plan`

### Model usage

The Claude Code session you run `/ralph` from acts as the **orchestrator** — it finds the spec, creates the worktree, and kicks off `loop.sh`. The build loop and post-loop gates run entirely inside `loop.sh` as a subprocess. The orchestrator monitors the output and only steps in when something goes wrong (e.g. worktree not cleaned up, loop exits with an error). Use a capable model for this session (Sonnet or Opus recommended).

The build loop spawns subagents for each iteration using **Haiku** by default — fast and cheap for the repetitive write-build-fix cycle.

---

## Setup

### 1. Install skills

```bash
npx skills add Olunuga/ralph-loop
```

Installs `/ralph-init`, `/ralph-install`, `/ralph-update`, `/spec`, `/req-prd`, `/req-slc`, and `/ralph` into Claude Code globally.

### 2. Install pipeline into your project

Open a Claude Code session in your project root, then run:

```
/ralph-install
```

This pulls ralph-loop into `ralph/` automatically. Pass a tag or branch to pin a version:

```
/ralph-install 0.0.2
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

### Single feature (existing codebase)

```
/spec my-feature                        # interview → one spec
/ralph my-feature                       # plan → build → gates → draft PR
# after merging:
bash ralph/scripts/cleanup_specs.sh     # archive completed spec
```

### Multi-topic JTBD

```
/req-prd my-feature                     # interview → multiple specs by topic of concern
/ralph my-feature                       # full gap analysis → build → gates → draft PR
# after merging:
bash ralph/scripts/cleanup_specs.sh     # archive completed specs
```

### Full product with SLC releases

```
/req-slc my-app                         # interview → AUDIENCE_JTBD.md + all activity specs
/ralph my-app                           # SLC plan → build first slice → gates → draft PR
# after merging release 1:
bash ralph/scripts/cleanup_specs.sh     # archive completed specs (AUDIENCE_JTBD.md kept)
/ralph my-app                           # planner picks next SLC slice automatically
```

A draft PR is opened automatically when all gates pass. Review the `ralph/<slug>` branch and mark it ready when satisfied.

---

## Spec cleanup

After merging a PR, run:

```bash
bash ralph/scripts/cleanup_specs.sh
```

This moves completed specs (referenced in `IMPLEMENTATION_PLAN.md`) to `ralph/specs/done/`, keeping the active specs directory lean for future loop iterations. `AUDIENCE_JTBD.md` is never archived — it spans releases.

---

## Updating ralph-loop in a project

Open a Claude Code session in your project root and run:

```
/ralph-update
```

The skill fetches available tags and branches from the repo, shows your current version, and asks you to choose. It then shows a diff of what changed and asks for confirmation before copying anything.

If you already know the version, pass it upfront to skip the selection step:

```
/ralph-update 0.0.2
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

## Project-specific files (not in this repo)

These are generated per-project and live in your project's `ralph/` directory:

| File | Generated by |
|---|---|
| `ralph/config.sh` | `/ralph-init` |
| `ralph/AGENTS.md` | `loop.sh bootstrap` |
| `ralph/AUDIENCE_JTBD.md` | `/req-slc` |
| `ralph/specs/` | `/spec`, `/req-prd`, or `/req-slc` |
| `ralph/specs/done/` | `cleanup_specs.sh` |

---

## Requirements

- macOS with Xcode
- [Claude Code](https://claude.ai/code) (`npm install -g @anthropic-ai/claude-code`)
- `gh` CLI (for draft PR creation)
