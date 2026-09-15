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

I will use Export, then the handoff bundle. Write the bundle README as instructions to a
coding agent that has never seen this conversation: name which files hold the tokens, which
hold the components, and what to do with each. A coding agent reads that README first and
follows what it names.

Keep in the bundle: the token definitions, the component files with their states, the
screenshots, and the chat. Leave out PDF and slide exports. The agent cannot read a token
value out of a picture of a slide.

---

## After you paste it

Once Claude Design gives you the bundle:

1. Press Export, then pick the handoff bundle. "Download as .zip" gives you the files.
   "Send to local coding agent" delivers them to wherever that agent runs, which is not
   this project, so you still have to move them.
2. Unpack it, then put the contents in `ralph/design/system/`. That exact directory name.
   Claude Design unpacks under its own name, so rename it.
3. Commit the files, not the .zip. The build agent refuses to read an archive, and an
   archive in git cannot be reviewed.
4. Keep the README. The build agent reads it before anything else in the bundle.
