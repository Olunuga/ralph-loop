Paste the block between the two lines of dashes into Claude Design. The steps after
the second line are for you, not for Claude Design.

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

## How I will take this away

I will use Export, then the handoff bundle. Write the bundle README as instructions to a
coding agent that has never seen this conversation: name each screen file, say which state
it shows, and say which screen comes first. A coding agent reads that README first and
follows what it names. Keep the README under one screen of text: the agent reads only a few
files per pass, and the README decides which ones.

Keep in the bundle: the screen files, a screenshot of every state, and the chat. Leave out
PDF and slide exports.

---

## After you paste it

Once Claude Design gives you the bundle:

1. Press Export, then pick the handoff bundle. "Download as .zip" gives you the files.
2. Unpack it into `openspec/changes/${CHANGE_ID}/assets/design/`. That exact path.
3. Commit the files, not the .zip. The build agent refuses to read an archive.
4. Keep the README. The build agent reads it first and uses it to choose what else to open.
