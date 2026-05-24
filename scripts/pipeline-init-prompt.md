You are running the initialization phase of Forge pipeline mode.

## What pipeline mode is

A pipeline is an ordered sequence of phases sandwiching a loop:

```
bootstrap (1+ one-shot phases)
  → loop (1+ phases, each iterates a markdown-checklist queue)
    → wrap-up (1+ one-shot phases: aggregate, audit, freeze)
```

Each phase commits to git independently. State lives on disk. Loop phases use fresh
agent context per iteration. Wrap-up phases assume all upstream loops have drained.

Use pipelines when the workflow has setup/teardown around the loop, or when the output
is something other than code commits (specs, audits, docs, research syntheses).

## Step 1: Understand the brief

The user has provided a brief: `{{BRIEF}}`. Read it fully. Extract:

- **Goal:** what is the final deliverable?
- **Inputs:** what feeds the pipeline (URLs, local files, source code, descriptions)?
- **Phases the brief implies:**
  - Bootstrap: what setup, scaffolding, or queue seeding is needed?
  - Loop: what is the unit of repeated work? What does the queue contain?
  - Wrap-up: what aggregation, audit, or finalization is needed?
- **Output kind:** code, spec, audit, docs, research — affects the phase prompt content.

If anything is unclear, ask the user clarifying questions before proceeding.

## Step 2: Ask configuration questions

Ask these in order:

1. "What should we name this pipeline?" (kebab-case, used for filenames)
2. "Which execution agent?" (claude / droid / codex / opencode / gemini / copilot / cc-compatible / custom)
3. "Which model?" (optional — blank for CLI default)

## Step 3: Design the phase list

Propose 2–6 phases. A typical shape:

- `p01` (oneshot): bootstrap — create directory structure, seed queue, write skeletons
- `p02` (loop): the main repeated work — one queue item per iteration
- `p03` (oneshot): wrap-up — aggregate outputs, write final deliverable

If the workflow needs more (e.g., a pre-loop validation phase, a post-loop audit, a
freeze phase), add them. Show the user the proposed phase list and confirm before
generating files.

## Step 4: Generate pipeline files

Create the following under `.ralph/<pipeline-name>/`:

```
.ralph/<pipeline-name>/
├── pipeline.json           # the manifest
├── _shared/                # (optional, can be empty) — prepended to every phase prompt
├── phases/
│   ├── p01-bootstrap.md    # one prompt file per phase
│   ├── p02-loop.md
│   └── p03-wrapup.md
└── queues/
    └── work.md             # markdown checklist for the loop phase
```

`pipeline.json` schema:

```json
{
  "name": "my-pipeline",
  "phases": [
    {
      "id": "p01",
      "type": "oneshot",
      "prompt": "phases/p01-bootstrap.md",
      "commit": "bootstrap: <describe>"
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
      "commit": "wrap-up: <describe>"
    }
  ]
}
```

Notes:
- `id` must be unique within the pipeline; conventional format is `p01`, `p02`, etc.
- `prompt` and `queue` paths are relative to `.ralph/<pipeline-name>/`.
- `max_iters` per phase is optional; falls back to the driver's arg or 200.
- `commit` (oneshot) and `commit_prefix` (loop) become git commit messages.

For each phase prompt, start from the templates in `scripts/phases/`:
- `bootstrap-prompt.md` for bootstrap-type oneshots
- `loop-prompt-markdown-queue.md` for loop phases
- `wrapup-prompt.md` for wrap-up oneshots

Replace the `<!-- AI generating the pipeline: ... -->` comments in those templates with
the concrete task for this pipeline. The "ONE iteration" framing in the loop template
is load-bearing — keep it verbatim. Only edit the "Your task this iteration" section.

For the queue file (`queues/work.md`), seed it with the initial items from the brief
(or leave it empty if the bootstrap phase will populate it):

```markdown
- [ ] first item
- [ ] second item
- [ ] third item
```

## Step 5: Generate the driver script

Copy `scripts/pipeline.sh` to `.ralph/<pipeline-name>.sh`. Substitute:
- `__AGENT__` with the chosen agent
- `__MODEL__` with the chosen model (empty string if none)
- `__PIPELINE_NAME__` with the pipeline name

Make the script executable: `chmod +x .ralph/<pipeline-name>.sh`.

## Step 6: Update .gitignore

Add `.ralph/` to `.gitignore` if not already present.

## Step 7: Instruct the user

Tell the user:

- Pipeline `<pipeline-name>` is ready under `.ralph/<pipeline-name>/`.
- Inspect with `DRY_RUN=1 .ralph/<pipeline-name>.sh` (prints all assembled prompts; no
  agent calls, no commits).
- Run for real with `.ralph/<pipeline-name>.sh [max_iters]` (default 200).
- Resume after interruption with `START_AT=<phase-id> .ralph/<pipeline-name>.sh`.
- If a loop phase hits `max_iters` without draining the queue, downstream wrap-up
  phases are skipped (they assume the loop is done). Re-run with `START_AT=<that-id>`.
