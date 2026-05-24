# Pipeline brief: audit `<vendor>` against `<compliance-framework>`

## Goal

Produce a compliance audit report mapping `<vendor>`'s public commitments,
documentation, and observable behavior to each control in
`<compliance-framework>` (e.g., SOC 2 Type II, ISO 27001, HIPAA). Output is a
findings document per control: status (pass / partial / fail / not-applicable),
evidence, gaps, and recommended remediation.

## Why this shape

A compliance audit is per-control work — each control is independent and gets
its own iteration. The output is a structured findings corpus that legal,
security, or procurement teams can review.

## Inputs (prefetch sources)

```
class                slug                identifier                                                notes
http_get_md          trust-center        https://trust.<vendor-domain>/                            public trust portal
http_get_md          privacy             https://<vendor-domain>/privacy                           privacy policy
http_get_md          security            https://<vendor-domain>/security                          security overview
http_get_md          dpa                 https://<vendor-domain>/dpa                               data processing addendum
http_get_md          sub-processors      https://<vendor-domain>/subprocessors                     subprocessor list
github_readme        upstream-readme     <vendor-org>/<vendor-repo>                                if open-source components are in scope
local_file           soc2-report         vendor-docs/<vendor>-soc2-2026.pdf                        (if provided under NDA — see note below)
local_file           dpa-signed          legal/dpa-<vendor>.pdf                                    (if applicable)
```

## Output kind

Compliance audit (audit). Each output file follows a strict template:

```
# Control <id>: <name>

**Status:** pass | partial | fail | not-applicable
**Severity (if fail):** critical | high | medium | low

## Evidence
- <citation 1>
- <citation 2>

## Gaps
<what's missing or insufficient>

## Remediation
<concrete recommendation, or "n/a">
```

## Forbidden sources

Do NOT read:

- Privileged legal communications (`legal/privileged/**`, attorney memos, etc.)
- Customer data or PII from any source
- Anything under `secrets/`, `*.env`, `credentials.*`
- (If a vendor SOC 2 report is under NDA, ensure the NDA permits AI-assisted
  review before including it in the manifest.)

## Phase shape proposed

1. **bootstrap** (oneshot) — create `findings/`, `evidence/`, `queues/controls.md`
2. **provenance-bootstrap** (oneshot) — seed `provenance-index.md` and empty `risk-and-taint-log.md`
3. **seed-controls** (oneshot) — write `queues/controls.md` with one queue item per control in `<compliance-framework>` (e.g., one row per SOC 2 Trust Service Criteria control)
4. **prefetch** (shell) — invoke `scripts/prefetch.sh` with the manifest above
5. **loop** — per-iteration: read one control from the queue, search the corpus for evidence, write `findings/<control-id>.md` per the template, flip the checkbox
6. **summary** (oneshot) — aggregate findings into `audit-summary.md` (counts by status, top severity gaps, executive summary)
7. **red-team** (oneshot) — audit citations + taint log + verify every control has a finding

## Shared rules

- Drop `scripts/phases/provenance-rules.md` into `_shared/`
- Drop `scripts/phases/forbidden-paths.md` into `_shared/` with the forbidden list filled in
- Add a custom `_shared/audit-template.md` enforcing the findings template above

## Completion criteria

- `findings/` contains one file per control in `<compliance-framework>`
- `audit-summary.md` exists with counts and top findings
- `red-team-report.md` shows every finding has at least one citation
- `risk-and-taint-log.md` is either empty or every entry has been reviewed
