#!/bin/bash
# Ralph Loop Script — Reference Template
#
# This file serves as the structural reference for generating loop scripts.
# When Ralph creates a new loop, the AI reads this template, understands the
# loop structure (archive, branch tracking, progress init, completion detection),
# and generates a concrete script in .ralph/<loop-name>.sh with the selected
# agent command baked in.
#
# The section between "BEGIN: AUTO-PUSH+PR" and "END: AUTO-PUSH+PR" markers is
# CONDITIONAL. Only include it if the user opted for auto-push+PR in Step 2d.
# If they chose local-only, delete that entire section and the finalize() call
# sites in the loop. See the markers and comments in the section for details.
#
# Usage: .ralph/<loop-name>.sh [max_iterations]

set -e
set -o pipefail

MAX_ITERATIONS=${1:-10}
if ! [[ "$MAX_ITERATIONS" =~ ^[0-9]+$ ]] || [ "$MAX_ITERATIONS" -eq 0 ]; then
  echo "Error: max_iterations must be a positive integer (got: '$MAX_ITERATIONS')"
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "Error: jq is required but not installed. Install it with:"
  echo "  brew install jq    # macOS"
  echo "  apt install jq     # Debian/Ubuntu"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PRD_FILE="$PROJECT_DIR/prd.json"
PROGRESS_FILE="$PROJECT_DIR/progress.txt"
ARCHIVE_DIR="$PROJECT_DIR/.ralph-archive"
LAST_BRANCH_FILE="$PROJECT_DIR/.ralph-last-branch"
# In generated scripts, this points to the co-located prompt file:
# PROMPT_FILE="$SCRIPT_DIR/<loop-name>-prompt.md"
# shellcheck disable=SC2034
PROMPT_FILE="$SCRIPT_DIR/prompt.md"
# In generated scripts, this is set to the selected executable (e.g. claude).
AGENT_BIN="AGENT_BIN_HERE"

if [ ! -f "$PRD_FILE" ]; then
  echo "Error: missing $PRD_FILE. Generate prd.json before running this loop."
  exit 1
fi

if ! jq -e '
  type == "object" and
  (.branchName | type == "string" and length > 0) and
  (.userStories | type == "array")
' "$PRD_FILE" >/dev/null 2>&1; then
  echo "Error: $PRD_FILE is invalid. It must include non-empty string branchName and array userStories."
  exit 1
fi

if [[ "$AGENT_BIN" == AGENT_BIN_* ]]; then
  echo "Error: AGENT_BIN placeholder was not replaced in this generated script."
  echo "Regenerate the loop script so AGENT_BIN points to your chosen CLI."
  exit 1
fi

if ! command -v "$AGENT_BIN" >/dev/null 2>&1; then
  echo "Error: agent binary '$AGENT_BIN' is not installed or not on PATH."
  exit 1
fi

# Archive previous run if branch changed
if [ -f "$PRD_FILE" ] && [ -f "$LAST_BRANCH_FILE" ]; then
  CURRENT_BRANCH=$(jq -r '.branchName // empty' "$PRD_FILE" 2>/dev/null || echo "")
  LAST_BRANCH=$(cat "$LAST_BRANCH_FILE" 2>/dev/null || echo "")

  if [ -n "$CURRENT_BRANCH" ] && [ -n "$LAST_BRANCH" ] && [ "$CURRENT_BRANCH" != "$LAST_BRANCH" ]; then
    DATE=$(date +%Y-%m-%d)
    FOLDER_NAME=${LAST_BRANCH#ralph/}
    ARCHIVE_FOLDER="$ARCHIVE_DIR/$DATE-$FOLDER_NAME"

    echo "Archiving previous run: $LAST_BRANCH"
    mkdir -p "$ARCHIVE_FOLDER"

    if git -C "$PROJECT_DIR" show "$LAST_BRANCH:prd.json" > "$ARCHIVE_FOLDER/prd.json" 2>/dev/null; then
      :
    else
      rm -f "$ARCHIVE_FOLDER/prd.json"
      echo "   Could not archive prd.json from branch: $LAST_BRANCH"
    fi

    if git -C "$PROJECT_DIR" show "$LAST_BRANCH:progress.txt" > "$ARCHIVE_FOLDER/progress.txt" 2>/dev/null; then
      :
    else
      rm -f "$ARCHIVE_FOLDER/progress.txt"
      echo "   Could not archive progress.txt from branch: $LAST_BRANCH"
    fi

    echo "   Archived to: $ARCHIVE_FOLDER"

    echo "# Ralph Progress Log" > "$PROGRESS_FILE"
    echo "Started: $(date)" >> "$PROGRESS_FILE"
    echo "---" >> "$PROGRESS_FILE"
  fi
fi

# Track current branch
if [ -f "$PRD_FILE" ]; then
  CURRENT_BRANCH=$(jq -r '.branchName // empty' "$PRD_FILE" 2>/dev/null || echo "")
  if [ -n "$CURRENT_BRANCH" ]; then
    echo "$CURRENT_BRANCH" > "$LAST_BRANCH_FILE"
  fi
fi

# Initialize progress file if it doesn't exist
if [ ! -f "$PROGRESS_FILE" ]; then
  echo "# Ralph Progress Log" > "$PROGRESS_FILE"
  echo "Started: $(date)" >> "$PROGRESS_FILE"
  echo "---" >> "$PROGRESS_FILE"
fi

# === BEGIN: AUTO-PUSH+PR (include this section only if user opted in at Step 2d) ===
# When generating a concrete script:
#   - If the user said YES to auto-push+PR: include this entire section and set
#     DEFAULT_BRANCH to the detected base branch (main/master).
#   - If the user said NO: delete this entire section (from BEGIN to END marker)
#     and also remove the two `if [ "$AUTO_PUSH_PR" = "true" ]` blocks in the
#     loop below.
AUTO_PUSH_PR="false"
# Baked in at generation time by checking:
#   1. Does refs/remotes/origin/main exist? → "main"
#   2. Does refs/remotes/origin/master exist? → "master"
#   3. Neither → default to "main"
DEFAULT_BRANCH="main"

# Push branch and create PR after the loop ends. Errors are handled gracefully —
# a push or PR failure never masks a successful loop run.
finalize() {
  local status="$1"
  local branch

  branch=$(git -C "$PROJECT_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
  if [ -z "$branch" ] || [ "$branch" = "$DEFAULT_BRANCH" ]; then
    echo "Not on a feature branch; skipping push and PR."
    return
  fi

  # Check if there are any commits on this branch beyond the default branch
  local commit_count
  commit_count=$(git -C "$PROJECT_DIR" rev-list --count "$DEFAULT_BRANCH..$branch" 2>/dev/null || echo "0")
  if [ "$commit_count" -eq 0 ]; then
    echo "No commits on branch $branch; skipping push and PR."
    return
  fi

  echo ""
  echo "═══════════════════════════════════════════════════════"
  echo "  Pushing branch and creating PR"
  echo "═══════════════════════════════════════════════════════"

  if ! git -C "$PROJECT_DIR" push -u origin "$branch"; then
    echo ""
    echo "Warning: git push failed. Push manually with:"
    echo "  git push -u origin $branch"
    return
  fi

  if ! command -v gh >/dev/null 2>&1; then
    echo "gh CLI not found. Push complete, but create PR manually:"
    echo "  gh pr create --head '$branch' --base '$DEFAULT_BRANCH'"
    return
  fi

  # Check if a PR already exists for this branch
  local existing_pr
  existing_pr=$(cd "$PROJECT_DIR" && gh pr view "$branch" --json number --jq '.number' 2>/dev/null || echo "")
  if [ -n "$existing_pr" ]; then
    echo "PR #$existing_pr already exists for branch $branch"
    return
  fi

  local pr_title pr_body
  if [ "$status" = "complete" ]; then
    pr_title="ralph: all stories complete"
    pr_body="All user stories in prd.json have been implemented and pass quality checks.

See \`progress.txt\` for iteration-by-iteration details."
  else
    pr_title="ralph: partial progress (max iterations reached)"
    pr_body="Ralph reached max iterations before all stories were complete.

Check \`prd.json\` for story status and \`progress.txt\` for details on what was accomplished and any blockers."
  fi

  if ! (
    cd "$PROJECT_DIR" && gh pr create \
      --head "$branch" \
      --base "$DEFAULT_BRANCH" \
      --title "$pr_title" \
      --body "$pr_body"
  ); then
    echo ""
    echo "Warning: PR creation failed. Push succeeded. Create PR manually:"
    echo "  gh pr create --head '$branch' --base '$DEFAULT_BRANCH'"
    return
  fi

  echo "PR created."
}
# === END: AUTO-PUSH+PR ===

echo "Starting Ralph - Max iterations: $MAX_ITERATIONS"

for i in $(seq 1 "$MAX_ITERATIONS"); do
  echo ""
  echo "═══════════════════════════════════════════════════════"
  echo "  Ralph Iteration $i of $MAX_ITERATIONS"
  echo "═══════════════════════════════════════════════════════"

  # === AGENT COMMAND (replaced during generation) ===
  # Claude Code:    claude -p "$(cat "$PROMPT_FILE")" --dangerously-skip-permissions --model MODEL
  # Factory Droid:  droid exec --skip-permissions-unsafe -f "$PROMPT_FILE" --output-format text -m MODEL
  # OpenAI Codex:   codex exec --yolo -m MODEL "$(cat "$PROMPT_FILE")"
  # OpenCode:       opencode run --yolo -m MODEL "$(cat "$PROMPT_FILE")"
  # Gemini CLI:     gemini -p "$(cat "$PROMPT_FILE")" --yolo -m MODEL
  # GitHub Copilot: copilot -p "$(cat "$PROMPT_FILE")" --yolo --model MODEL
  # CC-Mirror:      $BINARY -p "$(cat "$PROMPT_FILE")" --dangerously-skip-permissions --model MODEL
  set +e
  OUTPUT=$(AGENT_COMMAND_HERE 2>&1 | tee /dev/stderr)
  AGENT_EXIT=$?
  set -e

  if [ "$AGENT_EXIT" -ne 0 ]; then
    echo ""
    echo "Error: agent command failed with exit code $AGENT_EXIT."
    echo "Fix agent CLI/auth/config and rerun this loop."
    exit "$AGENT_EXIT"
  fi

  if echo "$OUTPUT" | grep -q "<promise>COMPLETE</promise>"; then
    echo ""
    echo "Ralph completed all tasks!"
    echo "Completed at iteration $i of $MAX_ITERATIONS"
    if [ "$AUTO_PUSH_PR" = "true" ]; then
      finalize "complete"
    fi
    exit 0
  fi

  echo "Iteration $i complete. Continuing..."
  sleep 2
done

echo ""
echo "Ralph reached max iterations ($MAX_ITERATIONS) without completing all tasks."
echo "Check $PROGRESS_FILE for status."
if [ "$AUTO_PUSH_PR" = "true" ]; then
  finalize "partial"
fi
exit 1
