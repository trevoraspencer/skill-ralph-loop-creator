#!/usr/bin/env bash
# Forge Pipeline Script — Reference Template
#
# Multi-phase driver. Reads a pipeline.json manifest and runs phases in order,
# committing after each. Two phase types in this PR:
#   - oneshot: run agent once, commit any changes
#   - loop:    iterate over a markdown-checklist queue (lines starting with
#              "- [ ]") until empty or MAX_ITERS, committing per iteration
#
# Shell-type phases (pre-fetch / arbitrary scripts) land in PR 4.
#
# Env flags:
#   DRY_RUN=1            — skip agent calls and commits; print assembled prompts
#   START_AT=<phase-id>  — skip phases before this one (for resuming)
#
# Usage: .ralph/<pipeline-name>.sh [max_iters_per_loop_phase]
# Default max_iters_per_loop_phase: 200

set -euo pipefail

# --- Configuration (substituted at generation time) ---
AGENT="__AGENT__"            # e.g. claude, droid, codex, opencode, gemini, copilot
MODEL="__MODEL__"            # empty string = use CLI default
PIPELINE_NAME="__PIPELINE_NAME__"
# --- End configuration ---

MAX_ITERS="${1:-200}"
if ! [[ "$MAX_ITERS" =~ ^[0-9]+$ ]] || [ "$MAX_ITERS" -eq 0 ]; then
  echo "Error: max_iters must be a positive integer (got: '$MAX_ITERS')"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PIPELINE_DIR="$SCRIPT_DIR/$PIPELINE_NAME"
PIPELINE_JSON="$PIPELINE_DIR/pipeline.json"
SHARED_DIR="$PIPELINE_DIR/_shared"

START_AT="${START_AT:-}"
DRY_RUN="${DRY_RUN:-}"

# --- Preflight ---

command -v jq >/dev/null 2>&1 || {
  echo "Error: jq is required but not installed. Install with: brew install jq (macOS) or apt install jq (Debian/Ubuntu)"
  exit 1
}

[ -f "$PIPELINE_JSON" ] || { echo "Error: $PIPELINE_JSON not found"; exit 1; }
[ -d "$PIPELINE_DIR" ] || { echo "Error: $PIPELINE_DIR not found"; exit 1; }

# Validate pipeline schema
if ! jq -e '
  type == "object" and
  (.name | type == "string" and length > 0) and
  (.phases | type == "array" and length > 0) and
  (all(.phases[]; .id and .type and (.type == "oneshot" or .type == "loop" or .type == "shell")))
' "$PIPELINE_JSON" >/dev/null 2>&1; then
  echo "Error: $PIPELINE_JSON has invalid schema."
  echo "Required: {name: string, phases: [{id, type: oneshot|loop|shell, ...}]}"
  exit 1
fi

# Validate agent binary
case "$AGENT" in
  cc-compatible)
    : "${CC_BINARY:?CC_BINARY must be set for cc-compatible agent}"
    if ! command -v "$CC_BINARY" >/dev/null 2>&1; then
      echo "Error: agent binary '$CC_BINARY' is not installed or not on PATH."
      exit 1
    fi
    ;;
  custom)
    : "${CUSTOM_CMD:?CUSTOM_CMD must be set for custom agent}"
    ;;
  *)
    if ! command -v "$AGENT" >/dev/null 2>&1; then
      echo "Error: agent binary '$AGENT' is not installed or not on PATH."
      exit 1
    fi
    ;;
esac

# --- Phase ID list (in declared order) ---

# shellcheck disable=SC2207
PHASE_IDS=($(jq -r '.phases[].id' "$PIPELINE_JSON"))

# Validate START_AT if provided
if [ -n "$START_AT" ]; then
  found=0
  for pid in "${PHASE_IDS[@]}"; do
    [ "$pid" = "$START_AT" ] && found=1 && break
  done
  if [ "$found" -ne 1 ]; then
    echo "Error: START_AT='$START_AT' is not a phase id in this pipeline."
    echo "Known phases: ${PHASE_IDS[*]}"
    exit 1
  fi
fi

# --- Helpers ---

# Cleanup any leftover temp prompt files on exit/signal
TMP_PROMPTS=()
cleanup_tmp_prompts() {
  for f in "${TMP_PROMPTS[@]+"${TMP_PROMPTS[@]}"}"; do
    [ -f "$f" ] && rm -f "$f"
  done
  TMP_PROMPTS=()
}
trap cleanup_tmp_prompts EXIT INT TERM

# Decide whether a phase should run, given START_AT.
should_run_phase() {
  local pid="$1"
  if [ -z "$START_AT" ]; then return 0; fi
  local s_idx=-1 p_idx=-1 i
  for i in "${!PHASE_IDS[@]}"; do
    [ "${PHASE_IDS[$i]}" = "$START_AT" ] && s_idx=$i
    [ "${PHASE_IDS[$i]}" = "$pid" ] && p_idx=$i
  done
  [ "$p_idx" -ge "$s_idx" ]
}

# Assemble a prompt file: prepend shared includes (alphabetical) to the base.
assemble_prompt() {
  local base="$1" out="$2"
  if compgen -G "$SHARED_DIR/*.md" >/dev/null 2>&1; then
    cat "$SHARED_DIR"/*.md "$base" > "$out"
  else
    cp "$base" "$out"
  fi
}

# Run the configured agent with the given prompt file. Returns the agent's exit code.
run_agent() {
  local prompt_file="$1"
  case "$AGENT" in
    claude)
      if [ -n "$MODEL" ]; then
        claude -p "$(cat "$prompt_file")" --dangerously-skip-permissions --model "$MODEL"
      else
        claude -p "$(cat "$prompt_file")" --dangerously-skip-permissions
      fi
      ;;
    droid)
      local args=(exec --auto medium -f "$prompt_file" --output-format text)
      [ -n "$MODEL" ] && args+=(-m "$MODEL")
      droid "${args[@]}"
      ;;
    codex)
      if [ -n "$MODEL" ]; then
        codex exec --yolo -m "$MODEL" "$(cat "$prompt_file")"
      else
        codex exec --yolo "$(cat "$prompt_file")"
      fi
      ;;
    opencode)
      if [ -n "$MODEL" ]; then
        opencode run --yolo -m "$MODEL" "$(cat "$prompt_file")"
      else
        opencode run --yolo "$(cat "$prompt_file")"
      fi
      ;;
    gemini)
      if [ -n "$MODEL" ]; then
        gemini -p "$(cat "$prompt_file")" --yolo -m "$MODEL"
      else
        gemini -p "$(cat "$prompt_file")" --yolo
      fi
      ;;
    copilot)
      if [ -n "$MODEL" ]; then
        copilot -p "$(cat "$prompt_file")" --yolo --model "$MODEL"
      else
        copilot -p "$(cat "$prompt_file")" --yolo
      fi
      ;;
    cc-compatible)
      if [ -n "$MODEL" ]; then
        "$CC_BINARY" -p "$(cat "$prompt_file")" --dangerously-skip-permissions --model "$MODEL"
      else
        "$CC_BINARY" -p "$(cat "$prompt_file")" --dangerously-skip-permissions
      fi
      ;;
    custom)
      # Custom commands reference $PROMPT_FILE; override it for the eval scope.
      (PROMPT_FILE="$prompt_file"; eval "$CUSTOM_CMD")
      ;;
    *)
      echo "Unknown agent: $AGENT"
      return 127
      ;;
  esac
}

# Git checkpoint: stage everything and commit if there are changes. Idempotent.
git_checkpoint() {
  local msg="$1"
  git -C "$PROJECT_DIR" add -A
  if git -C "$PROJECT_DIR" diff --cached --quiet; then
    echo "  (no changes to commit for: $msg)"
  else
    git -C "$PROJECT_DIR" commit -q -m "$msg"
  fi
}

# --- Phase runners ---

run_oneshot_phase() {
  local pid="$1" prompt_path="$2" commit_msg="$3"
  echo ""
  echo "═══════════════════════════════════════════════════════"
  echo "  Phase $pid (oneshot)"
  echo "═══════════════════════════════════════════════════════"

  local base="$PIPELINE_DIR/$prompt_path"
  if [ ! -f "$base" ]; then
    echo "Error: phase $pid prompt not found: $base"
    exit 1
  fi

  local assembled
  assembled="$(mktemp /tmp/forge-pipeline-XXXXXX.md)"
  TMP_PROMPTS+=("$assembled")
  assemble_prompt "$base" "$assembled"

  if [ -n "$DRY_RUN" ]; then
    echo "=== DRY_RUN: assembled prompt for $pid ==="
    cat "$assembled"
    echo ""
    echo "=== DRY_RUN: would run agent; would commit: $commit_msg ==="
    rm -f "$assembled"
    return 0
  fi

  set +e
  run_agent "$assembled"
  local rc=$?
  set -e
  rm -f "$assembled"

  if [ "$rc" -ne 0 ]; then
    echo "Error: phase $pid agent exited with code $rc"
    exit "$rc"
  fi

  git_checkpoint "$commit_msg"
}

run_shell_phase() {
  local pid="$1" script_path="$2" commit_msg="$3"
  echo ""
  echo "═══════════════════════════════════════════════════════"
  echo "  Phase $pid (shell)"
  echo "═══════════════════════════════════════════════════════"

  local script="$PIPELINE_DIR/$script_path"
  if [ ! -f "$script" ]; then
    echo "Error: phase $pid shell script not found: $script"
    exit 1
  fi
  if [ ! -x "$script" ]; then
    echo "Error: phase $pid shell script not executable: $script"
    echo "  Fix with: chmod +x $script"
    exit 1
  fi

  if [ -n "$DRY_RUN" ]; then
    echo "=== DRY_RUN: would run shell script for $pid ==="
    echo "  script: $script"
    echo "  would commit: $commit_msg"
    return 0
  fi

  # Run with useful env vars exported. Script chooses inputs/outputs.
  set +e
  ( cd "$PROJECT_DIR" && \
    PIPELINE_DIR="$PIPELINE_DIR" \
    PIPELINE_NAME="$PIPELINE_NAME" \
    PROJECT_DIR="$PROJECT_DIR" \
    "$script" )
  local rc=$?
  set -e

  if [ "$rc" -ne 0 ]; then
    echo "Error: phase $pid shell script exited with code $rc"
    exit "$rc"
  fi

  git_checkpoint "$commit_msg"
}

run_loop_phase() {
  local pid="$1" prompt_path="$2" queue_path="$3" commit_prefix="$4" phase_max_iters="$5"
  echo ""
  echo "═══════════════════════════════════════════════════════"
  echo "  Phase $pid (loop)"
  echo "═══════════════════════════════════════════════════════"

  local base="$PIPELINE_DIR/$prompt_path"
  local queue="$PIPELINE_DIR/$queue_path"
  [ -f "$base" ] || { echo "Error: phase $pid prompt not found: $base"; exit 1; }
  [ -f "$queue" ] || { echo "Error: phase $pid queue not found: $queue"; exit 1; }

  # Use phase-specific max_iters if provided, otherwise the global default.
  local mi="$MAX_ITERS"
  if [ -n "$phase_max_iters" ] && [ "$phase_max_iters" != "null" ]; then
    mi="$phase_max_iters"
  fi

  local assembled
  assembled="$(mktemp /tmp/forge-pipeline-XXXXXX.md)"
  TMP_PROMPTS+=("$assembled")
  assemble_prompt "$base" "$assembled"

  if [ -n "$DRY_RUN" ]; then
    echo "=== DRY_RUN: assembled loop prompt for $pid ==="
    cat "$assembled"
    echo ""
    echo "=== DRY_RUN: queue ($queue) ==="
    cat "$queue"
    echo ""
    echo "=== DRY_RUN: would iterate up to $mi times; would commit per item ($commit_prefix: <item>) ==="
    rm -f "$assembled"
    return 0
  fi

  local i=0
  while [ "$i" -lt "$mi" ]; do
    if ! grep -q '^- \[ \]' "$queue"; then
      echo "  Queue empty after $i iterations — phase $pid done"
      rm -f "$assembled"
      return 0
    fi
    local item
    item="$(grep -m1 '^- \[ \]' "$queue" | sed 's/^- \[ \] //;s/[[:space:]]*$//')"
    echo "  Iter $((i+1))/$mi — $item"

    set +e
    run_agent "$assembled"
    local rc=$?
    set -e
    if [ "$rc" -ne 0 ]; then
      echo "  Agent iteration failed for '$item' — continuing"
    fi

    git_checkpoint "${commit_prefix}: $item"
    i=$((i+1))
    sleep 2
  done

  # Hit max_iters without draining the queue.
  if grep -q '^- \[ \]' "$queue"; then
    echo ""
    echo "Phase $pid hit max_iters=$mi with queue not empty."
    echo "Re-run with: START_AT=$pid .ralph/$PIPELINE_NAME.sh [max_iters]"
    echo "Downstream phases skipped — wrap-up phases require the loop to be complete."
    rm -f "$assembled"
    exit 0
  fi

  rm -f "$assembled"
}

# --- Main: iterate phases ---

echo "Starting Forge pipeline: $PIPELINE_NAME"
[ -n "$START_AT" ] && echo "  START_AT=$START_AT"
[ -n "$DRY_RUN" ] && echo "  DRY_RUN=1 (no agent calls, no commits)"

for pid in "${PHASE_IDS[@]}"; do
  if ! should_run_phase "$pid"; then
    echo "skip $pid (before START_AT=$START_AT)"
    continue
  fi

  ptype=$(jq -r --arg id "$pid" '.phases[] | select(.id==$id) | .type' "$PIPELINE_JSON")
  prompt_path=$(jq -r --arg id "$pid" '.phases[] | select(.id==$id) | .prompt // empty' "$PIPELINE_JSON")

  case "$ptype" in
    oneshot)
      commit_msg=$(jq -r --arg id "$pid" '.phases[] | select(.id==$id) | .commit // "phase: \($id)"' "$PIPELINE_JSON")
      [ -z "$prompt_path" ] && { echo "Error: oneshot phase $pid missing prompt"; exit 1; }
      run_oneshot_phase "$pid" "$prompt_path" "$commit_msg"
      ;;
    loop)
      queue_path=$(jq -r --arg id "$pid" '.phases[] | select(.id==$id) | .queue // empty' "$PIPELINE_JSON")
      commit_prefix=$(jq -r --arg id "$pid" '.phases[] | select(.id==$id) | .commit_prefix // "iter"' "$PIPELINE_JSON")
      phase_mi=$(jq -r --arg id "$pid" '.phases[] | select(.id==$id) | .max_iters // empty' "$PIPELINE_JSON")
      [ -z "$prompt_path" ] && { echo "Error: loop phase $pid missing prompt"; exit 1; }
      [ -z "$queue_path" ] && { echo "Error: loop phase $pid missing queue"; exit 1; }
      run_loop_phase "$pid" "$prompt_path" "$queue_path" "$commit_prefix" "$phase_mi"
      ;;
    shell)
      script_path=$(jq -r --arg id "$pid" '.phases[] | select(.id==$id) | .script // empty' "$PIPELINE_JSON")
      commit_msg=$(jq -r --arg id "$pid" '.phases[] | select(.id==$id) | .commit // "phase: \($id)"' "$PIPELINE_JSON")
      [ -z "$script_path" ] && { echo "Error: shell phase $pid missing script"; exit 1; }
      run_shell_phase "$pid" "$script_path" "$commit_msg"
      ;;
    *)
      echo "Error: unknown phase type '$ptype' for phase $pid"
      exit 1
      ;;
  esac
done

echo ""
echo "Pipeline '$PIPELINE_NAME' complete."
