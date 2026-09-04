## 1. Design system prompt

- [x] 1.1 Write `prompts/DESIGN_SYSTEM_PROMPT_TEMPLATE.md`: asks Claude Design for colour, typography, spacing, and core components, with placeholders for audiences, jobs, activities, and platform
- [x] 1.2 State in the template that screens are generated later per release, so the output is a system and not a set of screens
- [x] 1.3 Add a step to `skills/req-slc/SKILL.md` after story map approval that fills the template and writes `ralph/design/SYSTEM_PROMPT.md`
- [x] 1.4 Tell the user to paste it into Claude Design, unpack the handoff into `ralph/design/system/`, and commit the contents rather than the archive
- [x] 1.5 Verify against spec `design-system-prompt`: the prompt names the captured audiences, jobs, activities, and platform, and does not ask for screens

## 2. Screen prompt

- [x] 2.1 Write `prompts/SCREEN_PROMPT_TEMPLATE.md` with placeholders for the activity, the depth, that depth's success criteria, and the design system path
- [x] 2.2 Add a materialisation step to `skills/slice/SKILL.md` writing `openspec/changes/<cell-id>/design/SCREEN_PROMPT.md` per created change
- [x] 2.3 Scope each prompt to its own depth, excluding deeper depths from the same activity
- [x] 2.4 When `ralph/design/system/` exists, cite the repository and that path so Claude Design imports it; when absent, say so and point at the change's proposal
- [x] 2.5 Name `openspec/changes/<cell-id>/assets/design/` as the unpack target in the skill's Step 7 report
- [ ] 2.6 Verify against spec `screen-prompt`: three cells give three prompts, each scoped to its depth, and the design system citation switches on the directory's presence

## 3. Bundle reading

- [x] 3.1 Extend step 0d2 of `prompts/PROMPT_build.md` to recognise `$RALPH_BRIEF_DIR/assets/design/` as an unpacked handoff
- [x] 3.2 Read the bundle README first and follow what it names, because it is instructions addressed to a coding agent
- [x] 3.3 Fall back to the existing image rule when the bundle has no README, and say so
- [x] 3.4 State the per-iteration file cap for a bundle, and require the agent to name every bundle file it read
- [x] 3.5 Refuse to read a `.tar`, `.tar.gz`, or `.zip` under `assets/`: name it, say to unpack it, and continue from the text brief
- [ ] 3.6 Verify against spec `handoff-bundle-reading`: a README is read first, a bundle without one degrades to images, an archive is refused, and loose images alone behave as today

## 4. Documentation

- [x] 4.1 Add the Claude Design loop to `README.md`: `req-slc` emits the system prompt, you place the system, `slice` emits screen prompts citing it, you place the screens, the build agent reads them
- [x] 4.2 State in `README.md` that the transfer is manual in both directions, and that nothing verifies a built screen against its design
- [x] 4.3 Record in `CLAUDE.md` that the bundle README is read first because it is agent instructions, and that committing an archive is refused rather than unpacked
