## ADDED Requirements

### Requirement: Bundle is a valid OpenSpec community schema

The plugin SHALL ship `schemas/ralph-bridge/` containing `schema.yaml` and a `templates/` directory with one template per artifact. The installed OpenSpec CLI SHALL resolve and validate it.

#### Scenario: CLI accepts the bundle

- **WHEN** the bundle is installed and `openspec schema validate ralph-bridge` runs
- **THEN** the command exits 0, and `openspec schemas` lists `ralph-bridge`

#### Scenario: Every artifact resolves a template

- **WHEN** `openspec templates` runs with `ralph-bridge` active
- **THEN** every artifact id in `schema.yaml` maps to an existing file under `templates/`

### Requirement: Schema defines the bridge artifact set

The schema SHALL define `proposal`, `specs`, `design`, `tasks`, and `gate-report`. Dependencies: `specs` and `design` require `proposal`; `tasks` requires both; `gate-report` requires `tasks`. The `apply` block SHALL require `tasks` and track `tasks.md`.

#### Scenario: Build order matches the dependencies

- **WHEN** `openspec status --change <name> --json` runs on a new `ralph-bridge` change
- **THEN** `proposal` is `ready`, `specs` and `design` are blocked on `proposal`, `tasks` is blocked on both, and `applyRequires` is `[tasks]`

#### Scenario: gate-report never blocks implementation

- **WHEN** `tasks` is complete but `gate-report` is not
- **THEN** the change is apply-ready

### Requirement: Propose instructions are gate-aware

The `design` and `tasks` instructions SHALL name `ralph/gate_context.md`, `scripts/gates/static/`, and `ralph/gates/static/` as required reads. They SHALL state that a task adding a gate-covered construct must carry the gate-satisfying work in the same task or an adjacent subtask.

#### Scenario: Instructions carry the gate reads

- **WHEN** `openspec instructions design --change <name> --json` runs
- **THEN** the returned `instruction` names `ralph/gate_context.md` and the gate directories

#### Scenario: Generated tasks carry gate-satisfying work

- **WHEN** a task adds a UI element covered by an accessibility gate
- **THEN** `tasks.md` includes the accessibility work in that task or the next subtask

#### Scenario: Gate context is absent

- **WHEN** `ralph/gate_context.md` does not exist
- **THEN** the instructions tell the model to proceed from the gate definitions alone and record the absence under Open Questions in `design.md`

### Requirement: Apply judges on delta, not absolute

The `apply` instruction SHALL require a gate baseline before implementation, a static and LLM run after, and a verdict of `post − baseline`. A `- <gate_name>: SKIP` line in `ralph/gate_context.md` SHALL remove that gate from the comparison.

#### Scenario: Inherited violation does not fail the change

- **WHEN** a gate reports the same violation in the baseline and the post-implementation run
- **THEN** the change is green for that gate

#### Scenario: Introduced violation fails the change

- **WHEN** a gate reports a violation absent from the baseline
- **THEN** the change is red and the violation is listed in `gate-report.md`

#### Scenario: SKIP suppresses a gate

- **WHEN** `ralph/gate_context.md` contains `- <gate_name>: SKIP` for the failing gate
- **THEN** that gate is excluded from the verdict

### Requirement: gate-report records the evidence

`gate-report.md` SHALL record the baseline result, the post-implementation result, the delta verdict, the SKIP entries applied, and any deferred violation with its tracking reference.

#### Scenario: Report is written after implementation

- **WHEN** all tasks are complete and the post-implementation run finishes
- **THEN** `gate-report.md` exists with a baseline section, a post-implementation section, and a green or red verdict

#### Scenario: Deferred violation is traceable

- **WHEN** a violation is deferred as tech debt instead of fixed
- **THEN** `gate-report.md` names the gate, the reason, and the issue reference
