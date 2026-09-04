## ADDED Requirements

### Requirement: pre-commit runs the fast static tier

`hooks/pre-commit` SHALL run the `fast` static tier and block the commit on failure. It SHALL NOT run the `precise` tier or any LLM gate. Output SHALL name each failing gate and its offending files.

#### Scenario: Violating commit is blocked

- **WHEN** the staged change introduces a `fast`-tier violation and the author commits
- **THEN** the hook exits non-zero and names the failing gates and files

#### Scenario: Precise violation does not block the commit

- **WHEN** the staged change introduces a `precise`-tier violation only
- **THEN** the commit lands, and `pre-push` catches the violation

#### Scenario: Clean commit lands

- **WHEN** the staged change introduces no `fast`-tier violation
- **THEN** the hook exits 0

### Requirement: pre-push runs the precise static tier and the LLM gates

`hooks/pre-push` SHALL run the `precise` static tier and then the LLM gates against the branch diff, and block the push on failure. It SHALL run the static tier first, so a cheap deterministic failure stops the push before any model call.

#### Scenario: LLM gate blocks the push

- **WHEN** an LLM gate flags a defect on the branch and the author pushes
- **THEN** the hook exits non-zero and names the gate and the defect

#### Scenario: Precise violation blocks the push before any model call

- **WHEN** the branch carries a `precise`-tier violation
- **THEN** the hook exits non-zero and no LLM gate runs

### Requirement: Both hooks document their bypass

On failure, each hook SHALL state that `--no-verify` bypasses the check and that an accepted pattern belongs in `ralph/gate_context.md` as a `SKIP` entry.

#### Scenario: Author bypasses deliberately

- **WHEN** the author runs `git commit --no-verify` or `git push --no-verify`
- **THEN** the hook does not run and the operation proceeds

#### Scenario: Failure output teaches the escape

- **WHEN** either hook blocks
- **THEN** the output names `--no-verify` and the `SKIP` entry format

### Requirement: Hooks degrade safely when the pipeline is absent

Both hooks SHALL exit 0 with a one-line notice when the gate engine cannot run: no `ralph/` directory, no `ralph/config.sh`, or no locatable gate runner. A missing pipeline SHALL NOT block a commit or push.

#### Scenario: Repository has no ralph pipeline

- **WHEN** a hook runs in a repository with no `ralph/` directory
- **THEN** it prints a one-line notice and exits 0

#### Scenario: Gate runner cannot be located

- **WHEN** `ralph/config.sh` exists but the gate runner is missing
- **THEN** the hook warns, names the missing script, and exits 0

### Requirement: Hooks resolve the same configuration as the loop

Both hooks SHALL resolve `PROJECT_ROOT` and `RALPH_PLUGIN_DIR` as `bin/loop.sh` does, source `ralph/config.sh`, and honour `ralph/.diff_base`. A hook and the loop SHALL produce the same verdict for the same tree.

#### Scenario: Non-main base branch

- **WHEN** `ralph/.diff_base` names a branch other than `main`
- **THEN** the hook diffs against that branch and does not flag changes inherited from it

#### Scenario: Project gate overrides the plugin gate

- **WHEN** a gate of the same name exists in `scripts/gates/static/` and `ralph/gates/static/`
- **THEN** the hook runs the project copy only, matching the loop's deduplication rule

### Requirement: The loop bypasses the hooks

Every commit made by `bin/loop.sh` SHALL pass `--no-verify`. The loop runs the gate engine directly, so a hook on its commits repeats work already done and can block the loop on a check it is part-way through satisfying. The hooks exist for humans and for commits made outside the loop.

#### Scenario: Loop commits are not gated twice

- **WHEN** the loop commits a gate fix while `pre-commit` is installed
- **THEN** the hook does not run, and the static suite executes once per iteration rather than twice

#### Scenario: Hook cannot stall the loop

- **WHEN** `pre-commit` would fail on a tree the loop is part-way through fixing
- **THEN** the loop's commit still lands, and the loop's own gate run decides the outcome

#### Scenario: No silent commit failure

- **WHEN** any `bin/loop.sh` commit fails for any reason
- **THEN** the failure is reported rather than discarded by `|| true`

### Requirement: Stop hook is opt-in and static only

The Stop hook SHALL run the `fast` static tier, SHALL NOT run LLM gates, and SHALL NOT be registered without an explicit request during setup.

#### Scenario: Not registered by default

- **WHEN** setup completes without an explicit request for in-session feedback
- **THEN** `.claude/settings.json` has no Stop hook entry for the gate check

#### Scenario: Registered hook reports and costs nothing

- **WHEN** the Stop hook runs after a turn that leaves a fast-tier violation
- **THEN** it names the failing gate and files, and makes no model call
