Paste everything below into Claude Design.

---

${DESIGN_SYSTEM_CITATION}

## What to design

Design the screens for one activity at one capability depth. Nothing else.

Activity: ${ACTIVITY}
Depth: ${DEPTH}

${DEPTH_DESCRIPTION}

## The job this serves

${JOB_TO_BE_DONE}

## What success looks like at this depth

${SUCCESS_CRITERIA}

## What I need back

Every screen this activity needs at this depth, and every state each screen has: empty,
loading, error, and the normal case. Show the path a user takes through them.

Stay at this depth. If a deeper capability would make a screen better, say so and leave it
out. It belongs to a later release.

Use the design system exactly. If it cannot express something this activity needs, tell me
what is missing rather than inventing a one-off.
