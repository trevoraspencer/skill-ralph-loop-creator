# Pipeline brief: decompose `<product-name>` from public sources

## Goal

Produce a behavioral specification corpus for `<product-name>` derived ONLY from
publicly available sources (official docs, GitHub repos, blog posts, conference
talks). Output is a structured `spec/` directory: one markdown file per capability,
every claim cited to a source in the corpus.

## Why this shape

`<product-name>` is a third-party product. We need to understand what it does and
how it behaves from the OUTSIDE, without reading any proprietary or internal
source. The output is reference material for `<your-purpose-here>` — e.g.,
"informing our own product roadmap", "writing a compatibility layer", "evaluating
whether to adopt it."

## Inputs (prefetch sources)

```
class                slug                  identifier                                                notes
http_get_md          docs-home             https://docs.<their-domain>/                              landing page
http_get_md          docs-getting-started  https://docs.<their-domain>/getting-started               quickstart
http_get_md          docs-api-reference    https://docs.<their-domain>/api                           API surface
github_readme        upstream-readme       <their-org>/<their-repo>                                  repo README
github_issues_json   upstream-issues       <their-org>/<their-repo>                                  open + closed issues — useful for "what's broken / planned"
github_prs_json      upstream-prs          <their-org>/<their-repo>                                  PRs — useful for "what's recently changed"
```

(Edit the rows with your actual sources before invoking.)

## Output kind

Behavioral specification (spec). Each output file describes WHAT the product does
and HOW it behaves, not HOW it's implemented.

## Forbidden sources

Do NOT read:

- `<their-org>/<their-repo>/src/**` if cloned locally — we are decomposing from
  public docs only, not from source
- Any of our own internal product source — we want a clean external view
- Anything under `secrets/`, `*.env`, `credentials.*`

## Phase shape proposed

1. **bootstrap** (oneshot) — create `spec/`, `evidence/`, `queues/work.md` directories
2. **provenance-bootstrap** (oneshot) — seed `provenance-index.md` and empty `risk-and-taint-log.md`
3. **prefetch** (shell) — invoke `scripts/prefetch.sh` with the manifest above
4. **decompose-queue-seed** (oneshot) — read prefetched corpus, write `queues/work.md` with one queue item per capability identified
5. **loop** — per-iteration: read one queue item (one capability), write `spec/<capability>.md` citing the corpus, flip the checkbox
6. **red-team** (oneshot) — audit citations, review taint log, write `red-team-report.md`

## Shared rules

- Drop `scripts/phases/provenance-rules.md` into `_shared/` — every claim cites a corpus file
- Drop `scripts/phases/forbidden-paths.md` into `_shared/` with the forbidden list filled in

## Completion criteria

- `spec/` contains one markdown file per capability identified in step 4
- `red-team-report.md` shows zero unflagged citation problems
- `risk-and-taint-log.md` is either empty OR every entry has been reviewed and dispositioned
