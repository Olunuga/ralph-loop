## ADDED Requirements

### Requirement: slice writes a screen prompt per materialised cell

For each change it creates, `/ralph-loop:slice` SHALL write `openspec/changes/<cell-id>/design/SCREEN_PROMPT.md`. The prompt SHALL name the activity, the capability depth, and that depth's success criteria, and SHALL ask for the screens that activity needs at that depth.

#### Scenario: One prompt per cell

- **WHEN** a slice of three cells is materialised
- **THEN** three screen prompts exist, one inside each change

#### Scenario: Prompt is scoped to the depth

- **WHEN** a prompt is written for a basic-depth cell
- **THEN** it asks only for the screens that depth needs, and does not describe deeper depths

#### Scenario: Prompt names the target location

- **WHEN** the skill reports what it created
- **THEN** it names `openspec/changes/<cell-id>/assets/design/` as the place to unpack the handoff

### Requirement: The screen prompt cites the design system

When `ralph/design/system/` exists, the screen prompt SHALL point Claude Design at it by repository path rather than restating the system, so generated screens match what is already built.

#### Scenario: Design system is present

- **WHEN** `ralph/design/system/` exists
- **THEN** the prompt names the repository and that path, and tells Claude Design to import it

#### Scenario: Design system is absent

- **WHEN** `ralph/design/system/` does not exist
- **THEN** the prompt says no system exists yet and asks Claude Design to work from the product context in the change's proposal
