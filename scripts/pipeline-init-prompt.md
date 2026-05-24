You are running the initialization phase of Forge pipeline mode.

## What pipeline mode is

A pipeline is an ordered sequence of phases. The typical shape:

```
bootstrap   (1+ one-shot phases — scaffold dirs, seed queues)
  → pre-fetch (optional shell phase — pull external corpus to local disk)
    → loop  (1+ phases — iterate a markdown-checklist queue, fresh context per item)
      → wrap-up (1+ one-shot phases — aggregate, audit, freeze)
```

**Phase types available:**

- `oneshot` — agent invoked once with a prompt; driver commits any changes
- `loop` — agent invoked per pending item in a markdown-checklist queue
- `shell` — arbitrary script (no agent); ideal for pre-fetching external sources,
  build steps, file transforms. Script receives `PIPELINE_DIR`, `PIPELINE_NAME`,
  `PROJECT_DIR` as env vars.

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

For pipelines that derive output from external sources where citations matter
(specs, audits, research syntheses, anything making claims about a third party),
also consider these opt-in templates:
- `provenance-bootstrap.md` — a bootstrap-type oneshot that initializes
  `provenance-index.md` and `risk-and-taint-log.md` at the pipeline root.
- `provenance-rules.md` — drop in `.ralph/<pipeline-name>/_shared/` to enforce
  source-citation rules on every phase.
- `forbidden-paths.md` — drop in `.ralph/<pipeline-name>/_shared/` for workflows
  with forbidden source classes (proprietary code, privileged docs, secrets).
  Edit the "Forbidden paths for this pipeline" section with the user's actual
  constraints.
- `red-team-wrapup.md` — a wrap-up oneshot that audits citations and verifies
  the taint log. Use as the LAST phase when provenance or taint guardrails apply.

Ask the user up front whether the workflow needs provenance/taint enforcement.
If yes, generate the additional bootstrap, shared, and wrap-up phases.

Replace the `<!-- AI generating the pipeline: ... -->` comments in those templates with
the concrete task for this pipeline. The "ONE iteration" framing in the loop template
is load-bearing — keep it verbatim. Only edit the "Your task this iteration" section.

For shell phases (e.g., pre-fetch), the user writes the script directly. If the brief
implies pulling external sources (URLs, GitHub repos, docs sites), use the reference
prefetcher at `scripts/prefetch.sh` plus a TSV manifest. Generate a shell phase that
invokes it:

```bash
#!/usr/bin/env bash
# .ralph/<pipeline-name>/phases/p02-prefetch.sh
set -euo pipefail
"${PROJECT_DIR}/scripts/prefetch.sh" \
  "${PIPELINE_DIR}/manifest.tsv" \
  "${PIPELINE_DIR}/evidence"
```

Generate the matching `manifest.tsv` from the brief's source list (tab-separated, one
row per source: `class<TAB>slug<TAB>identifier<TAB>notes`). See `scripts/prefetch.sh`
for the supported classes (`http_get_md`, `github_readme`, `github_issues_json`,
`github_prs_json`, `local_file`).

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
