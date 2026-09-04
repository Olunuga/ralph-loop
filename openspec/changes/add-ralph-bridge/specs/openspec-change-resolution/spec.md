## ADDED Requirements

### Requirement: run resolves the intent source by name

`/ralph-loop:run <name>` SHALL prefer an OpenSpec change named `<name>`, and fall back to `ralph/specs/<name>.md`. It SHALL report the chosen mode before the build loop starts.

#### Scenario: OpenSpec change exists

- **WHEN** `openspec/changes/<name>/` exists and is apply-ready
- **THEN** run selects OpenSpec mode and reports it

#### Scenario: Only a legacy spec exists

- **WHEN** no OpenSpec change carries the name but `ralph/specs/<name>.md` does
- **THEN** run selects legacy mode and behaves as it does today

#### Scenario: Both exist

- **WHEN** both sources carry the name
- **THEN** run selects OpenSpec mode and warns that the legacy spec is ignored

#### Scenario: Neither exists

- **WHEN** no source is found
- **THEN** run stops with an error naming both paths it checked

#### Scenario: Change is not apply-ready

- **WHEN** the change exists but `openspec status --change <name> --json` reports it is not apply-ready
- **THEN** run stops and names the missing artifacts

### Requirement: OpenSpec mode loads context files as the build brief

In OpenSpec mode, run SHALL call `openspec instructions apply --change <name> --json` and pass the returned context files to the build loop in the slot `ralph/specs/<name>.md` fills in legacy mode. Run SHALL NOT invoke `/opsx:apply`.

#### Scenario: Context reaches the build agent

- **WHEN** the build loop starts in OpenSpec mode
- **THEN** the build agent's brief contains the change's proposal, design, spec, and task content

#### Scenario: apply is never nested

- **WHEN** the autonomous loop runs in OpenSpec mode
- **THEN** no `/opsx:apply` invocation occurs, because apply pauses for a human and would end autonomy

#### Scenario: CLI call fails

- **WHEN** the call exits non-zero or returns unparseable JSON
- **THEN** run stops with the CLI error and does not start the build loop

### Requirement: tasks.md is the shared ledger

In OpenSpec mode, run SHALL treat unchecked `- [ ]` items in the change's `tasks.md` as its work list, and SHALL mark an item `- [x]` only after that task passes gates.

#### Scenario: Human did some tasks first

- **WHEN** a human checked some tasks through `/opsx:apply` and hands the change to run
- **THEN** run works only the unchecked tasks

#### Scenario: Failed task stays unchecked

- **WHEN** a task is implemented but its iteration fails gates and rolls back
- **THEN** the task stays `- [ ]`

#### Scenario: Checkbox state survives rollback

- **WHEN** an iteration rolls back
- **THEN** checkboxes for previously completed tasks are preserved, as the loop already protects `IMPLEMENTATION_PLAN.md`

#### Scenario: All tasks complete

- **WHEN** every item is `- [x]` and the final gate run is green
- **THEN** run opens the draft pull request as in legacy mode

### Requirement: Everything except the intent source is identical

Gate execution, blast radius routing, rollback-to-green, model escalation, and diagnostics SHALL be identical in both modes. Only the build brief and the task ledger change.

#### Scenario: Same gates, same verdict

- **WHEN** the same code change is produced in each mode
- **THEN** the same static and LLM gates run and produce the same verdict

#### Scenario: Same rollback behaviour

- **WHEN** a gate fails in OpenSpec mode
- **THEN** the loop performs the same smart rollback and diagnostician escalation as in legacy mode
