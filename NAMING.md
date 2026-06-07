# Naming model (Forge vs Ralph)

Forge was renamed from Ralph in v2.0.0. The repo uses **three naming layers** on
purpose — not accidental drift.

## 1. Product identity (Forge)

What users invoke and install:

| Item | Value |
|------|-------|
| Slash command | `/forge` (formerly `/ralph`) |
| Skill `name:` | `forge` |
| Install directory | `.claude/skills/forge/` or `.factory/skills/forge/` |
| New git branch prefix | `forge/<feature>` in `prd.json` |
| PR titles from loops | `forge: …` |

Natural-language triggers like "use ralph to …" remain in the skill description
for muscle memory. They route to the same Forge skill.

## 2. Runtime contract (Ralph paths — frozen for backward compatibility)

Generated loop scripts and on-disk state keep v1 paths so existing projects
continue to work without migration:

| Item | Value |
|------|-------|
| Loop scripts | `.ralph/<loop-name>.sh` |
| Prompt files | `.ralph/<loop-name>-prompt.md` |
| Shared includes | `.ralph/_shared/*.md` |
| Pipeline layout | `.ralph/<pipeline-name>/` |
| Archives | `.ralph-archive/` |
| Branch tracker | `.ralph-last-branch` |

Do **not** rename these in a minor release. A full `.forge/` runtime rename would
be a v3 breaking change with a migration guide.

## 3. Repo source (mixed — intentional)

| Item | Current name | Notes |
|------|--------------|-------|
| GitHub repo | `skill-ralph-loop-creator` | Kept for SEO and continuity |
| Forward template | `scripts/ralph.sh` | Reference driver copied at generation time; header says "Forge" |
| Decompose / pipeline templates | `scripts/decompose.sh`, `scripts/pipeline.sh` | Already neutral names |

## Legacy `prd.json` branches

Existing files with `"branchName": "ralph/…"` keep working — the loop script
reads whatever branch name is in `prd.json`. Archive folder names strip both
`ralph/` and `forge/` prefixes when saving to `.ralph-archive/`.

New forward loops and decompose output use the `forge/` prefix.

## Quick reference

```
User says /forge          →  generates .ralph/my-loop.sh  →  checks out forge/my-feature
Old v1 install: skills/ralph/  →  migrate to skills/forge/
Old prd.json: ralph/foo   →  still valid; archive strips ralph/ or forge/ prefix
```

See [Migration from Ralph](README.md#migration-from-ralph) for install-path upgrades.
