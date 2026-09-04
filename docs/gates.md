# Gates

[ralph-loop](../README.md) · Previous: [Workflows](workflows.md) · Next: [Design](design.md)

The checks code must pass, and how to add your own.

---

Gates are checks code must pass before it lands. They come from two places, and are
discovered automatically: the plugin's `scripts/gates/`, and your project's `ralph/gates/`.

## Static gates

Deterministic checks (grep, awk, lint, AST analysis). Fast-tier checks run every iteration; precise-tier checks run once post-loop.

```
scripts/gates/static/
├── code_quality/          # force unwraps, @Observable, stubs, access control, print(), etc.
├── architecture/          # layer boundaries, dependency direction, modelContext ownership
├── security/              # hardcoded secrets, insecure HTTP, NSLog, UserDefaults credentials
├── accessibility/         # missing labels, hardcoded fonts, color-only differentiation
└── code_quality/missing_tests.sh   # function added with no test change
```

`missing_tests` reads `TEST_DIR`, `TEST_FILE_PATTERN`, and `FUNCTION_DECL_PATTERN` from
`ralph/config.sh`, written by `init`. Leave any empty and the gate passes with a notice
rather than failing.

## LLM gates

Semantic checks that require LLM judgment — one Sonnet call per category, post-loop only.

```
scripts/gates/llm/
├── code_quality.md        # naming clarity, SRP, feature envy, error handling, test quality
├── architecture.md        # DI compliance, god objects, pattern consistency
├── security.md            # data sensitivity, auth flow correctness, input validation
├── accessibility.md       # label quality, nav order, custom component a11y
└── test_adequacy.md       # do added tests assert, and call the new behaviour?
```

The two test gates enforce test-exists-with-code, not test-first. The loop commits once
per iteration, so write ordering is not observable.

## Adding custom gates

Drop files into your project's `ralph/gates/` directory:

**Static gate** (`ralph/gates/static/<category>/my_check.sh`):
```bash
#!/bin/bash
set -euo pipefail

gate_name()     { echo "My custom check"; }
gate_category() { echo "org"; }
gate_tier()     { echo "fast"; }

gate_check() {
    BASE_REF=$(git merge-base "${DIFF_BASE_BRANCH:-main}" HEAD 2>/dev/null || echo "HEAD~1")
    # Your check logic — exit 0 = pass, exit 1 = fail
}
```

**LLM gate** (`ralph/gates/llm/compliance.md`):
```markdown
---
category: compliance
---

You are reviewing Swift code changes for [your criteria].

Respond with exactly:
1: PASS|FAIL — [reason]
OVERALL: PASS|FAIL
```

No pipeline changes needed. A project gate with the same filename as a plugin gate replaces it.

## Blast radius analysis

When an LLM gate flags an architectural issue, the pipeline measures the **blast radius** of the affected type before attempting a fix.

| Dimension | What it measures | Low (0) | Medium (1) | High (2) |
|-----------|-----------------|---------|------------|----------|
| File fan-out | Files referencing the type | <= 5 | 6-15 | > 15 |
| Type coupling | Distinct types that depend on it | <= 3 | 4-10 | > 10 |
| Layers crossed | Architectural layers (dirs) affected | 1 | 2 | >= 3 |
| Infra reach | Directories containing references | 1-2 | 3-4 | 5+ |
| Test coupling | Test files referencing the type | <= 1 | 2-3 | > 3 |

The composite score (0-10) determines the action:

- **Score 0-3 (auto)**: Escalate to Opus for a careful, contained fix
- **Score 4-6 (conditional)**: Escalate to Opus, but only if the change stays within one architectural layer — otherwise defer
- **Score 7-10 (defer)**: Create a GitHub issue labeled `tech-debt` with the gate feedback, blast radius report, and recommended refactoring approach. The gate passes — architectural improvements don't block feature delivery

Deferred issues are always saved to `ralph/deferred_issues.md` as a backup. Duplicate GitHub issues are detected via search before creation.

Every threshold is tunable in `ralph/gate_context.md` with keys named
`blast_radius_fanout_thresholds`, `..._coupling_...`, `..._layer_...`, `..._infra_...`,
`..._test_...`, plus `blast_radius_auto_max` and `blast_radius_conditional_max`.

Run it by hand with `blast_radius.sh <TypeName> <source-dir>`.

---


---

[ralph-loop](../README.md) · Previous: [Workflows](workflows.md) · Next: [Design](design.md)
