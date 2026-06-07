# Changelog

All notable user-facing changes to Forge (formerly Ralph) are documented here. For
implementation details, scoping decisions, and per-PR rationale, see
[`ERRORS.md`](ERRORS.md).

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and
this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed

- Decompose mode now emits `branchName: "forge/…"` in generated `prd.json`
  (aligned with forward mode). Existing `ralph/…` values in old files continue
  to work unchanged.
- Forward loop archive folders now strip both `ralph/` and `forge/` branch
  prefixes when writing to `.ralph-archive/` (fixes ugly folder names for new
  `forge/` branches).

### Added

- [`NAMING.md`](NAMING.md) — documents the three naming layers (product, runtime,
  repo source) after the v2 Ralph → Forge rename.

## [2.0.0] — 2026-05-24

The v2 release: a rename to disambiguate from Anthropic's `/ralph-loop` plugin,
plus multi-phase pipeline support, shared-includes, a reference prefetcher, and
opt-in provenance/taint guardrails for non-code workflows (specs, audits, research).

Existing v1-generated `.ralph/*.sh` scripts continue to run unchanged — the
runtime contract is preserved. Only the slash command and the skill `name:` field
change.

### Changed

- **Renamed `/ralph` → `/forge`.** Skill `name:` field and slash command renamed
  to disambiguate from Anthropic's official `/ralph-loop` plugin. Repo name stays
  `skill-ralph-loop-creator` for SEO and continuity. Natural-language triggers
  ("use ralph to …", "reverse ralph this") are preserved in the skill description.
  See [Migration from Ralph](README.md#migration-from-ralph).
- README positioning rewritten as platform-agnostic and agent-agnostic; a
  separate "How this compares to other tools" section names neighboring plugins
  (Anthropic's `/ralph-loop` and Superpowers) as complements, not competitors.

### Added

- **Pipeline mode (`/forge pipeline @brief.md`).** Multi-phase driver that
  orchestrates a sequence of phases sandwiching a loop: bootstrap → loop →
  wrap-up. Each phase commits independently. Three phase types:
  - `oneshot` — run agent once, commit
  - `loop` — iterate a markdown-checklist queue until empty (or `max_iters`)
  - `shell` — run an arbitrary script with no agent, commit changes
  - If a `loop` phase hits `max_iters` without draining its queue, downstream
    wrap-up phases are skipped (they assume the loop is complete). Re-run with
    `START_AT=<phase-id>` to resume.
- **`DRY_RUN=1` env flag** for forward, decompose, and pipeline scripts. Runs
  all preflight checks, prints the assembled prompt(s), skips agent invocation,
  exits 0. Lets you verify wiring without burning tokens.
- **`START_AT=<phase-id>` env flag** for pipeline scripts. Skip earlier phases
  to resume after interruption or `max_iters` blowout.
- **Shared-includes (`.ralph/_shared/*.md`).** Drop `.md` files into the
  directory and they're concatenated alphabetically and prepended to every
  iteration's prompt — for every forward and decompose loop in the project.
  Pipelines support a per-pipeline `_shared/` directory under
  `.ralph/<pipeline-name>/_shared/`. If the directory doesn't exist, behavior
  is unchanged from v1 (no-op).
- **Reference prefetcher (`scripts/prefetch.sh`).** TSV-driven, called from a
  `shell` phase to pull external corpus to local disk before the loop runs
  (deterministic iterations, no rate-limit surprises). Five source classes:
  - `http_get_md` — curl + pandoc HTML→markdown (with raw-HTML fallback)
  - `github_readme` — `gh api repos/<owner>/<repo>/readme`
  - `github_issues_json` — `gh issue list --json`
  - `github_prs_json` — `gh pr list --json`
  - `local_file` — `cp` from a project-local path
- **Opt-in provenance + taint guardrail templates** under `scripts/phases/`:
  - `provenance-bootstrap.md` — initializes `provenance-index.md` + `risk-and-taint-log.md`
  - `provenance-rules.md` — drop into `_shared/` to require source citations on every claim
  - `forbidden-paths.md` — drop into `_shared/` to enforce "do not read X" with a taint-log audit trail
  - `red-team-wrapup.md` — wrap-up phase that audits citations and reviews the taint log
- **Example briefs (`examples/briefs/`):** three ready-to-copy pipeline briefs
  covering the main shapes:
  - `decompose-public-product.md` — third-party product spec corpus, with provenance + taint guardrails
  - `audit-vendor-compliance.md` — vendor compliance audit, one control per loop iteration
  - `generate-reference-docs.md` — reference docs from source, with a link-check shell phase
- **GitHub Actions CI** (`.github/workflows/test.yml`): two jobs run on every
  push and PR:
  - `smoke-tests` — runs `scripts/test-template.sh` (29 tests at v2.0.0)
  - `shellcheck` — runs `shellcheck -x` over every `*.sh` in `scripts/`
- **Documentation:** new [`TROUBLESHOOTING.md`](TROUBLESHOOTING.md)
  (symptom → fix catalog) and [`CONTRIBUTING.md`](CONTRIBUTING.md) (repo
  orientation, test setup, conventions).

### Fixed

- `decompose.sh` `prd.json` output is now compatible with forward Forge's
  schema (camelCase, `branchName`/`userStories`/`acceptanceCriteria`). Running
  forward Forge on decompose output now works at preflight.
- `decompose.sh` custom-agent invocation now exposes `$PROMPT_FILE` pointing at
  the per-iteration prompt (with node ID + decomp.json appended) rather than
  the base template.
- `decompose.sh` now uses absolute paths so it works correctly when run from a
  subdirectory.
- `decompose.sh` now sleeps 2 seconds between iterations (matching `ralph.sh`).
- `ralph.sh` shebang normalized to `#!/usr/bin/env bash` (was `#!/bin/bash`).
- Stale "CC-Mirror" naming in `ralph.sh` corrected to "CC-compatible".

### Backward compatibility

- Existing `.ralph/*.sh` generated loop scripts continue to run unchanged.
- Existing `prd.json` files with `branchName: "ralph/…"` continue to work.
- Runtime directories `.ralph/`, `.ralph-archive/`, `.ralph-last-branch` keep
  their names.
- Natural-language triggers like `"use ralph to add X"` continue to route to
  this skill.

## Pre-2.0

The pre-v2 history is the original Ralph skill: forward-mode bash loops driving
headless agent CLIs (claude, droid, codex, opencode, gemini, copilot,
cc-compatible, custom) plus decompose mode for hierarchical feature breakdown.
See git history before 2026-05-24 for details.
