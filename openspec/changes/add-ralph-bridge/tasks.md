## 1. Schema bundle skeleton

- [x] 1.1 Create `schemas/ralph-bridge/` with `schema.yaml` (`name: ralph-bridge`, `version: 1`, description) and a `templates/` directory
- [x] 1.2 Declare the five artifacts with the dependency graph: `proposal` (no deps), `specs` and `design` (require `proposal`), `tasks` (requires both), `gate-report` (requires `tasks`)
- [x] 1.3 Declare `apply` with `requires: [tasks]` and `tracks: tasks.md`, leaving `gate-report` out so it never blocks implementation
- [x] 1.4 Seed `templates/` from the installed `spec-driven` templates
- [x] 1.5 Verify: install into a scratch project, then `openspec schemas`, `openspec schema validate ralph-bridge`, and `openspec templates` all succeed

## 2. Gate-aware instructions and gate-report

- [x] 2.1 Write the `design` instruction so it names `ralph/gate_context.md`, `scripts/gates/static/`, and `ralph/gates/static/` as required reads
- [x] 2.2 Write the `tasks` instruction with the rule that a task adding a gate-covered construct carries the gate-satisfying work with it; keep the `- [ ] X.Y` format the apply phase parses
- [x] 2.3 Add the missing-gate-context fallback to both: proceed from the gate definitions alone, record the absence under Open Questions
- [x] 2.4 Write the `apply` instruction with the three steps: baseline, post-implementation static plus LLM, `post − baseline` verdict, and the rule that `- <gate_name>: SKIP` removes a gate from the comparison
- [x] 2.5 Add the `gate-report` artifact and `templates/gate-report.md` with baseline, post-implementation, delta, applied SKIPs, and deferred violations with references
- [x] 2.6 Carry this repo's prose rules from `openspec/config.yaml` into the bundle's artifact instructions, so every project that installs `ralph-bridge` gets them without editing its own config
- [x] 2.7 Verify against spec `ralph-bridge-schema`: run a throwaway change end to end, confirm the dependency graph in `openspec status --json` and the gate reads in `openspec instructions design --json`

## 3. Version stamping

- [x] 3.1 Define the stamp file inside the bundle, recording the plugin version that wrote it and the CLI version that validated it
- [x] 3.2 Add a minimum supported OpenSpec CLI version to the bundle and have init refuse to wire below it, naming both versions
- [x] 3.3 Write the stamp on every install and refresh
- [x] 3.4 Add the drift check: warn when the stamp names an older plugin version than the installed plugin, and tell the user to re-run `/ralph-loop:init --openspec`
- [x] 3.5 Re-validate the bundle when the live `openspec --version` differs from the stamp, and warn if validation now fails
- [x] 3.6 Call the drift check from both `/ralph-loop:init --openspec` and `/ralph-loop:run`
- [x] 3.7 Verify against spec `openspec-project-setup`: install, bump the plugin version, confirm the stale warning; change the CLI version, confirm re-validation

## 4. Gate-run integrity in `bin/loop.sh`

- [x] 4.1 Change the fix validation at `bin/loop.sh:504` to run every static tier the post-loop sequence runs: `fast` and `precise`, not `fast` alone
- [x] 4.2 Add a full static sweep after all post-loop gate fixes land and before UI routing; stop the pipeline before the pull request when it fails
- [x] 4.3 Record the sweep verdict in `progress.txt` alongside the other post-loop results
- [x] 4.4 Add `--no-verify` to every `git commit` in `bin/loop.sh` (lines 521, 1149, 1259)
- [x] 4.5 Replace the `|| true` on the commits at lines 521 and 1259 with real error reporting, so no commit failure is discarded
- [x] 4.6 Verify against spec `gate-run-integrity`: a fix that reintroduces a `precise` violation is reverted; a late fix that breaks an earlier static gate stops the pipeline before the pull request
- [x] 4.7 Verify a project-defined `precise` gate in `ralph/gates/static/` takes part in fix validation with no further change to `bin/loop.sh`

## 5. Git hooks and the Stop hook

- [x] 5.1 Write `hooks/pre-commit`: resolve `PROJECT_ROOT` and `RALPH_PLUGIN_DIR` as `bin/loop.sh` does, source `ralph/config.sh`, honour `ralph/.diff_base`, run the `fast` static tier, exit non-zero on failure
- [x] 5.2 Add safe degradation to `pre-commit`: exit 0 with a one-line notice when `ralph/`, `ralph/config.sh`, or the gate runner is missing
- [x] 5.3 Let `ralph/gate_context.md` override which tier each hook runs, keeping the shipped defaults: `fast` on `pre-commit`, `precise` on `pre-push`
- [x] 5.4 Write `hooks/pre-push` with the same resolution and degradation, running the `precise` static tier first and the LLM gates second, so a deterministic failure stops the push before any model call
- [x] 5.5 Make both hooks print, on failure, each failing gate with its files plus the `--no-verify` bypass and the `SKIP` entry format
- [x] 5.6 Write `hooks/stop_gate_check.sh` running the `fast` static tier only, with no LLM gate and no model call
- [x] 5.7a Fix the dedup scan order in `scripts/run_static_gates.sh` and `scripts/run_llm_gates.sh`: scan the project directory before the plugin, so a project gate overrides the plugin gate as `CLAUDE.md` documents
- [x] 5.7 Verify against spec `gate-enforcement-hooks`: violating commit blocked, clean commit lands, `--no-verify` bypasses, no-`ralph/` repo exits 0, non-`main` `.diff_base` does not flag inherited changes, project gate shadows the plugin gate
- [ ] 5.8 Verify the loop and the hooks do not collide: with `pre-commit` installed, a full `/ralph-loop:run` completes and the static suite runs once per iteration, not twice

## 6. `/ralph-loop:run` OpenSpec mode

- [x] 6.1 Confirm whether `openspec instructions apply --change <name> --json` returns context file paths or inline content; record the answer in `design.md` Open Questions
- [x] 6.2 Add `RALPH_BRIEF_DIR` and `RALPH_PLAN_FILE` to `bin/loop.sh`, defaulting to `$PROJECT_ROOT/ralph/specs` and `IMPLEMENTATION_PLAN.md`, and route both file slots through them
- [x] 6.3 Change `rollback_all` to preserve `$RALPH_PLAN_FILE` instead of the hardcoded `IMPLEMENTATION_PLAN*.md` glob, keeping the multi-spec split files working
- [x] 6.4 Update `prompts/PROMPT_build.md` to read the brief from `RALPH_BRIEF_DIR` rather than the literal `ralph/specs/*`
- [x] 6.5 Add the resolver to `skills/run/SKILL.md`: prefer the OpenSpec change, fall back to the legacy spec, report the mode, warn when both exist, error naming both paths when neither does, stop when the change is not apply-ready
- [x] 6.6 In OpenSpec mode, load the context files as the brief and set `RALPH_PLAN_FILE` to the change's `tasks.md`; stop with the CLI error on a failed or unparseable call
- [x] 6.7 Verify no `/opsx:apply` invocation exists in the run path
- [x] 6.8 Verify against spec `openspec-change-resolution`: only unchecked tasks are worked, a rolled-back task stays `- [ ]`, checkbox state survives rollback, all-green opens the draft pull request
- [x] 6.9 Verify gate parity: the same change through both modes runs the same gates at the same points with the same verdict

## 7. `/ralph-loop:init --openspec`

- [x] 7.1 Add `--openspec` flag parsing to `skills/init/SKILL.md`; without it, no `openspec/` directory and no git hooks
- [x] 7.2 Add the CLI precondition: if `openspec` is absent, stop the wiring, print `npm i -g openspec`, leave the rest of setup intact
- [x] 7.3 Run `openspec init` when `openspec/` is absent, copy the bundle into `openspec/schemas/ralph-bridge/`, set `schema: ralph-bridge`
- [x] 7.4 Make the wiring idempotent so a re-run refreshes the bundle and changes nothing else
- [x] 7.5 Handle the existing-OpenSpec case: install the bundle, ask before changing an active schema that is not `ralph-bridge`, modify no existing changes or specs
- [x] 7.6 Seed `ralph/gate_context.md` with the `- <gate_name>: SKIP|ENFORCE` starter; leave an existing file untouched and say so
- [x] 7.7 Install both git hooks into `.git/hooks/` as executables; when a foreign hook exists, warn and write the template beside it instead of overwriting
- [x] 7.8 Ask whether to register the Stop hook and register it only on an explicit yes
- [x] 7.9 Run `openspec schema validate ralph-bridge` as the final step and report a failure at setup time
- [x] 7.10 Commit the new `openspec/` and `ralph/` files so worktrees include them
- [x] 7.11 Verify the upgrade path: on an existing ralph project, `config.sh`, `gates/`, `gate_context.md`, and `specs/` are byte-identical after the run, and a legacy `/ralph-loop:run <name>` still works

## 8. Documentation

- [x] 8.1 Add a bridge section to `CLAUDE.md`: the `schemas/` and `hooks/` directories, the two-lane workflow, and the `RALPH_BRIEF_DIR` / `RALPH_PLAN_FILE` slots
- [x] 8.2 Record in `CLAUDE.md` Operational Knowledge that `/ralph-loop:init --openspec` is both the setup and the upgrade command, and that the loop bypasses the hooks by design
- [x] 8.3 Add both setup paths to `README.md`, including the `--no-verify` bypass and how to record an accepted pattern as a `SKIP` entry
- [x] 8.4 Delete `ralph-bridge-DESIGN.md` from the repo root; this change supersedes it
