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
