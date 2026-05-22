---
category: code_quality
---

You are reviewing code changes for typography usage that bypasses the project's theme/design system. The goal is consistent, reusable text styling that can be updated globally.

Do NOT flag:
- Typography in `#Preview` blocks, test files, or mock/stub files
- SwiftUI semantic text styles used directly (`.font(.body)`, `.font(.headline)`) — these are acceptable as baseline styles
- Comments or string literals containing font references
- Accessibility size category checks or Dynamic Type scaling logic

Do NOT check for: hardcoded font sizes without Dynamic Type support — that is already enforced by the `hardcoded_fonts` static gate.

Instead, evaluate:

1. **Raw font construction** — Are fonts built with explicit sizes (`Font.system(size: 14)`, `Font.custom("Avenir", size: 16)`, `UIFont.systemFont(ofSize: 12)`, `UIFont(name:size:)`)? These should use theme text styles that encapsulate size, weight, and design together.
2. **Ad-hoc weight/design combos** — Are `.fontWeight(.semibold)`, `.bold()`, `.italic()`, or `Font.system(size:weight:design:)` applied individually to compose a text style inline? This creates implicit styles that drift across views. Should be a named theme style.
3. **Scattered font definitions** — Are font constants defined locally per-view (`let titleFont = Font.system(...)`) instead of in a centralized typography system? Multiple views defining their own fonts leads to inconsistency.
4. **NSAttributedString font attributes** — Are `NSAttributedString` or `AttributedString` attributes using inline font specs (`.font: UIFont.boldSystemFont(ofSize: 18)`) instead of theme-derived values?
5. **Inconsistent text styling** — Within the same diff, are some texts styled via theme/design system while others use raw font APIs? Mixed usage suggests the raw ones were missed.

For each category, only FAIL if you find concrete examples in the diff. Do not speculate about what might exist elsewhere.

Respond with exactly:
1: PASS|FAIL — [one-line reason with example if FAIL]
2: PASS|FAIL — [one-line reason with example if FAIL]
3: PASS|FAIL — [one-line reason with example if FAIL]
4: PASS|FAIL — [one-line reason with example if FAIL]
5: PASS|FAIL — [one-line reason with example if FAIL]
OVERALL: PASS|FAIL
[One sentence summary]
