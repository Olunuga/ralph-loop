## ADDED Requirements

### Requirement: Fix validation covers every static tier

After a gate fix, `bin/loop.sh` SHALL re-run every static tier that the post-loop sequence runs: `fast` and `precise`: before it commits the fix.

#### Scenario: Fix reintroduces a precise violation

- **WHEN** an LLM gate fix reintroduces a violation of a `precise`-tier gate
- **THEN** the fix validation fails, the loop reverts the fix, and the attempt counter advances

#### Scenario: Project adds a precise gate

- **WHEN** a project defines a new `precise` gate in `ralph/gates/static/`
- **THEN** that gate takes part in fix validation with no change to `bin/loop.sh`

### Requirement: A full sweep runs before the pull request

After all post-loop gate fixes land, and before the UI routing step, `bin/loop.sh` SHALL run the complete static suite once over the final tree. The pull request SHALL NOT open while that sweep fails.

#### Scenario: Late fix breaks an earlier gate

- **WHEN** a fix applied during the LLM gate stage violates a static gate that passed in the earlier static stage
- **THEN** the full sweep fails and the pipeline stops before opening the pull request

#### Scenario: Clean tree passes through

- **WHEN** the final tree violates no static gate
- **THEN** the sweep passes, is recorded in `progress.txt`, and the pipeline proceeds to UI routing

#### Scenario: Sweep result is visible

- **WHEN** the sweep runs
- **THEN** its verdict is written to `progress.txt` alongside the other post-loop gate results

### Requirement: Gate coverage is identical in both intent modes

The fix validation and the full sweep SHALL behave the same whether the loop runs from an OpenSpec change or from a legacy `ralph/specs/<name>.md`.

#### Scenario: Same coverage in both modes

- **WHEN** the same code change runs through OpenSpec mode and legacy mode
- **THEN** the same tiers run at the same points and produce the same verdict
