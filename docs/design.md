# Design

[ralph-loop](../README.md) · Previous: [Gates](gates.md) · Next: [Reference](reference.md)

Giving the build agent a visual target, and the Claude Design loop.

---

Two forms, both under `assets/` beside the intent: loose images, or an unpacked Claude
Design handoff bundle in `assets/design/`. The build agent reads a bundle's README first,
because Claude Design writes it as instructions for a coding agent.

## Working with Claude Design

The pipeline writes the prompts and reads the results. You do both transfers by hand.

```
/ralph-loop:req-slc my-product     writes ralph/design/SYSTEM_PROMPT.md
                                   -> paste into Claude Design
                                   -> unpack the handoff into ralph/design/system/, commit
                                      (rename it: Claude Design unpacks to its own name,
                                       and slice reads ralph/design/system/ only)

/ralph-loop:slice                  writes design/SCREEN_PROMPT.md in each change,
                                   each citing ralph/design/system/
                                   -> paste into Claude Design
                                   -> unpack into <change>/assets/design/, commit

/ralph-loop:run <cell-id>          the build agent reads the bundle while implementing
```

Committing the design system is what closes the loop. Claude Design imports it from the
repository and checks generated screens against it, so release three's screens match
release one's.

Commit the unpacked files, never the `.tar` or `.zip`. An archive is opaque to review, and
the build agent refuses to read one.

Nothing verifies that a built screen matches its design. Use snapshot or UI tests for that.

## Layout

A feature with a visual target can carry the target beside its spec. The build agent reads
the images while implementing.

```
ralph/specs/<name>/spec.md          legacy spec, now a directory
ralph/specs/<name>/assets/home.png  the reference

openspec/changes/<name>/assets/     same idea for an OpenSpec change
```

A spec with no reference stays a single `ralph/specs/<name>.md`, exactly as before.

`/ralph-loop:spec` asks for a reference and places it. The spec text must name each asset
and say what it shows, so planning can point a task at the right one. Archiving moves the
directory as a unit, so assets are never orphaned.

The agent reads at most 2 images per iteration. Above that, it reads the ones the current
task names. Nothing compares the built view against the reference: use snapshot or UI tests
for that.

---


---

[ralph-loop](../README.md) · Previous: [Gates](gates.md) · Next: [Reference](reference.md)
