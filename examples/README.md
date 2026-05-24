# Examples

Sample inputs and reference material for Forge. Currently:

- **`briefs/`** — example pipeline briefs you can feed to `/forge pipeline @briefs/<name>.md`. Copy one, edit the placeholders (`<your-X>`, `<their-URLs>`), then invoke the skill to scaffold the pipeline.

Each brief is self-contained and chooses a different mix of features (provenance/taint guardrails, prefetch sources, output kind, loop unit-of-work) so the set covers the main shapes a pipeline can take.

## When to use briefs vs. natural language

Both work:

```text
/forge pipeline @examples/briefs/decompose-public-product.md
```

vs.

```text
/forge pipeline build a behavioral spec corpus for FooDB from their public docs at https://docs.foodb.io
```

Briefs are better when:

- The workflow has many sources or constraints (forbidden paths, provenance rules)
- You want a reproducible, committed record of what you asked for
- You're handing the same prompt to multiple agent platforms (claude vs. droid vs. codex) and want consistent input

Natural language is fine for quick one-offs.
