You are running a wrap-up phase of a Forge pipeline. This is a ONE-SHOT phase: you
will be invoked exactly once, do your work, and exit. The driver will then commit your
changes. This is typically the last phase in the pipeline.

All loop phases that precede this wrap-up have completed. Their queues are empty. Their
outputs are on disk.

## Your task this phase

<!-- AI generating the pipeline: replace this section with the concrete wrap-up task. -->
<!-- Examples: -->
<!--   - Aggregate per-item outputs into a single deliverable file -->
<!--   - Audit for completeness against the original brief -->
<!--   - Generate a summary index pointing to all per-item artifacts -->
<!--   - Freeze a release: tag versions, write CHANGELOG, finalize provenance -->
<!--   - Red-team check: every claim has a source, every source exists, nothing forbidden -->

## Output discipline

- Read whatever loop outputs you need from disk.
- Write the final deliverables.
- Do NOT modify upstream outputs unless explicitly asked — they are already committed.
- Keep your changes scoped to wrap-up artifacts (summary, index, audit report, ...).

## When you are done

Stop. The driver will run `git add -A && git commit` with the phase's configured commit
message. The pipeline is then complete.
