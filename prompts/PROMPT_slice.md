TASK: Read the story map, determine what is already built, and propose the cells that form
the next Simple, Lovable, Complete release.

Output a cell list. Do NOT write an implementation plan, and do NOT write any file.

STEP 1 - Read the inputs

- ralph/AUDIENCE_JTBD.md: the audiences, the jobs to be done, and the Story Map table.
- ralph/specs/: one spec per activity, defining what each capability depth delivers.
- ralph/releases/: any earlier release records. Cells already shipped are not candidates.

Enumerate every cell in the Story Map. A cell id is the backticked value in a table cell,
of the form <activity-slug>-<depth>. A cell holding "-" does not exist; skip it.

STEP 2 - Gap analysis per cell

For each cell, search the codebase and decide its status:

- DONE: the behaviour at that depth is present and working.
- PARTIAL: some of it exists.
- MISSING: none of it exists.

Note where it would live (file path, layer) and the sibling implementation to follow.

STEP 3 - Dependencies

For each cell, name the cells it needs first. A cell whose dependency is neither DONE nor
in your proposal cannot be in the slice.

STEP 4 - Propose the slice

Apply the SLC criteria:

- Simple: narrow. Not every activity, not every depth.
- Lovable: someone actually wants to use it within that scope.
- Complete: it accomplishes a meaningful job end to end. Not a broken preview.

Cut vertically across activities. A slice with two activities done fully beats four done
partially. The depths need not match: if one activity needs enhanced depth to be worth
shipping, take enhanced for that activity and basic for the rest.

Exclude every DONE cell. Defer every cell with an unsatisfied dependency.

STEP 5 - Report

Print exactly this, and nothing else:

PROPOSED SLICE
- <cell-id> | <activity> | <depth> | <one-line reason it is in this release>
...

ALREADY DONE
- <cell-id> | <one-line evidence from the codebase>
...

DEFERRED
- <cell-id> | needs <cell-id> | <one-line reason>
...

RATIONALE
<Two or three sentences: what job this slice completes, and why it is lovable at this scope.>

If ALREADY DONE or DEFERRED is empty, print the heading and "none".
