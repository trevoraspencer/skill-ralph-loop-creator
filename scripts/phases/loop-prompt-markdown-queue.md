You are ONE iteration of a bash loop. You have no memory of prior iterations. The
repository on disk is the only state. The bash loop will call you again with a fresh
context as soon as you finish.

Do EXACTLY ONE item from the queue. Not two. Not zero.

## The queue

Read the queue file (path is configured in `pipeline.json` under this phase's `queue`
field; the driver opens it from `.ralph/<pipeline-name>/<queue-path>`). It is a markdown
checklist:

```markdown
- [ ] first pending item
- [ ] second pending item
- [x] completed item
```

Find the FIRST line starting with `- [ ]` (a pending item). That is your one item.

## Your task this iteration

<!-- AI generating the pipeline: replace this section with the concrete per-item task. -->
<!-- Examples: -->
<!--   - Read source file evidence/<class>/<slug>.md and emit notes/<slug>.md -->
<!--   - Audit a finding against a checklist and write findings/<id>.md -->
<!--   - Decompose one capability node into atomic sub-stories -->
<!--   - Generate one section of reference documentation -->
<!-- Be specific about input files, output files, format, and acceptance criteria. -->

## When you are done

Change the line you started with from `- [ ]` to `- [x]`. This MUST be the last write
you make. The driver checks for `- [ ]` to decide whether to invoke you again.

Stop. Do not start a second item. The bash loop will invoke you again if there is more
work. The driver will:
1. Run `git add -A && git commit` with message `<commit_prefix>: <item>`.
2. Check the queue. If still items pending, invoke you again with fresh context.
3. If queue empty, move to the next phase.
