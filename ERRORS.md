# Repo Evaluation: Errors and Inconsistencies

All issues identified below have been fixed. This file is retained for reference.

## v2 changelog

### Renamed: `/ralph` → `/forge`

The skill's `name:` field and slash command were renamed to disambiguate from
Anthropic's official `/ralph-loop` plugin (which uses an in-session re-feed pattern,
not the external bash loop this skill generates). Repo name stays
`skill-ralph-loop-creator` for SEO and continuity. Natural-language triggers ("use
ralph to …", "reverse ralph this") are preserved in the skill description for
muscle-memory continuity. Runtime directories (`.ralph/`, `.ralph-archive/`,
`.ralph-last-branch`) and generated v1 scripts are unchanged.

### Added: `DRY_RUN=1` flag

Both `scripts/ralph.sh` and `scripts/decompose.sh` now honor `DRY_RUN=1` as an env
flag. When set: the script runs all preflight checks, prints the assembled prompt
for the first iteration to stdout, skips the agent invocation, and exits 0. Lets
users verify a freshly-generated loop is wired correctly (prompt file present,
agent binary on PATH, prd.json/decomp.json valid) without burning tokens.

Two new smoke tests in `scripts/test-template.sh` (Test 11 forward, Test 12
decompose) assert that the agent command does not execute and the prompt content
is printed.

### Deferred from v2 to PR 3

`START_AT=<phase-id>` was bundled with DRY_RUN in the original PR 1 plan, but
"phase" has no meaning in the v1 forward and decompose modes — those scripts
iterate over a queue of stories/nodes, not phases. Adding `START_AT` with bolted-on
"skip earlier stories" semantics would create a new behavior with no real-world
demand. Deferred to PR 3 where it lands alongside the multi-phase pipeline driver
and has a natural fit.

### Added: shared-includes (`.ralph/_shared/*.md`)

Any `.md` files in `.ralph/_shared/` are concatenated alphabetically and prepended
to the per-iteration prompt for every forward and decompose loop in the project.
If the directory does not exist, scripts behave exactly as before (no-op, BC).

Implementation details:

- `scripts/ralph.sh` adds a `build_iter_prompt()` helper called at the top of each
  iteration. If `_shared/*.md` files exist, it concatenates them with the base prompt
  into a temp file and reassigns `PROMPT_FILE` to point at the temp. If no shared
  content exists, `PROMPT_FILE` stays pointed at the original base prompt (no temp
  file, no behavior change). A cleanup trap removes the temp file on exit.
- `scripts/decompose.sh` extends the existing `ITER_PROMPT_FILE` assembly to write
  shared content first, then append the sed-substituted per-iteration prompt and
  decomp.json. The existing cleanup trap handles temp file removal.

Three new smoke tests in `scripts/test-template.sh`:

- Test 13: forward with `_shared/` — asserts content prepended in alphabetical order.
- Test 14: forward without `_shared/` — asserts BC (base prompt unchanged).
- Test 15: decompose with `_shared/` — asserts content prepended before per-iteration
  prompt and decomp.json state.

**Scope deferred to pipeline mode (PR 3):** per-loop shared content (different shared
rules per loop). For v1 modes, one consolidated project-wide `_shared/` is sufficient
for the common case.

### Added: pipeline mode (`/forge pipeline @brief.md`)

Multi-phase pipeline driver that orchestrates a sequence of phases sandwiching a
loop: bootstrap (1+ oneshot phases) → loop (1+ phases with markdown-checklist queues)
→ wrap-up (1+ oneshot phases). Each phase commits independently.

New files:

- `scripts/pipeline.sh` — reference driver template with `__AGENT__`, `__MODEL__`,
  `__PIPELINE_NAME__` placeholders. Supports `oneshot` and `loop` phase types. Honors
  `DRY_RUN=1` (skip agent calls, print prompts + queues) and `START_AT=<phase-id>`
  (resume from a specific phase).
- `scripts/pipeline-init-prompt.md` — orchestrating prompt that reads the user's
  brief, asks configuration questions, designs the phase shape, and generates the
  pipeline files.
- `scripts/phases/bootstrap-prompt.md`, `loop-prompt-markdown-queue.md`,
  `wrapup-prompt.md` — default phase prompt templates the orchestrating agent
  starts from. The loop template's "you are ONE iteration" framing is load-bearing
  and must not be edited.

Runtime layout:

```
.ralph/
  <pipeline-name>.sh             # generated driver
  <pipeline-name>/
    pipeline.json                # manifest
    _shared/*.md                 # (optional) per-pipeline shared content
    phases/*.md                  # per-phase prompts
    queues/*.md                  # markdown-checklist queues for loop phases
```

Key behavior: if a loop phase hits `max_iters` without draining its queue, the
driver exits 0 immediately and downstream wrap-up phases are NOT run. Wrap-up
phases assume the loop is complete, so running them on an incomplete loop would
produce wrong output. User re-runs with `START_AT=<that-phase-id>` to resume.

Six new smoke tests in `scripts/test-template.sh` (Tests 16-21):

- Test 16: pipeline DRY_RUN over a 3-phase pipeline (oneshot, loop, oneshot).
- Test 17: `START_AT=p02` skips p01.
- Test 18: missing `pipeline.json` fails preflight.
- Test 19: invalid `pipeline.json` schema fails preflight.
- Test 20: real-run loop phase hitting `max_iters` with non-empty queue blocks
  downstream wrap-up phase (uses init_git_repo helper that disables commit signing).
- Test 21: pipeline `_shared/*.md` prepended to per-phase prompts (alphabetical
  order, before base prompt).

`START_AT` (previously deferred from PR 1) ships here with its natural home in
multi-phase pipelines.

**Deferred to PR 4:** `shell` phase type for arbitrary scripts (e.g., pre-fetch
external sources before the loop runs). Adds `curl`/`pandoc` to the preflight when
the pipeline includes shell phases.

### Added: `shell` phase type + reference prefetcher

Extends pipeline mode with `shell` as a third phase type. A shell phase runs an
arbitrary script (no agent) from `$PROJECT_DIR` with `PIPELINE_DIR`, `PIPELINE_NAME`,
and `PROJECT_DIR` exported as env vars. After the script exits 0, the driver commits
any changes with the phase's `commit` message. Under `DRY_RUN=1`, the script does
NOT execute — driver prints "would run shell script" and the path.

Use cases: pre-fetch external corpus to local disk (so loop iterations are
deterministic and don't burn rate limits), run build/transform steps, finalize
deliverables that don't need agent involvement.

`scripts/pipeline.sh` changes:

- Schema accepts `"type": "shell"` alongside `oneshot` and `loop`.
- New `run_shell_phase()` validates the script is present and executable, runs it
  with env vars exported, then commits.
- Main dispatch case adds the `shell` branch.

`scripts/prefetch.sh` (new) — TSV-driven prefetcher with five source classes:

- `http_get_md` — curl + pandoc (HTML→markdown) with raw-HTML fallback on pandoc failure
- `github_readme` — `gh api repos/<owner>/<repo>/readme` raw
- `github_issues_json` — `gh issue list --json` (all states, limit 2000)
- `github_prs_json` — `gh pr list --json` (all states, limit 2000)
- `local_file` — `cp` from a project-local path

Manifest format: tab-separated, one header row, columns `class\tslug\tidentifier\tnotes`.
Outputs go to `<evidence-dir>/<class>/<slug>.<ext>`. Idempotent — existing outputs
are skipped unless `REFRESH=1`. The prefetcher does its own preflight: it warns
up front if `curl`/`pandoc`/`gh` are missing for the classes the manifest uses.

GitHub Discussions class (which needs GraphQL pagination) is deferred — users who
need it can adapt the script.

Four new smoke tests in `scripts/test-template.sh`:

- Test 22: pipeline shell phase DRY_RUN does not execute the script.
- Test 23: pipeline shell phase real run executes the script, writes files, commits.
- Test 24: shell phase with missing script fails preflight.
- Test 25: `prefetch.sh` handles the `local_file` class end-to-end (no network).

`http_get_md`, `github_*` classes aren't tested in CI here because they need
network or GitHub auth. They'll be exercised when the prefetcher is used in real
pipelines.

### Added: provenance + taint guardrail templates (opt-in)

Four new opt-in templates under `scripts/phases/` for pipelines that derive output
from external sources where citations matter (specs, audits, research syntheses,
anything decomposing or auditing a third party):

- `provenance-bootstrap.md` — bootstrap-type oneshot that initializes
  `provenance-index.md` (skeleton table mapping local paths → source URLs → fetch
  dates) and `risk-and-taint-log.md` (empty append-only log).
- `provenance-rules.md` — drops in `.ralph/<pipeline-name>/_shared/`. Enforces
  "every non-obvious claim cites at least one corpus file" on every phase via the
  shared-includes mechanism shipped in PR 2.
- `forbidden-paths.md` — drops in `.ralph/<pipeline-name>/_shared/`. Declares the
  forbidden source classes for the pipeline (e.g., `src/proprietary/**`, secrets,
  privileged docs). If an iteration accidentally touches a forbidden path, it logs
  the incident to the taint log, discards what was absorbed, and continues. The
  pipeline doesn't auto-fail on a non-empty taint log — the red-team wrap-up
  surfaces each incident for human review.
- `red-team-wrapup.md` — wrap-up oneshot that audits citations (every claim cited,
  every cited file in the index, every index entry exists on disk, every citation
  supports its claim), reviews the taint log, scans for contamination by pattern,
  and writes `red-team-report.md`.

No driver changes. No `pipeline.json` schema changes. Everything composes via the
existing shared-includes mechanism (PR 2) and ordinary oneshot/wrap-up phases.

**Scoping note:** the original plan also listed `output_kind` (code/spec/audit/docs/
research per-kind defaults) as a possible future PR. Skipped as a premature
abstraction — users compose specific templates (like the four above) instead of
selecting from a closed enum of "kinds." If a clear pattern emerges from real-world
use of these templates, an `output_kind` field can be added later without breaking
anything.

**Scoping note (PR 5 from original plan):** the "markdown-checklist queue as an
alternative to JSON state" was subsumed by PR 3, which shipped markdown queue as
the PRIMARY queue type for pipeline loops. The original framing (JSON primary,
markdown alternative) became inverted in practice. Existing decompose mode keeps
its hierarchical JSON state (`decomp.json`) since hierarchy doesn't fit a flat
checklist anyway.

### Added: GitHub Actions CI

`.github/workflows/test.yml` runs `scripts/test-template.sh` on every push to
`main` and every pull request. Installs `jq` (the only test dependency not
pre-installed on `ubuntu-latest`) and configures a global git identity so
`init_git_repo`'s initial commit succeeds in test temp dirs.

Plan items 1–5 (and this CI add-on) shipped the foundation. Beyond this is
user-driven discovery from real pipeline runs — anything substantive should
update `ERRORS.md` honestly and ship as its own small reviewable PR.

## Critical (fixed)

### 1. Decompose `prd.json` output was incompatible with forward Ralph

**Problem:** `decompose.sh` emitted `{feature, stories}` with `acceptance_criteria`
(snake_case). Forward Ralph validates for `{branchName, userStories}` with
`acceptanceCriteria` (camelCase). Running forward Ralph on decompose output failed
at preflight.

**Fix:** Updated `decompose.sh` jq query to emit forward-Ralph-compatible schema:
`branchName` (derived from feature name), `userStories`, `acceptanceCriteria`,
`notes`, and `passes` fields. Added a test assertion verifying schema compatibility.

---

## Moderate (fixed)

### 2. `decompose.sh` custom agent got wrong prompt variable

**Problem:** `eval "$CUSTOM_CMD"` exposed `$PROMPT_FILE` (base template) instead of
`$ITER_PROMPT_FILE` (per-iteration prompt with node ID and decomp.json appended).

**Fix:** Wrapped custom eval in a subshell that overrides `PROMPT_FILE` to
`$ITER_PROMPT_FILE`.

### 3. README "Repo Layout" section was incomplete

**Problem:** Missing `scripts/decompose.sh`, `scripts/decompose-prompt.md`, and
`scripts/decompose-init-prompt.md`.

**Fix:** Added all three files to the Repo Layout section.

### 4. `decompose-init-prompt.md` was unreferenced

**Problem:** The file existed but was never mentioned in `SKILL.md` or `README.md`.

**Fix:** Added reference in SKILL.md decompose agent workflow and Decompose Files
Reference table. Added to README Repo Layout.

### 5. "CC-Mirror" vs "cc-compatible" naming

**Problem:** `ralph.sh` line 226 used stale name "CC-Mirror".

**Fix:** Renamed to "CC-compatible" to match all other files.

---

## Minor (fixed)

### 6. Inconsistent shebang lines

**Problem:** `ralph.sh` used `#!/bin/bash` while other scripts used
`#!/usr/bin/env bash`.

**Fix:** Changed `ralph.sh` to `#!/usr/bin/env bash`.

### 7. Placeholder conventions

Three different placeholder styles exist across the project (`AGENT_BIN_HERE`,
`__AGENT__`, `{{INPUTS}}`). Each serves a different substitution mechanism (AI
template reading, sed, agent prompt interpolation), so this is by design and was
left as-is.

### 8. Relative vs absolute path construction in `decompose.sh`

**Problem:** `decompose.sh` used relative paths from CWD, breaking if run from a
subdirectory.

**Fix:** Added `SCRIPT_DIR`/`PROJECT_DIR` computation (matching `ralph.sh`) and
derived all paths as absolute.

### 9. No sleep between decompose iterations

**Problem:** `ralph.sh` has `sleep 2` between iterations; `decompose.sh` did not.

**Fix:** Added `sleep 2` after each iteration in `decompose.sh`.
