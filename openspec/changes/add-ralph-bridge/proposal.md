## Why

OpenSpec plans well but knows nothing about gates, so it proposes work the gate engine later rejects. Ralph-loop gates well but its intent layer is one Markdown file per feature. Join the two: OpenSpec owns intent, ralph owns enforcement, neither is forked.

## What Changes

- **`schemas/ralph-bridge/`**: an OpenSpec community schema shipped in this plugin. Artifacts: `proposal`, `specs`, `design`, `tasks`, and a new `gate-report`. Its propose instructions read `ralph/gate_context.md` so plans stay gate-clean. Its apply instructions judge on delta, not absolute: a change answers for the violations it introduces, not for the ones it inherited.
- **`hooks/`**: `pre-commit` runs the `fast` static tier. `pre-push` runs the `precise` static tier and the LLM gates. Both installed by default. They run for every author except the loop, which gates itself.
- **Opt-in Claude Stop hook**: fast static tier only, for in-session feedback. Never LLM, to bound token cost.
- **`/ralph-loop:init --openspec`**: one command, used for both first-time setup and upgrade. Installs the schema, seeds gate context, writes the git hooks. Without the flag, init is unchanged.
- **Version stamping**: the installed schema records which plugin version wrote it and which OpenSpec CLI validated it. Setup and run compare the stamp and warn when it drifts.
- **`/ralph-loop:run` intent resolver**: prefers an OpenSpec change of that name, falls back to `ralph/specs/<name>.md`. The change's `tasks.md` becomes the ledger both lanes share.
- **Two `bin/loop.sh` gate-integrity fixes.** Fix validation runs every static tier, not `fast` alone. A full static sweep runs before the pull request. Every loop commit passes `--no-verify`: the loop runs the gate engine directly, and the hooks exist for humans and out-of-band commits.

Not breaking. Every addition is opt-in or additive.

## Capabilities

### New Capabilities

- `ralph-bridge-schema`: the schema bundle: gate-aware propose, delta-judged apply, `gate-report` evidence.
- `gate-enforcement-hooks`: `pre-commit`, `pre-push`, the opt-in Stop hook, and the rule that the loop bypasses all three.
- `gate-run-integrity`: full-tier fix validation and a final static sweep before the pull request.
- `openspec-project-setup`: `/ralph-loop:init --openspec`: install, upgrade, and version-drift detection.
- `openspec-change-resolution`: the intent resolver and `tasks.md` as the shared ledger.

### Modified Capabilities

None. `openspec/specs/` is empty; this is the first change in the repo.

## Impact

**New:** `schemas/ralph-bridge/{schema.yaml,templates/}`, `hooks/{pre-commit,pre-push,stop_gate_check.sh}`

**Modified:** `skills/init/SKILL.md` (the `--openspec` branch), `skills/run/SKILL.md` (resolver), `bin/loop.sh` (brief and ledger slots, full sweep, `--no-verify`), `prompts/PROMPT_build.md`, `CLAUDE.md`, `README.md`

**Unchanged:** the gate engine, every gate definition, `ralph/config.sh`, the `gate_context.md` format, `ralph/gates/`, `.diff_base`

**Dependency:** OpenSpec CLI, on the `--openspec` path only. Verified against 1.5.0.

**Risk surface:** git hooks can block commits, so they must exit 0 whenever the gate engine is absent. LLM gates on push cost tokens and need a documented bypass. The `bin/loop.sh` edits touch `rollback_all`, the most delicate function in the file.
