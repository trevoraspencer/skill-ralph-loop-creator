# Forge (formerly Ralph)

**Agent-agnostic, platform-agnostic autonomous loop creator.** Install Forge in any agent platform that supports skills (Factory.AI Droid, Claude Code, …) and use it to generate **portable external bash loops** that drive **any headless coding-agent CLI** (claude, droid, codex, opencode, gemini, copilot, …) across many fresh-context iterations. Forward mode implements features end-to-end; decompose mode breaks existing features into atomic user stories for greenfield re-implementation. Works for code, specs, audits, docs, and research alike.

h/t [Geoffrey Huntley](https://ghuntley.com/ralph/) and [Ben Tossell](https://github.com/factory-ben/ralph) for the original Ralph pattern.

> **Renamed from Ralph.** The v1 invocation `/ralph` is renamed to `/forge`. Existing `.ralph/*.sh` generated scripts continue to work unchanged — only the slash command and the skill `name:` field change. See [Migration from Ralph](#migration-from-ralph) below.

## What It Does

Forge is a skill (`SKILL.md`) that guides an agent to:

1. Read your feature spec (for example `/forge @plan.md`)
2. Ask clarifying questions
3. Ask which execution agent/model to use
4. Generate `prd.json` with prioritized user stories
5. Generate a loop script in `.ralph/<loop-name>.sh` (runtime directory name preserved for backward compatibility)
6. Run that loop to implement one story per iteration until done or max iterations reached

Each iteration uses a fresh headless agent call. State persists in `prd.json`, `progress.txt`, git commits, and optional branch/PR automation.

## How this compares to other tools you may already use

If you only need a **single in-session loop with one agent**, use that agent's native looping plugin — e.g., Anthropic's [`/ralph-loop` plugin](https://claude.com/plugins/ralph-loop) for Claude Code, which re-feeds the same prompt via a Stop hook in-session.

If you want **methodology guidance** — brainstorming, planning, TDD, code review — use a methodology-focused plugin for your platform — e.g., Anthropic's [Superpowers plugin](https://claude.com/plugins/superpowers) for Claude Code.

Forge is **complementary to both**: it generates **external** bash loops, **across many fresh-context iterations**, for **any CLI**, with optional **multi-phase pipeline orchestration** (coming soon). Use whichever combination fits the task.

## Requirements

- `jq`
- Git repository
- At least one supported headless AI coding CLI installed and authenticated
- Optional: `gh` CLI if you enable auto-push + PR creation

## Install This Skill

Forge is portable. Install it as a skill in your preferred agent platform by copying this repo's `SKILL.md` and `scripts/` into that platform's skills directory.

### Factory.AI Droid

Factory docs: <https://docs.factory.ai/cli/configuration/skills>

Project-scoped install (shared in repo):

```bash
mkdir -p .factory/skills/forge
cp SKILL.md .factory/skills/forge/SKILL.md
cp -R scripts .factory/skills/forge/
```

Personal install (available across projects on your machine):

```bash
mkdir -p ~/.factory/skills/forge
cp SKILL.md ~/.factory/skills/forge/SKILL.md
cp -R scripts ~/.factory/skills/forge/
```

Then restart `droid` (or your integration) so it rescans skills.

### Claude Code

Claude Code skills docs: <https://code.claude.com/docs/en/slash-commands>

Project-scoped install:

```bash
mkdir -p .claude/skills/forge
cp SKILL.md .claude/skills/forge/SKILL.md
cp -R scripts .claude/skills/forge/
```

Personal install:

```bash
mkdir -p ~/.claude/skills/forge
cp SKILL.md ~/.claude/skills/forge/SKILL.md
cp -R scripts ~/.claude/skills/forge/
```

Forge can then be invoked directly as `/forge` or auto-invoked when your prompt matches its description.

## Migration from Ralph

If you installed v1 under `~/.claude/skills/ralph/` (or `.factory/skills/ralph/`), you can:

- **Recommended:** Delete the old directory and reinstall under `forge/` as shown above. Restart your CLI to rescan skills. The `/ralph` slash command stops working; `/forge` takes its place.
- **Alternative:** Rename the directory in-place (`mv ~/.claude/skills/ralph ~/.claude/skills/forge`), then `git pull` to get the new `SKILL.md`. Same result.

**Backward compatible (no migration needed):**

- Existing `.ralph/*.sh` generated loop scripts continue to run.
- Existing `prd.json` files with `branchName: "ralph/…"` continue to work — the script reads whatever branch name is in `prd.json`.
- Runtime directories `.ralph/`, `.ralph-archive/`, and `.ralph-last-branch` keep their names.
- Natural-language triggers like `"use ralph to add X"` continue to route to this skill (legacy phrases are kept in the skill description).

## Usage

Run from an interactive agent session:

```text
/forge @plan.md
```

Or in natural language:

```text
use forge to add task priorities
```

Forge will ask:

1. Which execution agent (`claude`, `droid`, `codex`, `opencode`, `gemini`, `copilot`, `cc-compatible`, or `custom`)
2. Which model (optional)
3. Loop name (used for `.ralph/<loop-name>.sh`)
4. Whether to auto-push branch and create PR when done

After generation, run:

```bash
.ralph/<loop-name>.sh [max_iterations]
```

Default `max_iterations` is `10`.

### Verify wiring without burning tokens — `DRY_RUN=1`

Before paying for a full run, sanity-check that the generated loop is wired correctly:

```bash
DRY_RUN=1 .ralph/<loop-name>.sh
DRY_RUN=1 .ralph/decompose-<n>.sh
```

`DRY_RUN=1` runs all preflight checks, prints the assembled prompt for the first iteration to stdout, and exits 0 without calling the agent. Useful for confirming that `prd.json` parses, the agent binary is on `PATH`, the prompt file is present, and the prompt content reads as you'd expect.

## Supported Execution Agents

| Agent | Binary | Headless command template |
|-------|--------|---------------------------|
| Claude Code | `claude` | `claude -p "$(cat "$PROMPT_FILE")" --dangerously-skip-permissions --model MODEL` |
| Factory Droid | `droid` | `droid exec --skip-permissions-unsafe -f "$PROMPT_FILE" --output-format text -m MODEL` |
| OpenAI Codex | `codex` | `codex exec --yolo -m MODEL "$(cat "$PROMPT_FILE")"` |
| OpenCode | `opencode` | `opencode run --yolo -m MODEL "$(cat "$PROMPT_FILE")"` |
| Gemini CLI | `gemini` | `gemini -p "$(cat "$PROMPT_FILE")" --yolo -m MODEL` |
| GitHub Copilot | `copilot` | `copilot -p "$(cat "$PROMPT_FILE")" --yolo --model MODEL` |
| CC-compatible | user-provided | Claude-style flags with custom binary (for example `zai`, `minimax`, `kimi`) |
| Custom | user-provided | Full command template containing `$PROMPT_FILE` |

If no model is provided, Forge omits model flags and uses the CLI default.

## Generated Files and Runtime State

```text
project/
  .gitignore            # Adds: .ralph/, .ralph-archive/, .ralph-last-branch
  .ralph/
    <loop-name>.sh
    <loop-name>-prompt.md
  prd.json
  progress.txt
  .ralph-archive/       # previous run archives when branch changes
  .ralph-last-branch    # last branch used by Forge
```

The `.ralph/` runtime directory name is preserved from v1 for backward compatibility — existing generated scripts and gitignore entries continue to work.

## Repo Layout

- `SKILL.md`: main Forge instructions and workflow
- `scripts/ralph.sh`: reference loop template used when generating `.ralph/<loop-name>.sh`
- `scripts/prompt.md`: prompt template copied to `.ralph/<loop-name>-prompt.md`
- `scripts/decompose.sh`: decompose loop template used when generating `.ralph/decompose-<n>.sh`
- `scripts/decompose-prompt.md`: per-iteration decompose prompt copied to `.ralph/decompose-<n>-prompt.md`
- `scripts/decompose-init-prompt.md`: initialization prompt used by the orchestrating agent during decompose setup
- `scripts/test-template.sh`: smoke tests for template preflight + completion behavior

## Development Check

```bash
./scripts/test-template.sh
```

## Troubleshooting

- `/forge` is not available: verify install path and folder name (`forge`), then restart your CLI session.
- `/ralph` no longer routes here after upgrading: that's expected — the slash command was renamed to `/forge`. Natural-language triggers like "use ralph to …" still work.
- Loop script exits with jq error: install `jq` (`brew install jq` on macOS).
- Execution agent command not found: install/authenticate the selected agent CLI and retry.
- Auto-push/PR does nothing: ensure you are on a non-default branch with commits; install/authenticate `gh` for PR creation.
- Want to test wiring without paying for tokens: run with `DRY_RUN=1 .ralph/<loop-name>.sh` — it prints the assembled prompt and exits without calling the agent.

## License

MIT
