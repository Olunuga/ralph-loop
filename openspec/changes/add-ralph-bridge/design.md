## Context

Ralph-loop has a strong enforcement plane: the gate runners, 19 static gates, 4 LLM gates, blast radius routing, rollback-to-green, and a thin intent plane: one Markdown file per feature. OpenSpec is the reverse. This change joins them without forking either.

Constraints:

- **Existing ralph users must not break.** `config.sh`, `gate_context.md`, `gates/`, `.diff_base`, and `specs/*.md` keep working with no migration.
- **Enforcement must be deterministic.** A prompt-layer bridge can only suggest. Gates must hold regardless of who wrote the code.
- **The autonomous loop must stay autonomous.** Nothing that pauses for a human can sit inside it.
- **Verified against OpenSpec CLI 1.5.0.** A bundle is `schema.yaml` (`version: 1`, artifacts with `id`/`generates`/`template`/`instruction`/`requires`, plus `apply`) and a `templates/` directory. `openspec schema validate` and `openspec templates` check it.

## Goals / Non-Goals

**Goals**: make propose gate-aware; make both lanes gate-enforced, with no way to skip the gates silently; reuse `gate_context.md` as the one shared calibration file; let a human and the loop share one change through one ledger.

**Non-Goals**: no fork of OpenSpec; no separate schemas repo yet; no new loop; no change to gate definitions or the blast radius policy; no replacement of `ralph/specs/`.

## Decisions

### D1: Ship the bundle in the plugin, install by copy

`schemas/ralph-bridge/` lives here. `/ralph-loop:init --openspec` copies it into the project and sets it active.

One repo the user owns, one install path, no dependency on a registry that does not exist yet. A standalone schemas repo is correct eventually but adds a second install step and a second version to track for no benefit today. The copy is one `cp -R`, so extracting it later is cheap.

### D2: Gate awareness travels through the artifact instructions

The `design` and `tasks` instructions name `gate_context.md` and the gate directories as required reads, and state the rule: a task adding a gate-covered construct carries the gate-satisfying work with it.

The `instruction` field is the only hook OpenSpec gives a community schema, and it is the right one: `openspec instructions <artifact> --json` returns it verbatim to the model. A pre-processing script would need a hook that OpenSpec does not have.

This layer is soft. A model can ignore it. That is why D4 exists.

### D3: Judge on delta, not absolute

Apply captures a baseline before implementation, re-runs gates after, and judges `post − baseline`. `SKIP` entries remove a gate from the comparison entirely.

Absolute judgement makes every change in an imperfect codebase red, which trains everyone to ignore the gates. Delta judgement makes the change answerable for what it introduced. This matches the existing diff-scoping rule and the smart-rollback behaviour already in `loop.sh`.

`gate-report` is a separate artifact because it is evidence produced after implementation, so it cannot be a precondition of implementation. It is declared `requires: [tasks]` but left out of `apply.requires`, so it never blocks.

### D4: Git hooks enforce the gates for every author

`pre-commit` runs the `fast` static tier. `pre-push` runs the `precise` static tier and the LLM gates. Both installed by default.

The split follows cost against event frequency. The `fast` tier is deterministic and cheap, so it runs on every commit. The `precise` tier and the LLM gates are slower, so they run on push, which is rare and is the last point before the change becomes visible to others.

Putting `precise` on `pre-push` rather than `pre-commit` is what keeps it enforced at all. A commit-time `precise` run would compound latency across a working session, and dropping it entirely would leave `precise` gates enforced only inside `bin/loop.sh`: a human committing by hand would never see them.

Installed by default because a hook the user must remember to install enforces nothing. This is the one place the bridge diverges from `superpowers-bridge`, which operates only at the prompt layer. `--no-verify` stays as the documented escape, named in the hook's own failure output.

Both hooks exit 0 with a one-line notice whenever the gate engine cannot run, and block only on a real gate failure. A hook that errors on an unrelated repository gets deleted.

### D5: The Stop hook is opt-in and static-only

Stop fires after every turn. LLM gates there are an unbounded token cost. The fast static tier is cheap enough to run constantly and catches what matters in-session. Debounced LLM gates would need persisted state for a check `pre-push` already does.

### D6: Two independent executors, one ledger

`/ralph-loop:run` does not call `/opsx:apply`. It reads the same change through `openspec instructions apply --json` and drives its own loop, because `apply` pauses for a human and nesting it would end autonomy.

Coordination is the change's `tasks.md`. Both lanes read unchecked items and mark them only after gates pass.

`openspec instructions apply --change <name> --json` on CLI 1.5.0 returns `contextFiles` as absolute paths keyed by artifact id (`proposal`, `specs`, `design`, `tasks`), not inline content, plus a parsed `tasks` array of `{id, description, done}` and a `progress` object. The resolver reads the files itself and gets the task list without parsing checkboxes; it still writes checkbox state back to `tasks.md`.

### D7: Redirect the loop's two file slots, do not branch its logic

`bin/loop.sh` reads a brief and tracks a ledger. Both paths become environment variables: `RALPH_BRIEF_DIR` and `RALPH_PLAN_FILE`: each defaulting to today's value. In OpenSpec mode, run points them at the change's context files and `tasks.md`.

The loop then marks `tasks.md` directly, so the ledger is genuinely shared with no sync step and no drift window. Everything else runs unchanged.

The alternative: materialise the change into `ralph/specs/` and `IMPLEMENTATION_PLAN.md`, then sync checkboxes back: needs zero changes to `loop.sh` but creates two ledgers that diverge the moment an iteration rolls back mid-run. That reconciliation is exactly the class of bug this codebase already fights.

Consequence: `rollback_all` preserves `IMPLEMENTATION_PLAN*.md` by name. It must preserve `$RALPH_PLAN_FILE` instead, or checkboxes are lost on every rollback.

### D8: Resolution is by name, OpenSpec wins

Check `openspec/changes/<name>/` first, then `ralph/specs/<name>.md`. Both present means OpenSpec mode with a warning; neither means an error naming both paths.

An OpenSpec change is the richer, more recent artifact. A stale legacy file with the same name is the likelier accident. The warning makes the choice visible instead of silent.

### D9: Stamp the installed schema, check the stamp on use

The installed bundle records the plugin version that wrote it and the CLI version that validated it. `init --openspec` and `run` compare that stamp against the live plugin and `openspec --version`, and warn on drift.

Without this, the only validation happens once at setup. After `claude plugin update ralph-loop` the project's copy is silently old, and after `npm update -g openspec` the bundle may no longer validate, with the failure surfacing at the next propose rather than at upgrade time. The stamp lives inside the installed bundle so it travels with the copy rather than needing a separate registry.

`version: 1` in `schema.yaml` is the OpenSpec format version and cannot serve this purpose. The stamp is a distinct file.

Init also enforces a minimum CLI version, so an incompatible CLI fails loudly at setup.

### D10: The loop gates itself, the hooks gate commits made outside it

Two changes to `bin/loop.sh` are needed before the hooks are installed.

**Fix validation runs every static tier.** `bin/loop.sh:504` re-runs `fast` only after a gate fix, but post-loop Gate 1 runs `precise`. An LLM-gate fix can reintroduce a `precise` violation and reach the pull request unchecked. One gate is `precise` (`unused_imports.sh`), so the exposure is narrow until a project adds `precise` gates in `ralph/gates/static/`. Fix validation therefore runs every tier, and a final full sweep after all fixes land catches the wider case: any gate that passed early and was broken by a later fix.

**Loop commits pass `--no-verify`.** `loop.sh` commits at lines 521, 1149, and 1259 with plain `git commit`. With `pre-commit` installed, every loop fix commit re-runs the static suite the loop just ran, and lines 521 and 1259 end in `|| true`, so a blocked commit fails silently and the loop proceeds as if it committed. The loop is already inside the gate engine; the hooks are for humans and out-of-band commits. The `|| true` cases also need real error reporting, so no commit failure is discarded.

## Risks / Trade-offs

- **Gate-aware propose is soft.** → D4's hooks catch what slips through. Propose-time awareness is an efficiency measure, not a control.
- **`precise` feedback arrives at push, not at commit**, so a violation can sit through several commits. → Push is still ahead of review, and a project that wants it earlier can move the tier in `gate_context.md` without editing the hook.
- **LLM gates on push are non-deterministic and can block a valid push.** → `--no-verify` is named in the hook's own output, with the instruction to record an accepted pattern as a `SKIP` entry.
- **The installed schema drifts from the plugin.** → D9's stamp detects it and names the fix.
- **`RALPH_PLAN_FILE` touches `rollback_all`.** → The single highest-risk edit in the change. It needs an explicit rollback test.
- **The full sweep adds a static run to every pipeline.** → Static gates are cheap and deterministic. One extra pass buys certainty that the tree that opens the pull request is the tree that passed.
- **Git hooks are not version-controlled.** `.git/hooks/` is local, so a fresh clone has no enforcement until init runs. → Accepted here; a `core.hooksPath` variant is a follow-up.

## Migration Plan

Additive, no data migration. `/ralph-loop:init --openspec` is idempotent and serves every case.

1. **New project:** `npm i -g openspec`, install the plugin, run `/ralph-loop:init --openspec`.
2. **Existing ralph project:** `claude plugin update ralph-loop`, then the same command. It touches only new files; `config.sh`, `gates/`, `gate_context.md`, and `specs/` stay byte-identical. Existing calibration carries over and gains a second reader.
3. **Existing OpenSpec project:** the wiring installs the bundle and asks before changing the active schema.
4. **After any plugin update:** re-run the same command to refresh the installed bundle. D9's stamp warns when this is due.

**Rollback:** delete `openspec/schemas/ralph-bridge/`, restore the previous `schema:` value, remove the two files from `.git/hooks/`. Nothing under `ralph/` changes, and `/ralph-loop:run` falls back to legacy mode by resolution order.

## Open Questions

- Should `gate-report.md` write accepted violations back into `gate_context.md` automatically? Manual for this change; automation is a follow-up.
- Should `gate-report.md` feed the `ralph-bridge` schema's own propose step, so a project's accepted violations shape the next change's plan? Out of scope here; revisit after the bundle ships.
