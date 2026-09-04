## 1. Config keys

- [ ] 1.1 Add `TEST_DIR`, `TEST_FILE_PATTERN`, and `FUNCTION_DECL_PATTERN` to the `ralph/config.sh` template written by `skills/init/SKILL.md`, with the function pattern defaulting to one that covers `func`, `def`, and `function`
- [ ] 1.2 Discover the values during init: read the test target from the existing discovery step, and infer the pattern from the files found under it
- [ ] 1.3 Verify against spec `test-presence-gate`: init on a project with a test target writes all three keys

## 2. Static gate

- [ ] 2.1 Write `scripts/gates/static/code_quality/missing_tests.sh` exporting `gate_name`, `gate_category` as `code_quality`, `gate_tier` as `fast`, and `gate_check`
- [ ] 2.2 Read `TEST_DIR`, `TEST_FILE_PATTERN`, and `FUNCTION_DECL_PATTERN` from config; print a notice naming the missing key and pass when any is unset
- [ ] 2.3 Scope the check to the branch diff against `DIFF_BASE_BRANCH`, added lines only, matching the pattern used by `print_statements.sh`
- [ ] 2.4 Fail when the diff adds a function declaration outside `TEST_DIR` and adds or changes no file matching `TEST_FILE_PATTERN`; name every source file that lacks a test change
- [ ] 2.5 Verify against spec `test-presence-gate`: new function with no test fails; with a test passes; rename-only passes; test-only change passes; unset config passes with a notice
- [ ] 2.6 Verify `- missing_tests: SKIP` suppresses it, and a project copy at `ralph/gates/static/code_quality/missing_tests.sh` overrides the plugin copy

## 3. LLM gate

- [ ] 3.1 Write `scripts/gates/llm/test_adequacy.md` with `category: code_quality` frontmatter
- [ ] 3.2 Write the numbered checklist: added test with no assertion, added test that only constructs the type under test, added behaviour whose test does not call it
- [ ] 3.3 Add the convergence rule used by the existing LLM gates, so retries flag only concrete defects against the numbered checklist
- [ ] 3.4 Verify against spec `test-adequacy-gate`: an assertion-free test is reported, a real test passes, and a diff with neither tests nor behaviour passes
- [ ] 3.5 Verify a second run on an unchanged diff reports the same defects

## 4. Planning rule

- [ ] 4.1 Extend the `tasks` instruction in `schemas/ralph-bridge/schema.yaml` so the gate rule also names tests: a task adding behaviour carries its test in the same task or the next subtask
- [ ] 4.2 State that a task which only renames, moves, or reformats needs no test subtask
- [ ] 4.3 Verify against spec `test-aware-planning`: `openspec instructions tasks --json` returns the test rule alongside the existing gate rule

## 5. Documentation

- [ ] 5.1 Add both gates to the gate list in `README.md` and note the three config keys
- [ ] 5.2 Record in `CLAUDE.md` that the pipeline enforces test-exists-with-code, not test-first, and why the loop cannot observe ordering
