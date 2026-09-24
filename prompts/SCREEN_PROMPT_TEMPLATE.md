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

Every screen this activity needs at this depth, and every state each screen has. Empty,
loading, error and the normal case are a floor, not the list: add every state this activity
actually has, including ones I did not think to ask for, and say which ones you added.

Show the path a user takes through them.

Give each state a short label and use that label everywhere. Those labels become the task
list, so a state without one gets built by nobody.

Where something is refused or fails, show the treatment you chose, not only that it fails: a
toast, a line under the field, a full screen with its copy and its button. The tasks were
written before you drew anything and they guessed. Your choice replaces the guess, so it has
to be visible.

Stay at this depth. If a deeper capability would make a screen better, say so and leave it
out. It belongs to a later release.

Use the design system exactly. If it cannot express something this activity needs, tell me
what is missing rather than inventing a one-off.

## How I will take this away

When the screens are finished, ask me to confirm them, then produce a handoff bundle for a
coding agent. The Export menu does not offer one, so I am asking for it here.

The bundle must hold:

1. `README.md`, written to a coding agent that has never seen this conversation. Name each
   screen file, say which state it shows, say which screen comes first, and say which
   tokens the screens use from the system. Keep it to one screen of text: the agent opens
   only a few files per pass, and this file decides which ones.
2. The screen documents, with every state drawn.
3. Any file the documents need in order to open.

Cite the system by token name. Do not restate the system's values here: a copied hex value
goes stale the moment the system changes.

---

## After you paste it

1. When Claude Design says the screens are done, ask it for the handoff bundle. The Export
   menu has no such item; the bundle is produced on request in the chat.
2. Download the bundle folder.
3. Put its contents in `openspec/changes/${CHANGE_ID}/assets/design/`. That exact path.
4. Delete the bundle's own `design_system/` directory if it has one. Claude Design copies
   the system in to make the bundle self-contained. The system is already committed at
   `ralph/design/system/`, and a second copy drifts from it. The bundle README cites the
   committed path, so nothing breaks when the copy goes.
5. Commit the files, not the .zip. The build agent refuses to read an archive.
6. Check `README.md` is there. The build agent reads it first and uses it to choose what
   else to open.

A single `.dc.html` downloaded on its own is not enough. It needs sibling files that the
single download leaves behind, and it has no README to tell the agent where to start.

An exported PNG of the screens is worth committing beside the bundle. The build agent reads
images, and a picture of every state in one frame is quick for it to take in.
