## Why

A task can add a feature, pass all 23 gates, and ship with zero tests. The loop runs `UNIT_TEST_CMD` every iteration and rolls back on failure, but nothing requires that new behaviour comes with a test. No gate checks coverage, and no prompt asks for one.

## What Changes

- **Planning rule** in the `ralph-bridge` `tasks` instruction: a task that adds behaviour carries its test in the same task or an adjacent subtask. Same shape as the existing accessibility rule.
- **`missing_tests.sh`**, a diff-scoped static gate in `code_quality`. When the branch diff adds a source file with a new public or internal function, the diff must also add or change a file in the test target. Deterministic, no model call.
- **`test_adequacy.md`**, an LLM gate. It judges whether the added tests exercise the behaviour the change introduces, and flags tests with no assertions or tests that only construct an object.
- **`TEST_DIR` and `TEST_FILE_PATTERN`** in `ralph/config.sh`, discovered by `/ralph-loop:init`, so the static gate knows what counts as a test file in any language.

Strict TDD is out of scope. The loop sees one commit per iteration, so test-written-first is not observable. This enforces test-exists-with-code.

Not breaking. Both gates are diff-scoped and skippable through `ralph/gate_context.md`.

## Capabilities

### New Capabilities

- `test-presence-gate`: the deterministic static gate that requires a test change when behaviour is added, and the config keys it reads.
- `test-adequacy-gate`: the LLM gate that judges whether the added tests exercise the new behaviour.
- `test-aware-planning`: the `tasks` instruction rule that keeps test work in the same task as the behaviour it covers.

### Modified Capabilities

None. The gate runners, the loop, and the `ralph-bridge` artifact set are unchanged in structure.

## Impact

**New:** `scripts/gates/static/code_quality/missing_tests.sh`, `scripts/gates/llm/test_adequacy.md`

**Modified:** `schemas/ralph-bridge/schema.yaml` (the `tasks` instruction), `skills/init/SKILL.md` (discover `TEST_DIR`), `CLAUDE.md`, `README.md`

**Unchanged:** `bin/loop.sh`, both gate runners, every existing gate.

**Depends on** `add-ralph-bridge` for the `ralph-bridge` schema. The two gates work without it; only the planning rule needs it.

**Risk surface:** a language-agnostic test-file heuristic is the weak point. A project whose tests do not match `TEST_FILE_PATTERN` gets false failures, so the gate must skip cleanly when the pattern is unset.
