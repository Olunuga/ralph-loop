## ADDED Requirements

### Requirement: The gate judges whether added tests exercise the new behaviour

`scripts/gates/llm/test_adequacy.md` SHALL review the branch diff and report a defect when an added test does not exercise the behaviour the change introduces. It SHALL flag a test with no assertion, and a test that only constructs an object without calling the behaviour under test.

#### Scenario: Test has no assertion

- **WHEN** the diff adds a test function containing no assertion
- **THEN** the gate reports it and names the test

#### Scenario: Test exercises nothing

- **WHEN** an added test only constructs the type under test and never calls the new behaviour
- **THEN** the gate reports it

#### Scenario: Test covers the behaviour

- **WHEN** an added test calls the new behaviour and asserts on the result
- **THEN** the gate passes for that test

#### Scenario: Change adds no test and no behaviour

- **WHEN** the diff adds neither behaviour nor tests
- **THEN** the gate passes

### Requirement: The gate follows the existing LLM gate contract

The prompt SHALL carry `category: code_quality` in its frontmatter, and SHALL flag only concrete defects against its own numbered checklist, so retries do not invent new complaints.

#### Scenario: Retry stays on the same criteria

- **WHEN** the gate runs a second time on an unchanged diff
- **THEN** it reports the same defects and invents no new ones

#### Scenario: SKIP suppresses the gate

- **WHEN** `ralph/gate_context.md` contains `- test_adequacy: SKIP`
- **THEN** the gate does not run
