# Reference

[ralph-loop](../README.md) · Previous: [Design](design.md)

Where things live, and how work is kept isolated.

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

## Workspace isolation

Each feature runs in its own **git worktree** (`.worktrees/<slug>`) branched off the spec, keeping all in-progress changes isolated from the main working tree. The worktree is removed automatically after the post-loop gates pass.

The init skill writes a `PreToolUse` hook into `.claude/settings.json` that blocks any agent from reading or writing files outside the project directory.

---

---

[ralph-loop](../README.md) · Previous: [Design](design.md)
