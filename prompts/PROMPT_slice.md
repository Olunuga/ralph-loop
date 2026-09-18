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

STEP 3b - Shared foundations

A cell is one activity at one capability depth. Some work belongs to no cell and every cell
needs it. The theme is one example: each screen uses it, no screen owns it. Networking is
another, for a product that talks to a server.

A thing is a foundation when all three are true:

- Two or more cells in your proposal need it.
- No single cell owns it. Putting it in one cell makes every other cell depend on that cell
  for a reason a reader cannot see.
- It is absent from the codebase. Check before you name it.

Work through this list and name only what the proposed cells actually need. Do not propose a
foundation for a need no cell has:

- Colour, type and spacing read from one place.
- Talking to a server: a client, request and response shapes, and how an error surfaces.
- Keeping data between launches: the store, the schema, and how it migrates.
- Knowing who the user is: sign-in, the session, and what a signed-out person sees.
- Moving between screens: the navigation shell, when the release has more than one screen.
- Working offline, and reconciling when the connection returns.
- Recording what happens: logging, crash reporting, analytics.
- More than one language, or more than one region.

For each one you name, say in one line which cells need it and what is missing today.

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

FOUNDATIONS
- <foundation-slug> | <which cells need it> | <what is missing today>
...

BUILD ORDER
1. <foundation-slug> | nothing
2. <cell-id> | needs <foundation-slug>
...

RATIONALE
<Two or three sentences: what job this slice completes, and why it is lovable at this scope.>

Order every cell in PROPOSED SLICE, using the dependencies from STEP 3. A cell comes after
every cell it needs. Two cells that need nothing from each other keep story map order.

Every foundation comes before every cell that needs it. A foundation named in FOUNDATIONS
takes a numbered position here like any other piece of work.

Use a short slug ending in `-foundation`: `theme-foundation`, `networking-foundation`,
`persistence-foundation`.

If FOUNDATIONS is empty, print the heading and "none".

If ALREADY DONE or DEFERRED is empty, print the heading and "none".
