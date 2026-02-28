# Repo Evaluation: Errors and Inconsistencies

All issues identified below have been fixed. This file is retained for reference.

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
