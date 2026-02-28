# Repo Evaluation: Errors and Inconsistencies

## Critical

### 1. Decompose `prd.json` output is incompatible with forward Ralph

The decompose pipeline claims to produce "forward-Ralph-compatible" output
(`SKILL.md` Decompose Files Reference, `decompose-init-prompt.md` Step 7), but the
schemas are fundamentally mismatched.

**Forward Ralph expects** (validated in `ralph.sh:51-57`):

```json
{
  "branchName": "ralph/feature",
  "userStories": [
    {
      "acceptanceCriteria": ["..."],
      "notes": "",
      "passes": false
    }
  ]
}
```

**Decompose emits** (`decompose.sh:199-212`):

```json
{
  "feature": "...",
  "stories": [
    {
      "acceptance_criteria": ["..."],
      "depends_on": [],
      "passes": false
    }
  ]
}
```

Specific mismatches:

| Field | Forward Ralph | Decompose Output |
|-------|--------------|-----------------|
| Top-level key for stories | `userStories` | `stories` |
| Top-level project identifier | `project` + `branchName` (required) | `feature` (no `branchName`) |
| Acceptance criteria key | `acceptanceCriteria` (camelCase) | `acceptance_criteria` (snake_case) |
| Notes field | `notes` (present) | missing |
| Dependencies field | missing | `depends_on` (present) |

Running forward Ralph on decompose output **fails immediately** at the `ralph.sh`
preflight check with: *"Error: prd.json is invalid. It must include non-empty string
branchName and array userStories."*

---

## Moderate

### 2. `decompose.sh` custom agent gets wrong prompt variable

In `decompose.sh:163-164`, the `custom` agent case runs `eval "$CUSTOM_CMD"`. Per
SKILL.md, custom commands reference `$PROMPT_FILE`. But inside the decompose loop,
`PROMPT_FILE` (line 9) points to the base template, while the actual per-iteration
prompt (with node ID substituted and `decomp.json` appended) is `ITER_PROMPT_FILE`.
Every other agent branch correctly uses `$ITER_PROMPT_FILE`.

### 3. README "Repo Layout" section is incomplete

`README.md:135-139` lists only 4 files. Missing:

- `scripts/decompose.sh` — the decompose loop template
- `scripts/decompose-prompt.md` — the per-iteration decompose prompt
- `scripts/decompose-init-prompt.md` — the decompose initialization prompt

### 4. `decompose-init-prompt.md` is unreferenced

The file `scripts/decompose-init-prompt.md` exists but is never mentioned in
`SKILL.md` or `README.md`. The SKILL.md decompose workflow (Step 6) mentions copying
`scripts/decompose.sh` and `scripts/decompose-prompt.md` but never references the
init prompt. It is unclear how the agent should use this file.

### 5. "CC-Mirror" vs "cc-compatible" naming

`ralph.sh:226` uses the name `CC-Mirror` in its comment block. Every other file
(`SKILL.md`, `README.md`, `decompose.sh`) consistently calls this `cc-compatible`.

---

## Minor

### 6. Inconsistent shebang lines

- `ralph.sh`: `#!/bin/bash`
- `decompose.sh`, `test-template.sh`: `#!/usr/bin/env bash`

### 7. Inconsistent placeholder conventions

Three different placeholder styles:

- `ralph.sh`: `AGENT_BIN_HERE` / `AGENT_COMMAND_HERE`
- `decompose.sh`: `__AGENT__` / `__MODEL__` / `__LOOP_NAME__`
- `decompose-init-prompt.md`: `{{INPUTS}}`

### 8. Relative vs absolute path construction

`ralph.sh` builds absolute paths from `SCRIPT_DIR`. `decompose.sh` uses relative
paths from CWD (`PROMPT_FILE=".ralph/decompose-${LOOP_NAME}-prompt.md"`). Running
`decompose.sh` from a subdirectory would break all paths.

### 9. No sleep between decompose iterations

`ralph.sh:250` has `sleep 2` between iterations (documented in SKILL.md).
`decompose.sh` has no sleep, risking API rate-limiting with high iteration counts.
