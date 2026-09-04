## ADDED Requirements

### Requirement: req-slc writes a design system prompt

After the story map is approved, `/ralph-loop:req-slc` SHALL write `ralph/design/SYSTEM_PROMPT.md`. The prompt SHALL be ready to paste into Claude Design, and SHALL carry the audiences, the jobs to be done, the full activity set, and the platform, all taken from what the skill just captured.

#### Scenario: Prompt is written with the specs

- **WHEN** the user approves the story map
- **THEN** `ralph/design/SYSTEM_PROMPT.md` exists and names the audiences, the jobs, the activities, and the platform

#### Scenario: Prompt asks for a system, not screens

- **WHEN** the prompt is read
- **THEN** it asks for the base design system, meaning colour, typography, spacing, and core components, and states that screens come later per release

#### Scenario: User is told what to do with it

- **WHEN** the skill finishes
- **THEN** it tells the user to paste the prompt into Claude Design, and where to put the result

### Requirement: The design system handoff has a known home

The handoff from Claude Design SHALL be unpacked into `ralph/design/system/` and committed. The skill SHALL state this location and SHALL NOT create the directory until content exists.

#### Scenario: Location is stated

- **WHEN** the skill reports the prompt
- **THEN** it names `ralph/design/system/` as the place to unpack the handoff

#### Scenario: Tar is not committed

- **WHEN** the skill explains the handoff step
- **THEN** it says to unpack the archive and commit its contents, not the archive itself

#### Scenario: No handoff yet

- **WHEN** no design system has been placed
- **THEN** nothing fails: the prompt stands alone and `ralph/design/system/` does not exist
