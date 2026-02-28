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
TMP4="$(mktemp -d)"
TMP5="$(mktemp -d)"
TMP6="$(mktemp -d)"
TMP7="$(mktemp -d)"
TMP8="$(mktemp -d)"
TMP9="$(mktemp -d)"
TMP10="$(mktemp -d)"
trap 'rm -rf "$TMP1" "$TMP2" "$TMP3" "$TMP4" "$TMP5" "$TMP6" "$TMP7" "$TMP8" "$TMP9" "$TMP10"' EXIT

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

echo "All forward Ralph smoke tests passed."

# ═══════════════════════════════════════════════════════
# Reverse Ralph (decompose.sh) smoke tests
# ═══════════════════════════════════════════════════════

DECOMPOSE_TEMPLATE="$ROOT_DIR/scripts/decompose.sh"

render_decompose_script() {
  local out_file="$1"
  local agent="$2"
  local model="$3"
  local loop_name="$4"

  sed \
    -e "s|__AGENT__|${agent}|g" \
    -e "s|__MODEL__|${model}|g" \
    -e "s|__LOOP_NAME__|${loop_name}|g" \
    "$DECOMPOSE_TEMPLATE" > "$out_file"
  chmod +x "$out_file"
}

echo ""
echo "Running decompose template smoke tests..."

# Test 4: decompose.sh exits with clear error if decomp.json is missing
# Use custom agent to skip the agent binary preflight (we're testing file checks, not agent checks)
mkdir -p "$TMP4/.ralph"
render_decompose_script "$TMP4/.ralph/decompose-smoke.sh" "custom" "" "smoke"
cp "$ROOT_DIR/scripts/decompose-prompt.md" "$TMP4/.ralph/decompose-smoke-prompt.md"
# Do NOT create decomp.json

if (cd "$TMP4" && CUSTOM_CMD="echo noop" ./.ralph/decompose-smoke.sh 1 >"$TMP4/out.txt" 2>&1); then
  echo "FAIL: missing decomp.json should fail"
  cat "$TMP4/out.txt"
  exit 1
fi
assert_contains "$TMP4/out.txt" "decomp.json not found" "decompose: missing decomp.json"
echo "  Test 4 passed: missing decomp.json"

# Test 5: decompose.sh exits with clear error if jq is not installed
# Create a fake PATH that has bash/sed/cat but NOT jq
mkdir -p "$TMP5/.ralph"
FAKE_BIN="$TMP5/fake-bin"
mkdir -p "$FAKE_BIN"
# Symlink essential commands but not jq
for cmd in bash sed cat mktemp printf grep env; do
  CMD_PATH="$(command -v "$cmd" 2>/dev/null || true)"
  [ -n "$CMD_PATH" ] && ln -sf "$CMD_PATH" "$FAKE_BIN/$cmd"
done
render_decompose_script "$TMP5/.ralph/decompose-smoke.sh" "custom" "" "smoke"
cp "$ROOT_DIR/scripts/decompose-prompt.md" "$TMP5/.ralph/decompose-smoke-prompt.md"
cat > "$TMP5/decomp.json" <<'JSON'
{"feature_name":"test","source_urls":[],"capability_surface":"test","nodes":[],"completed_at":null}
JSON

if (cd "$TMP5" && CUSTOM_CMD="echo noop" PATH="$FAKE_BIN" ./.ralph/decompose-smoke.sh 1 >"$TMP5/out.txt" 2>&1); then
  echo "FAIL: missing jq should fail"
  cat "$TMP5/out.txt"
  exit 1
fi
assert_contains "$TMP5/out.txt" "jq is required" "decompose: missing jq"
echo "  Test 5 passed: missing jq"

# Test 6: decompose.sh exits with clear error if prompt file is missing
mkdir -p "$TMP6/.ralph"
render_decompose_script "$TMP6/.ralph/decompose-smoke.sh" "custom" "" "smoke"
cat > "$TMP6/decomp.json" <<'JSON'
{"feature_name":"test","source_urls":[],"capability_surface":"test","nodes":[],"completed_at":null}
JSON
# Do NOT create prompt file

if (cd "$TMP6" && CUSTOM_CMD="echo noop" ./.ralph/decompose-smoke.sh 1 >"$TMP6/out.txt" 2>&1); then
  echo "FAIL: missing prompt file should fail"
  cat "$TMP6/out.txt"
  exit 1
fi
assert_contains "$TMP6/out.txt" "not found" "decompose: missing prompt file"
echo "  Test 6 passed: missing prompt file"

# Test 7: all-atomic decomp.json skips loop and emits prd.json immediately
# Use custom agent — the loop should never invoke the agent since all nodes are already atomic.
mkdir -p "$TMP7/.ralph"
render_decompose_script "$TMP7/.ralph/decompose-smoke.sh" "custom" "" "smoke"
cp "$ROOT_DIR/scripts/decompose-prompt.md" "$TMP7/.ralph/decompose-smoke-prompt.md"
cat > "$TMP7/decomp.json" <<'JSON'
{
  "feature_name": "Test Feature",
  "source_urls": [],
  "capability_surface": "test",
  "nodes": [
    {
      "id": "N-001",
      "parent_id": null,
      "title": "Already Atomic Node",
      "description": "This node is already atomic.",
      "status": "atomic",
      "children": [],
      "stories": [
        {
          "id": "US-001",
          "node_id": "N-001",
          "title": "Test story",
          "description": "As a user, I want a test so that testing works.",
          "acceptance_criteria": ["It works"],
          "depends_on": [],
          "priority": 1
        }
      ]
    }
  ],
  "completed_at": null
}
JSON

if ! (cd "$TMP7" && CUSTOM_CMD="echo noop" ./.ralph/decompose-smoke.sh 1 >"$TMP7/out.txt" 2>&1); then
  echo "FAIL: all-atomic should succeed"
  cat "$TMP7/out.txt"
  exit 1
fi
assert_contains "$TMP7/out.txt" "All nodes are atomic" "decompose: all-atomic skip"
assert_contains "$TMP7/out.txt" "prd.json written with 1 atomic stories" "decompose: prd.json emitted"
# Verify prd.json was actually created
if [ ! -f "$TMP7/prd.json" ]; then
  echo "FAIL: prd.json was not created"
  exit 1
fi
# Verify prd.json uses forward-Ralph-compatible schema (branchName + userStories + camelCase)
if ! jq -e '
  type == "object" and
  (.branchName | type == "string" and length > 0) and
  (.userStories | type == "array" and length == 1) and
  (.userStories[0].acceptanceCriteria | type == "array") and
  (.userStories[0].notes | type == "string") and
  (.userStories[0].passes == false)
' "$TMP7/prd.json" >/dev/null 2>&1; then
  echo "FAIL: prd.json schema is not forward-Ralph-compatible"
  echo "--- prd.json ---"
  cat "$TMP7/prd.json"
  exit 1
fi
echo "  Test 7 passed: all-atomic skip and prd.json emission"

# Test 8: needs_split node with max_iterations=1 runs exactly one agent call and exits
# Use custom agent with a mock command that just echoes (no real agent available in CI).
mkdir -p "$TMP8/.ralph"
render_decompose_script "$TMP8/.ralph/decompose-smoke.sh" "custom" "" "smoke"
cp "$ROOT_DIR/scripts/decompose-prompt.md" "$TMP8/.ralph/decompose-smoke-prompt.md"
cat > "$TMP8/decomp.json" <<'JSON'
{
  "feature_name": "Test Feature",
  "source_urls": [],
  "capability_surface": "test",
  "nodes": [
    {
      "id": "N-001",
      "parent_id": null,
      "title": "Needs Split Node",
      "description": "This node needs splitting.",
      "status": "needs_split",
      "children": [],
      "stories": []
    }
  ],
  "completed_at": null
}
JSON

if (cd "$TMP8" && CUSTOM_CMD='echo "mock agent iteration"' ./.ralph/decompose-smoke.sh 1 >"$TMP8/out.txt" 2>&1); then
  # It should exit 0 (partial progress, max iterations reached)
  :
fi
assert_contains "$TMP8/out.txt" "Reverse Ralph iteration 1" "decompose: ran iteration 1"
assert_contains "$TMP8/out.txt" "Pending nodes: 1" "decompose: found pending node"
assert_contains "$TMP8/out.txt" "Iteration 1 complete" "decompose: iteration completed"
echo "  Test 8 passed: single iteration with needs_split node"

# Test 9: decompose.sh exits with clear error if agent binary is missing
mkdir -p "$TMP9/.ralph"
render_decompose_script "$TMP9/.ralph/decompose-smoke.sh" "definitely-not-installed-binary" "" "smoke"
cp "$ROOT_DIR/scripts/decompose-prompt.md" "$TMP9/.ralph/decompose-smoke-prompt.md"
cat > "$TMP9/decomp.json" <<'JSON'
{"feature_name":"test","source_urls":[],"capability_surface":"test","nodes":[],"completed_at":null}
JSON

if (cd "$TMP9" && ./.ralph/decompose-smoke.sh 1 >"$TMP9/out.txt" 2>&1); then
  echo "FAIL: missing agent binary should fail"
  cat "$TMP9/out.txt"
  exit 1
fi
assert_contains "$TMP9/out.txt" "not installed or not on PATH" "decompose: agent binary preflight"
echo "  Test 9 passed: missing agent binary"

# Test 10: decompose.sh rejects non-numeric max_iterations
mkdir -p "$TMP10/.ralph"
render_decompose_script "$TMP10/.ralph/decompose-smoke.sh" "custom" "" "smoke"
cp "$ROOT_DIR/scripts/decompose-prompt.md" "$TMP10/.ralph/decompose-smoke-prompt.md"
cat > "$TMP10/decomp.json" <<'JSON'
{
  "feature_name": "Test Feature",
  "source_urls": [],
  "capability_surface": "test",
  "nodes": [
    {
      "id": "N-001",
      "parent_id": null,
      "title": "Needs Split Node",
      "description": "This node needs splitting.",
      "status": "needs_split",
      "children": [],
      "stories": []
    }
  ],
  "completed_at": null
}
JSON

if (cd "$TMP10" && CUSTOM_CMD='echo "should not run"' ./.ralph/decompose-smoke.sh abc >"$TMP10/out.txt" 2>&1); then
  echo "FAIL: non-numeric max_iterations should fail"
  cat "$TMP10/out.txt"
  exit 1
fi
assert_contains "$TMP10/out.txt" "max_iterations must be a positive integer" "decompose: invalid max_iterations"
echo "  Test 10 passed: invalid max_iterations"

echo ""
echo "All decompose template smoke tests passed."
