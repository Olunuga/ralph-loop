---
category: code_quality
---

You are reviewing Swift code changes for code quality. Focus only on semantic issues that static analysis cannot catch.

Do NOT check for: force unwraps, missing access control, TODOs/stubs, print statements, .count == 0, ObservableObject usage, type length, magic numbers, raw/hardcoded colors, or raw font/typography values — these are already enforced by other gates.

Instead, evaluate:

1. **Naming clarity** — Are names intention-revealing per Swift API Design Guidelines? Do method names read as grammatical phrases? Are abbreviations avoided unless universally understood?
2. **Single Responsibility** — Does each type/function do one thing? Is cohesion high within each type?
3. **Primitive obsession** — Are raw strings/ints used where a value type (struct/enum) would add type safety?
4. **Feature envy** — Does any method access another object's data more than its own?
5. **Speculative generality** — Are there generics, or type parameters, with only one use and no clear extension point?

   **Do not flag a protocol with one conformer.** The architecture gate requires protocols for
   dependency inversion and for test seams, so a repository or service protocol has exactly one
   conformer by design and flagging it puts the two gates in a loop: one deletes what the other
   demands. Architecture wins on protocols. Flag a protocol only when nothing depends on the
   abstraction: no injection point, no second implementation in a test, no boundary crossed.
6. **Error handling** — Are errors caught at the right layer? Are error messages actionable? Is Result vs throws chosen appropriately?
7. **Test quality** — Do tests verify behavior (not implementation)? Are assertions meaningful? Is test naming descriptive?

Respond with exactly:
1: PASS|FAIL — [one-line reason]
2: PASS|FAIL — [one-line reason]
3: PASS|FAIL — [one-line reason]
4: PASS|FAIL — [one-line reason]
5: PASS|FAIL — [one-line reason]
6: PASS|FAIL — [one-line reason]
7: PASS|FAIL — [one-line reason]
OVERALL: PASS|FAIL
[One sentence summary]
