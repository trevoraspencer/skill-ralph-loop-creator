You are running the provenance bootstrap phase. This is a ONE-SHOT phase: invoked
once, write the skeleton files, exit. The driver will commit your changes.

## Your task this phase

Create two skeleton files at the pipeline root (`.ralph/<pipeline-name>/`):

### 1. `provenance-index.md`

```markdown
# Provenance Index

Mapping from local corpus files to their external sources. Populated by the
prefetch phase. Used by the red-team wrap-up phase to verify citations.

| local path | source | fetched |
|------------|--------|---------|
```

Leave the rows empty. The prefetch phase (or whatever populates the corpus) will
append rows as it fetches.

### 2. `risk-and-taint-log.md`

```markdown
# Risk and Taint Log

Append-only log of incidents where a forbidden source was inadvertently touched.
Empty = clean run. Any entries → human review required before merging.

<!-- format for each entry:
## <timestamp> — <forbidden-path>
- Tool: <tool_name>
- Context: <what you were trying to do>
- Absorbed: <brief description, or "none">
- Action: discarded; iteration continued
-->
```

Leave it empty. Iterations append entries only if they touch a forbidden path.

## Output discipline

- Both files must exist at the pipeline root before this phase completes.
- Both files are committed as part of this phase.
- Do not pre-populate either file. The skeletons are what downstream phases expect.

## When you are done

Stop. The driver will run `git add -A && git commit` with this phase's configured
commit message.
