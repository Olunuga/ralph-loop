---
name: init
description: One-time setup of the Ralph autonomous dev pipeline for a new project
allowed-tools: Bash Read Write AskUserQuestion
disable-model-invocation: true
---

You are setting up the Ralph autonomous development pipeline for this project.

Run each step in order. Tell the user which step you are on.

## Arguments

`--openspec` turns on the OpenSpec wiring in Step 7. Without it, Step 7 is skipped
entirely: no `openspec/` directory is created and no git hooks are written.

`/ralph-loop:init --openspec` is also the upgrade command. It is idempotent. Run it again
after `claude plugin update ralph-loop` to refresh the installed schema and to add config
keys a new plugin version introduced.

It never touches `ralph/gates/`, `ralph/gate_context.md`, `ralph/.diff_base`, or anything
under `ralph/specs/`.

`ralph/config.sh` is the one file it rewrites, and it only ever adds. Every value already in
the file is carried across unchanged, and Step 2 asks only about keys that are missing or
empty. A re-run is how an existing project picks up a key such as `LAYER_VIEW`. Tell the
user which keys you added, and say that nothing else changed.

---

## Step 1 — Create project directories

Create the ralph project shell if it doesn't exist:
```bash
mkdir -p ralph/specs ralph/specs/done ralph/gates/static ralph/gates/llm ralph/scripts/hooks
```

Copy the workspace boundary hook from the plugin:
```bash
PLUGIN_DIR="$(dirname "$(which loop.sh)")/.."
cp "$PLUGIN_DIR/scripts/hooks/workspace_boundary.sh" ralph/scripts/hooks/workspace_boundary.sh
chmod +x ralph/scripts/hooks/workspace_boundary.sh
```

---

## Step 2 — Discover project info

Before asking the user anything, run these commands to discover what you can.

Note: `xcrun simctl` and `xcodebuild -list` require access to system services that the
Claude Code sandbox may block. If these commands fail with "Operation not permitted" or
"CoreSimulatorService connection" errors, retry with `dangerouslyDisableSandbox: true`.

```bash
# .xcodeproj name
ls *.xcodeproj 2>/dev/null | head -1

# available schemes and test targets
xcodebuild -list 2>/dev/null

# available simulators
xcrun simctl list devices available 2>/dev/null | grep -E "iPhone [0-9]" | tail -5

# top-level directories (to infer source dir)
ls -d */ 2>/dev/null
```

From the output, infer:
- `XCODEPROJ` — the `.xcodeproj` filename
- `XCWORKSPACE` — the `.xcworkspace` filename (if one exists at the project root)
- `SCHEME` — the first non-test scheme listed
- `UNIT_TEST_TARGET` — the target ending in `Tests` (not `UITests`)
- `UI_TEST_TARGET` — the target ending in `UITests`
- `SIMULATOR` — the newest iPhone simulator available (prefer iPhone 16, fallback to highest number)
- `SOURCE_DIR` — the directory matching the scheme name (or xcodeproj name without extension)
- `TEST_DIR` — the directory holding the unit test target's files, usually named after `UNIT_TEST_TARGET`
- `TEST_FILE_PATTERN` — the filename convention for tests in that directory. Infer it from what
  is actually there: `*Tests.swift`, `test_*.py`, `*.test.ts`, `*_test.go`. If the directory is
  empty or absent, leave both keys empty rather than guessing.

If `ralph/config.sh` already exists, read it. Use its values as the baseline and only ask about fields that are missing or empty. Never replace a value the user set, and never drop a key you do not recognise: a later plugin version may have added it, or the user may have.

Present everything you discovered to the user in a single AskUserQuestion:

"Here's what I found — please confirm or correct:

  App name:        <inferred or 'unknown'>
  Description:     <from config.sh or 'unknown'>
  .xcodeproj:      <discovered>
  .xcworkspace:    <discovered or 'none'>
  Scheme:          <discovered>
  Simulator:       <discovered>
  Unit test target: <discovered>
  UI test target:  <discovered>
  Protocols dir:   <from config.sh or 'unknown — e.g. MyApp/Repositories/Protocols'>
  Source dir:      <discovered>

Reply with any corrections (e.g. 'description: a fitness tracking app, protocols: MyApp/Services') or 'ok' to proceed."

Apply any corrections the user gives, then write `ralph/config.sh`.

---

## Step 2b — Architecture, when the codebase has none

Look for layer directories under the source directory:

```bash
SRC="<source_dir>"
for d in Views ViewModels Services Repositories Models Features Domain Data Presentation; do
  [[ -d "$SRC/$d" ]] && echo "FOUND $d"
done
echo "source files: $(find "$SRC" -name "*.swift" 2>/dev/null | wc -l | tr -d ' ')"
find "$SRC" -maxdepth 1 -name "*.swift" 2>/dev/null | head -10
```

If layer directories already exist, record their real paths for the `LAYER_*` variables in
Step 3. A codebase with its own structure keeps it: never propose a different one during
setup.

Show the mapping you inferred, as `<their directory> -> <slot>`, and ask one question:
"Record this structure, or restructure the project first?"

- **Record it**: the normal answer. Carry the paths to Step 3 and skip the rest of this step.
- **Restructure first**: go to Step 2d. Setup will still finish; the restructure is planned
  as work, not done here.

Then skip the rest of this step either way.

Three states remain, and they are not the same:

1. **No directories and no source files.** A new project. Create the directories; the first
   feature lands in them.
2. **No directories, but source files sit loose under the source directory.** Creating empty
   directories beside them switches the gates on over nothing, because the gates look only
   inside the layer paths. Say so before asking, in these words: "There are N source files
   that are not in any layer directory. Creating the directories does not move them, and the
   architecture gates will not see them until they move."
   Choose the architecture first, then run Step 2c.
3. **Directories exist but are empty.** Treat this as state 1.

If none exist, the project has no architecture yet. Three things depend on one being chosen
now, so do not defer it:

- `layer_boundaries.sh`, `dependency_direction.sh`, and `model_context.sh` read
  `LAYER_VIEW`, `LAYER_VIEWMODEL`, `LAYER_SERVICE`, and `LAYER_REPOSITORY` from
  `ralph/config.sh`. With none set they fall back to `Views`, `ViewModels`, `Services`,
  `Repositories` under the source directory, find nothing, and pass without checking.
- `ralph/AGENTS.md` tells the build agent which layer a new file belongs in. With no
  architecture that section is blank.
- Each change's `design.md` otherwise invents its own structure, and they drift.

Use AskUserQuestion: "This project has no folder structure yet. Which architecture should
the pipeline enforce?"

- **Feature-first MVVM (Recommended)**: `Features/<Name>/{Views,ViewModels}/`, with
  `Core/Services/`, `Core/Repositories/`, `Core/Models/` shared. Everything one feature owns
  sits together, so a change touches one directory and two features cannot quietly share a
  view model.
- **Flat MVVM**: `Views/`, `ViewModels/`, `Services/`, `Repositories/`, `Models/`. Every
  view in one directory. Simpler to start, harder to read once there are many features.
- **Let me describe it**: the user names their own directories, and you map them onto the
  four slots below.

**The four slots are positions in a dependency order, not MVVM parts.** The gates enforce
one thing: UI does not leak downward. `view` is whatever holds the UI. `viewmodel` is
whatever the UI binds to. `service` and `repository` are whatever sits below that, with
`repository` reaching storage or the network. The names are historical; any layered
architecture maps onto them.

| Architecture | view | viewmodel | service | repository |
| --- | --- | --- | --- | --- |
| Feature-first MVVM | Features/*/Views | Features/*/ViewModels | Core/Services | Core/Repositories |
| Flat MVVM | Views | ViewModels | Services | Repositories |
| The Composable Architecture | Views | Reducers | Clients | Clients (persistence) |
| Clean Architecture | Views | Presenters | UseCases | Gateways |
| VIPER | Views | Presenters | Interactors | DataManagers |
| MVC with a service layer | Views | Controllers | Services | Stores |

On **Let me describe it**, ask for the directories and the dependency direction, then show
the mapping you inferred as `<their directory> -> <slot>` and ask them to confirm it. Leave a
slot empty when nothing fills it; an empty slot turns its rule off rather than failing.

Record the user's own names in `ralph/AGENTS.md` in Step 6. `LAYER_*` carries the paths; the
names the team uses belong in the documentation the build agent reads.

Create the directories, each with a `.gitkeep` so git tracks them:

```bash
for d in <chosen dirs>; do mkdir -p "$SRC/$d" && touch "$SRC/$d/.gitkeep"; done
```

On an Xcode project that does not use synchronized folder references, a directory created on
disk is not in the project file until it is added in Xcode. Tell the user to check, and say
that the gates read the filesystem and will pass either way, so a missing project reference
shows up as a build failure rather than a gate failure.

Carry the chosen paths into the `LAYER_*` variables in Step 3, and into the Architecture section of
`ralph/AGENTS.md` in Step 6.

---

## Step 2c — Move loose files into the chosen architecture

Run this only when Step 2b found loose source files. Skip it otherwise.

```bash
LOOSE=$(find "$SRC" -name "*.swift" -not -path "*/Views/*" -not -path "*/ViewModels/*" \
  -not -path "*/Services/*" -not -path "*/Repositories/*" -not -path "*/Models/*" \
  -not -path "*/Core/*" -not -path "*/Features/*" 2>/dev/null)
echo "$LOOSE" | grep -c . 
git status --porcelain | head -5
```

**Above 20 files, do not offer the move.** Say: "This is N files. A move of that size is a
refactor with its own risk, not a setup step." Then go to Step 2d.

**Refuse on a dirty tree.** If `git status --porcelain` prints anything, say: "Commit or
stash your changes first. A move mixed with uncommitted edits cannot be undone cleanly."
Then continue to Step 3 without moving anything.

At 20 files or fewer on a clean tree, read each one and decide its slot from what it holds.
Use the chosen architecture's directory for that slot, not the slot name:

| What the file holds | Layer |
| --- | --- |
| A `View`, or anything importing SwiftUI for its own body | view |
| An `ObservableObject`, `@Observable`, or a type a view binds to | viewmodel |
| A protocol and its implementation for data access, persistence, or network | repository |
| Business rules with no UI and no storage of its own | service |
| A plain data type, a `Codable`, a `@Model` | the models directory |
| The `@main` entry point, an app delegate, a widget bundle | leave where it is |

Show the full list as `<path> -> <target>` and ask for confirmation. A file you cannot place
goes in the list as `<path> -> unsure, left in place`, never guessed.

On confirmation, move with `git mv` so history follows the file, then commit on its own:

```bash
git mv "<src>" "<dst>"
```
```bash
git -c commit.gpgsign=false commit -m "ralph: move source files into the chosen architecture"
```

Then verify, and report honestly:

```bash
<BUILD_CMD from Step 2>
```

A build failure here is almost always Xcode project references, not the code. Tell the user
which files moved and that the project file needs them re-added. Do not try to edit the
`.xcodeproj` yourself.

---

## Step 2d — Restructuring a project that already has an architecture

Run this only when the user asked to restructure in Step 2b, or when Step 2c refused because
there were more than 20 loose files.

**Do not move any file here.** Moving working code is a refactor: it can break the build, it
touches files no gate has seen, and it deserves a plan, a review and a pull request. Setup is
not the place for it.

Write the intent down and hand it to the pipeline instead.

1. Record the target in `ralph/config.sh` now, not after. The `LAYER_*` paths name where code
   should live. Until the move happens the gates check directories that are empty or partial,
   which reports PASS. Say that plainly: "The gates will not enforce this until the files
   move."
2. Ask which architecture to move to, using the same options and mapping table as Step 2b.
3. Write the current structure and the target into `ralph/AGENTS.md` in Step 6, as two lists.
   The build agent reads that file, so a new file lands in the target layer from the next
   iteration on, even before old files move.
4. Tell the user how to do the move as real work. Name one route, chosen by whether
   OpenSpec is wired. Check after Step 7 has run, or check directly:

```bash
command -v openspec >/dev/null && grep -q '^schema: *ralph-bridge' openspec/config.yaml 2>/dev/null \
  && echo OPENSPEC || echo LEGACY
```

`OPENSPEC`:

```
Restructuring is a change, not a setup step. Describe it once and the pipeline builds it:

    /opsx:propose restructure-source     writes the proposal, specs, design and tasks
    /ralph-loop:run restructure-source   builds it and opens a pull request
```

`LEGACY`:

```
Restructuring is a change, not a setup step. Describe it once and the pipeline builds it:

    /ralph-loop:spec restructure-source   writes the spec
    /ralph-loop:run restructure-source    builds it and opens a pull request
```

Do not name `/ralph-loop:slice` here. It slices a story map into one change per activity and
stops without `ralph/AUDIENCE_JTBD.md`. A restructure is a single change, not a release
slice.

Either way the move is planned, gated, and opened as a pull request the user reviews file by
file. Say that. Nothing moves until they approve it.

Do not run the command yourself. Name it and continue to Step 3.

---

## Step 3 — Write ralph/config.sh

```bash
#!/bin/bash
# ralph/config.sh — Project build configuration for the Ralph loop.
# Sourced by loop.sh on every run.

APP_NAME="<app_name>"
APP_DESCRIPTION="<description>"

XCODEPROJ="<xcodeproj>"
XCWORKSPACE="<xcworkspace>"  # leave empty if no .xcworkspace exists
PROTOCOLS_DIR="<protocols_dir>"
SOURCE_DIR="<source_dir>"

# Layer paths for the architecture gates. Plain variables, not an associative array:
# macOS ships bash 3.2, which has none. A glob is allowed. Quote every value: a source
# directory with a space in it is common on Xcode projects.
# An unset role falls back to <source_dir>/Views and its siblings.
# Feature-first: "<source_dir>/Features/*/Views" and "<source_dir>/Core/Repositories".
LAYER_VIEW="<source_dir>/Features/*/Views"
LAYER_VIEWMODEL="<source_dir>/Features/*/ViewModels"
LAYER_SERVICE="<source_dir>/Core/Services"
LAYER_REPOSITORY="<source_dir>/Core/Repositories"

# Test layout. missing_tests.sh reads these. Leave any of them empty to turn
# that gate off; it passes with a notice rather than failing.
TEST_DIR="<test_dir>"
TEST_FILE_PATTERN="<test_file_pattern>"
FUNCTION_DECL_PATTERN="^[[:space:]]*((public|private|internal|open|static|final|override)[[:space:]]+)*(func|def|function)[[:space:]]"

BUILD_CMD="xcodebuild \
  -scheme <scheme> \
  -destination 'platform=iOS Simulator,name=<simulator>' \
  build \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  -derivedDataPath .build \
  -quiet"

UNIT_TEST_CMD="xcodebuild \
  -scheme <scheme> \
  -destination 'platform=iOS Simulator,name=<simulator>' \
  test \
  -only-testing:<unit_test_target> \
  -parallel-testing-enabled NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  -derivedDataPath .build \
  -quiet"

UI_TEST_CMD="xcodebuild \
  -scheme <scheme> \
  -destination 'platform=iOS Simulator,name=<simulator>' \
  test \
  -only-testing:<ui_test_target> \
  -parallel-testing-enabled NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  -derivedDataPath .build \
  -quiet"

SNAPSHOT_TEST_CMD=""
LINT_CMD=""
```

---

## Step 4 — Write .claude/settings.json

Check if `.claude/settings.json` already exists. If it does, read it and merge the hooks in — do not overwrite existing keys.

If it does not exist, create `.claude/` and write:

```json
{
  "permissions": {
    "allow": [
      "Bash(loop.sh*)",
      "Bash(blast_radius.sh*)",
      "Bash(cd .worktrees/* && loop.sh*)",
      "Bash(git worktree add*)",
      "Bash(git worktree remove*)",
      "Bash(git worktree list*)",
      "Bash(git checkout -b*)",
      "Bash(git checkout -*)",
      "Bash(git show*)",
      "Bash(git log*)",
      "Bash(git -C .worktrees/*)",
      "Bash(git add*)",
      "Bash(git commit*)",
      "Bash(git push*)",
      "Bash(git reset*)",
      "Bash(git clean*)",
      "Bash(find ralph/*)",
      "Bash(find .worktrees/*)",
      "Bash(git status*)",
      "Bash(git diff*)",
      "Bash(git branch*)",
      "Bash(git merge-base*)",
      "Bash(gh pr list*)",
      "Bash(gh pr view*)",
      "Bash(gh pr create*)",
      "Bash(ls .worktrees/*)",
      "Bash(ls ralph/*)",
      "Bash(source ralph/config.sh*)",
      "Bash(grep * ralph/*)"
    ]
  },
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Write|Edit|Bash",
        "hooks": [
          {
            "type": "command",
            "command": "bash ralph/scripts/hooks/workspace_boundary.sh"
          }
        ]
      }
    ]
  }
}
```

---

## Step 5 — Update .gitignore

Ensure the following Ralph pipeline artifacts are gitignored. Check if each entry already exists before appending:

```bash
for entry in ".worktrees/" "IMPLEMENTATION_PLAN*.md" "progress.txt" "iteration_context.md" "ralph/.loop_status" "ralph/.loop_output" "ralph/.diff_base" "ralph/.llm_gate_failures" "ralph/.fix_agent.log" "ralph/.loop.pid"; do
    grep -qF "$entry" .gitignore 2>/dev/null || echo "$entry" >> .gitignore
done
```

---

## Step 6 — Bootstrap AGENTS.md

Run the bootstrap to let Claude discover the codebase architecture:

```bash
loop.sh bootstrap 2>&1
```

This generates `ralph/AGENTS.md`. Wait for it to complete, then read the file and show a summary to the user.

Use AskUserQuestion to ask: "Does this AGENTS.md look correct? Any layers, protocols, or gate rules to add? Reply 'yes' to finish, or describe what to fix."

Apply any corrections the user requests, then save.

---

## Step 7: OpenSpec wiring (only with `--openspec`)

Skip this entire step if the user did not pass `--openspec`.

**7a. Require the CLI.**
```bash
command -v openspec >/dev/null || echo "MISSING"
```
If missing, tell the user: "OpenSpec is not installed. Run `npm i -g openspec`, then
re-run `/ralph-loop:init --openspec`." Skip the rest of this step and continue to Step 8.
The ralph setup from Steps 1 to 6 stays in place.

**7b. Require a supported CLI version.**
```bash
bash "$PLUGIN_DIR/scripts/schema_stamp.sh" require-min
```
Exit 1 means the CLI is too old. The script names the installed version and the minimum.
Report it, skip the rest of this step, and continue to Step 8.

**7c. Initialise OpenSpec if absent.**
`--tools` is required. Without it, `openspec init` prints the tool list and creates nothing.
```bash
[[ -f openspec/config.yaml ]] || openspec init --tools claude
```
This also writes `.claude/commands/` and `.claude/skills/` for the opsx commands.

**7d. Install the schema bundle.**
```bash
mkdir -p openspec/schemas
cp -R "$PLUGIN_DIR/schemas/ralph-bridge" openspec/schemas/
```
This overwrites any previous copy, which is what makes a re-run refresh the bundle.

**7e. Set the active schema.**
Read `schema:` in `openspec/config.yaml`.
- Absent, or already `ralph-bridge`: set it to `ralph-bridge`.
- Any other value: use AskUserQuestion to ask whether to switch. Leave it alone on a no.
Never modify anything under `openspec/changes/` or `openspec/specs/`.

**7f. Stamp the install.**
```bash
bash "$PLUGIN_DIR/scripts/schema_stamp.sh" write "$(pwd)"
```

**7g. Seed the gate context.**
Only when `ralph/gate_context.md` does not exist. If it does, tell the user
"Existing gate calibration preserved" and do not touch it.
```markdown
# Gate context

Accepted patterns and gate overrides for this project. One entry per line, in this
exact format. The gate runner parses these lines; markdown headers are ignored.

- example_gate: SKIP — pre-existing violations on this branch
- another_gate: ENFORCE

Hook tiers. Defaults are fast on pre-commit and precise on pre-push.

- pre_commit_tier: fast
- pre_push_tier: precise
```

**7h. Install the git hooks.**
For each of `pre-commit` and `pre-push`:
- If `.git/hooks/<name>` does not exist, copy `$PLUGIN_DIR/hooks/<name>` there and `chmod +x`.
- If it exists and its first lines name ralph, overwrite it.
- If it exists and is not a ralph hook, do NOT overwrite. Write the template to
  `.git/hooks/<name>.ralph` and tell the user to merge the two by hand.

**7i. Offer the Stop hook.**
Use AskUserQuestion: "Register the in-session gate check? It runs the fast static tier
after every Claude turn and makes no model call." Register it in `.claude/settings.json`
only on an explicit yes, pointing at `$PLUGIN_DIR/hooks/stop_gate_check.sh`.

**7j. Validate.**
```bash
openspec schema validate ralph-bridge
```
A non-zero exit means the bundle does not work with this CLI version. Report it now
rather than leaving it to surface at the next propose.

---

## Step 8: Commit ralph/ to git

Ralph project files must be tracked in git so that worktrees include them.

```bash
git add ralph/ .claude/settings.json .gitignore
[[ -d openspec ]] && git add openspec/
git -c commit.gpgsign=false commit -m "chore: configure ralph autonomous pipeline"
```

---

## Done

Tell the user:

"Ralph is set up and committed. Here's what was configured:
- ralph/config.sh — build commands for <app_name>
- ralph/gates/ — directory for custom project gates
- .claude/settings.json — workspace boundary hook active
- ralph/AGENTS.md — codebase architecture documented

<If --openspec was used, also list:>
- openspec/schemas/ralph-bridge/ : gate-aware planning schema, set active
- ralph/gate_context.md : gate overrides and hook tiers
- .git/hooks/pre-commit : fast static gates
- .git/hooks/pre-push : precise static gates, then LLM gates

Next steps:
  /ralph-loop:spec TICKET-001   : describe a feature, get a spec
  /ralph-loop:run TICKET-001    : run the autonomous pipeline
  /ralph-loop:req-slc <product> : describe a whole product, get a story map

  /ralph-loop:status            : what is done and what to do next, any time

Bypass a hook with --no-verify. Record an accepted pattern in ralph/gate_context.md
as: - <gate_name>: SKIP — <reason>

To add custom gates, drop .sh files into ralph/gates/static/<category>/
or .md files into ralph/gates/llm/. See the plugin README for details."
