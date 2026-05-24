You are running a bootstrap phase of a Forge pipeline. This is a ONE-SHOT phase: you
will be invoked exactly once, do your work, and exit. The driver will then commit your
changes and move on to the next phase.

## Your task this phase

<!-- AI generating the pipeline: replace this section with the concrete bootstrap task. -->
<!-- Examples: -->
<!--   - Create the initial directory structure (queues/, evidence/, output/, ...) -->
<!--   - Seed a queue file from the user's brief or a source manifest -->
<!--   - Write skeleton output files that downstream phases will populate -->
<!--   - Initialize provenance/audit logs if the pipeline uses them -->

## Output discipline

- Write all required files to disk before exiting.
- Do NOT call out to any agent loop or generate code that calls another agent.
- Keep changes minimal and atomic — the driver will git-commit everything you produced.
- If the bootstrap depends on inputs the user has not provided, write a clear placeholder
  file with TODO markers rather than failing silently.

## When you are done

Stop. The driver will:
1. Run `git add -A && git commit` with the phase's configured commit message.
2. Move to the next phase.

Do NOT start any work on subsequent phases.
