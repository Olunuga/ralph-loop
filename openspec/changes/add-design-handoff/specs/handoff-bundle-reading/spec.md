## ADDED Requirements

### Requirement: The build agent reads an unpacked handoff bundle

`prompts/PROMPT_build.md` SHALL recognise an unpacked Claude Design handoff under `$RALPH_BRIEF_DIR/assets/design/`. The agent SHALL read the bundle README first, because that README is instructions addressed to a coding agent, then the files it names.

#### Scenario: Bundle is present

- **WHEN** `assets/design/` exists and contains a README
- **THEN** the agent reads the README before any other file in the bundle, and follows what it says

#### Scenario: Bundle names specific files

- **WHEN** the README names design files to read
- **THEN** the agent reads those files rather than everything in the directory

#### Scenario: Bundle has no README

- **WHEN** `assets/design/` exists with no README
- **THEN** the agent reads the images in it under the existing image rule and says the bundle had no README

#### Scenario: Only images, no bundle

- **WHEN** `assets/` holds images and no `design/` directory
- **THEN** the existing image behaviour is unchanged

### Requirement: Bundle reading is bounded

The instruction SHALL cap how much of a bundle the agent reads in one iteration, and SHALL state the cap. The agent SHALL name every bundle file it read.

#### Scenario: Bundle is large

- **WHEN** the bundle holds more files than the cap
- **THEN** the agent reads the README plus the files the current task needs, and names what it skipped

#### Scenario: Agent reports what it used

- **WHEN** the agent reads any bundle file
- **THEN** it names each file, so the iteration output shows which design the implementation followed

### Requirement: An archive is not a bundle

A `.tar`, `.tar.gz`, or `.zip` file under `assets/` SHALL NOT be read. The agent SHALL name it and say it must be unpacked.

#### Scenario: Archive was committed by mistake

- **WHEN** `assets/` holds a tar or zip archive
- **THEN** the agent names it, says to unpack it into `assets/design/`, and continues from the text brief
