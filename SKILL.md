---
name: forge
description: "Agent-agnostic, platform-agnostic autonomous loop creator. Generates portable external bash loops that drive any headless coding-agent CLI (claude, droid, codex, opencode, gemini, copilot, …) across fresh-context iterations. Forward mode implements features end-to-end; decompose mode breaks existing features into atomic user stories for reimplementation; pipeline mode orchestrates multi-phase workflows (bootstrap → loop → wrap-up). Works for code, specs, audits, docs, and research alike. Use when asked to '/forge', '/forge decompose', '/forge pipeline', 'use forge', 'forge this', 'decompose a feature', 'reverse ralph', 'use ralph' (legacy), or 'ralph this' (legacy)."
---

# Forge — Agent-Agnostic, Platform-Agnostic Autonomous Loop Creator

Forge generates portable external bash loops that drive any headless coding-agent CLI (claude, droid, codex, opencode, gemini, copilot, …) across many fresh-context iterations. Implements forward, decompose, and (coming soon) multi-phase pipeline workflows. Memory persists via git, `progress.txt`, and `prd.json`. Forge is not tied to any single AI agent or platform — the user chooses which agent powers each loop, and the skill installs in any platform that supports skills (Factory.AI Droid, Claude Code, …).

> **Previously known as Ralph.** The v1 invocation `/ralph` is renamed to `/forge`. Existing `.ralph/*.sh` generated scripts continue to work unchanged — only the slash command and the skill `name:` field change. Natural-language triggers like "use ralph to …" still route here for muscle-memory continuity.

> **How this compares to other tools you may already use.** If you only need a single in-session loop with one agent, use that agent's native looping plugin (e.g., Anthropic's `/ralph-loop` plugin for Claude Code, which re-feeds the same prompt via a Stop hook in-session). If you want methodology guidance — brainstorming, planning, TDD, code review — use a methodology-focused plugin for your platform (e.g., Anthropic's Superpowers plugin for Claude Code). Forge is complementary to both: it generates **external** bash loops, **across many fresh-context iterations**, **for any CLI**, with optional multi-phase pipeline orchestration. Use whichever combination fits the task.

## Workflow

### Step 1: Understand the Feature

If the user tagged a markdown file via `@`, read it as the feature spec. Otherwise, ask the user to describe the feature.

Ask clarifying questions if needed:
- What problem does this solve?
- What are the key user actions?
- What's out of scope?
- How do we know it's done?

### Step 2: Configure the Loop

Ask the user four questions to configure the loop:

#### 2a. Which AI agent?

Present this list and ask the user to choose:

1. `claude` — Claude Code
2. `droid` — Factory Droid
3. `codex` — OpenAI Codex
4. `opencode` — OpenCode
5. `gemini` — Gemini CLI
6. `copilot` — GitHub Copilot
7. `cc-compatible` — Claude Code-compatible binary (user provides binary name, e.g., `zai`, `minimax`, `kimi`)
8. `custom` — Fully custom command (user provides entire command template with `$PROMPT_FILE` as placeholder)

**Headless command templates per agent** (used when generating the loop script):

```bash
# claude — Claude Code
claude -p "$(cat "$PROMPT_FILE")" --dangerously-skip-permissions --model $MODEL

# droid — Factory Droid
droid exec --skip-permissions-unsafe -f "$PROMPT_FILE" --output-format text -m $MODEL

# codex — OpenAI Codex
codex exec --yolo -m $MODEL "$(cat "$PROMPT_FILE")"

# opencode — OpenCode
opencode run --yolo -m $MODEL "$(cat "$PROMPT_FILE")"

# gemini — Gemini CLI
gemini -p "$(cat "$PROMPT_FILE")" --yolo -m $MODEL

# copilot — GitHub Copilot
copilot -p "$(cat "$PROMPT_FILE")" --yolo --model $MODEL

# cc-compatible — Same as Claude Code with user-provided binary name
$BINARY -p "$(cat "$PROMPT_FILE")" --dangerously-skip-permissions --model $MODEL

# custom — User provides entire command template
# User's template must include $PROMPT_FILE where the prompt file path should go
```

If the user selects `cc-compatible`, ask for the binary name (e.g., `zai`). If the user selects `custom`, ask for the full command template and instruct them to use `$PROMPT_FILE` where the prompt file path belongs.

#### 2b. Which model?

Ask the user for the model identifier (free text input). Examples:
- Claude Code: `opus`, `claude-opus-4-6`, `sonnet`, `claude-sonnet-4-5-20250929`
- Factory Droid: `claude-opus-4-6`, `o3`
- OpenAI Codex: `o3`, `o4-mini`
- OpenCode: `anthropic/claude-opus-4-6`, `openai/o3` (format: `provider/model`)
- Gemini CLI: `gemini-2.5-pro`, `gemini-2.0-flash`
- GitHub Copilot: `claude-sonnet-4-5`, `gpt-4o`

If the user says "default" or leaves it blank, omit the model flag entirely (use the agent's built-in default).

#### 2c. Loop name?

Suggest a name based on the feature in kebab-case (e.g., `add-task-priorities`). The user can accept or provide a different name. This becomes the filename: `.ralph/<loop-name>.sh`

#### 2d. Auto-push and create PR?

Ask the user: **"Should Forge automatically push the branch and create a PR when the loop finishes?"**

- **Yes** — When the loop ends (all stories complete or max iterations reached), the script will push the branch to `origin` and create a pull request via `gh pr create`. The base branch (e.g., `main` or `master`) is auto-detected at generation time by checking which branch exists on the remote.
- **No** — The script only runs locally. All commits stay local. The user pushes and creates PRs themselves.

If the user says yes, detect the base branch now (at generation time) by checking:
1. Does `refs/remotes/origin/main` exist? → use `main`
2. Does `refs/remotes/origin/master` exist? → use `master`
3. Neither → default to `main`

Bake the resolved base branch directly into the generated script as `DEFAULT_BRANCH="main"` (or `"master"`).

### Step 3: Create prd.json

Generate a `prd.json` file in the project root:

```json
{
  "project": "[Project Name]",
  "branchName": "forge/[feature-name-kebab-case]",
  "description": "[Feature description]",
  "userStories": [
    {
      "id": "US-001",
      "title": "[Story title]",
      "description": "As a [user], I want [feature] so that [benefit]",
      "acceptanceCriteria": [
        "Criterion 1",
        "Criterion 2",
        "Typecheck passes"
      ],
      "priority": 1,
      "passes": false,
      "notes": ""
    }
  ]
}
```

### Step 4: Generate and Run the Loop

1. Create `.ralph/` directory in the project root if it doesn't exist
2. Check `.gitignore` — add `.ralph/`, `.ralph-archive/`, and `.ralph-last-branch` if missing (create `.gitignore` if it doesn't exist)
3. Read `scripts/ralph.sh` (the reference template in this skill) to understand the loop structure
4. Generate `.ralph/<loop-name>.sh` using the reference template's structure, with the selected agent command baked in:
   - Use the exact command template from Step 2a, substituting the user's model from Step 2b
   - If no model was specified, omit the model flag from the command
   - Set `PROMPT_FILE="$SCRIPT_DIR/<loop-name>-prompt.md"` (co-located with the script)
   - Set `AGENT_BIN` to the selected executable (for `custom`, use the command's executable token)
   - Keep all existing logic: archive, branch tracking, progress init, completion detection, 2s sleep between iterations
   - If the user opted for auto-push+PR in Step 2d: include the `finalize()` function with `DEFAULT_BRANCH` set to the resolved base branch, and `AUTO_PUSH_PR="true"`. Otherwise set `AUTO_PUSH_PR="false"` and omit the `finalize()` function.
5. Copy `scripts/prompt.md` (from this skill) → `.ralph/<loop-name>-prompt.md`
6. Make the script executable: `chmod +x .ralph/<loop-name>.sh`
7. Tell the user: `Run with: .ralph/<loop-name>.sh [max_iterations]`

## Critical Rules for User Stories

### Size: Small but Substantive

Each story MUST be completable in ONE iteration. If you can't describe it in 2-3 sentences, it's too big. But each story must also involve meaningful work — if it's a single find-and-replace or a one-line edit, it's too small and should be combined with related work.

**Too small (combine with related work):**
- "Replace nvidia-smi with rocm-smi in one file" → combine into a broader documentation accuracy story
- "Add one missing env var to README" → combine with other doc gaps
- "Fix a typo in a config file" → combine with other config improvements
- Any story that a developer could complete in under 5 minutes

**Right-sized:**
- Add a database column and migration
- Add a UI component to an existing page
- Update a server action with new logic
- Add a filter dropdown to a list
- Fix a validation bug, add tests for the fix, and update docs
- Consolidate duplicated helper functions across multiple files

**Too big (split these):**
- "Build the entire dashboard" → schema, queries, UI components, filters
- "Add authentication" → schema, middleware, login UI, session handling

### Order: Dependencies First

1. Schema/database changes (migrations)
2. Server actions / backend logic
3. UI components that use the backend
4. Dashboard/summary views

### Acceptance Criteria: Verifiable

**Good:**
- "Add `status` column with default 'pending'"
- "Filter dropdown has options: All, Active, Completed"
- "Typecheck passes"

**Bad:**
- "Works correctly"
- "Good UX"

**Always include:**
- `"Typecheck passes"` on every story
- `"Verify in browser"` on UI stories

## Example

**User says:** "use forge to add task priorities" (or legacy: "use ralph to add task priorities")

**Step 1:** Read the feature description, ask clarifying questions.

**Step 2:** Ask: Which agent? → `claude`. Which model? → `sonnet`. Loop name? → `add-task-priorities`. Auto-push+PR? → `yes`.

**Step 3:** Create prd.json:
```json
{
  "project": "TaskApp",
  "branchName": "forge/task-priority",
  "description": "Add priority levels (high/medium/low) to tasks",
  "userStories": [
    {
      "id": "US-001",
      "title": "Add priority field to database",
      "description": "As a developer, I need to store task priority.",
      "acceptanceCriteria": [
        "Add priority column: 'high' | 'medium' | 'low' (default 'medium')",
        "Migration runs successfully",
        "Typecheck passes"
      ],
      "priority": 1,
      "passes": false,
      "notes": ""
    },
    {
      "id": "US-002",
      "title": "Display priority badge on task cards",
      "description": "As a user, I want to see priority at a glance.",
      "acceptanceCriteria": [
        "Colored badge: red=high, yellow=medium, gray=low",
        "Visible without hovering",
        "Typecheck passes",
        "Verify in browser"
      ],
      "priority": 2,
      "passes": false,
      "notes": ""
    }
  ]
}
```

**Step 4:** Generate `.ralph/add-task-priorities.sh` (with `claude -p "$(cat "$PROMPT_FILE")" --dangerously-skip-permissions --model sonnet` as the agent command, `AUTO_PUSH_PR="true"` and `DEFAULT_BRANCH="main"` since the user opted for auto-push+PR), copy prompt to `.ralph/add-task-priorities-prompt.md`, and add `.ralph/`, `.ralph-archive/`, and `.ralph-last-branch` to `.gitignore`.

> prd.json created with 2 user stories. Run `.ralph/add-task-priorities.sh` to start autonomous execution.

## How Forge Executes

Each iteration, a fresh headless agent:
1. Reads `prd.json` and `progress.txt`
2. Picks highest priority story where `passes: false`
3. Implements it
4. Runs quality checks (typecheck, lint, test)
5. Commits if passing (or commits progress notes if stuck — see "If You Get Stuck" in prompt)
6. Updates `prd.json` to mark `passes: true` (or updates `notes` if blocked)
7. Appends learnings to `progress.txt`
8. Exits

Loop continues until all stories pass or max iterations hit.

If the user opted for auto-push+PR (Step 2d), then after the loop ends (all stories complete or max iterations reached):
1. The loop script pushes the branch to origin
2. Creates a PR via `gh pr create` from the forge branch to the default branch
3. If `gh` CLI is not available or PR creation fails, prints manual instructions instead of aborting
4. Push or PR failures are handled gracefully — they never mask a successful loop run

If the user chose local-only, the script simply exits after the loop. All commits remain local.

## Files Reference

| File | Purpose |
|------|---------|
| `prd.json` | User stories with pass/fail status |
| `progress.txt` | Append-only learnings for future iterations |
| `.ralph/<name>.sh` | Generated loop script with agent command baked in |
| `.ralph/<name>-prompt.md` | Prompt file for the loop (copy of `scripts/prompt.md`) |

## Decompose Mode

Triggered by: `/forge decompose <input>` (or legacy `/ralph decompose <input>`) or natural
language like "reverse ralph this feature", "decompose X into a replication plan", "break
this feature down into user stories".

### What it does

Decompose mode takes any description of an existing feature and decomposes it — recursively
and completely — into an atomized `prd.json` that a forward Forge loop can execute to
greenfield-reimplement the feature.

Decomposition is behavioral and functional: it captures what the feature does and how it
behaves from the outside, not how it is built internally. The forward loop handles all
implementation decisions.

### Inputs accepted

- URLs (fetched and spidered up to 2 hops of linked documentation)
- Local file paths (read directly)
- Natural language descriptions
- Any combination of the above

### Agent workflow

Follow the detailed instructions in `scripts/decompose-init-prompt.md` for steps 1–7 below.

1. **Gather inputs.** Read all provided sources. For URLs, fetch the page and follow
   documentation links up to 2 hops deep (same documentation domain only). Synthesize
   all gathered content into a capability surface: a structured description of all
   observable behaviors, states, inputs, outputs, configuration options, and integrations
   of the feature.

2. **Ask the loop name.** Ask the user what to name this decomposition run. Used for the
   generated script filename: `.ralph/decompose-<n>.sh`.

3. **Ask which execution agent** to use for the decomposition loop. Same agent matrix as
   forward Forge: `claude`, `droid`, `codex`, `opencode`, `gemini`, `copilot`,
   `cc-compatible`, or `custom`.

4. **Ask which model** (optional — leave blank to use the CLI default).

5. **Seed `decomp.json`.** Generate the initial state file with top-level capability
   clusters extracted from the capability surface. Each cluster gets status `needs_split`.

6. **Generate `.ralph/decompose-<n>.sh`** from `scripts/decompose.sh`, substituting
   `__AGENT__`, `__MODEL__`, and `__LOOP_NAME__`. Copy `scripts/decompose-prompt.md` to
   `.ralph/decompose-<n>-prompt.md`.

7. **Instruct the user** to run:
   ```
   .ralph/decompose-<n>.sh [max_iterations]
   ```
   Default `max_iterations` is 50. The loop runs autonomously until all leaf nodes in
   `decomp.json` have status `atomic` (split parent nodes get status `split`), then
   emits `prd.json`.

### Known Limitations

- **Context window**: The full `decomp.json` is appended to each iteration's prompt.
  For very large feature decompositions (hundreds of nodes), this may approach agent
  context limits. If this happens, increase `max_iterations` and let the loop resume
  across runs.

### Decompose Files Reference

| File | Purpose |
|------|---------|
| `scripts/decompose-init-prompt.md` | Initialization prompt for the orchestrating agent (steps 1–7) |
| `decomp.json` | Decomposition state tree with nodes and status |
| `prd.json` | Final output — forward-Forge-compatible flat story list |
| `.ralph/decompose-<n>.sh` | Generated decomposition loop script |
| `.ralph/decompose-<n>-prompt.md` | Prompt file for the decomposition loop |

## DRY_RUN — verify wiring without burning tokens

Both generated loop scripts (`.ralph/<name>.sh` and `.ralph/decompose-<n>.sh`) support a
`DRY_RUN=1` env flag. With `DRY_RUN=1`, the script:

1. Runs all preflight checks (jq, agent binary, prd.json/decomp.json validity).
2. On the first iteration, prints the assembled prompt to stdout.
3. Skips the actual agent invocation.
4. Exits 0.

Use this to verify that a freshly-generated loop is wired correctly (prompt file present,
agent binary on PATH, prd.json or decomp.json valid) before paying for tokens:

```bash
DRY_RUN=1 .ralph/my-loop.sh
DRY_RUN=1 .ralph/decompose-my-run.sh
```

The runtime directory (`.ralph/`), runtime files (`.ralph-archive/`, `.ralph-last-branch`),
the branch prefix in legacy `prd.json` files (`ralph/<name>`), and all generated scripts
from v1 are unchanged. Only the slash command and the skill `name:` field are renamed.

## Shared-includes — project-wide prompt content prepended to every iteration

Any `.md` files in `.ralph/_shared/` are concatenated (alphabetical order by filename)
and prepended to the per-iteration prompt for every forward and decompose loop in the
project. If the `.ralph/_shared/` directory does not exist, scripts behave exactly as
before (no-op, backward compatible).

Use this for policy, templates, glossary, evidence rules — anything you want every
iteration of every loop to see without duplicating it across per-loop prompt files.

```text
project/
  .ralph/
    _shared/
      01-policy.md         # prepended first
      02-output-format.md  # prepended second
      03-glossary.md       # prepended third
    add-task-priorities.sh           # forward loop
    add-task-priorities-prompt.md
    decompose-product-x.sh           # decompose loop
    decompose-product-x-prompt.md
```

Both loops above receive all three `_shared/*.md` files prepended to their
per-iteration prompts.

**When generating new loops:** do not create `.ralph/_shared/` automatically — the user
opts in by creating it themselves. Mention it in the post-generation message if the
project's nature suggests shared content would help (e.g., "If you want output-format
or policy rules applied to every iteration, drop them in `.ralph/_shared/*.md`").

**Per-loop shared content** (different shared rules per loop) is supported in pipeline
mode via per-pipeline `.ralph/<pipeline-name>/_shared/` directories. For forward and
decompose modes, use one consolidated `.ralph/_shared/` for the project.

## Pipeline Mode

Triggered by: `/forge pipeline <brief-path-or-description>` or natural language like
"build a pipeline for X", "set up a multi-phase workflow".

### What it does

Pipeline mode generates a multi-phase driver script that orchestrates a sequence of
phases sandwiching a loop:

```
bootstrap (1+ one-shot phases)
  → loop (1+ phases, each iterates a markdown-checklist queue)
    → wrap-up (1+ one-shot phases: aggregate, audit, freeze)
```

Each phase commits to git independently. State lives on disk. Loop phases use fresh
agent context per iteration. Wrap-up phases assume all upstream loops have drained
their queues — if a loop hits `max_iters` without finishing, downstream wrap-ups
are skipped and the user re-runs with `START_AT=<that-phase>` to resume.

Use pipelines when the workflow has setup/teardown around the loop, or when the
output is something other than code commits (specs, audits, docs, research syntheses).

### Inputs accepted

- A markdown brief (e.g., `/forge pipeline @brief.md`)
- A natural-language description ("set up a pipeline to audit Product X against SOC 2")
- Local file paths the brief references

### Agent workflow

Follow the detailed instructions in `scripts/pipeline-init-prompt.md`. The orchestrating
agent:

1. Reads the brief, extracts goal/inputs/output kind.
2. Asks for pipeline name, agent, and model.
3. Designs a 2–6-phase shape (bootstrap → loop → wrap-up), confirms with user.
4. Generates `.ralph/<pipeline-name>/` with `pipeline.json`, `phases/`, `queues/`,
   optional `_shared/`.
5. Generates `.ralph/<pipeline-name>.sh` from `scripts/pipeline.sh`, substituting
   `__AGENT__`, `__MODEL__`, `__PIPELINE_NAME__`.

### `pipeline.json` schema

```json
{
  "name": "my-pipeline",
  "phases": [
    {
      "id": "p01",
      "type": "oneshot",
      "prompt": "phases/p01-bootstrap.md",
      "commit": "bootstrap: setup workspace"
    },
    {
      "id": "p02",
      "type": "loop",
      "prompt": "phases/p02-loop.md",
      "queue": "queues/work.md",
      "commit_prefix": "iter",
      "max_iters": 200
    },
    {
      "id": "p03",
      "type": "oneshot",
      "prompt": "phases/p03-wrapup.md",
      "commit": "wrap-up: aggregate"
    }
  ]
}
```

- `id` must be unique within the pipeline.
- `type` is `oneshot`, `loop`, or `shell`.
- `prompt` and `queue` paths are relative to `.ralph/<pipeline-name>/`.
- `commit` (oneshot/shell) and `commit_prefix` (loop) become git commit messages.
- `max_iters` per phase is optional; falls back to the driver's arg or 200.

### Shell phases — arbitrary scripts (no agent)

For deterministic work that doesn't need an agent — pre-fetching external sources,
running build steps, transforming files — declare a `shell` phase:

```json
{
  "id": "p02",
  "type": "shell",
  "script": "phases/p02-prefetch.sh",
  "commit": "prefetch: external sources"
}
```

The driver:

1. Validates the script exists and is executable.
2. Runs it from `$PROJECT_DIR` with these env vars exported: `PIPELINE_DIR`,
   `PIPELINE_NAME`, `PROJECT_DIR`.
3. On success, commits any changes with the phase's `commit` message.
4. Under `DRY_RUN=1`, prints "would run shell script" and the path; does not execute.

The script chooses its own inputs and outputs. The driver does not preflight the
script's dependencies — the script should fail with a clear error if missing tools.

### Reference: `scripts/prefetch.sh` — hermetic corpus fetcher

A TSV-driven prefetcher for the common pattern of pulling external sources to local
disk before a loop phase reads them. Ships with five source classes:

| class | identifier | output |
|-------|-----------|--------|
| `http_get_md` | URL | `evidence/http_get_md/<slug>.md` (pandoc HTML→markdown; falls back to `.html` if pandoc fails) |
| `github_readme` | `owner/repo` | `evidence/github_readme/<slug>.md` |
| `github_issues_json` | `owner/repo` | `evidence/github_issues_json/<slug>.json` |
| `github_prs_json` | `owner/repo` | `evidence/github_prs_json/<slug>.json` |
| `local_file` | path | `evidence/local_file/<slug>.<original-ext>` |

Manifest format (tab-separated, header row):

```text
class	slug	identifier	notes
http_get_md	intro	https://example.com/docs/intro	intro page
github_readme	readme	owner/repo	repo readme
local_file	internal	docs/spec.md	internal spec
```

Usage in a shell phase script:

```bash
#!/usr/bin/env bash
# .ralph/<pipeline-name>/phases/p02-prefetch.sh
set -euo pipefail
# $PIPELINE_DIR is set by the driver
"${PROJECT_DIR}/scripts/prefetch.sh" \
  "${PIPELINE_DIR}/manifest.tsv" \
  "${PIPELINE_DIR}/evidence"
```

Idempotent — existing outputs are skipped unless `REFRESH=1` is set. Performs its own
preflight: warns up front if `curl`/`pandoc`/`gh` are missing for the classes used.

### Markdown-checklist queue

Loop phases iterate a markdown checklist:

```markdown
- [ ] first pending item
- [ ] second pending item
- [x] completed item
```

Each iteration: driver picks the first `- [ ]` line, invokes the agent. The agent
must flip the line to `- [x]` as its last write. Driver re-checks the queue.

### Phase prompt templates

Default templates live in `scripts/phases/`:
- `bootstrap-prompt.md` — oneshot bootstrap pattern
- `loop-prompt-markdown-queue.md` — loop iteration with markdown queue (includes the
  "you are ONE iteration" framing — keep that verbatim)
- `wrapup-prompt.md` — oneshot wrap-up pattern

The orchestrating agent copies these to `.ralph/<pipeline-name>/phases/` and edits the
"Your task this phase/iteration" section for the specific pipeline.

### Runtime layout

```
project/
  .ralph/
    <pipeline-name>.sh             # generated driver
    <pipeline-name>/
      pipeline.json                # manifest
      _shared/*.md                 # (optional) prepended to every phase prompt
      phases/*.md                  # per-phase prompts
      queues/*.md                  # markdown-checklist queues for loop phases
```

### Env flags

- `DRY_RUN=1` — prints assembled prompts and queue contents for every phase that
  would run; no agent calls, no commits, exits 0.
- `START_AT=<phase-id>` — skip phases before this one. Used to resume after
  interruption or after iterating on later phases.

### Opt-in: provenance and taint guardrails

For pipelines that derive output from external sources where citations matter — specs,
audits, research syntheses, anything making claims about a third party — opt in to
the provenance and taint guardrails. These are templates (no driver changes); they
plug into the shared-includes mechanism.

| Template | Where it goes | What it does |
|----------|--------------|--------------|
| `scripts/phases/provenance-bootstrap.md` | as a bootstrap-type oneshot phase | initializes `provenance-index.md` + empty `risk-and-taint-log.md` |
| `scripts/phases/provenance-rules.md` | `.ralph/<name>/_shared/` | enforces "every claim cites a corpus file" on every phase |
| `scripts/phases/forbidden-paths.md` | `.ralph/<name>/_shared/` | declares forbidden source classes; loop iterations log incidents to the taint log |
| `scripts/phases/red-team-wrapup.md` | as the LAST oneshot wrap-up phase | audits citations, reviews taint log, scans for contamination, writes `red-team-report.md` |

A typical provenance-aware pipeline:

```json
{
  "name": "audit-vendor-x",
  "phases": [
    { "id": "p01", "type": "oneshot", "prompt": "phases/p01-bootstrap.md",     "commit": "bootstrap" },
    { "id": "p02", "type": "oneshot", "prompt": "phases/p02-provenance.md",    "commit": "provenance: init" },
    { "id": "p03", "type": "shell",   "script": "phases/p03-prefetch.sh",      "commit": "prefetch" },
    { "id": "p04", "type": "loop",    "prompt": "phases/p04-loop.md",          "queue": "queues/work.md", "commit_prefix": "iter" },
    { "id": "p05", "type": "oneshot", "prompt": "phases/p05-red-team.md",      "commit": "red-team audit" }
  ]
}
```

With `provenance-rules.md` and `forbidden-paths.md` dropped in `_shared/`, every
phase prompt receives the rules. The red-team wrap-up reads `provenance-index.md`
and `risk-and-taint-log.md` to produce its audit report. A non-empty taint log
does not automatically fail the pipeline — the user reviews each incident.

For pipelines where these don't apply (code-generation workflows that act on
project-internal source), skip the guardrails entirely.

### Files Reference

| File | Purpose |
|------|---------|
| `scripts/pipeline.sh` | Reference driver template (substituted at generation time) |
| `scripts/pipeline-init-prompt.md` | Orchestrating prompt for `/forge pipeline @brief.md` |
| `scripts/phases/bootstrap-prompt.md` | Default oneshot bootstrap template |
| `scripts/phases/loop-prompt-markdown-queue.md` | Default loop-iteration template |
| `scripts/phases/wrapup-prompt.md` | Default oneshot wrap-up template |
| `scripts/phases/provenance-bootstrap.md` | Opt-in: initializes provenance + taint files |
| `scripts/phases/provenance-rules.md` | Opt-in `_shared/` template: source-citation enforcement |
| `scripts/phases/forbidden-paths.md` | Opt-in `_shared/` template: forbidden sources + taint protocol |
| `scripts/phases/red-team-wrapup.md` | Opt-in wrap-up template: audits citations + taint log |
| `scripts/prefetch.sh` | Reference TSV-driven prefetcher for shell phases |
| `.ralph/<name>/pipeline.json` | Generated manifest |
| `.ralph/<name>.sh` | Generated driver script |
