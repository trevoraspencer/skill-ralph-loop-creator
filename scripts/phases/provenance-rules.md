# Provenance and Source-Citation Rules

This file applies to every phase in this pipeline. Its instructions override any
conflicting instruction in a per-phase prompt.

## The rule

Every non-obvious claim you make must cite at least one source from the local corpus.
A "source" is a file under `.ralph/<pipeline-name>/evidence/` (or wherever the
prefetch phase placed its output). A "non-obvious claim" is any factual assertion
about the subject of the pipeline that a reader might want to verify — feature
behavior, configuration, limits, integrations, history, decisions, claims about a
third-party product, statements derived from external documentation, etc.

A citation looks like:

> Foo supports both X and Y modes ([docs/quickstart][s1]; [docs/configuration][s2]).
>
> [s1]: evidence/http_get_md/docs-quickstart.md
> [s2]: evidence/http_get_md/docs-configuration.md

Either inline (`(source: evidence/...)`) or reference-style as above. Use whichever
the per-phase prompt asks for.

## What does NOT need a citation

- Boilerplate scaffolding ("create a `phases/` directory", "write a file with this
  template")
- Process language ("you are one iteration", "stop after completing one item")
- Restating something the prompt itself told you
- General programming knowledge that any developer would know

## What MUST be cited

- Any claim about how the subject of the pipeline behaves
- Any number, limit, configuration value, or default
- Any feature list, capability claim, or supported scenario
- Any integration, API surface, or external dependency
- Any quote (always quote with backticks AND cite the source)

## If you don't have a source

Do NOT invent. Do NOT extrapolate from training data. Either:

1. **Skip the claim** — leave that section blank with a TODO marker like
   `<!-- TODO: needs evidence -->`
2. **Add to the queue** — if this claim needs a source we don't have, add a row to
   the relevant queue/manifest to prefetch the source on a future run

## Provenance index

Maintain `provenance-index.md` at the pipeline root. Bootstrap phase writes the
skeleton; prefetch phases populate rows. Each row maps a local file path to its
source URL and fetch date:

```
| local path                                     | source                                  | fetched     |
|------------------------------------------------|------------------------------------------|-------------|
| evidence/http_get_md/docs-quickstart.md        | https://example.com/docs/quickstart      | 2026-05-24  |
| evidence/github_readme/upstream.md             | gh:owner/repo readme                     | 2026-05-24  |
```

When you cite a file, the wrap-up red-team phase will verify the file exists in the
provenance index.

## Red-team wrap-up

A wrap-up phase named `red-team` audits this rule. It will flag:

- Claims without citations
- Citations pointing to files not in the provenance index
- Citations pointing to files that don't exist on disk
- Files in the corpus that aren't cited anywhere (potential dead weight)

Treat any flag as a real finding to fix before declaring the pipeline complete.
