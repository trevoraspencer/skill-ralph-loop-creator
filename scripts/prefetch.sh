#!/usr/bin/env bash
# Forge prefetch reference — TSV-driven external source fetcher
#
# Reads a tab-separated manifest of sources and pulls each one to local disk
# under <evidence-dir>/<class>/<slug>.<ext>. Designed to be used as the
# script for a `shell` phase in a Forge pipeline, but can be invoked
# standalone for any workflow that wants a hermetic local corpus.
#
# Manifest format (TSV, one header row, tabs between fields):
#
#   class                  slug          identifier              notes
#   http_get_md            intro         https://example/intro   landing
#   github_readme          readme        owner/repo              repo README
#   github_issues_json     issues        owner/repo              issues JSON
#   github_prs_json        prs           owner/repo              PRs JSON
#   local_file             internal      docs/spec.md            internal spec
#
# Source classes:
#   http_get_md         — fetch URL with curl, convert HTML→markdown with pandoc.
#                         Falls back to writing raw HTML if pandoc fails.
#                         Output: <evidence>/<class>/<slug>.md (or .html on fallback)
#   github_readme       — gh api repos/<owner>/<repo>/readme (raw)
#                         Output: <evidence>/<class>/<slug>.md
#   github_issues_json  — gh issue list --repo <owner>/<repo> --state all --limit 2000
#                         Output: <evidence>/<class>/<slug>.json
#   github_prs_json     — gh pr list --repo <owner>/<repo> --state all --limit 2000
#                         Output: <evidence>/<class>/<slug>.json
#   local_file          — cp the local file (identifier = relative path) to evidence
#                         Output: <evidence>/<class>/<slug>.<original-ext>
#
# Idempotent: existing output files are skipped unless REFRESH=1 is set.
#
# Usage:
#   prefetch.sh [manifest.tsv] [evidence-dir]
#
# Defaults:
#   manifest.tsv  = $PIPELINE_DIR/manifest.tsv (or ./manifest.tsv)
#   evidence-dir  = $PIPELINE_DIR/evidence    (or ./evidence)

set -euo pipefail

MANIFEST="${1:-${PIPELINE_DIR:-.}/manifest.tsv}"
EVIDENCE_DIR="${2:-${PIPELINE_DIR:-.}/evidence}"
REFRESH="${REFRESH:-}"

log() { printf '[prefetch] %s\n' "$*" >&2; }

# --- Preflight ---

[ -f "$MANIFEST" ] || { log "manifest not found: $MANIFEST"; exit 1; }

need_curl=0; need_pandoc=0; need_gh=0
while IFS=$'\t' read -r class _slug _identifier _notes; do
  [ "$class" = "class" ] && continue
  [ -z "$class" ] && continue
  case "$class" in
    http_get_md)        need_curl=1; need_pandoc=1 ;;
    github_readme|github_issues_json|github_prs_json)
                        need_gh=1 ;;
    local_file)         ;;
    *)                  log "warning: unknown class '$class' (will be skipped)" ;;
  esac
done < "$MANIFEST"

missing=()
[ "$need_curl"   = 1 ] && ! command -v curl   >/dev/null && missing+=("curl")
[ "$need_pandoc" = 1 ] && ! command -v pandoc >/dev/null && missing+=("pandoc")
[ "$need_gh"     = 1 ] && ! command -v gh     >/dev/null && missing+=("gh")
if [ "${#missing[@]}" -gt 0 ]; then
  log "missing required commands for this manifest: ${missing[*]}"
  log "install them or remove the corresponding rows from $MANIFEST"
  exit 1
fi

mkdir -p "$EVIDENCE_DIR"

# --- Source-class handlers ---

fetch_http_get_md() {
  local slug="$1" url="$2"
  local out_md="$EVIDENCE_DIR/http_get_md/$slug.md"
  local out_html="$EVIDENCE_DIR/http_get_md/$slug.html"
  if [ -f "$out_md" ] || [ -f "$out_html" ]; then
    [ -z "$REFRESH" ] && { log "  skip http_get_md/$slug (already fetched; REFRESH=1 to refetch)"; return 0; }
  fi
  mkdir -p "$EVIDENCE_DIR/http_get_md"

  local tmp; tmp="$(mktemp)"
  if ! curl -sSL --max-time 60 -A "Mozilla/5.0 (forge-prefetch)" "$url" -o "$tmp"; then
    log "  curl failed for $url — skipping"
    rm -f "$tmp"
    return 0
  fi

  if pandoc -f html -t gfm --wrap=none "$tmp" -o "$out_md" 2>/dev/null; then
    log "  http_get_md/$slug.md ($(wc -c < "$out_md") bytes)"
  else
    cp "$tmp" "$out_html"
    log "  http_get_md/$slug.html ($(wc -c < "$out_html") bytes; pandoc fallback to raw HTML)"
  fi
  rm -f "$tmp"
}

fetch_github_readme() {
  local slug="$1" repo="$2"
  local out="$EVIDENCE_DIR/github_readme/$slug.md"
  [ -f "$out" ] && [ -z "$REFRESH" ] && { log "  skip github_readme/$slug (already fetched)"; return 0; }
  mkdir -p "$EVIDENCE_DIR/github_readme"
  if gh api -H "Accept: application/vnd.github.raw" "repos/$repo/readme" > "$out" 2>/dev/null; then
    log "  github_readme/$slug.md ($(wc -c < "$out") bytes)"
  else
    rm -f "$out"
    log "  gh fetch failed for $repo readme — skipping"
  fi
}

fetch_github_issues_json() {
  local slug="$1" repo="$2"
  local out="$EVIDENCE_DIR/github_issues_json/$slug.json"
  [ -f "$out" ] && [ -z "$REFRESH" ] && { log "  skip github_issues_json/$slug (already fetched)"; return 0; }
  mkdir -p "$EVIDENCE_DIR/github_issues_json"
  if gh issue list --repo "$repo" --state all --limit 2000 \
       --json number,title,body,state,labels,createdAt,updatedAt,url,author,comments \
       > "$out" 2>/dev/null; then
    log "  github_issues_json/$slug.json ($(wc -c < "$out") bytes)"
  else
    rm -f "$out"
    log "  gh issue list failed for $repo — skipping"
  fi
}

fetch_github_prs_json() {
  local slug="$1" repo="$2"
  local out="$EVIDENCE_DIR/github_prs_json/$slug.json"
  [ -f "$out" ] && [ -z "$REFRESH" ] && { log "  skip github_prs_json/$slug (already fetched)"; return 0; }
  mkdir -p "$EVIDENCE_DIR/github_prs_json"
  if gh pr list --repo "$repo" --state all --limit 2000 \
       --json number,title,body,state,labels,createdAt,updatedAt,mergedAt,url,author \
       > "$out" 2>/dev/null; then
    log "  github_prs_json/$slug.json ($(wc -c < "$out") bytes)"
  else
    rm -f "$out"
    log "  gh pr list failed for $repo — skipping"
  fi
}

fetch_local_file() {
  local slug="$1" path="$2"
  if [ ! -f "$path" ]; then
    log "  local_file/$slug: source not found: $path — skipping"
    return 0
  fi
  local ext="${path##*.}"
  [ "$ext" = "$path" ] && ext="md"  # no extension → assume .md
  local out="$EVIDENCE_DIR/local_file/$slug.$ext"
  [ -f "$out" ] && [ -z "$REFRESH" ] && { log "  skip local_file/$slug (already copied)"; return 0; }
  mkdir -p "$EVIDENCE_DIR/local_file"
  cp "$path" "$out"
  log "  local_file/$slug.$ext"
}

# --- Main: iterate manifest rows ---

log "manifest: $MANIFEST"
log "evidence: $EVIDENCE_DIR"

count=0
while IFS=$'\t' read -r class slug identifier _notes; do
  [ "$class" = "class" ] && continue
  [ -z "$class" ] && continue
  [ -z "$slug" ] && { log "warning: row missing slug — skipping"; continue; }
  [ -z "$identifier" ] && { log "warning: row missing identifier — skipping ($class/$slug)"; continue; }
  count=$((count + 1))
  case "$class" in
    http_get_md)         fetch_http_get_md         "$slug" "$identifier" ;;
    github_readme)       fetch_github_readme       "$slug" "$identifier" ;;
    github_issues_json)  fetch_github_issues_json  "$slug" "$identifier" ;;
    github_prs_json)     fetch_github_prs_json     "$slug" "$identifier" ;;
    local_file)          fetch_local_file          "$slug" "$identifier" ;;
    *)                   log "  unknown class '$class' — skipping ($slug)" ;;
  esac
done < "$MANIFEST"

log "processed $count manifest rows"
