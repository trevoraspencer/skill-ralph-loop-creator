You are running the red-team wrap-up phase. This is a ONE-SHOT phase: invoked once
at the end of the pipeline, audit the outputs, write a report, exit.

All upstream phases — bootstrap, prefetch, loop iterations — have completed. Your
job is independent verification: nothing the prior phases produced is trusted by
default; you check it.

## Your task this phase

Produce `red-team-report.md` at the pipeline root, with three sections.

### Section 1: Citation audit

Read `provenance-index.md` and every output file the loop phases produced.
For every non-obvious claim in the outputs, verify:

- **Has a citation** — every claim names at least one source.
- **Citation points to a corpus file** — the cited path exists on disk.
- **Cited file is in the provenance index** — the source is one we actually fetched
  (not invented).
- **Citation supports the claim** — the cited content actually says what the claim
  asserts. Quote a relevant excerpt as evidence.

For each violation, report:
- The claim
- The output file and line
- The specific problem (missing citation, dangling reference, citation does not
  support claim, etc.)

### Section 2: Taint log review

Read `risk-and-taint-log.md`.

- **If empty**: report "Clean run — no forbidden sources touched."
- **If non-empty**: for each entry, summarize what happened and state whether the
  pipeline output appears to be contaminated by the absorbed content. The user will
  use this to decide whether to merge or rerun.

Additionally, scan all pipeline outputs for content patterns that look like they
came from a forbidden path (e.g., if `src/proprietary/**` is forbidden, look for
identifiers, type names, or file paths that match that pattern). Report any matches
even if the taint log is empty — they could indicate a missed incident.

### Section 3: Corpus utilization

For each file in the provenance index, report whether it was cited at least once.

- Files never cited may be dead weight (consider removing from the prefetch
  manifest on the next run) — or they may indicate a gap in the outputs (the
  source was fetched but never used to make any claim).
- Both cases are worth surfacing; the user decides which applies.

## Output discipline

- Write `red-team-report.md` at the pipeline root.
- Do NOT modify the outputs you are auditing. This phase reads-only.
- Do NOT clear the taint log. The user owns that decision.
- Do NOT delete uncited corpus files. The user owns that decision.

## When you are done

Stop. The driver will commit `red-team-report.md`. The pipeline is then complete.
The user reads the report and decides whether the deliverable is ready to merge.
