#!/usr/bin/env bash
set -euo pipefail

# --- Configuration (substituted at generation time) ---
# Keep this block agent-agnostic. Agent-specific flags go in the case arms below.
AGENT="__AGENT__"            # e.g. claude, droid, codex, opencode, gemini, copilot
MODEL="__MODEL__"            # empty string = use CLI default
LOOP_NAME="__LOOP_NAME__"
PROMPT_FILE=".ralph/decompose-${LOOP_NAME}-prompt.md"
DECOMP_FILE="decomp.json"
PRD_FILE="prd.json"
MAX_ITERS="${1:-50}"
# --- End configuration ---

# Validate dependencies
command -v jq >/dev/null 2>&1 || {
  echo "Error: jq is required but not installed. Install it with:"
  echo "  brew install jq    # macOS"
  echo "  apt install jq     # Debian/Ubuntu"
  exit 1
}
[ -f "$DECOMP_FILE" ] || { echo "$DECOMP_FILE not found. Run /ralph decompose first."; exit 1; }
[ -f "$PROMPT_FILE" ] || { echo "$PROMPT_FILE not found. Run /ralph decompose first."; exit 1; }

# Validate agent binary is available before entering the loop
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

# Clean up temp files on exit or signal
ITER_PROMPT_FILE=""
cleanup() { [ -n "$ITER_PROMPT_FILE" ] && rm -f "$ITER_PROMPT_FILE"; true; }
trap cleanup EXIT INT TERM

iter=0

while [ "$iter" -lt "$MAX_ITERS" ]; do
  iter=$((iter + 1))
  echo "Reverse Ralph iteration $iter / $MAX_ITERS"

  # Check if all leaf nodes are atomic (split nodes are done — their children carry the work)
  PENDING=$(jq '[.nodes[] | select(.status != "atomic" and .status != "split")] | length' "$DECOMP_FILE")
  if [ "$PENDING" -eq 0 ]; then
    echo "All nodes are atomic. Generating prd.json..."
    break
  fi

  echo "  Pending nodes: $PENDING"

  # Pick the next node: needs_split before needs_stories (depth-first)
  NEXT_NODE=$(jq -r '
    ([ .nodes[] | select(.status == "needs_split") ] | first | .id) //
    ([ .nodes[] | select(.status == "needs_stories") ] | first | .id) //
    empty
  ' "$DECOMP_FILE")

  if [ -z "$NEXT_NODE" ]; then
    echo "No more pending nodes."
    break
  fi

  # Validate node ID format to prevent sed injection
  if ! printf '%s' "$NEXT_NODE" | grep -qE '^N-[0-9]+$'; then
    echo "Error: unexpected node ID format: '$NEXT_NODE'. Expected N-NNN."
    exit 1
  fi

  # Build the iteration prompt: base template + current decomp.json state
  # NOTE: The full decomp.json is appended to each prompt. For very large feature
  # decompositions (hundreds of nodes), this may approach agent context limits.
  # If that happens, increase max_iterations and let the loop resume across runs.
  ITER_PROMPT_FILE="$(mktemp /tmp/ralph-decompose-iter-XXXXXX.md)"
  sed "s|__NEXT_NODE_ID__|${NEXT_NODE}|g" "$PROMPT_FILE" > "$ITER_PROMPT_FILE"
  printf '\n## Current decomp.json\n```json\n' >> "$ITER_PROMPT_FILE"
  cat "$DECOMP_FILE" >> "$ITER_PROMPT_FILE"
  printf '\n```\n' >> "$ITER_PROMPT_FILE"

  # --- Agent dispatch ---
  # Each arm handles its own flags.
  # MODEL is empty string when not specified; test with [ -n "$MODEL" ] before use.
  # Do NOT add cross-agent flags to the shared block above.

  set +e
  case "$AGENT" in
    claude)
      if [ -n "$MODEL" ]; then
        claude -p "$(cat "$ITER_PROMPT_FILE")" --dangerously-skip-permissions --model "$MODEL"
      else
        claude -p "$(cat "$ITER_PROMPT_FILE")" --dangerously-skip-permissions
      fi
      ;;

    droid)
      # droid exec defaults to read-only spec mode. Writing decomp.json requires
      # at least --auto medium.
      # Do NOT use --use-spec (interactive planning mode, incompatible with headless loops).
      # Do NOT use --skip-permissions-unsafe unless running in a fully sandboxed environment.
      DROID_ARGS=(exec --auto medium -f "$ITER_PROMPT_FILE" --output-format text)
      [ -n "$MODEL" ] && DROID_ARGS+=(-m "$MODEL")
      droid "${DROID_ARGS[@]}"
      ;;

    codex)
      if [ -n "$MODEL" ]; then
        codex exec --yolo -m "$MODEL" "$(cat "$ITER_PROMPT_FILE")"
      else
        codex exec --yolo "$(cat "$ITER_PROMPT_FILE")"
      fi
      ;;

    opencode)
      if [ -n "$MODEL" ]; then
        opencode run --yolo -m "$MODEL" "$(cat "$ITER_PROMPT_FILE")"
      else
        opencode run --yolo "$(cat "$ITER_PROMPT_FILE")"
      fi
      ;;

    gemini)
      if [ -n "$MODEL" ]; then
        gemini -p "$(cat "$ITER_PROMPT_FILE")" --yolo -m "$MODEL"
      else
        gemini -p "$(cat "$ITER_PROMPT_FILE")" --yolo
      fi
      ;;

    copilot)
      if [ -n "$MODEL" ]; then
        copilot -p "$(cat "$ITER_PROMPT_FILE")" --yolo --model "$MODEL"
      else
        copilot -p "$(cat "$ITER_PROMPT_FILE")" --yolo
      fi
      ;;

    cc-compatible)
      if [ -n "$MODEL" ]; then
        "$CC_BINARY" -p "$(cat "$ITER_PROMPT_FILE")" --dangerously-skip-permissions --model "$MODEL"
      else
        "$CC_BINARY" -p "$(cat "$ITER_PROMPT_FILE")" --dangerously-skip-permissions
      fi
      ;;

    custom)
      eval "$CUSTOM_CMD"
      ;;

    *)
      echo "Unknown agent: $AGENT. Supported: claude, droid, codex, opencode, gemini, copilot, cc-compatible, custom"
      exit 1
      ;;
  esac
  AGENT_EXIT=$?
  set -e

  rm -f "$ITER_PROMPT_FILE"
  ITER_PROMPT_FILE=""

  if [ "$AGENT_EXIT" -ne 0 ]; then
    echo ""
    echo "Error: agent command failed with exit code $AGENT_EXIT."
    echo "Fix agent CLI/auth/config and rerun this loop."
    exit "$AGENT_EXIT"
  fi

  echo "  Iteration $iter complete."
done

# Final check (covers break-early path)
PENDING=$(jq '[.nodes[] | select(.status != "atomic" and .status != "split")] | length' "$DECOMP_FILE")

if [ "$PENDING" -gt 0 ]; then
  echo "Loop ended with $PENDING nodes still pending (max iterations reached)."
  echo "Re-run: .ralph/decompose-${LOOP_NAME}.sh $MAX_ITERS"
  exit 0
fi

# Emit prd.json from atomic leaf node stories, sorted by priority
echo "Emitting prd.json..."
jq '{
  feature: .feature_name,
  stories: [
    .nodes[] | select(.status == "atomic") | .stories[] | {
      id,
      title,
      description,
      acceptance_criteria,
      depends_on,
      priority,
      passes: false
    }
  ] | sort_by(.priority)
}' "$DECOMP_FILE" > "$PRD_FILE"

STORY_COUNT=$(jq '.stories | length' "$PRD_FILE")
echo "Done. prd.json written with $STORY_COUNT atomic stories."
echo "Run forward Ralph: .ralph/<your-forward-loop-name>.sh"
