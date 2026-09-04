## Context

The pipeline runs `UNIT_TEST_CMD` every iteration and rolls back on failure, so it protects existing tests. It does not require new ones. All 23 gates cover code quality, architecture, security, and accessibility; none looks at tests. Nothing in the prompts, the skills, or the `ralph-bridge` schema mentions testing. A task can add a feature, pass everything, and ship untested.

Constraints:

- **The plugin is language-agnostic.** Test conventions differ per project, so the gate cannot hardcode Swift or any other language.
- **Gates must be diff-scoped.** A gate that scans whole files flags pre-existing gaps and gets skipped.
- **A false failure is worse than a missed one.** A gate that blocks valid work gets a permanent `SKIP` entry and then protects nothing.

## Goals / Non-Goals

**Goals:** require a test change when a change adds behaviour; judge whether the added tests exercise that behaviour; keep test work in the same task as the code it covers.

**Non-Goals:** strict TDD; a coverage percentage threshold; changes to `bin/loop.sh`; changes to any existing gate.

## Decisions

### D1: Enforce test-exists-with-code, not test-first

The loop commits once per iteration, so the order of writes inside an iteration is not observable. Any check for test-first would have to inspect the agent transcript, which is not available to a gate. The enforceable property is that behaviour and its test land together.

### D2: Two gates, one deterministic and one semantic

`missing_tests.sh` answers "did a test file change?" That is cheap, deterministic, and catches the common case of a feature with no test at all. It cannot tell a real test from an empty stub.

`test_adequacy.md` answers "does the test exercise the new behaviour?" That needs judgement, so it is an LLM gate. Running it alone would be expensive and would miss the cheap case. Running the static one alone would accept an assertion-free stub.

The pairing matches the tier split already in use: the static gate is `fast` and runs on every commit, the LLM gate runs on push and in post-loop gates.

### D3: The test location comes from config, and an unset key means pass

`TEST_DIR` and `TEST_FILE_PATTERN` go in `ralph/config.sh`, discovered by `init` the same way `UNIT_TEST_TARGET` already is. A heuristic that guesses the test layout will be wrong somewhere, and a wrong guess produces false failures.

When either key is unset the gate passes with a notice. Failing closed would block every project that upgrades the plugin before re-running `init`, which is the situation most projects will be in on the day this ships.

### D4: "Adds behaviour" means an added function in a non-test file

The static gate looks for an added line that declares a function in a file outside `TEST_DIR`. Detecting semantic behaviour change is not possible without parsing, and parsing is not language-agnostic.

The rule under-detects: a change to an existing function body adds behaviour but declares no function, so the static gate stays silent. `test_adequacy.md` covers that case, because it reads the diff rather than pattern-matching it.

The function-declaration pattern is read from `TEST_FILE_PATTERN`'s sibling key so a project can tune it, defaulting to a pattern that covers `func`, `def`, and `function`.

### D5: The planning rule mirrors the accessibility rule

The `tasks` instruction already states that a task adding a gate-covered construct carries the gate-satisfying work with it. The test rule is the same sentence with a different trigger, so it goes in the same paragraph rather than a new one.

## Risks / Trade-offs

- **A wrong `TEST_FILE_PATTERN` produces false failures.** Mitigation: unset means pass, and `- missing_tests: SKIP` turns it off per project.
- **The static gate misses edits to existing functions.** Mitigation: `test_adequacy.md` reads the diff and covers that case.
- **The LLM gate costs tokens on every push.** Mitigation: it is one more prompt in a set that already runs four, and push is infrequent.
- **A project with no tests at all gets a failure on its first change.** Mitigation: the delta rule in `ralph-bridge` apply judges new violations only, and `SKIP` remains available.

## Migration Plan

Additive. Both gates ship in the plugin and are picked up by the existing runners with no registration step.

1. `claude plugin update ralph-loop` brings the gates.
2. Until `init` re-runs and writes `TEST_DIR`, `missing_tests` passes with a notice, so nothing breaks.
3. `/ralph-loop:init` writes the two keys and the gate becomes active.

**Rollback:** delete the two gate files, or add both `SKIP` entries to `ralph/gate_context.md`.

## Open Questions

- Should `missing_tests` require the test change to be in the same commit, or anywhere in the branch diff? Branch diff for now, because the loop commits per iteration and a same-commit rule would fight the inline fix path.
