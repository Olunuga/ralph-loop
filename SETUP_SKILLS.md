# Ralph Pipeline — Setup with Skills

## Prerequisites

```bash
npm install -g @anthropic-ai/claude-code
```

---

## 1. Install the skills

Install all three skills at once via [skills.sh](https://skills.sh/):

```bash
npx skills add Olunuga/ralph-loop
```

This installs `/ralph-init`, `/spec`, `/ralph`, and `/ralph-update` globally.

Or manually copy each from `ralph/skills/<name>/SKILL.md` to `~/.claude/skills/<name>/SKILL.md`.

---

## 2. Copy the pipeline into the project

Copy the `ralph/` directory into the root of your project:

```
your-project/
└── ralph/
    ├── loop.sh
    ├── PROMPT_build.md
    ├── PROMPT_plan.md
    ├── PROMPT_plan_work.md
    ├── PROMPT_bootstrap.md
    ├── skills/
    │   ├── ralph-init/
    │   │   └── SKILL.md
    │   ├── ralph/
    │   │   └── SKILL.md
    │   ├── ralph-update/
    │   │   └── SKILL.md
    │   └── spec/
    │       └── SKILL.md
    └── scripts/
        ├── check_architecture.sh
        ├── consensus_judge.sh
        └── hooks/
            └── workspace_boundary.sh
```

---

## 3. Run setup

Open Claude Code in the project root and run:

```
/ralph-init
```

This will:

- Auto-discover your app's scheme, simulator, and test targets
- Write `ralph/config.sh`
- Write `.claude/settings.json` (workspace boundary hook + pre-approved commands)
- Install `/spec`, `/ralph`, and `/ralph-update` as global skills
- Run bootstrap to generate `ralph/AGENTS.md`

---

## 4. Build a feature

### Step 1 — Write a spec

```
/spec TICKET-001
```

Walks you through a JTBD conversation and writes `ralph/specs/TICKET-001-<slug>.md`. You approve the spec before it's saved.

### Step 2 — Run the pipeline

```
/ralph TICKET-001
```

Shows you the spec for final approval, then runs autonomously:

- Creates branch `ralph/TICKET-001`
- Generates an implementation plan
- Builds, tests, and validates the code
- Reports what was built when done

### Step 3 — Review and merge

```bash
git checkout ralph/TICKET-001
# review the diff
git checkout main && git merge ralph/TICKET-001
```

---

## Updating ralph in a project

When ralph-loop has updates you want to pull into an existing project, open a Claude Code session in the project root and run:

```
/ralph-update
```

The skill reads `RALPH_VERSION` from `ralph/config.sh` as the default. You can also pass a specific version:

```
/ralph-update v1.2.0
/ralph-update some-branch
```

Shows a diff of what changed, asks for confirmation, then copies only the generic files. `config.sh`, `AGENTS.md`, and `specs/` are never touched.

---

## Human decisions

1. **Spec approval** — confirm what to build before the pipeline starts
2. **Branch review** — inspect the branch and merge when satisfied

