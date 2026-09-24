# Workflows

[ralph-loop](../README.md) · Next: [Gates](gates.md)

Every way to get from an idea to merged code.

---

## Starting out: a new project, or one that already exists

Setup differs most here. Everything after it is the same.

### A new project, nothing built yet

```
/ralph-loop:init --openspec
```

It asks how you want the code laid out, since there is nothing to copy from. Pick one, and
it creates the folders and records your choice. Then map the product and start:

```
/ralph-loop:req-slc my-product
/ralph-loop:slice                # builds the colours, type and groundwork first
/ralph-loop:run theme-foundation
```

The colours and type come before the first screen. The checks reject a raw colour value, so
a screen built first fails, and the agent invents its own colours instead.

### A project that already has code

```
/ralph-loop:doctor               # what is already broken, before you add to it
/ralph-loop:init --openspec      # keeps your existing layout, records where things live
```

`doctor` runs the build, the tests and every check, groups what it finds by cause, and
splits it into what blocks the pipeline and what is only untidy. You pick what to fix, and
it writes specs for those.

`init` does not propose a new layout for code that already has one. It records where your
files actually live so the checks know where to look.

Loose files with no folders, 20 or fewer, on a clean branch? It offers to move them. More
than that is a change of its own, planned and reviewed like any other.

Then carry on as normal, with `/ralph-loop:spec` for one feature or `/ralph-loop:req-slc`
for a whole product.

---

## Single feature (quick)

```
/ralph-loop:spec my-feature        # describe what to build, get a spec
/ralph-loop:run my-feature         # run the pipeline autonomously
```

## OpenSpec change (gate-aware planning)

Needs `/ralph-loop:init --openspec`. See Setup step 3.

```
/opsx:propose my-feature           # proposal, specs, design, tasks. Reads your gate definitions
/ralph-loop:run my-feature         # run the pipeline against the change
```

`propose` produces `openspec/changes/my-feature/`. Because it reads `ralph/gate_context.md`
and your gate scripts, the plan it writes does not propose work a gate rejects.

You can also build it yourself, or split the work:

```
/opsx:apply my-feature             # you implement, in your session, pausing on blockers
/ralph-loop:run my-feature         # hand the rest to the loop
```

Both mark the same `tasks.md`. Do the two tricky tasks with `apply`, then let `run` finish
the remaining unchecked ones. `run` never calls `apply`, because a command that pauses to
ask cannot sit inside an autonomous loop.

## Multi-topic PRD (multiple specs from one JTBD)

```
/ralph-loop:req-prd my-project     # decompose JTBD into topics, one spec per topic
/ralph-loop:run my-project         # pipeline plans across all specs
```

## SLC release (map the product, ship it in parts)

```
/ralph-loop:req-slc my-product   # once: map the product
/ralph-loop:slice                # per release: split it into changes
/ralph-loop:run <change>         # per change: build it
/ralph-loop:cleanup <change>     # per change: file it away once merged
/ralph-loop:status               # any time: what is done, what to do next
```

`req-slc` writes a table: columns are things people do, rows are how far each one goes. A
release takes one cell per column, so a person gets something they can finish rather than
one thing done deeply and the rest missing.

`slice` builds the shared groundwork first (colours and type, talking to a server, keeping
data), then one change per cell. Each change gets its own checks and its own pull request.

**[Full walkthrough: SLC releases](slc.md)** covers the map, the groundwork, how screens
arrive after the tasks, and filing changes away.

## Resuming an incomplete run

If the loop exits early (iteration budget exhausted, laptop slept, session ended), re-run the same command:

```
/ralph-loop:run my-feature         # detects existing commits, picks up remaining tasks
```

The pipeline detects prior `ralph:` commits on the branch, reconciles the plan (marks completed tasks), and continues from where it left off. No work is lost — committed code survives across runs.

## Baseline health check

```
/ralph-loop:doctor                 # diagnose build, test, and gate failures
```

Runs the full baseline: build, unit tests, static gates (fast + precise), and LLM gates. Groups findings by root cause and classifies them as **critical** (blocks the pipeline) or **tech debt** (from gate analysis — magic numbers, raw colors, etc.). You pick what to fix, and it delegates to `/ralph-loop:spec` or `/ralph-loop:req-prd` to create the fix specs.

## Post-merge cleanup

One command, either mode.

```
/ralph-loop:cleanup my-feature
```

It detects what the name refers to. An OpenSpec change is archived with `openspec archive`,
which moves it under `openspec/changes/archive/` and folds its deltas into `openspec/specs/`,
so the main specs stay the current picture of the system. A legacy spec moves to
`ralph/specs/done/` and its `spec/` branch is deleted. A spec directory with an `assets/`
folder moves as a unit, so design references archive with their spec.

Archiving is not optional on an SLC product. `/ralph-loop:status` and `/ralph-loop:slice
--status` both read `openspec/changes/archive/`, so a change that is built but never archived
reads as unfinished and its release never completes.

Run it from the project root on the branch the pull request merged into. Neither mode deletes
the `ralph/<name>` build branch; do that yourself once the pull request is closed.

---


---

[ralph-loop](../README.md) · Next: [Gates](gates.md)
