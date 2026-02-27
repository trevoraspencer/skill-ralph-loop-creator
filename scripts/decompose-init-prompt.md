You are running the initialization phase of Reverse Ralph.

## Step 1: Gather inputs

The user has provided the following inputs: {{INPUTS}}

For each URL:
- Fetch the page
- Follow documentation links up to 2 hops deep (same domain, documentation pages only;
  skip changelog entries, login pages, pricing pages, and unrelated product areas)

For each local file:
- Read its contents

For natural language descriptions:
- Use as-is

## Step 2: Build the capability surface

Synthesize a capability surface from all gathered content: a structured description of
the feature's complete observable behavior. Include:
- All user-facing entry points (commands, APIs, UI actions, invocation patterns)
- All states the feature can be in
- All configuration options and what they control
- All integrations with other systems
- All edge cases and error behaviors described in the documentation
- Success and failure conditions
- Any inter-feature dependencies or prerequisites

Write this as if describing the feature to a developer who has never seen it, using only
behavioral and functional terms. Do not describe implementation details.

## Step 3: Identify top-level capability clusters

From the capability surface, identify 3–8 top-level capability clusters. Each cluster
should represent a coherent, distinct behavioral area that could be worked on somewhat
independently. These become the root nodes in `decomp.json`.

## Step 4: Ask the user

Ask these questions before proceeding:

1. "What would you like to name this decomposition run?" (used for the loop script filename)
2. "Which execution agent should run the decomposition loop?"
   (claude / droid / codex / opencode / gemini / copilot / cc-compatible / custom)
3. "Which model? (Leave blank to use the CLI default)"

## Step 5: Seed decomp.json

Write `decomp.json` to the project root:

{
  "feature_name": "<inferred from input>",
  "source_urls": ["<all URLs fetched>"],
  "capability_surface": "<full capability surface from Step 2>",
  "nodes": [ /* one node per top-level cluster, each with status "needs_split" */ ],
  "completed_at": null
}

## Step 6: Generate the loop script

Copy `scripts/decompose.sh` to `.ralph/decompose-<n>.sh`. Substitute:
- `__AGENT__` with the chosen agent
- `__MODEL__` with the chosen model (empty string if none)
- `__LOOP_NAME__` with the run name

Copy `scripts/decompose-prompt.md` to `.ralph/decompose-<n>-prompt.md`.

## Step 7: Instruct the user

Tell the user:
- `decomp.json` has been seeded with N top-level clusters
- Run: `.ralph/decompose-<n>.sh [max_iterations]` (default 50)
- The loop runs autonomously until all nodes are atomic, then emits `prd.json`
- `prd.json` feeds directly into a forward Ralph loop with no transformation
- If interrupted, re-run the same command — it resumes where it left off
