## Context

Claude Design turns a prompt into a prototype and exports a handoff bundle: a tar archive holding the design, the components used, the design intent, and a README written for a coding agent. It can also import a component library from a GitHub repository and check its output against it.

The pipeline has neither end. Nothing produces a prompt for Claude Design, and the `assets/` convention on `main` reads images only, so a handoff bundle placed there is ignored.

Constraints:

- **The user does the transfer.** The pipeline cannot call Claude Design, so both directions are manual: paste a prompt out, place a result back.
- **Context is bounded.** A bundle holds many files. The image rule already caps reading at 2 per iteration for the same reason.
- **Two scopes, two moments.** A design system is a product-level thing, produced once. Screens are per activity at a depth, produced per release.

## Goals / Non-Goals

**Goals:** emit a design system prompt from what `req-slc` already captured; emit a screen prompt per cell from what `slice` already knows; read a placed handoff bundle in the build loop.

**Non-Goals:** calling Claude Design; validating that a screen matches its design; unpacking archives automatically; changing the existing image path.

## Decisions

### D1: Two prompts at two moments, matching the two scopes

`req-slc` writes one design system prompt for the product. `slice` writes one screen prompt per cell.

The alternative was a single prompt per change covering both. It would restate the design system in every change, so a system decision made in release one would drift by release three, with each change carrying its own copy.

The split matches what each command already knows. `req-slc` has the audiences, jobs, and full activity set, which is exactly the input a design system needs. `slice` knows one activity at one depth with its success criteria, which is exactly the input a screen needs.

### D2: The design system is committed, so Claude Design can import it

The handoff for the system unpacks into `ralph/design/system/` and is committed. A screen prompt then points Claude Design at that repository path rather than restating the system.

This uses Claude Design's GitHub import, which checks generated output against the imported library. Without it, each release's screens are generated from a prose description of the system and drift from what was built. With it, the repository is the single source and the loop closes.

### D3: Bundles are unpacked before they are committed

A tar in git is opaque to review and unreadable by the agent. The skills tell the user to unpack into the target directory and commit the contents.

The build agent enforces this by refusing to read an archive: it names the file and says to unpack it. Automatic unpacking was rejected because it would run an archive extraction over content the pipeline did not produce.

### D4: The bundle README is instructions, so it is read first

Claude Design writes the bundle README for a coding agent, telling it to read the design files and match the visual output in whatever technology fits the codebase.

That makes it different from a design reference image, which is passive. The agent reads the README first and follows what it names, rather than treating the directory as a pile of files. This also bounds the reading: the README says which files matter.

### D5: Bundles live beside images, under `assets/`

`assets/design/` for an unpacked bundle, loose images directly in `assets/` as before. Both archive with their spec, which the design references work already handles.

A separate top-level directory was rejected: it would need its own archiving rule, and the two are the same kind of thing at different fidelity.

## Risks / Trade-offs

- **A bundle floods the iteration context.** → Capped, and the README names what matters.
- **The user forgets to place a handoff.** → Nothing fails. The prompt is inert and the agent works from the text brief.
- **A committed design system goes stale against the code.** → Out of scope. Nothing verifies the built view against any design, which was already the stated non-goal of the design references work.
- **Claude Design's bundle format changes.** → The agent reads the README rather than assuming a file layout, so a format change degrades to reading images.

## Migration Plan

Additive. Nothing existing changes.

1. `claude plugin update ralph-loop` brings the prompt templates and skill steps.
2. An existing product runs `req-slc` again only if it wants the system prompt; the story map is unchanged.
3. Changes materialised before this work have no `design/` directory, and the agent behaves as it does today.

**Rollback:** revert the `PROMPT_build.md` change. Prompts and bundles on disk become unread but harmless.

## Open Questions

- What is the right file cap for a bundle? The image cap is 2. A bundle README plus three named files is a guess until a real handoff is placed.
- Should `slice --status` report which changes still have no placed handoff? Useful, but it needs a rule for which cells are visual. Left out.
