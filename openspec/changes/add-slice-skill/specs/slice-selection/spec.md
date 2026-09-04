## ADDED Requirements

### Requirement: The skill reads the story map and proposes cells

`/ralph-loop:slice` SHALL read `ralph/AUDIENCE_JTBD.md` and the activity specs in `ralph/specs/`, determine the status of each activity at each capability depth against the codebase, and propose the cells that form the next Simple, Lovable, Complete release. It SHALL name each proposed cell as `<activity>-<depth>` and give the reason it is in the slice.

#### Scenario: Story map exists

- **WHEN** `ralph/AUDIENCE_JTBD.md` holds a story map and the user runs the skill
- **THEN** it proposes a set of cells, each named `<activity>-<depth>` with a one-line reason

#### Scenario: Slice cuts across depths

- **WHEN** one activity needs a deeper capability than the others to be worth shipping
- **THEN** the proposal contains cells at different depths, and says why that cell is deeper

#### Scenario: Cell is already done

- **WHEN** the codebase already satisfies a cell
- **THEN** the skill excludes it from the proposal and lists it as already done

#### Scenario: Dependency is unsatisfied

- **WHEN** a candidate cell depends on a cell that is neither done nor in the proposal
- **THEN** the skill defers it and names the dependency

### Requirement: The skill refuses to run without the required inputs

The skill SHALL stop with a named reason when `ralph/AUDIENCE_JTBD.md` is absent, when the OpenSpec CLI is not installed, or when `ralph-bridge` is not the active schema.

#### Scenario: No story map

- **WHEN** `ralph/AUDIENCE_JTBD.md` does not exist
- **THEN** the skill stops and tells the user to run `/ralph-loop:req-slc` first

#### Scenario: OpenSpec is not wired

- **WHEN** the OpenSpec CLI is missing or `ralph-bridge` is not active
- **THEN** the skill stops and tells the user to run `/ralph-loop:init --openspec`

### Requirement: Nothing is written until the user confirms

The skill SHALL present the proposed slice and wait for approval before it creates any change. The user SHALL be able to remove a cell from the proposal, add a deferred one, or cancel.

#### Scenario: User approves

- **WHEN** the user approves the proposal
- **THEN** the skill creates the changes and writes the release record

#### Scenario: User cancels

- **WHEN** the user cancels
- **THEN** no change directory and no release record is created

#### Scenario: User edits the slice

- **WHEN** the user removes or adds a cell before approving
- **THEN** the skill materialises the edited set, not its own recommendation
