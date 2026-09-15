Paste the block between the two lines of dashes into Claude Design. The steps after
the second line are for you, not for Claude Design.

---

Create the base design system for a product. I need the system only, not screens.
Screens come later, one release at a time.

## The product

Platform: ${PLATFORM}

${PRODUCT_SUMMARY}

## Who uses it

${AUDIENCES}

## What they are trying to get done

${JOBS_TO_BE_DONE}

## Everything the product will eventually do

These are the activities across the whole product, not one release. Design a system wide
enough to cover all of them, so later screens do not need new foundations.

${ACTIVITIES}

## What I need back

1. **Colour**: a full palette with semantic roles (surface, on-surface, primary, danger,
   success), and the contrast ratio for every foreground and background pair I would use.
2. **Typography**: a type scale with the role of each step, the font family, and the line
   height for each.
3. **Spacing**: a spacing scale and the rule for when each step applies.
4. **Core components**: the components the activities above will need. For each, show
   every state it has, including empty, loading, error, and disabled.
5. **Rules**: how the pieces combine. What a screen looks like at rest, how density
   changes, how the system behaves at the platform's smallest and largest sizes.

Name every token. I will commit these names into the codebase, so they have to be stable
and readable in source.

Do not design individual screens. If an activity above needs something the system cannot
express, tell me what is missing rather than designing around it.

## How I will take this away

When the system is finished, ask me to confirm it, then produce a handoff bundle for a
coding agent. The Export menu does not offer one, so I am asking for it here.

The bundle must hold:

1. `README.md`, written to a coding agent that has never seen this conversation. Say what
   the bundle is, say the HTML is a reference and not production code, state the fidelity,
   list every file and what it holds, and put the component states in a table. Keep it to
   what an agent needs to start work.
2. `tokens.json`, the machine-readable source of truth. Every token with its value in each
   appearance and the rule for when it applies. Flat dot-namespaced names I can commit into
   source as they are.
3. The spec document, with a live specimen of every component state.
4. Any stylesheet needed to trace a value back to its source ramp.

Every value has to reach me as text. A hex value that exists only inside a picture, or only
as an answer in this chat, is lost. Name every token, and keep the names stable.

---

## After you paste it

1. When Claude Design says the system is done, ask it for the handoff bundle. The Export
   menu has no such item; the bundle is produced on request in the chat.
2. Download the bundle folder.
3. Put its contents in `ralph/design/system/`. That exact directory name. The download
   arrives under its own name, so rename it.
4. Commit the files, not the .zip. The build agent refuses to read an archive, and an
   archive in git cannot be reviewed.
5. Check `README.md` and `tokens.json` are both there. The build agent reads the README
   before anything else, and `tokens.json` is the only machine-readable record of the values.

A single `.dc.html` downloaded on its own is not enough. It carries token names in its
notes but raw hex in its markup, and it needs sibling files that the single download leaves
behind.
