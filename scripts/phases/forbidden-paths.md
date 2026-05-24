# Forbidden Sources and Contamination Protocol

This file applies to every phase in this pipeline. Its instructions override any
conflicting instruction in a per-phase prompt.

## The rule

Some categories of file are OFF LIMITS for this pipeline. You must not read them.
You must not allow their content to influence what you produce. The list of
forbidden source classes is below, customized for this pipeline by the user.

Common reasons a source is forbidden:

- **IP boundary** — decomposing a third-party product behaviorally from public docs
  only; the proprietary source is forbidden to keep the work clean-room.
- **Legal boundary** — auditing without privileged access; settlement docs, attorney
  communications, etc. are forbidden.
- **Security boundary** — secrets, credential stores, private keys must not appear
  in agent output.

## Forbidden paths for this pipeline

<!-- AI generating the pipeline: replace this list with the user's actual constraints. -->
<!-- Use globs relative to the project root. Examples: -->

- `src/proprietary/**`
- `secrets/**`, `**/*.env`, `**/credentials.json`
- `legal/privileged/**`
- (none specified by the user — remove this section if so)

## What "do not read" means in practice

1. **Do not call any tool** that would open, search, or summarize a forbidden path.
   No `Read`, no `Grep`, no `Glob`. No `Bash cat`, `head`, `find -exec`, etc.
2. **If you accidentally encountered a forbidden path** (e.g., a tool returned it as
   part of a broader result you didn't request): immediately stop reading. Do not
   summarize what you saw. Do not write anything that uses information from it.
3. **Log the incident** to `risk-and-taint-log.md` at the pipeline root with:
   - Timestamp
   - Forbidden path that was touched
   - How it happened (which tool call, what you were trying to do)
   - What content (if any) was absorbed
   - That you have discarded the absorbed content
4. **Continue the iteration** — but produce nothing that draws on the forbidden
   content. If you cannot complete this iteration without using the absorbed content,
   leave a TODO marker and move on; the wrap-up phase will pick up the gap.

## Risk and taint log format

```
# Risk and Taint Log

## <timestamp> — <forbidden-path>
- Tool: <tool_name>
- Context: <what you were trying to do>
- Absorbed: <brief description of any content you saw, or "none">
- Action: discarded; iteration continued
```

A bootstrap phase writes the initial empty log. Future iterations append. Never edit
past entries; only append.

## Red-team wrap-up

A wrap-up phase named `red-team` audits this rule. It will:

1. Verify the taint log exists.
2. If the taint log has any entries, flag the pipeline as compromised and emit a
   summary report of every incident — the user reviews each one before merging.
3. Optionally re-scan all phase outputs for content that pattern-matches forbidden
   paths (e.g., file paths that look like they came from `src/proprietary/`).

A non-empty taint log does NOT automatically fail the pipeline — sometimes the
absorbed content was incidental and properly discarded. But every incident gets
human review.
