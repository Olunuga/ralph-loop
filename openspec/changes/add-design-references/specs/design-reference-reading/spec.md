## ADDED Requirements

### Requirement: The build agent reads design references directly

`prompts/PROMPT_build.md` SHALL instruct the agent to list `$RALPH_BRIEF_DIR/assets/` and read each image with the Read tool before it implements a task. The agent SHALL do this itself rather than delegating to a text subagent, because a subagent returns text and cannot pass an image back.

#### Scenario: Brief has design references

- **WHEN** the brief directory contains an `assets/` directory with images
- **THEN** the agent reads each image before implementing, and the images are in its context

#### Scenario: Brief has no assets directory

- **WHEN** no `assets/` directory exists
- **THEN** the agent proceeds with the text brief and reports nothing

#### Scenario: Asset is not a readable image

- **WHEN** `assets/` contains a file the Read tool cannot render, such as a `.sketch` or `.fig`
- **THEN** the agent names the file, states that it cannot read it, and continues with the text brief

### Requirement: Reading is bounded

The instruction SHALL cap how many images the agent reads in one iteration and SHALL state the cap. When `assets/` holds more images than the cap, the agent SHALL read the ones the current task names, and report which it skipped.

#### Scenario: More assets than the cap

- **WHEN** `assets/` holds more images than the cap
- **THEN** the agent reads the images the current task references, and names the ones it skipped

#### Scenario: Agent reports what it used

- **WHEN** the agent reads one or more references
- **THEN** it names each file it read, so the iteration output shows which reference the implementation followed
