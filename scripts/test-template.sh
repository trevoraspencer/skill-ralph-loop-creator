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
TMP11="$(mktemp -d)"
TMP12="$(mktemp -d)"
TMP13="$(mktemp -d)"
TMP14="$(mktemp -d)"
TMP15="$(mktemp -d)"
trap 'rm -rf "$TMP1" "$TMP2" "$TMP3" "$TMP4" "$TMP5" "$TMP6" "$TMP7" "$TMP8" "$TMP9" "$TMP10" "$TMP11" "$TMP12" "$TMP13" "$TMP14" "$TMP15"' EXIT

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
assert_contains "$TMP1/out.txt" "Forge completed all tasks!" "completion path"

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

echo "All forward Forge smoke tests passed."

# ═══════════════════════════════════════════════════════
# Forge decompose (decompose.sh) smoke tests
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
# Verify prd.json uses forward-Forge-compatible schema (branchName + userStories + camelCase)
if ! jq -e '
  type == "object" and
  (.branchName | type == "string" and length > 0) and
  (.userStories | type == "array" and length == 1) and
  (.userStories[0].acceptanceCriteria | type == "array") and
  (.userStories[0].notes | type == "string") and
  (.userStories[0].passes == false)
' "$TMP7/prd.json" >/dev/null 2>&1; then
  echo "FAIL: prd.json schema is not forward-Forge-compatible"
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
assert_contains "$TMP8/out.txt" "Forge decompose iteration 1" "decompose: ran iteration 1"
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

# ═══════════════════════════════════════════════════════
# DRY_RUN tests (forward + decompose)
# ═══════════════════════════════════════════════════════

echo ""
echo "Running DRY_RUN smoke tests..."

# Test 11: forward Ralph DRY_RUN=1 prints prompt content and skips agent call
mkdir -p "$TMP11/.ralph"
render_script \
  "$TMP11/.ralph/smoke.sh" \
  "bash" \
  "bash -lc 'echo \"AGENT_SHOULD_NOT_RUN_IN_DRY_RUN\"'"
cat > "$TMP11/prd.json" <<'JSON'
{"branchName":"forge/dry-run-smoke","userStories":[]}
JSON
cat > "$TMP11/.ralph/prompt.md" <<'PROMPT'
DRY_RUN_TEST_PROMPT_BODY_FORWARD
PROMPT

if ! (cd "$TMP11" && DRY_RUN=1 ./.ralph/smoke.sh 1 >"$TMP11/out.txt" 2>&1); then
  echo "FAIL: DRY_RUN should exit 0"
  cat "$TMP11/out.txt"
  exit 1
fi
assert_contains "$TMP11/out.txt" "DRY_RUN" "forward DRY_RUN: banner present"
assert_contains "$TMP11/out.txt" "DRY_RUN_TEST_PROMPT_BODY_FORWARD" "forward DRY_RUN: prompt printed"
if grep -q "AGENT_SHOULD_NOT_RUN_IN_DRY_RUN" "$TMP11/out.txt"; then
  echo "FAIL: agent command must not execute under DRY_RUN"
  cat "$TMP11/out.txt"
  exit 1
fi
echo "  Test 11 passed: forward DRY_RUN prints prompt, skips agent"

# Test 12: decompose Ralph DRY_RUN=1 prints assembled iteration prompt and skips agent call
mkdir -p "$TMP12/.ralph"
render_decompose_script "$TMP12/.ralph/decompose-smoke.sh" "custom" "" "smoke"
cp "$ROOT_DIR/scripts/decompose-prompt.md" "$TMP12/.ralph/decompose-smoke-prompt.md"
cat > "$TMP12/decomp.json" <<'JSON'
{
  "feature_name": "Test Feature",
  "source_urls": [],
  "capability_surface": "test",
  "nodes": [
    {
      "id": "N-001",
      "parent_id": null,
      "title": "Needs Split Node",
      "description": "Needs splitting.",
      "status": "needs_split",
      "children": [],
      "stories": []
    }
  ],
  "completed_at": null
}
JSON

if ! (cd "$TMP12" && DRY_RUN=1 CUSTOM_CMD='echo "AGENT_SHOULD_NOT_RUN_DECOMPOSE_DRY_RUN"' ./.ralph/decompose-smoke.sh 1 >"$TMP12/out.txt" 2>&1); then
  echo "FAIL: decompose DRY_RUN should exit 0"
  cat "$TMP12/out.txt"
  exit 1
fi
assert_contains "$TMP12/out.txt" "DRY_RUN" "decompose DRY_RUN: banner present"
assert_contains "$TMP12/out.txt" "Process node ID: N-001" "decompose DRY_RUN: prompt printed with substituted node id"
if grep -q "AGENT_SHOULD_NOT_RUN_DECOMPOSE_DRY_RUN" "$TMP12/out.txt"; then
  echo "FAIL: agent command must not execute under DRY_RUN"
  cat "$TMP12/out.txt"
  exit 1
fi
echo "  Test 12 passed: decompose DRY_RUN prints prompt, skips agent"

echo ""
echo "All DRY_RUN smoke tests passed."

# ═══════════════════════════════════════════════════════
# Shared-includes tests (.ralph/_shared/*.md prepended to prompt)
# ═══════════════════════════════════════════════════════

echo ""
echo "Running shared-includes smoke tests..."

# Test 13: forward Forge with .ralph/_shared/*.md prepends those files (alphabetical) before base prompt
mkdir -p "$TMP13/.ralph/_shared"
render_script \
  "$TMP13/.ralph/smoke.sh" \
  "bash" \
  "bash -lc 'echo \"agent should not run\"'"
cat > "$TMP13/prd.json" <<'JSON'
{"branchName":"forge/shared-smoke","userStories":[]}
JSON
cat > "$TMP13/.ralph/prompt.md" <<'PROMPT'
BASE_PROMPT_BODY_FORWARD
PROMPT
cat > "$TMP13/.ralph/_shared/01-policy.md" <<'PROMPT'
SHARED_POLICY_LINE_FORWARD
PROMPT
cat > "$TMP13/.ralph/_shared/02-templates.md" <<'PROMPT'
SHARED_TEMPLATES_LINE_FORWARD
PROMPT

if ! (cd "$TMP13" && DRY_RUN=1 ./.ralph/smoke.sh 1 >"$TMP13/out.txt" 2>&1); then
  echo "FAIL: forward shared-includes should exit 0 under DRY_RUN"
  cat "$TMP13/out.txt"
  exit 1
fi
assert_contains "$TMP13/out.txt" "SHARED_POLICY_LINE_FORWARD" "forward shared: 01-policy.md prepended"
assert_contains "$TMP13/out.txt" "SHARED_TEMPLATES_LINE_FORWARD" "forward shared: 02-templates.md prepended"
assert_contains "$TMP13/out.txt" "BASE_PROMPT_BODY_FORWARD" "forward shared: base prompt still appears"
# Order check: shared content should appear BEFORE base prompt
policy_line=$(grep -n "SHARED_POLICY_LINE_FORWARD" "$TMP13/out.txt" | head -1 | cut -d: -f1)
base_line=$(grep -n "BASE_PROMPT_BODY_FORWARD" "$TMP13/out.txt" | head -1 | cut -d: -f1)
if [ -z "$policy_line" ] || [ -z "$base_line" ] || [ "$policy_line" -ge "$base_line" ]; then
  echo "FAIL: forward shared content must appear before base prompt (policy at $policy_line, base at $base_line)"
  cat "$TMP13/out.txt"
  exit 1
fi
echo "  Test 13 passed: forward shared-includes prepended in order"

# Test 14: forward Forge without _shared/ directory still works (BC)
mkdir -p "$TMP14/.ralph"
render_script \
  "$TMP14/.ralph/smoke.sh" \
  "bash" \
  "bash -lc 'echo \"agent should not run\"'"
cat > "$TMP14/prd.json" <<'JSON'
{"branchName":"forge/no-shared-smoke","userStories":[]}
JSON
cat > "$TMP14/.ralph/prompt.md" <<'PROMPT'
BASE_ONLY_PROMPT
PROMPT

if ! (cd "$TMP14" && DRY_RUN=1 ./.ralph/smoke.sh 1 >"$TMP14/out.txt" 2>&1); then
  echo "FAIL: forward without _shared should still exit 0"
  cat "$TMP14/out.txt"
  exit 1
fi
assert_contains "$TMP14/out.txt" "BASE_ONLY_PROMPT" "forward without shared: base prompt printed"
echo "  Test 14 passed: forward without _shared/ unchanged (BC)"

# Test 15: decompose with .ralph/_shared/*.md prepends shared content to assembled iteration prompt
mkdir -p "$TMP15/.ralph/_shared"
render_decompose_script "$TMP15/.ralph/decompose-smoke.sh" "custom" "" "smoke"
cp "$ROOT_DIR/scripts/decompose-prompt.md" "$TMP15/.ralph/decompose-smoke-prompt.md"
cat > "$TMP15/.ralph/_shared/01-rules.md" <<'PROMPT'
SHARED_RULES_LINE_DECOMPOSE
PROMPT
cat > "$TMP15/decomp.json" <<'JSON'
{
  "feature_name": "Test Feature",
  "source_urls": [],
  "capability_surface": "test",
  "nodes": [
    {
      "id": "N-001",
      "parent_id": null,
      "title": "Needs Split Node",
      "description": "Needs splitting.",
      "status": "needs_split",
      "children": [],
      "stories": []
    }
  ],
  "completed_at": null
}
JSON

if ! (cd "$TMP15" && DRY_RUN=1 CUSTOM_CMD='echo "agent should not run"' ./.ralph/decompose-smoke.sh 1 >"$TMP15/out.txt" 2>&1); then
  echo "FAIL: decompose shared-includes should exit 0 under DRY_RUN"
  cat "$TMP15/out.txt"
  exit 1
fi
assert_contains "$TMP15/out.txt" "SHARED_RULES_LINE_DECOMPOSE" "decompose shared: 01-rules.md prepended"
assert_contains "$TMP15/out.txt" "Process node ID: N-001" "decompose shared: base iteration prompt still appears with substituted node id"
# Order check: shared appears before per-iteration content
shared_line=$(grep -n "SHARED_RULES_LINE_DECOMPOSE" "$TMP15/out.txt" | head -1 | cut -d: -f1)
iter_line=$(grep -n "Process node ID: N-001" "$TMP15/out.txt" | head -1 | cut -d: -f1)
if [ -z "$shared_line" ] || [ -z "$iter_line" ] || [ "$shared_line" -ge "$iter_line" ]; then
  echo "FAIL: decompose shared content must appear before iteration prompt"
  cat "$TMP15/out.txt"
  exit 1
fi
echo "  Test 15 passed: decompose shared-includes prepended in order"

echo ""
echo "All shared-includes smoke tests passed."
