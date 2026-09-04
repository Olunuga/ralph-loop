## ADDED Requirements

### Requirement: OpenSpec wiring is opt-in behind a flag

`/ralph-loop:init` SHALL accept an `--openspec` flag. Without it, init behaves as it does today and creates no `openspec/` directory and no git hooks. With it, init performs the wiring after its existing steps.

#### Scenario: Init without the flag

- **WHEN** the user runs `/ralph-loop:init`
- **THEN** the project gains `ralph/` as today, and gains no `openspec/` directory and no git hooks

#### Scenario: Init with the flag

- **WHEN** the user runs `/ralph-loop:init --openspec`
- **THEN** init completes its existing steps and then performs the wiring

### Requirement: One command serves both setup and upgrade

`/ralph-loop:init --openspec` SHALL be idempotent and SHALL be the documented path for a first install and for an upgrade after `claude plugin update ralph-loop`. Re-running it SHALL refresh the installed schema without disturbing project configuration.

#### Scenario: Re-run refreshes the schema

- **WHEN** the user runs `/ralph-loop:init --openspec` on a project that already has the bundle
- **THEN** the bundle is replaced with the plugin's current copy, and no other file changes

#### Scenario: Upgrade preserves project configuration

- **WHEN** an existing ralph project runs `/ralph-loop:init --openspec`
- **THEN** `ralph/config.sh`, `ralph/gates/`, `ralph/gate_context.md`, and `ralph/specs/` are byte-identical to their state before the run

#### Scenario: Legacy specs still work after upgrade

- **WHEN** the upgrade completes and the user runs `/ralph-loop:run <name>` for an existing `ralph/specs/<name>.md`
- **THEN** the run proceeds against the legacy spec as before

### Requirement: Wiring installs the schema and makes it active

With `--openspec`, init SHALL confirm the OpenSpec CLI is present, run `openspec init` if `openspec/` is absent, copy the bundle into `openspec/schemas/ralph-bridge/`, set `schema: ralph-bridge` in `openspec/config.yaml`, and finish by running `openspec schema validate ralph-bridge`.

#### Scenario: CLI is missing

- **WHEN** `openspec` is not on PATH
- **THEN** init stops the wiring, prints `npm i -g openspec`, and leaves the rest of the ralph setup intact

#### Scenario: CLI is too old

- **WHEN** the installed CLI is below the bundle's minimum supported version
- **THEN** init stops the wiring and names both the installed version and the minimum required

#### Scenario: Project already uses OpenSpec

- **WHEN** `openspec/` exists with a different active schema
- **THEN** init installs the bundle, asks before changing the active schema, and does not modify existing changes or specs

#### Scenario: Validation fails

- **WHEN** `openspec schema validate ralph-bridge` exits non-zero after install
- **THEN** init reports the failure at setup time rather than leaving it to surface at the next propose

### Requirement: The installed schema carries a version stamp

The installed bundle SHALL record the plugin version that wrote it and the OpenSpec CLI version that validated it. The stamp SHALL live inside `openspec/schemas/ralph-bridge/`, so it travels with the copy.

#### Scenario: Stamp is written at install

- **WHEN** the wiring installs or refreshes the bundle
- **THEN** the stamp records the plugin version and the CLI version observed at that moment

#### Scenario: Bundle is stale against the plugin

- **WHEN** `/ralph-loop:init --openspec` or `/ralph-loop:run` finds a stamp naming an older plugin version than the installed plugin
- **THEN** the user is warned and told to re-run `/ralph-loop:init --openspec`

#### Scenario: CLI changed since validation

- **WHEN** the live `openspec --version` differs from the version in the stamp
- **THEN** the bundle is re-validated, and the user is warned if validation now fails

### Requirement: Wiring seeds gate context and installs the git hooks

With `--openspec`, init SHALL install `pre-commit` and `pre-push` into `.git/hooks/` as executables, and seed `ralph/gate_context.md` with a starter file that shows the `- <gate_name>: SKIP|ENFORCE` list-item format.

#### Scenario: Hooks are installed

- **WHEN** the wiring completes in a repository with no existing hooks
- **THEN** `.git/hooks/pre-commit` and `.git/hooks/pre-push` exist and are executable

#### Scenario: A foreign hook is already present

- **WHEN** `.git/hooks/pre-commit` exists and is not a ralph hook
- **THEN** init does not overwrite it, warns the user, and writes the template beside it for a manual merge

#### Scenario: gate_context.md already exists

- **WHEN** `ralph/gate_context.md` is present
- **THEN** init leaves it untouched and reports that existing calibration is preserved

#### Scenario: In-session feedback is offered, not assumed

- **WHEN** the wiring reaches the Stop hook step
- **THEN** init asks, and registers the hook only on an explicit yes

### Requirement: Setup output is committed

Init SHALL commit the new `openspec/` and `ralph/` files, so worktrees created by `/ralph-loop:run` contain them.

#### Scenario: Worktree inherits the pipeline

- **WHEN** the wiring completes and `/ralph-loop:run` creates a worktree
- **THEN** the worktree contains the schema, the gate context, and the ralph configuration
