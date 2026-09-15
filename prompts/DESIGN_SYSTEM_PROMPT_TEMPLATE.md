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

I export this project as HTML and commit the files into a codebase. Two consequences.

Put the whole system into files that survive that export. The tokens, the type scale, the
spacing scale, and every component with all its states have to be in the project itself.
Anything that exists only as an answer in this chat is lost when I export.

Write a page called README that a coding agent reads first. Address it to an agent that has
never seen this conversation. Name each file, say what it holds, and say what to do with
it. Say which file holds the token definitions. Keep it under one screen: the agent opens
only a few files per pass, and this page decides which ones.

Give me the token values as text I can copy, not only as colour swatches. A hex value
inside a picture is unusable.

---

## After you paste it

Once Claude Design has built the system:

1. Press the share button, then under Export pick **Project HTML**, then **Download**.
   Choose the .zip, not standalone.
2. Unpack the .zip and put its contents in `ralph/design/system/`. That exact directory
   name. The .zip unpacks under its own name, so rename it.
3. Commit the files, not the .zip. The build agent refuses to read an archive, and an
   archive in git cannot be reviewed.
4. Check a README came out with it. The build agent reads that file before anything else.
   If there is none, ask Claude Design to add one and export again.

The **Claude Code / Send** option in that menu sends the design to a connected Claude Code
destination. It does not put files at the path above, so it does not feed this pipeline.
PNG, PowerPoint, PDF, and MP4 are for sharing with people, not for the build agent.
