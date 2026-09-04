## 1. Layout and archiving

- [x] 1.1 Update `bin/cleanup_specs.sh` to archive `ralph/specs/<name>/` as a directory when one exists, keeping the existing single-file path
- [x] 1.2 Report a spec that is neither a file nor a directory as not found, and continue with the rest
- [x] 1.3 Verify against spec `design-reference-layout`: a directory spec archives with its assets, a single-file spec archives as before, and a missing spec is reported

## 2. Build agent reading

- [x] 2.1 Add a step to `prompts/PROMPT_build.md` that lists `$RALPH_BRIEF_DIR/assets/` and reads each image with the Read tool in the main agent, not a subagent
- [x] 2.2 State the per-iteration image cap, and the rule that above the cap the agent reads the images the current task names
- [x] 2.3 Require the agent to name every asset file it read, so the iteration output shows which reference was followed
- [x] 2.4 Handle a file the Read tool cannot render: name it, say it cannot be read, continue from the text brief
- [ ] 2.5 Verify against spec `design-reference-reading`: images present are read, no `assets/` directory is silent, and an unreadable file does not stop the iteration

## 3. Spec capture

- [x] 3.1 Add a design reference question to `skills/spec/SKILL.md` for features with a visual result
- [x] 3.2 On a supplied path, write the spec as `ralph/specs/<name>/spec.md`, copy the file into `assets/`, and commit both
- [x] 3.3 With no reference, keep writing a single-file spec and create no empty directory
- [x] 3.4 Reject a path that names no file, and ask again
- [x] 3.5 Warn when an asset exceeds a size threshold, and let the user proceed
- [x] 3.6 Require the spec text to name each asset and say what it shows
- [x] 3.7 Apply the same capture steps to `skills/req-prd/SKILL.md` and `skills/req-slc/SKILL.md`
- [ ] 3.8 Verify against spec `design-reference-capture`: a supplied reference lands in `assets/` and is committed, no reference leaves a single-file spec, and a bad path is rejected

## 4. Planning

- [x] 4.1 Extend the `tasks` instruction in `schemas/ralph-bridge/schema.yaml` so a task with a visual result names the asset file it must match
- [x] 4.2 Make the same change in `prompts/PROMPT_plan_work.md` so legacy planning matches
- [x] 4.3 Verify against spec `design-reference-capture`: generated tasks cite the asset file

## 5. Documentation

- [x] 5.1 Document the two asset locations and the single-file fallback in `README.md`
- [x] 5.2 Record in `CLAUDE.md` that assets are read by the main agent because subagents return text, and that nothing verifies the built view against the reference
