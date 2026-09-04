## Why

`/ralph-loop:req-slc` captures a full story map, and `PROMPT_plan_slc.md` already knows how to recommend a Simple, Lovable, Complete slice. But slicing only happens inside `/ralph-loop:run`, where it produces an `IMPLEMENTATION_PLAN.md` for one legacy build. There is no way to turn a slice into OpenSpec changes, so an SLC product cannot use gate-aware planning, `/opsx:apply`, or per-cell pull requests. Nothing records which changes made up a release.

## What Changes

- **`/ralph-loop:slice`**, a new skill. It reads `ralph/AUDIENCE_JTBD.md` and the activity specs, runs the existing gap analysis and SLC criteria, and proposes a slice. Nothing is written until you confirm.
- **One change per cell.** A slice picks one capability depth per activity, so each cell becomes its own OpenSpec change named `<activity>-<depth>`, for example `upload-photo-basic`. Each gets its own `tasks.md`, gates, and pull request.
- **The slice is a proposal.** The skill shows the recommended cells with the reason for each, and asks before writing. It refuses to overwrite a change that already has commits against it.
- **Release grouping** in `ralph/releases/<release>.md`: the release name, the cells it contains, their change names, and the status of each. `/ralph-loop:slice --status` reports where a release stands.
- **`req-slc` writes the story map as a table** in `AUDIENCE_JTBD.md`, so `slice` can read the cells rather than infer them from prose.

Out of scope: building the changes. `slice` produces intent; `/ralph-loop:run` and `/opsx:apply` build it, one change at a time.

Requires `/ralph-loop:init --openspec`, because the output is OpenSpec changes.

## Capabilities

### New Capabilities

- `slice-selection`: reading the story map, running gap analysis, proposing cells against SLC criteria, and requiring confirmation.
- `slice-materialization`: turning confirmed cells into one OpenSpec change each, with the activity spec content as the seed.
- `release-grouping`: recording which changes form a release, and reporting the release's status.

### Modified Capabilities

None. `req-slc` gains a table format; it drops nothing.

## Impact

**New:** `skills/slice/SKILL.md`, `prompts/PROMPT_slice.md`

**Modified:** `skills/req-slc/SKILL.md` (story map table), `README.md`, `CLAUDE.md`, `.claude-plugin/plugin.json` if skills are listed there

**Unchanged:** `bin/loop.sh`, `PROMPT_plan_slc.md`, the gate engine, the `ralph-bridge` schema. The legacy SLC path through `run` keeps working.

**Risk surface:** the skill creates several changes in one action. A wrong slice leaves unwanted change directories, so confirmation and a clean removal path both matter.
