## ADDED Requirements

### Requirement: Each confirmed cell becomes one OpenSpec change

For each cell in the confirmed slice, the skill SHALL create an OpenSpec change named `<activity>-<depth>` using the `ralph-bridge` schema, and seed it from that activity's spec content at that depth.

#### Scenario: Slice of three cells

- **WHEN** the user confirms a slice of three cells
- **THEN** three changes exist under `openspec/changes/`, one per cell, each on the `ralph-bridge` schema

#### Scenario: Change carries the cell's content

- **WHEN** a change is created for `<activity>-<depth>`
- **THEN** its proposal states the job, the activity, and the success criteria for that depth only, taken from the activity spec

#### Scenario: Deeper depths stay out

- **WHEN** an activity spec defines basic, enhanced, and advanced
- **THEN** a change for the basic cell contains no enhanced or advanced content

### Requirement: The skill never overwrites work in progress

The skill SHALL refuse to replace a change that already exists and has commits against it. It SHALL report the conflict and leave that change untouched, while continuing with the others.

#### Scenario: Change exists with commits

- **WHEN** a cell's change already exists and the branch has commits referencing it
- **THEN** the skill skips it, names it, and creates the remaining changes

#### Scenario: Change exists but is untouched

- **WHEN** a cell's change exists with no commits against it
- **THEN** the skill asks whether to replace it

### Requirement: Materialisation is reversible

The skill SHALL report every path it created, so an unwanted slice can be removed with a single named command.

#### Scenario: Slice was wrong

- **WHEN** materialisation completes
- **THEN** the output lists each created change directory and the release record, and gives the command that removes them
