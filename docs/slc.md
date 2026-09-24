[← README](../README.md) · [Workflows](workflows.md) · [Gates](gates.md) · [Design](design.md) · [Reference](reference.md)

# SLC releases

Map the whole product once. Ship a small, finished part of it. Repeat.

---

## The commands, in order

```
/ralph-loop:req-slc my-product   # once: map the product
/ralph-loop:slice                # per release: split it into changes
/ralph-loop:run <change>         # per change: build it
/ralph-loop:cleanup <change>     # per change: file it away once merged
/ralph-loop:status               # any time: what is done, what to do next
```

`status` writes `ralph/NEXT.md`: what you have, one thing to do next. A product runs for
weeks, so that file is how you pick the work back up.

---

## Before you start

**A new project**: `/ralph-loop:init --openspec` asks how you want the code laid out, since
there is nothing to copy from, and creates the folders.

**A project with code**: run `/ralph-loop:doctor` first to see what is already broken, then
`/ralph-loop:init --openspec`. It keeps the layout you have.

---

## 1. Map the product

`req-slc` asks who uses the product, what they are trying to get done, and how deep each
part can go. It writes a table. Columns are things people do. Rows are how far each one goes.

| Depth | Upload photo | Extract colors | Save palette |
|---|---|---|---|
| **Basic** | single file | top 5 colors | save to device |
| **Enhanced** | many at once | pick how many, show hex | name and tag |
| **Advanced** | import from a link | smarter matching | sync and export |

The table lives in `ralph/AUDIENCE_JTBD.md` and is never filed away. Later releases take
deeper rows without asking you again.

The answers land on a branch. The last step offers to merge it, because everything after
this reads your working folder, not a branch.

---

## 2. Shared groundwork comes first

Some work belongs to no single cell and every cell needs it: the colours and type every
screen uses, a way to talk to a server, somewhere to keep data between launches.

`slice` finds these first and makes each one a change of its own, before any feature. It
asks about each, so you can say you already have it.

The colours and type are the clearest case. The checks reject a raw colour value and a fixed
font size, so the first screen built without them fails. The agent then invents its own, and
the next screen invents different ones.

Sliced a release before this existed? Run `/ralph-loop:slice` with no flag. It adds what is
missing and creates no new release.

---

## 3. One change per cell

`slice` proposes the slice, shows the build order, and asks before writing anything. Then it
creates one change per cell.

Take one cell per column, so a person gets something they can finish, rather than one thing
done deeply and the rest missing. The row need not be level: take a deeper cell where a
shallow one would not be worth shipping.

Each change gets four documents:

| File | Written for |
|---|---|
| `proposal.md` | Someone who uses the product. Plain words, about 30 lines |
| `specs/` | The same reader. What must be true, and when |
| `design.md` | An engineer. Names files and types, about 80 lines |
| `tasks.md` | The build agent and you. You both tick the same boxes |

`ralph/releases/<name>.md` records which changes make up the release.

---

## 4. Screens are drawn after the tasks

This one catches people. **The tasks are written now. The screens are drawn later, often
weeks later.**

`slice` writes a prompt per change. You paste it into Claude Design, ask in the chat for a
handoff bundle, and commit what comes back. See [Design](design.md) for how.

Three things follow, and the pipeline handles each:

- **A task written first says what happens, not what it looks like.** "An empty name is
  refused" and not "a red line appears". Nobody has drawn it yet.
- **The drawing wins.** When it disagrees with a task, the task changes. `run` stops before
  building and fixes them. A task already ticked keeps its tick, and a new task says what to
  correct.
- **Designers add states nobody asked for.** Empty, loading and error are a floor, not the
  list.

To fix every affected change at once, without building:

```
/ralph-loop:slice --add-design-tasks
```

It compares the drawn states against the tasks one by one. It only adds; nothing you ticked
is lost.

---

## 5. Build

```
/ralph-loop:run <change>     # the pipeline builds it and opens a draft pull request
/opsx:apply <change>         # you build it, and it stops to ask
```

Both tick the same `tasks.md`, so you can start one way and finish the other.

One last check runs before the pull request opens: does every drawn state have a task? If
not, the branch is pushed, no pull request opens, and you are sent back to fix the tasks.

That check is not one of the code checks. Those read the changed lines, and a screen nobody
wrote a task for changes no lines at all.

---

## 6. File it away, then tag

```
/ralph-loop:cleanup <change>     # after the pull request merges
```

It moves the change into the archive and folds what it promised into your main specs, so
those stay a true picture of the product.

**Do not skip this.** `status` and `slice --status` both read the archive. A change that is
built but never filed reads as unfinished, and the release never completes.

```
/ralph-loop:slice --status       # is the release ready?
```

It calls a release done only when every change in it is filed. Then tag it and slice the
next one.

---

## Without OpenSpec

`/ralph-loop:run my-product` builds the whole release as one plan, with one pull request.
The map still drives it. You lose the per-change review and the release record.
