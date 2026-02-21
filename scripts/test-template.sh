#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMPLATE="$ROOT_DIR/scripts/ralph.sh"

if ! command -v jq >/dev/null 2>&1; then
  echo "Error: jq is required to run template tests."
  exit 1
fi

render_script() {
  local out_file="$1"
  local agent_bin="$2"
  local agent_cmd="$3"

  awk -v agent_bin="$agent_bin" -v agent_cmd="$agent_cmd" '
    {
      gsub(/AGENT_BIN_HERE/, agent_bin);
      gsub(/AGENT_COMMAND_HERE/, agent_cmd);
      print;
    }
  ' "$TEMPLATE" > "$out_file"
  chmod +x "$out_file"
}

assert_contains() {
  local file="$1"
  local pattern="$2"
  local label="$3"
  if ! grep -q "$pattern" "$file"; then
    echo "FAIL: $label"
    echo "Expected output to contain: $pattern"
    echo "--- output ---"
    cat "$file"
    exit 1
  fi
}

echo "Running template smoke tests..."

TMP1="$(mktemp -d)"
TMP2="$(mktemp -d)"
TMP3="$(mktemp -d)"
trap 'rm -rf "$TMP1" "$TMP2" "$TMP3"' EXIT

# Test 1: successful completion when agent emits COMPLETE marker.
mkdir -p "$TMP1/.ralph"
render_script \
  "$TMP1/.ralph/smoke.sh" \
  "bash" \
  "bash -lc 'echo \"<promise>COMPLETE</promise>\"'"
cat > "$TMP1/prd.json" <<'JSON'
{"branchName":"ralph/smoke","userStories":[]}
JSON

if ! (cd "$TMP1" && ./.ralph/smoke.sh 1 >"$TMP1/out.txt" 2>&1); then
  echo "FAIL: expected successful completion path"
  cat "$TMP1/out.txt"
  exit 1
fi
assert_contains "$TMP1/out.txt" "Ralph completed all tasks!" "completion path"

# Test 2: invalid prd.json fails preflight.
mkdir -p "$TMP2/.ralph"
render_script \
  "$TMP2/.ralph/smoke.sh" \
  "bash" \
  "bash -lc 'echo \"should not run\"'"
cat > "$TMP2/prd.json" <<'JSON'
{"branch":"missing-required-fields"}
JSON

if (cd "$TMP2" && ./.ralph/smoke.sh 1 >"$TMP2/out.txt" 2>&1); then
  echo "FAIL: invalid prd.json should fail"
  cat "$TMP2/out.txt"
  exit 1
fi
assert_contains "$TMP2/out.txt" "is invalid" "invalid prd preflight"

# Test 3: missing agent binary fails before loop starts.
mkdir -p "$TMP3/.ralph"
render_script \
  "$TMP3/.ralph/smoke.sh" \
  "definitely-not-installed-binary" \
  "bash -lc 'echo \"should not run\"'"
cat > "$TMP3/prd.json" <<'JSON'
{"branchName":"ralph/smoke","userStories":[]}
JSON

if (cd "$TMP3" && ./.ralph/smoke.sh 1 >"$TMP3/out.txt" 2>&1); then
  echo "FAIL: missing agent binary should fail"
  cat "$TMP3/out.txt"
  exit 1
fi
assert_contains "$TMP3/out.txt" "not installed or not on PATH" "agent binary preflight"

echo "All template smoke tests passed."
