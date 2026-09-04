# Workflows

[ralph-loop](../README.md) · Next: [Gates](gates.md)

Every way to get from an idea to merged code.

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

## SLC release planning (incremental delivery)

```
/ralph-loop:req-slc my-product     # capture audience, JTBDs, activities at all depths
/ralph-loop:run my-product         # auto-detects SLC mode, recommends thin slice
```

SLC mode captures the **full activity space** upfront, then ships a narrow part of it.

`req-slc` builds a story map. Activities are the columns, capability depths are the rows.
For a photo palette app with one JTBD, "extract a photo's colors so I can reuse them":

| Depth | Upload photo | Extract colors | Save palette |
|---|---|---|---|
| **Basic** | single file | top 5 dominant | save to device |
| **Enhanced** | bulk upload | adjustable count, hex codes | name and tag palettes |
| **Advanced** | batch plus URL import | perceptual clustering | sync, export ASE |

A **Simple, Lovable, Complete** slice takes one cell per column, cutting vertically so the
user gets a complete outcome rather than one activity done deeply and the rest missing.
Here that is basic, basic, basic. The other six cells stay visible as backlog.

The row does not have to be level. If extraction needs adjustable counts to be worth
shipping, the slice is basic, **enhanced**, basic.

`ralph/AUDIENCE_JTBD.md` holds the table and is never archived, so later releases pick
deeper cells with no re-interview.

**With OpenSpec**, a slice becomes one change per cell, so each cell gets its own gates and
its own pull request.

```
/ralph-loop:req-slc my-product     # once per product, builds the table
/ralph-loop:slice                  # per release, proposes a slice, you confirm
                                   #   writes openspec/changes/upload-photo-basic/
                                   #          openspec/changes/extract-colors-basic/
                                   #          openspec/changes/save-palette-basic/
/ralph-loop:run upload-photo-basic # per change, or /opsx:apply for the tricky ones
/opsx:archive upload-photo-basic   # per change, once merged
/ralph-loop:slice --status         # is the release shippable yet?
```

A slice of three cells means three changes and three pull requests. `ralph/releases/<name>.md`
records which changes form the release, and `--status` calls it complete only when every one
is archived. Then tag it.

The legacy path stays: `/ralph-loop:run my-product` slices at planning time and builds the
whole release as one plan, with one pull request.

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

Use the command that matches where the intent came from.

```
/ralph-loop:cleanup my-feature     # legacy spec: move to ralph/specs/done/, delete spec branch
/opsx:archive my-feature           # OpenSpec change: fold deltas into openspec/specs/, archive the change
```

`/opsx:archive` also updates your main specs, so `openspec/specs/` stays the current
picture of the system. `/ralph-loop:cleanup` only moves files. A spec directory with an
`assets/` folder moves as a unit, so design references archive with their spec.

---


---

[ralph-loop](../README.md) · Next: [Gates](gates.md)
