#!/bin/bash
# Ralph Loop Script — Reference Template
#
# This file serves as the structural reference for generating loop scripts.
# When Ralph creates a new loop, the AI reads this template, understands the
# loop structure (archive, branch tracking, progress init, completion detection),
# and generates a concrete script in .ralph/<loop-name>.sh with the selected
# agent command baked in.
#
# Usage: .ralph/<loop-name>.sh [max_iterations]

set -e

MAX_ITERATIONS=${1:-10}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PRD_FILE="$PROJECT_DIR/prd.json"
PROGRESS_FILE="$PROJECT_DIR/progress.txt"
ARCHIVE_DIR="$PROJECT_DIR/.ralph-archive"
LAST_BRANCH_FILE="$PROJECT_DIR/.ralph-last-branch"
# In generated scripts, this points to the co-located prompt file:
# PROMPT_FILE="$SCRIPT_DIR/<loop-name>-prompt.md"
PROMPT_FILE="$SCRIPT_DIR/prompt.md"

# Archive previous run if branch changed
if [ -f "$PRD_FILE" ] && [ -f "$LAST_BRANCH_FILE" ]; then
  CURRENT_BRANCH=$(jq -r '.branchName // empty' "$PRD_FILE" 2>/dev/null || echo "")
  LAST_BRANCH=$(cat "$LAST_BRANCH_FILE" 2>/dev/null || echo "")

  if [ -n "$CURRENT_BRANCH" ] && [ -n "$LAST_BRANCH" ] && [ "$CURRENT_BRANCH" != "$LAST_BRANCH" ]; then
    DATE=$(date +%Y-%m-%d)
    FOLDER_NAME=$(echo "$LAST_BRANCH" | sed 's|^ralph/||')
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

# Resolve the default branch (the base for the PR)
DEFAULT_BRANCH=$(git -C "$PROJECT_DIR" symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|refs/remotes/origin/||')
if [ -z "$DEFAULT_BRANCH" ]; then
  DEFAULT_BRANCH=$(git -C "$PROJECT_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")
fi

# Push branch and create PR after the loop ends (success or max iterations)
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

  git -C "$PROJECT_DIR" push -u origin "$branch"

  if ! command -v gh >/dev/null 2>&1; then
    echo "gh CLI not found. Push complete, but create PR manually:"
    echo "  gh pr create --head $branch --base $DEFAULT_BRANCH"
    return
  fi

  # Check if a PR already exists for this branch
  local existing_pr
  existing_pr=$(gh pr view "$branch" --repo "$(git -C "$PROJECT_DIR" remote get-url origin)" --json number --jq '.number' 2>/dev/null || echo "")
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

  gh pr create \
    --head "$branch" \
    --base "$DEFAULT_BRANCH" \
    --title "$pr_title" \
    --body "$pr_body" \
    --repo "$(git -C "$PROJECT_DIR" remote get-url origin)"

  echo "PR created."
}

echo "Starting Ralph - Max iterations: $MAX_ITERATIONS"

for i in $(seq 1 $MAX_ITERATIONS); do
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
  OUTPUT=$(AGENT_COMMAND_HERE 2>&1 | tee /dev/stderr) || true

  if echo "$OUTPUT" | grep -q "<promise>COMPLETE</promise>"; then
    echo ""
    echo "Ralph completed all tasks!"
    echo "Completed at iteration $i of $MAX_ITERATIONS"
    finalize "complete"
    exit 0
  fi

  echo "Iteration $i complete. Continuing..."
  sleep 2
done

echo ""
echo "Ralph reached max iterations ($MAX_ITERATIONS) without completing all tasks."
echo "Check $PROGRESS_FILE for status."
finalize "partial"
exit 1
