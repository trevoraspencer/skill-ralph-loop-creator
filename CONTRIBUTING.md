# Contributing

Thanks for your interest. Forge is small and the contribution loop is meant to be
fast: read the existing code (it's ~1500 LoC of bash + markdown), make a focused
change, run the tests, open a PR.

## Repo orientation

```
.
├── SKILL.md                          # the skill itself — main user-facing instructions
├── README.md                         # install + quickstart + comparison to other tools
├── TROUBLESHOOTING.md                # symptom → fix catalog
├── ERRORS.md                         # append-only changelog of fixes and scoping notes
├── LICENSE                           # MIT
├── examples/
│   ├── README.md
│   └── briefs/                       # example pipeline briefs users can copy
├── scripts/
│   ├── ralph.sh                      # forward-mode reference driver (substituted at gen time)
│   ├── prompt.md                     # forward-mode prompt
│   ├── decompose.sh                  # decompose-mode reference driver
│   ├── decompose-prompt.md           # decompose per-iteration prompt
│   ├── decompose-init-prompt.md      # decompose orchestration prompt
│   ├── pipeline.sh                   # pipeline-mode reference driver
│   ├── pipeline-init-prompt.md       # pipeline orchestration prompt
│   ├── prefetch.sh                   # reference TSV-driven prefetcher
│   ├── phases/                       # default per-phase prompt templates
│   └── test-template.sh              # full smoke suite (currently 26 tests)
└── .github/workflows/test.yml        # CI: runs smoke suite + shellcheck
```

## Local development setup

```bash
# Required for tests
brew install jq                       # macOS
sudo apt install jq                   # Debian/Ubuntu

# Required for the shellcheck CI job (run before pushing if you touched scripts/)
brew install shellcheck               # macOS
sudo apt install shellcheck           # Debian/Ubuntu
```

## Running the test suite

```bash
./scripts/test-template.sh
```

The suite is intentionally a single executable bash file with numbered tests
(currently 26). Each test sets up its own temp dir, renders a script from the
relevant template, exercises a specific behavior, and asserts on output. Tests
that need a real git repo use the `init_git_repo` helper, which disables commit
signing locally because some CI sandboxes can't reach external signing servers.

CI runs the same script via `.github/workflows/test.yml`. Two jobs: the smoke
suite and `shellcheck -x` over every `*.sh` in `scripts/`. PRs must pass both.

## Adding a new test

1. Pick the next free `TMP<n>` slot at the top of `scripts/test-template.sh`,
   add `TMP<n>="$(mktemp -d)"` and extend the cleanup `trap`.
2. Add a `# Test N:` block in the relevant section (forward / decompose /
   pipeline / shell / etc.). Each test should fit on one screen and assert on
   one specific behavior.
3. Run `./scripts/test-template.sh` — it should pass.
4. If the test would fail without your change, you're doing TDD right. If it
   passes immediately, double-check it's actually testing the new behavior.

## Adding a new agent

The supported agent matrix lives in three places. Add a case arm to each:

1. `SKILL.md` — agent list in Step 2a, headless command templates
2. `scripts/ralph.sh` — `AGENT_COMMAND_HERE` placeholder is filled at generation
   time; document the command template in the comments above the placeholder
3. `scripts/decompose.sh` — `case "$AGENT" in ... esac`
4. `scripts/pipeline.sh` — `run_agent()` function's case statement
5. `README.md` — Supported Execution Agents table

Add at least one smoke test that exercises the new case arm (via render +
custom-agent invocation pattern in `test-template.sh`).

## Adding a new phase type

Currently `oneshot`, `loop`, `shell`. To add another:

1. Extend the jq schema check in `scripts/pipeline.sh` to accept the new type
2. Add a `run_<type>_phase()` function
3. Wire it into the main dispatch `case "$ptype" in ... esac`
4. Document the new type in `SKILL.md` (Pipeline Mode section)
5. Add at least one smoke test under "Pipeline mode smoke tests" in
   `scripts/test-template.sh`
6. Consider whether the orchestrating `scripts/pipeline-init-prompt.md` should
   mention the new type

## Conventions

- Shebang: `#!/usr/bin/env bash`
- Top of every script: `set -euo pipefail`
- JSON manipulation: `jq` (already a dep) with `--arg` for user-controlled values
- Idempotent operations — re-running should be safe
- Graceful errors that never mask success (existing `finalize()` is a good model)
- Update `ERRORS.md` for every fix and significant decision (scoping, deferrals,
  reversals) — it's the project's change log and decision record

### Bash hardening notes

- Never use `trap '...' RETURN` with `local` variables — global trap fires from
  unrelated returns under `set -u`. Use explicit cleanup at each `return` site,
  or `trap '...' EXIT` for whole-script cleanup.
- Avoid `cmd && { block; } || log "skipping"` — failure inside `&&` falls through
  to `||`. Use `if/then/else` explicitly.
- Validate user-controlled strings before `sed`/`eval`/path construction
  (`decompose.sh`'s `N-<digits>` node-ID check is the pattern).
- For false-positive shellcheck warnings, use inline
  `# shellcheck disable=SC<code>` with a comment explaining WHY it's a false
  positive — don't suppress it project-wide.

## PR style

- Keep PRs small enough to review in one sitting (~50–500 LoC ideal).
- Write the commit message as if explaining the change to a colleague who hasn't
  seen the PR — what changed, why, what was deferred.
- Update `ERRORS.md` for anything substantive (bug fix, scoping change, deferred
  work). Append; don't rewrite past entries.
- If the change is docs-only, say so in the PR — reviewers can skip running tests.

## Filing issues

See [TROUBLESHOOTING.md](TROUBLESHOOTING.md) first — it covers the most common
failure modes. For anything not covered there, include:

- Which mode (forward / decompose / pipeline)
- Output of `DRY_RUN=1 .ralph/<your-script>.sh`
- Relevant `prd.json` / `decomp.json` / `pipeline.json`
- Agent + model in use
