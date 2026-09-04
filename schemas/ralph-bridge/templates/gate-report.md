# Gate Report

<!-- Evidence for this change. Written after implementation, from the two gate runs. -->

## Baseline

<!-- Gate result captured BEFORE any task was implemented. Commit SHA and date.
     List every failing gate with its offending files. "No failures" is a valid baseline. -->

**Captured at:** <commit SHA> on <date>

| Gate | Tier | Result | Files |
|------|------|--------|-------|
|      |      |        |       |

## Post-implementation

<!-- Gate result AFTER the last task. Static gates then LLM gates. -->

**Captured at:** <commit SHA> on <date>

| Gate | Tier | Result | Files |
|------|------|--------|-------|
|      |      |        |       |

## Delta

<!-- Post minus baseline. This is the verdict.
     A violation in both runs is inherited and does not fail the change.
     A violation absent from the baseline is introduced and does fail it. -->

**Verdict:** GREEN | RED

<!-- If RED, list each introduced violation: -->

| Gate | Introduced by | Files |
|------|---------------|-------|
|      |               |       |

## Suppressed

<!-- Each `- <gate_name>: SKIP` entry in ralph/gate_context.md that removed a gate
     from the comparison, and why it is there. Empty if none. -->

| Gate | Reason |
|------|--------|
|      |        |

## Deferred

<!-- Violations left unfixed. Each needs a tracking reference: an issue, a ticket,
     or a line in ralph/deferred_issues.md. Empty if none. -->

| Gate | Reason | Reference |
|------|--------|-----------|
|      |        |           |
