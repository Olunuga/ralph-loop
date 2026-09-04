## Why

A UI feature with a visual target has nowhere to put the target. Nothing in the skills, the prompts, or the `ralph-bridge` schema mentions images, and `PROMPT_build.md` reads the brief with text subagents, so an image file beside a spec is ignored. The build agent implements from prose alone.

## What Changes

- **Assets live beside the intent**, so archiving moves them with it:
  - Legacy: `ralph/specs/<name>/` becomes a directory holding `spec.md` plus `assets/`. A plain `ralph/specs/<name>.md` keeps working.
  - OpenSpec: `openspec/changes/<name>/assets/`.
- **The build agent reads them.** `PROMPT_build.md` gains a step that lists `assets/` under the brief and reads each image with the Read tool, which renders images to the model. Text subagents cannot do this, so the main agent does it.
- **The spec skills accept an asset.** `/ralph-loop:spec` asks whether a design reference exists, and writes what it is given into `assets/`.
- **Archiving moves the directory.** `bin/cleanup_specs.sh` moves a spec directory, not only a file, so assets are archived with the spec instead of being orphaned.
- **`RALPH_BRIEF_DIR` already points at the right place** in both modes, so `bin/loop.sh` needs no change.

Out of scope: comparing the built view against the reference. That needs a running simulator and a capture step. The agent reads the reference while implementing; verification stays with the existing snapshot and UI test path.

Not breaking. A spec with no `assets/` behaves exactly as today.

## Capabilities

### New Capabilities

- `design-reference-layout`: where assets live in each intent source, and how archiving moves them.
- `design-reference-reading`: how the build agent finds and reads the images, and what it does when it cannot.
- `design-reference-capture`: how the spec skills take a design reference from the user and place it.

### Modified Capabilities

None. `RALPH_BRIEF_DIR`, the gate engine, and the `ralph-bridge` artifact set are unchanged.

## Impact

**Modified:** `prompts/PROMPT_build.md`, `skills/spec/SKILL.md`, `skills/req-prd/SKILL.md`, `skills/req-slc/SKILL.md`, `bin/cleanup_specs.sh`, `schemas/ralph-bridge/schema.yaml`, `CLAUDE.md`, `README.md`

**Unchanged:** `bin/loop.sh`, both gate runners, every gate.

**Risk surface:** images cost context. A brief with many large references can crowd out the spec text, so the reading step needs a documented limit and a size warning.
