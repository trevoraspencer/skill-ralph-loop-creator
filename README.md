# Ralph

Agent-agnostic autonomous loop creator. Ralph is not tied to any single AI coding agent — it generates custom loop scripts that work with whichever agent and model you choose.

h/t [Geoffrey Huntley](https://ghuntley.com/ralph/) and [Ben Tossell](https://github.com/factory-ben/ralph).

## What Ralph Does

Ralph reads an implementation plan, asks which AI coding agent and model you want to use, then generates a self-contained loop script in a `.ralph/` directory within your project. The loop breaks features into user stories and iterates through them, spawning a fresh headless agent for each iteration.

1. You invoke Ralph with a plan (e.g., `/ralph @plan.md`)
2. Ralph asks clarifying questions about the feature
3. Ralph asks which agent, model, and loop name to use
4. Ralph creates `prd.json` with user stories
5. Ralph generates `.ralph/<loop-name>.sh` with the selected agent command baked in
6. You run the script — it autonomously implements each story

## Requirements

- At least one AI coding agent with headless CLI support (ideally multiple — one to create the loop, others to execute within it)
- `jq`

## Usage

Invoke Ralph as a slash command with an `@`-tagged markdown file as the feature spec:

```
/ralph @plan.md
```

Or just ask Ralph to implement a feature:

```
use ralph to add task priorities
```

Ralph will walk you through configuration (agent, model, loop name), generate the PRD and loop script, then tell you how to run it.

## Supported Agents

| Agent | Binary | Headless Command |
|-------|--------|-----------------|
| Claude Code | `claude` | `claude -p "$(cat "$PROMPT_FILE")" --dangerously-skip-permissions --model MODEL` |
| Factory Droid | `droid` | `droid exec --skip-permissions-unsafe -f "$PROMPT_FILE" --output-format text -m MODEL` |
| OpenAI Codex | `codex` | `codex exec --yolo -m MODEL "$(cat "$PROMPT_FILE")"` |
| OpenCode | `opencode` | `opencode run --yolo -m MODEL "$(cat "$PROMPT_FILE")"` |
| Gemini CLI | `gemini` | `gemini -p "$(cat "$PROMPT_FILE")" --yolo -m MODEL` |
| GitHub Copilot | `copilot` | `copilot -p "$(cat "$PROMPT_FILE")" --yolo --model MODEL` |
| CC-Compatible | user-provided | Same flags as Claude Code, different binary (e.g., `zai`, `minimax`, `kimi`) |
| Fully Custom | user-provided | User provides entire command template with `$PROMPT_FILE` placeholder |

## The `.ralph/` Directory

Ralph generates loop scripts into a `.ralph/` directory in your project root. This directory:

- Is automatically added to `.gitignore`
- Supports multiple named loops (e.g., `feature-a.sh`, `feature-b.sh`)
- Each loop is self-contained: a shell script and its co-located prompt file

```
project/
  .gitignore            # .ralph/ added automatically
  .ralph/
    feature-a.sh        # Loop script (e.g., Claude Code + sonnet)
    feature-a-prompt.md
    feature-b.sh        # Another loop (e.g., Gemini + flash)
    feature-b-prompt.md
  prd.json
  progress.txt
```

Run a loop with:

```bash
.ralph/<loop-name>.sh [max_iterations]
```

Default is 10 iterations.

## License

MIT
