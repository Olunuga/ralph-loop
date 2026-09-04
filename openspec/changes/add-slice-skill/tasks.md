## 1. Story map table

- [ ] 1.1 Change `skills/req-slc/SKILL.md` Step 6 so `AUDIENCE_JTBD.md` records the story map as a Markdown table with activities as columns and depths as rows
- [ ] 1.2 Give each cell a stable identifier of the form `<activity-slug>-<depth>` in the table, so `slice` can name changes from it
- [ ] 1.3 Verify against spec `slice-selection`: a generated `AUDIENCE_JTBD.md` yields an enumerable cell set

## 2. Slice recommendation

- [ ] 2.1 Write `prompts/PROMPT_slice.md` carrying the gap analysis and SLC criteria from `PROMPT_plan_slc.md` steps 3 and 4, with the output being a cell list rather than an implementation plan
- [ ] 2.2 Require a one-line reason per proposed cell, and a named dependency for every deferred one
- [ ] 2.3 Exclude cells the codebase already satisfies, and list them as already done
- [ ] 2.4 Verify against spec `slice-selection`: the proposal covers cells at different depths, excludes done cells, and defers cells with unsatisfied dependencies

## 3. The skill

- [ ] 3.1 Write `skills/slice/SKILL.md` with frontmatter matching the other skills, and `disable-model-invocation: true`
- [ ] 3.2 Stop with a named reason when `ralph/AUDIENCE_JTBD.md` is absent, when the OpenSpec CLI is missing, or when `ralph-bridge` is not the active schema
- [ ] 3.3 Run the recommendation and present the proposal with AskUserQuestion, letting the user approve, edit, or cancel
- [ ] 3.4 Verify against spec `slice-selection`: cancelling writes nothing, and an edited slice is what gets materialised

## 4. Materialisation

- [ ] 4.1 For each confirmed cell, run `openspec new change <activity>-<depth> --schema ralph-bridge`
- [ ] 4.2 Seed each change's proposal from that activity's spec at that depth only, excluding deeper depths
- [ ] 4.3 Skip a change that already exists and has commits against it; name it and continue with the rest
- [ ] 4.4 Ask before replacing a change that exists with no commits
- [ ] 4.5 Report every created path and the command that removes them
- [ ] 4.6 Verify against spec `slice-materialization`: three cells give three changes, deeper depths are absent, and a change with commits is skipped

## 5. Release grouping

- [ ] 5.1 Ask for the release name, then write `ralph/releases/<release>.md` listing each cell, its change name, and status `pending`
- [ ] 5.2 Leave earlier release records untouched when a new slice is materialised
- [ ] 5.3 Add `--status`: read the release records, derive each change's state from whether it exists, has commits, or is archived, and report per change
- [ ] 5.4 Report a release as complete only when every change in it is archived; say so plainly when no release exists yet
- [ ] 5.5 Exclude `ralph/releases/` from archiving in `bin/cleanup_specs.sh`, as `AUDIENCE_JTBD.md` already is
- [ ] 5.6 Verify against spec `release-grouping`: a record is written on confirmation, a part-done release is not called shippable, and cleanup leaves the records alone

## 6. Documentation

- [ ] 6.1 Add the SLC to OpenSpec flow to `README.md`: `req-slc` once, then `slice` per release, then `run` or `apply` per change, then archive and tag
- [ ] 6.2 State in `README.md` that a slice of N cells means N changes and N pull requests, and that the legacy `run` path remains for one plan per release
- [ ] 6.3 Record in `CLAUDE.md` that `PROMPT_slice.md` duplicates the criteria in `PROMPT_plan_slc.md`, and that extraction waits until the shape settles
