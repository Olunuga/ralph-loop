## ADDED Requirements

### Requirement: The gate requires a test change when behaviour is added

`scripts/gates/static/code_quality/missing_tests.sh` SHALL fail when the branch diff adds a function to a non-test source file and adds or changes no file in the test directory. It SHALL be diff-scoped, checking added lines only, and SHALL name every source file that lacks a matching test change.

#### Scenario: New behaviour with no test

- **WHEN** the diff adds a function to a source file and touches no test file
- **THEN** the gate fails and names the source file

#### Scenario: New behaviour with a test

- **WHEN** the diff adds a function and also adds or changes a file in the test directory
- **THEN** the gate passes

#### Scenario: Change adds no behaviour

- **WHEN** the diff only renames, reformats, deletes, or edits comments
- **THEN** the gate passes

#### Scenario: Change touches only test files

- **WHEN** every added file is in the test directory
- **THEN** the gate passes

### Requirement: The gate reads the test location from config

The gate SHALL read `TEST_DIR` and `TEST_FILE_PATTERN` from `ralph/config.sh`. When either is unset, it SHALL pass with a one-line notice rather than fail, so a project without the keys is never blocked by a heuristic it did not configure.

#### Scenario: Config keys are absent

- **WHEN** `TEST_DIR` or `TEST_FILE_PATTERN` is not set
- **THEN** the gate prints a notice naming the missing key and passes

#### Scenario: Project uses a non-default test layout

- **WHEN** `TEST_DIR` names a directory and `TEST_FILE_PATTERN` names the file convention
- **THEN** the gate treats files matching that pattern under that directory as tests, whatever the language

#### Scenario: Init discovers the keys

- **WHEN** `/ralph-loop:init` runs in a project with a test target
- **THEN** it writes `TEST_DIR` and `TEST_FILE_PATTERN` to `ralph/config.sh`

### Requirement: The gate is a normal fast-tier gate

The gate SHALL export `gate_name`, `gate_category`, `gate_tier`, and `gate_check`, with category `code_quality` and tier `fast`. A `- missing_tests: SKIP` line in `ralph/gate_context.md` SHALL suppress it, and a project copy SHALL override the plugin copy.

#### Scenario: SKIP suppresses the gate

- **WHEN** `ralph/gate_context.md` contains `- missing_tests: SKIP`
- **THEN** the gate does not run

#### Scenario: The gate runs in the fast tier

- **WHEN** the `fast` static tier runs
- **THEN** `missing_tests` is among the gates executed, on both the pre-commit hook and the loop
