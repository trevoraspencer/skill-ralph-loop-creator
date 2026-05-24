# Pipeline brief: generate reference documentation for `<our-codebase>`

## Goal

Produce a structured reference documentation site for `<our-codebase>` derived
from the source itself (function signatures, JSDoc/docstrings, package metadata,
example tests). Output is `docs/reference/` — one file per public module, plus an
index.

## Why this shape

We have source code that's the source of truth for behavior, but no consolidated
reference docs. Auto-generating from source keeps the docs honest and lets us
regenerate after refactors. Loop unit = one public module.

## Inputs (prefetch sources)

For a reference-from-source pipeline, the "corpus" is the codebase itself. Use
`local_file` rows OR skip the prefetch phase entirely if the source is already
in the project. If documenting an external package, use `github_readme` and
optionally clone the repo locally as a one-off setup step.

```
class                slug                identifier                                                notes
local_file           package-manifest    package.json                                              dependencies, version
local_file           tsconfig            tsconfig.json                                             module resolution rules
github_readme        upstream-readme     <package-org>/<package-repo>                              if documenting an upstream we depend on
```

The loop phase reads source files directly via `Read` — no prefetch needed for
the source itself.

## Output kind

Reference documentation (docs). Each output file follows this template:

```
# <module-path>

<one-paragraph what-and-why>

## Exports

### `<name>(<args>)` — <one-liner>

**Parameters:**
- `<arg>` (`<type>`) — <description>

**Returns:** `<type>` — <description>

**Example:**
\`\`\`<lang>
<minimal usage example>
\`\`\`

**Notes:** <edge cases, gotchas, related symbols>
```

## Forbidden sources

Do NOT read:

- Test fixtures or generated/build output (`dist/`, `build/`, `*.gen.*`)
- Secrets or env files (`*.env`, `secrets/`, `credentials.*`)
- Dependencies' source (`node_modules/`, `vendor/`) — we document OUR code only

## Phase shape proposed

1. **bootstrap** (oneshot) — create `docs/reference/`, `queues/modules.md`
2. **seed-modules** (oneshot) — scan source, write `queues/modules.md` with one queue item per public module (skip internals matching `**/*.internal.*` or `**/_*`)
3. **loop** — per-iteration: read one module from queue, read its source + co-located test, write `docs/reference/<module-path>.md` per the template, flip the checkbox
4. **build-index** (oneshot) — read all `docs/reference/**/*.md`, write `docs/reference/index.md` (grouped table of contents)
5. **link-check** (shell) — invoke a link-checker script over `docs/reference/`; fail if any internal link is broken (no agent needed for this)

## Shared rules

This pipeline does NOT need provenance/taint guardrails — the "source" IS the
internal codebase, and there's nothing forbidden about reading our own code (except
the explicit exclusions above).

Optional: drop a small `_shared/style.md` with project-specific tone, terminology,
and example conventions so every module page reads consistently.

## Completion criteria

- `docs/reference/` contains one file per module in `queues/modules.md`
- `docs/reference/index.md` exists and links to every module file
- The link-check shell phase exits 0 (no broken internal links)
