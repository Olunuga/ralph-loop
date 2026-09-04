## Context

`req-slc` captures a story map and writes `ralph/AUDIENCE_JTBD.md` plus one activity spec per activity, each defining basic, enhanced, and advanced depths. `PROMPT_plan_slc.md` steps 3 and 4 already do gap analysis and apply SLC criteria to recommend a slice.

That recommendation runs only inside `/ralph-loop:run`, and its output is an `IMPLEMENTATION_PLAN.md` for one legacy build. So an SLC product cannot use gate-aware planning, `/opsx:apply`, or per-cell pull requests, and nothing records which changes formed a release.

Constraints:

- **The legacy SLC path must keep working.** `run` with `plan-slc` is the current behaviour for projects that have not wired OpenSpec.
- **Slicing is a judgement call.** Gap analysis is mechanical, but which cells make a lovable release is not, so the user has to confirm.
- **Creating several changes at once is hard to undo.** A wrong slice leaves directories behind.

## Goals / Non-Goals

**Goals:** propose a slice from the story map; turn confirmed cells into OpenSpec changes; record which changes form a release and report its status.

**Non-Goals:** building the changes; replacing `plan-slc`; automating the slice choice; tagging or releasing.

## Decisions

### D1: One change per cell, named `<activity>-<depth>`

A cell is an activity at one capability depth. `upload-photo-basic` and `upload-photo-enhanced` are separate changes, shipped in different releases.

The alternative was one change per activity, scoped to whichever depth the slice picked. It gives shorter names, but the next release needs a second change with the same activity name, so the two are indistinguishable in `openspec/changes/` and in the archive. Putting the depth in the name keeps every change unambiguous for the life of the product.

The cost is more changes and more pull requests. That is also the benefit: each cell gets its own gates and its own reviewable diff.

### D2: The slice is a proposal, and nothing is written before approval

The skill shows the cells and the reason for each, and the user can remove a cell, add a deferred one, or cancel.

Slicing today happens at planning time, so it can be re-decided every run. Materialising it into committed changes fixes the decision. Requiring confirmation is what keeps a reversible decision from silently becoming an irreversible one.

The skill also refuses to replace a change that already has commits against it. It reports the conflict and continues with the rest, so a partly built release can gain a cell without losing work.

### D3: Reuse the existing recommendation logic

`PROMPT_slice.md` carries the gap analysis and SLC criteria from `PROMPT_plan_slc.md` steps 3 and 4. The logic is the same question, so it should give the same answer whichever command asks it.

`PROMPT_plan_slc.md` is not changed. The two prompts will drift, which is the cost of not extracting a shared file. Extraction is worth doing once the second consumer proves the shape is stable, not before.

### D4: The story map becomes a table in `AUDIENCE_JTBD.md`

`req-slc` currently records activities and depths as prose. The skill needs to enumerate cells, and parsing prose to find them is unreliable.

A Markdown table with activities as columns and depths as rows is readable by a person and unambiguous to parse. `req-slc` gains the table; it drops nothing.

### D5: Release records live in `ralph/releases/` and are never archived

One file per release, listing the cells, their change names, and status. `--status` reads them and calls a release shippable only when every change in it is archived.

They sit beside `AUDIENCE_JTBD.md` in being excluded from archiving, because they describe history across releases. Putting them inside a change would archive them with that change, which loses the grouping exactly when it becomes history worth keeping.

Status is derived, not stored: the skill reads whether each change exists, has commits, or is archived. A stored status would need updating on every merge, and would go stale.

## Risks / Trade-offs

- **A wrong slice leaves several change directories.** → Confirmation before writing, and the output names every created path plus the command that removes them.
- **`PROMPT_slice.md` and `PROMPT_plan_slc.md` will drift.** → Accepted. Extract a shared file when the shape settles.
- **More changes means more pull requests.** → That is the point of per-cell gates. A user who wants one pull request per release can use the legacy `run` path.
- **Derived status can misread a change.** → It reports what it observed per change rather than a single verdict, so a wrong reading is visible.

## Migration Plan

Additive. `req-slc` and the legacy `run` path are unchanged for existing projects.

1. `claude plugin update ralph-loop` brings the skill.
2. An existing `AUDIENCE_JTBD.md` without a table still works: the skill reports that it cannot enumerate cells and asks the user to re-run `req-slc` or add the table by hand.
3. New products get the table from `req-slc`.

**Rollback:** delete `skills/slice/`. Release records are inert without it.

## Open Questions

- Should `--status` also report the pull request state for each change? It would need `gh` and a branch naming convention. Left out until the flow has been used.
