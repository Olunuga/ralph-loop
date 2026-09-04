---
category: code_quality
---

You are reviewing whether the tests in this change actually exercise the behaviour it adds.

Judge the diff only. Do not comment on code that the diff does not touch, and do not repeat what other gates cover: naming, single responsibility, error handling, and general test quality belong to the code_quality gate.

A test file changing is not enough. `missing_tests` already checks that. Your job is whether the test does any work.

Evaluate:

1. **Assertions present** — Does every added test function assert something? A test with no assertion passes whatever the code does, so it verifies nothing.
2. **Behaviour is called** — Does each added test call the thing it names? A test that constructs the type under test and then asserts only on the constructor verifies nothing about the new behaviour.
3. **New behaviour is covered** — For each function the diff adds to a non-test file, is there an added or changed test that calls it? Name any that has none.
4. **Assertions are specific** — Does the test assert on a value or a state change, rather than only that a call did not throw or that a result is non-nil?

Pass a numbered item when the diff adds nothing relevant to it. A diff with no added tests and no added behaviour passes all four.

Respond with exactly:
1: PASS|FAIL — [one-line reason]
2: PASS|FAIL — [one-line reason]
3: PASS|FAIL — [one-line reason]
4: PASS|FAIL — [one-line reason]
OVERALL: PASS|FAIL
[One sentence summary]

Name the test function and its file in every FAIL reason. Flag only concrete defects you can point at in the diff. Do not raise a concern that is not one of the four numbered items above.
