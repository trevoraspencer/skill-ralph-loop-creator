# Ralph

Agent-agnostic autonomous loop creator. Ralph turns a feature spec into a repeatable implementation loop that runs one user story per iteration with a fresh headless agent context each time.

h/t [Geoffrey Huntley](https://ghuntley.com/ralph/) and [Ben Tossell](https://github.com/factory-ben/ralph).

## What It Does

Ralph is a skill (`SKILL.md`) that guides an agent to:

1. Read your feature spec (for example `/ralph @plan.md`)
2. Ask clarifying questions
3. Ask which execution agent/model to use
4. Generate `prd.json` with prioritized user stories
5. Generate a loop script in `.ralph/<loop-name>.sh`
6. Run that loop to implement one story per iteration until done or max iterations reached

Each iteration uses a fresh headless agent call. State persists in `prd.json`, `progress.txt`, git commits, and optional branch/PR automation.

## Requirements

- `jq`
- Git repository
- At least one supported headless AI coding CLI installed and authenticated
- Optional: `gh` CLI if you enable auto-push + PR creation

## Install This Skill

Ralph is portable. Install it as a skill in your preferred agent platform by copying this repo's `SKILL.md` and `scripts/` into that platform's skills directory.

### Factory.AI Droid

Factory docs: <https://docs.factory.ai/cli/configuration/skills>

Project-scoped install (shared in repo):

```bash
mkdir -p .factory/skills/ralph
cp SKILL.md .factory/skills/ralph/SKILL.md
cp -R scripts .factory/skills/ralph/
```

Personal install (available across projects on your machine):

```bash
mkdir -p ~/.factory/skills/ralph
cp SKILL.md ~/.factory/skills/ralph/SKILL.md
cp -R scripts ~/.factory/skills/ralph/
```

Then restart `droid` (or your integration) so it rescans skills.

### Claude Code

Claude Code skills docs: <https://code.claude.com/docs/en/slash-commands>

Project-scoped install:

```bash
mkdir -p .claude/skills/ralph
cp SKILL.md .claude/skills/ralph/SKILL.md
cp -R scripts .claude/skills/ralph/
```

Personal install:

```bash
mkdir -p ~/.claude/skills/ralph
cp SKILL.md ~/.claude/skills/ralph/SKILL.md
cp -R scripts ~/.claude/skills/ralph/
```

Ralph can then be invoked directly as `/ralph` or auto-invoked when your prompt matches its description.

## Usage

Run from an interactive agent session:

```text
/ralph @plan.md
```

Or in natural language:

```text
use ralph to add task priorities
```

Ralph will ask:

1. Which execution agent (`claude`, `droid`, `codex`, `opencode`, `gemini`, `copilot`, `cc-compatible`, or `custom`)
2. Which model (optional)
3. Loop name (used for `.ralph/<loop-name>.sh`)
4. Whether to auto-push branch and create PR when done

After generation, run:

```bash
.ralph/<loop-name>.sh [max_iterations]
```

Default `max_iterations` is `10`.

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

If no model is provided, Ralph omits model flags and uses the CLI default.

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
  .ralph-last-branch    # last branch used by Ralph
```

## Repo Layout

- `SKILL.md`: main Ralph instructions and workflow
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

- `/ralph` is not available: verify install path and folder name (`ralph`), then restart your CLI session.
- Loop script exits with jq error: install `jq` (`brew install jq` on macOS).
- Execution agent command not found: install/authenticate the selected agent CLI and retry.
- Auto-push/PR does nothing: ensure you are on a non-default branch with commits; install/authenticate `gh` for PR creation.

## License

MIT
