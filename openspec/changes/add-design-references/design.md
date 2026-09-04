## Context

`prompts/PROMPT_build.md` reads the brief with up to 10 parallel subagents. A subagent returns text, so an image beside a spec never reaches the model. Nothing in the skills, prompts, or `ralph-bridge` schema mentions images. A UI feature with a visual target is implemented from prose alone.

Two intent sources exist, so any convention has to work for a legacy `ralph/specs/<name>.md` and an `openspec/changes/<name>/` directory.

Constraints:

- **Existing specs must keep working.** Most projects have single-file specs and cannot be asked to restructure.
- **Assets must archive with their spec.** `bin/cleanup_specs.sh` moves completed specs to `ralph/specs/done/`. An asset left behind is orphaned.
- **Images cost context.** A large reference competes with the spec text inside one iteration.

## Goals / Non-Goals

**Goals:** give a design reference a home in both intent sources; put it in front of the build agent; archive it with its spec.

**Non-Goals:** comparing a built view against the reference; a new gate; any change to `bin/loop.sh` or the gate engine; supporting design tool formats that the Read tool cannot render.

## Decisions

### D1: Assets sit inside the intent, which makes a legacy spec a directory

`ralph/specs/<name>/spec.md` plus `ralph/specs/<name>/assets/`, and `openspec/changes/<name>/assets/`.

The alternative was one shared `ralph/assets/<name>/`. It avoids restructuring legacy specs, but it separates an asset from the thing it describes, so archiving has to move two places and know they are related. Keeping them together makes archiving a single move and makes an orphan impossible.

The cost is that `ralph/specs/<name>` is now sometimes a file and sometimes a directory. Every reader must handle both. That is three call sites: the spec skills, `cleanup_specs.sh`, and the plan prompts, all of which already glob the directory rather than assume a shape.

### D2: The main agent reads the images, not a subagent

`PROMPT_build.md` currently fans out to text subagents for the brief. Images need the Read tool in the main agent's own context, because a subagent's return value is text.

So the brief read splits: text files keep the parallel subagent path, and `assets/` is read by the agent directly. This is a small loss of parallelism on a step that runs once per iteration.

### D3: Bound the reading, and say what was read

The instruction caps images per iteration and requires the agent to name each file it read. Without a cap, a spec with a dozen full-page references crowds out the spec text. Without the naming, an iteration that ignored the reference looks the same as one that followed it.

When `assets/` exceeds the cap, the agent reads what the current task names. This depends on D4.

### D4: The spec text must name its assets

An image alone does not say which part is the target, or which screen it is. Requiring the spec to name each file and say what it shows also gives the planner something to attach to a task, which is what makes the per-task selection in D3 work.

### D5: Unreadable formats fail soft

A `.fig` or `.sketch` file cannot be rendered. The agent names it, says it cannot read it, and continues from the text. Failing the iteration would block a spec whose author exported the wrong format, for a problem the agent cannot fix.

## Risks / Trade-offs

- **A spec path is now a file or a directory.** → Three call sites handle both, and the single-file form stays supported indefinitely.
- **Images crowd the iteration context.** → Capped per iteration, with per-task selection above the cap.
- **An author commits a large binary.** → The spec skills warn above a size threshold. Git storage is the project's decision, not the pipeline's.
- **The agent can claim to follow a reference it ignored.** → It must name each file it read, so the iteration output shows what was used. Nothing verifies the result, which is the stated non-goal.

## Migration Plan

Additive. No existing spec changes.

1. `claude plugin update ralph-loop` brings the new prompt and skills.
2. Existing single-file specs keep working with no action.
3. A new spec gains a directory only when the user supplies a reference.

**Rollback:** revert the prompt change. Assets on disk are then unread but harmless.

## Open Questions

- What is the right image cap per iteration? Two is likely enough for one view, but this needs a real run to settle.
- Should `/ralph-loop:doctor` report specs whose assets the agent could not read? Out of scope here.
