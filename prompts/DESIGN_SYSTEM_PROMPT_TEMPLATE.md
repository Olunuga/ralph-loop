Paste everything below into Claude Design.

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
