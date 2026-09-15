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

I export this project as HTML and commit the files into a codebase. Two consequences.

Put every screen and every state into the project itself. Anything that exists only as an
answer in this chat is lost when I export.

Write a page called README that a coding agent reads first. Address it to an agent that has
never seen this conversation. Name each screen file, say which state it shows, and say
which screen comes first. Keep it under one screen of text: the agent opens only a few
files per pass, and this page decides which ones.

---

## After you paste it

Once Claude Design has built the screens:

1. Press the share button, then under Export pick **Project HTML**, then **Download**.
   Choose the .zip, not standalone.
2. Unpack the .zip into `openspec/changes/${CHANGE_ID}/assets/design/`. That exact path.
3. Commit the files, not the .zip. The build agent refuses to read an archive.
4. Check a README came out with it. The build agent reads that file first and uses it to
   choose what else to open.

The **Claude Code / Send** option sends the design to a connected Claude Code destination.
It does not put files at the path above, so it does not feed this pipeline.
