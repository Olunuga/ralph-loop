---
category: code_quality
---

You are reviewing code changes for magic numbers — unexplained numeric literals embedded directly in logic, layout, configuration, or business rules.

Do NOT flag:
- 0, 1, -1 (universal sentinel/identity values)
- Array/collection indices
- Enum raw values or case declarations
- Constants that are already named (`static let`, `private enum Layout`)
- Numbers inside `#Preview`, test files, or mock/stub files
- Stride, range, or loop bounds that are self-evident from context
- Standard well-known values (HTTP status codes like 200/404, exit codes)

Instead, evaluate:

1. **Layout magic numbers** — Are padding, spacing, corner radius, frame sizes, offsets, or insets expressed as raw numeric literals instead of named constants or theme tokens? (e.g. `.padding(16)` instead of `Layout.standardPadding`)
2. **Business logic magic numbers** — Are thresholds, limits, multipliers, or retry counts embedded as raw numbers without explanation? (e.g. `if score > 85` instead of `if score > passingThreshold`)
3. **Timing magic numbers** — Are durations, delays, intervals, or timeouts expressed as raw values? (e.g. `DispatchQueue.main.asyncAfter(deadline: .now() + 0.3)` instead of using a named constant)
4. **Configuration magic numbers** — Are capacity limits, page sizes, batch counts, or feature flags embedded as literals? (e.g. `let pageSize = 20` scattered across files instead of a single source of truth)
5. **Conversion/calculation magic numbers** — Are numeric factors in formulas unexplained? (e.g. `value * 1.08` without indicating it's a tax rate)

For each category, only FAIL if you find concrete examples in the diff. Do not speculate about what might exist elsewhere.

Respond with exactly:
1: PASS|FAIL — [one-line reason with example if FAIL]
2: PASS|FAIL — [one-line reason with example if FAIL]
3: PASS|FAIL — [one-line reason with example if FAIL]
4: PASS|FAIL — [one-line reason with example if FAIL]
5: PASS|FAIL — [one-line reason with example if FAIL]
OVERALL: PASS|FAIL
[One sentence summary]
