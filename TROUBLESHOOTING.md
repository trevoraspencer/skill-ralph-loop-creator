# Troubleshooting

Common failure modes when running Forge loops and pipelines, and how to fix them.
Organized by symptom.

## The skill doesn't load / `/forge` is not available

- Verify install path and folder name (`forge`), then restart your CLI session.
  See [README install instructions](README.md#install-this-skill).
- If you typed `/ralph` (the old name): that's expected to no longer work after the
  rename to `/forge`. Natural-language triggers ("use ralph to ...") are still
  preserved for muscle-memory.

## `jq: command not found`

```bash
brew install jq        # macOS
sudo apt install jq    # Debian/Ubuntu
```

Every generated loop and pipeline script preflights for `jq`.

## `agent binary '<name>' is not installed or not on PATH`

The script verifies the configured agent CLI exists before starting the loop.
Install the CLI and authenticate, then re-run. For `cc-compatible` agents, ensure
`CC_BINARY=<name>` is exported. For `custom` agents, ensure `CUSTOM_CMD` is set.

## The agent runs but doesn't make changes

### Forward / decompose loops

Check the agent's stdout (the script `tee`s it to your terminal). Common causes:

- **Wrong working directory** — agent CLIs cd into the project root by default, but
  some custom commands don't. Verify the agent saw `prd.json` (or `decomp.json`).
- **Permission prompts blocking the run** — the headless templates pass
  `--dangerously-skip-permissions` (claude, cc-compatible), `--skip-permissions-unsafe`
  (droid), or `--yolo` (codex/opencode/gemini/copilot) to suppress prompts. If you
  edited the agent command, ensure the equivalent flag is still present.
- **Agent picked a story it can't finish** — check the `notes` field in `prd.json`
  for that story. The agent should have written what went wrong.

### Pipeline loops

- Look at `progress.txt` (forward) or `red-team-report.md` (pipeline with red-team
  wrap-up) for what the agent actually attempted.
- Use `DRY_RUN=1` to inspect the assembled prompt — see "the prompt isn't what I
  expected" below.

## The prompt isn't what I expected — use `DRY_RUN=1`

Every loop script supports `DRY_RUN=1`. It runs preflight, prints the assembled
prompt for the first iteration to stdout, skips the agent call, and exits 0:

```bash
DRY_RUN=1 .ralph/my-loop.sh
DRY_RUN=1 .ralph/decompose-X.sh
DRY_RUN=1 .ralph/my-pipeline.sh
```

For pipelines, `DRY_RUN=1` walks every phase that would run (honoring `START_AT`),
prints the assembled prompt and queue contents for each, but executes nothing.

If the output isn't what you expected, the cause is usually one of:

- A `_shared/*.md` file you forgot you dropped in — they prepend in alphabetical
  order to every iteration.
- Wrong prompt file path in `pipeline.json` — paths are relative to `.ralph/<name>/`.
- A stale prompt in `.ralph/<name>-prompt.md` — re-running `/forge` regenerates it.

## A `loop` phase runs forever or hits `max_iters` repeatedly

The agent must flip the line it processed from `- [ ]` to `- [x]` as its LAST write
of the iteration. The driver checks the queue file after each iteration; if no item
was flipped, the same item gets picked again and the loop appears to spin.

To diagnose:

1. Run `DRY_RUN=1` to confirm the prompt clearly instructs the agent to flip the
   checkbox as the last write.
2. After a real iteration, check the queue file's most recent commit (`git log -1 -p
   queues/<file>.md`). The diff should show one line going `- [ ]` → `- [x]`.
3. If the diff shows the agent edited the wrong line or used the wrong character
   (e.g., `[X]` capital instead of `[x]`), tighten the prompt's instruction.

If `max_iters` was hit with the queue still non-empty, the driver exits 0 and skips
downstream wrap-up phases. Re-run with `START_AT=<phase-id>` to resume.

## `Phase <id> hit max_iters with queue not empty` — what now?

This is the driver's "skip wrap-up" safety: if the loop didn't finish, downstream
wrap-up phases assume something they don't have (a drained queue, complete outputs).
Re-run with `START_AT` pointing at the same loop phase:

```bash
START_AT=p03 .ralph/my-pipeline.sh 500
```

The second arg (`500` here) overrides `max_iters` for loop phases if you need more
budget than the default 200.

## Auto-push or PR creation does nothing (forward mode)

- Ensure you're on a non-default branch (i.e., not `main`/`master`) with commits.
  The `finalize()` function skips if you're on the default branch.
- Install and authenticate `gh` for PR creation — `gh auth login`. The script
  detects `gh` and falls back to printing manual instructions if it's missing.

## Commit signing failures in tests (sandbox/CI)

`init_git_repo` in `scripts/test-template.sh` disables `commit.gpgsign` locally for
test temp repos. If you ported tests elsewhere and hit a `signing failed:` error,
ensure the test setup includes:

```bash
git config commit.gpgsign false
git config gpg.format ""
```

The `pipeline.sh` driver does NOT disable signing — production users with signing
enabled should keep it enabled. Tests bypass it because most CI sandboxes can't
reach an external signing server.

## Shellcheck fails on my custom phase script

Shell phases (`type: shell`) are user-written; the CI shellcheck job only covers
files in `scripts/`. If you want shellcheck on phase scripts too, run it locally
before committing:

```bash
shellcheck -x .ralph/<pipeline-name>/phases/*.sh
```

## Where is the state?

| Mode | State location |
|------|----------------|
| forward (legacy/v1) | `prd.json`, `progress.txt`, git commits |
| decompose | `decomp.json` (tree); emits `prd.json` when complete |
| pipeline | `.ralph/<pipeline-name>/pipeline.json` + per-phase `queues/*.md` + per-phase output files; git commits per phase |
| shared content | `.ralph/_shared/` (forward/decompose) or `.ralph/<pipeline-name>/_shared/` (pipeline) |
| provenance/taint | `.ralph/<pipeline-name>/provenance-index.md` + `.ralph/<pipeline-name>/risk-and-taint-log.md` |

Everything except the git commits is on disk and can be inspected, edited, or
deleted directly. Re-running picks up wherever the state is.

## When `ERRORS.md` doesn't cover your issue

[Open an issue](https://github.com/trevoraspencer/skill-ralph-loop-creator/issues)
with:

- Which mode you're using (forward / decompose / pipeline)
- The output of `DRY_RUN=1 .ralph/<your-script>.sh` (redact anything sensitive)
- The relevant portion of `prd.json` / `decomp.json` / `pipeline.json`
- Which agent + model, and how the agent was invoked
