## ADDED Requirements

### Requirement: Planned tasks keep tests with the behaviour they cover

The `tasks` artifact instruction in `schemas/ralph-bridge/schema.yaml` SHALL state that a task adding behaviour must carry its test in the same task or an immediately following subtask, and that a task must never leave the tree in a state the test gates reject.

#### Scenario: Generated task carries its test

- **WHEN** a task adds a function that the test gates cover
- **THEN** `tasks.md` includes the test work in that task or the next subtask

#### Scenario: Instruction names the rule

- **WHEN** `openspec instructions tasks --change <name> --json` runs with `ralph-bridge` active
- **THEN** the returned instruction states the test rule alongside the existing gate rule

#### Scenario: Refactor tasks need no test

- **WHEN** a task only renames, moves, or reformats code
- **THEN** no test subtask is required
