## ADDED Requirements

### Requirement: The spec skills accept a design reference

`/ralph-loop:spec`, `/ralph-loop:req-prd`, and `/ralph-loop:req-slc` SHALL ask whether a design reference exists for a feature with a visual result. When the user supplies a path, the skill SHALL copy the file into the spec's `assets/` directory and commit it with the spec.

#### Scenario: User supplies a reference

- **WHEN** the user gives a path to an image during the spec conversation
- **THEN** the skill copies it into `ralph/specs/<name>/assets/`, writes the spec as `ralph/specs/<name>/spec.md`, and commits both

#### Scenario: No reference offered

- **WHEN** the user has no design reference
- **THEN** the skill writes the spec as a single file, exactly as it does today, and creates no empty directory

#### Scenario: Supplied path does not exist

- **WHEN** the given path names no file
- **THEN** the skill says so and asks again rather than writing a spec that references a missing asset

### Requirement: The spec text names the reference

When a spec has an asset, its text SHALL name each asset file and state what the reference shows. An image with no explanation is ambiguous about which part is the target.

#### Scenario: Spec cites its assets

- **WHEN** a spec has one or more assets
- **THEN** the spec text names each file and says what it shows

#### Scenario: Generated tasks cite the reference

- **WHEN** planning produces tasks for a spec that has assets
- **THEN** a task whose result is visual names the asset file it must match
