## Why

Claude Design turns a prompt into a prototype and packages the result as a handoff bundle: a tar archive holding the design, the components used, the design intent, and a README written for a coding agent. Nothing in the pipeline produces a prompt for it, and nothing reads its output. The `assets/` convention added for design references reads images only, so a handoff bundle placed there is ignored.

## What Changes

- **`req-slc` emits a design system prompt.** After the story map is approved, it writes `ralph/design/SYSTEM_PROMPT.md`, a prompt to paste into Claude Design that generates the product's base design system from the audiences, jobs, and activity set it just captured.
- **`slice` emits a screen prompt per cell.** Each materialised change gets `openspec/changes/<cell-id>/design/SCREEN_PROMPT.md`, a prompt that generates the screens for that activity at that depth. It cites the committed design system rather than restating it.
- **The build agent reads a handoff bundle.** `assets/` gains a second form: an unpacked Claude Design handoff. The agent reads its README first, because that README is instructions addressed to a coding agent, then the design files it names.
- **Bundles are unpacked, not committed as tar.** A tar in git is opaque to review and to the agent. The skills tell you to unpack into `assets/design/` and commit the contents.
- **The design system lives in the repo**, so Claude Design's GitHub import can pull it back in. Later screen prompts point at the repo path instead of restating the system, which keeps generated screens consistent with what was already built.

You place both outputs by hand. The pipeline writes the prompts and reads the results; it does not call Claude Design.

## Capabilities

### New Capabilities

- `design-system-prompt`: what `req-slc` writes, from which inputs, and where the handoff goes.
- `screen-prompt`: what `slice` writes per cell, and how it cites the design system.
- `handoff-bundle-reading`: how the build agent recognises and reads an unpacked handoff, and what it does with the bundle README.

### Modified Capabilities

None. The image path in `assets/` is unchanged; bundles are an additional form.

## Impact

**New:** `prompts/DESIGN_SYSTEM_PROMPT_TEMPLATE.md`, `prompts/SCREEN_PROMPT_TEMPLATE.md`

**Modified:** `skills/req-slc/SKILL.md`, `skills/slice/SKILL.md`, `prompts/PROMPT_build.md`, `README.md`, `CLAUDE.md`

**Unchanged:** `bin/loop.sh`, the gate engine, the `ralph-bridge` schema, the existing image reading path.

**Depends on** the design references work already on `main` for the `assets/` convention, and on the slice skill for the per-cell step.

**Risk surface:** a handoff bundle holds many files. Reading all of them would flood the iteration context, so the agent needs a bounded rule, as it already has for images.
