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
TMP16="$(mktemp -d)"
TMP17="$(mktemp -d)"
TMP18="$(mktemp -d)"
TMP19="$(mktemp -d)"
TMP20="$(mktemp -d)"
TMP21="$(mktemp -d)"
TMP22="$(mktemp -d)"
TMP23="$(mktemp -d)"
TMP24="$(mktemp -d)"
TMP25="$(mktemp -d)"
TMP26="$(mktemp -d)"
TMP27="$(mktemp -d)"
TMP28="$(mktemp -d)"
TMP29="$(mktemp -d)"
TMP30="$(mktemp -d)"
trap 'rm -rf "$TMP1" "$TMP2" "$TMP3" "$TMP4" "$TMP5" "$TMP6" "$TMP7" "$TMP8" "$TMP9" "$TMP10" "$TMP11" "$TMP12" "$TMP13" "$TMP14" "$TMP15" "$TMP16" "$TMP17" "$TMP18" "$TMP19" "$TMP20" "$TMP21" "$TMP22" "$TMP23" "$TMP24" "$TMP25" "$TMP26" "$TMP27" "$TMP28" "$TMP29" "$TMP30"' EXIT

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
branch_name=$(jq -r '.branchName' "$TMP7/prd.json")
if [ "$branch_name" != "forge/test-feature" ]; then
  echo "FAIL: decompose should emit forge/ branchName (got: $branch_name)"
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

# ═══════════════════════════════════════════════════════
# Pipeline mode smoke tests
# ═══════════════════════════════════════════════════════

PIPELINE_TEMPLATE="$ROOT_DIR/scripts/pipeline.sh"

render_pipeline_script() {
  local out_file="$1"
  local agent="$2"
  local model="$3"
  local pipeline_name="$4"

  sed \
    -e "s|__AGENT__|${agent}|g" \
    -e "s|__MODEL__|${model}|g" \
    -e "s|__PIPELINE_NAME__|${pipeline_name}|g" \
    "$PIPELINE_TEMPLATE" > "$out_file"
  chmod +x "$out_file"
}

# Set up a git repo in a tmp dir (needed for git_checkpoint in real-run tests).
# Disables commit signing — some CI/sandbox envs require external signing servers
# that aren't reachable from tests, and pipeline tests need to actually commit.
init_git_repo() {
  local dir="$1"
  git -C "$dir" init -q
  git -C "$dir" config user.email "test@example.com"
  git -C "$dir" config user.name "Test"
  git -C "$dir" config commit.gpgsign false
  git -C "$dir" config tag.gpgsign false
  git -C "$dir" config gpg.format ""
  # Create initial commit so HEAD exists
  echo "init" > "$dir/.init"
  git -C "$dir" add -A
  git -C "$dir" -c commit.gpgsign=false -c gpg.format= commit -q --no-gpg-sign -m "init"
}

echo ""
echo "Running pipeline mode smoke tests..."

# Test 16: pipeline DRY_RUN over 3-phase pipeline (oneshot, loop, oneshot)
mkdir -p "$TMP16/.ralph/demo/phases" "$TMP16/.ralph/demo/queues"
render_pipeline_script "$TMP16/.ralph/demo.sh" "custom" "" "demo"
cat > "$TMP16/.ralph/demo/pipeline.json" <<'JSON'
{
  "name": "demo",
  "phases": [
    { "id": "p01", "type": "oneshot", "prompt": "phases/p01.md", "commit": "p01" },
    { "id": "p02", "type": "loop",    "prompt": "phases/p02.md", "queue": "queues/work.md", "commit_prefix": "iter" },
    { "id": "p03", "type": "oneshot", "prompt": "phases/p03.md", "commit": "p03" }
  ]
}
JSON
cat > "$TMP16/.ralph/demo/phases/p01.md" <<'PROMPT'
PHASE_P01_BOOTSTRAP_BODY
PROMPT
cat > "$TMP16/.ralph/demo/phases/p02.md" <<'PROMPT'
PHASE_P02_LOOP_BODY
PROMPT
cat > "$TMP16/.ralph/demo/phases/p03.md" <<'PROMPT'
PHASE_P03_WRAPUP_BODY
PROMPT
cat > "$TMP16/.ralph/demo/queues/work.md" <<'Q'
- [ ] queue-item-alpha
- [ ] queue-item-beta
Q

if ! (cd "$TMP16" && DRY_RUN=1 CUSTOM_CMD='echo "AGENT_SHOULD_NOT_RUN_IN_PIPELINE_DRY_RUN"' ./.ralph/demo.sh 1 >"$TMP16/out.txt" 2>&1); then
  echo "FAIL: pipeline DRY_RUN should exit 0"
  cat "$TMP16/out.txt"
  exit 1
fi
assert_contains "$TMP16/out.txt" "PHASE_P01_BOOTSTRAP_BODY" "pipeline DRY_RUN: p01 prompt printed"
assert_contains "$TMP16/out.txt" "PHASE_P02_LOOP_BODY" "pipeline DRY_RUN: p02 prompt printed"
assert_contains "$TMP16/out.txt" "PHASE_P03_WRAPUP_BODY" "pipeline DRY_RUN: p03 prompt printed"
assert_contains "$TMP16/out.txt" "queue-item-alpha" "pipeline DRY_RUN: queue contents printed"
if grep -q "AGENT_SHOULD_NOT_RUN_IN_PIPELINE_DRY_RUN" "$TMP16/out.txt"; then
  echo "FAIL: agent must not run under DRY_RUN"
  cat "$TMP16/out.txt"
  exit 1
fi
echo "  Test 16 passed: pipeline DRY_RUN over 3-phase pipeline"

# Test 17: START_AT skips earlier phases
mkdir -p "$TMP17/.ralph/demo/phases" "$TMP17/.ralph/demo/queues"
render_pipeline_script "$TMP17/.ralph/demo.sh" "custom" "" "demo"
cat > "$TMP17/.ralph/demo/pipeline.json" <<'JSON'
{
  "name": "demo",
  "phases": [
    { "id": "p01", "type": "oneshot", "prompt": "phases/p01.md", "commit": "p01" },
    { "id": "p02", "type": "oneshot", "prompt": "phases/p02.md", "commit": "p02" },
    { "id": "p03", "type": "oneshot", "prompt": "phases/p03.md", "commit": "p03" }
  ]
}
JSON
cat > "$TMP17/.ralph/demo/phases/p01.md" <<'PROMPT'
P01_SHOULD_BE_SKIPPED
PROMPT
cat > "$TMP17/.ralph/demo/phases/p02.md" <<'PROMPT'
P02_SHOULD_RUN
PROMPT
cat > "$TMP17/.ralph/demo/phases/p03.md" <<'PROMPT'
P03_SHOULD_RUN
PROMPT

if ! (cd "$TMP17" && DRY_RUN=1 START_AT=p02 CUSTOM_CMD='echo "noop"' ./.ralph/demo.sh 1 >"$TMP17/out.txt" 2>&1); then
  echo "FAIL: pipeline START_AT should exit 0"
  cat "$TMP17/out.txt"
  exit 1
fi
assert_contains "$TMP17/out.txt" "skip p01" "pipeline START_AT: p01 skipped"
assert_contains "$TMP17/out.txt" "P02_SHOULD_RUN" "pipeline START_AT: p02 ran"
assert_contains "$TMP17/out.txt" "P03_SHOULD_RUN" "pipeline START_AT: p03 ran"
if grep -q "P01_SHOULD_BE_SKIPPED" "$TMP17/out.txt"; then
  echo "FAIL: p01 should not have been printed"
  cat "$TMP17/out.txt"
  exit 1
fi
echo "  Test 17 passed: pipeline START_AT skips earlier phases"

# Test 18: missing pipeline.json fails preflight with clear error
mkdir -p "$TMP18/.ralph/demo"
render_pipeline_script "$TMP18/.ralph/demo.sh" "custom" "" "demo"
# Do NOT create pipeline.json

if (cd "$TMP18" && CUSTOM_CMD='echo "noop"' ./.ralph/demo.sh 1 >"$TMP18/out.txt" 2>&1); then
  echo "FAIL: missing pipeline.json should fail"
  cat "$TMP18/out.txt"
  exit 1
fi
assert_contains "$TMP18/out.txt" "pipeline.json" "pipeline preflight: missing pipeline.json"
echo "  Test 18 passed: missing pipeline.json fails preflight"

# Test 19: invalid pipeline.json schema fails preflight
mkdir -p "$TMP19/.ralph/demo/phases"
render_pipeline_script "$TMP19/.ralph/demo.sh" "custom" "" "demo"
cat > "$TMP19/.ralph/demo/pipeline.json" <<'JSON'
{ "name": "demo", "phases": "this-should-be-an-array" }
JSON

if (cd "$TMP19" && CUSTOM_CMD='echo "noop"' ./.ralph/demo.sh 1 >"$TMP19/out.txt" 2>&1); then
  echo "FAIL: invalid pipeline.json should fail"
  cat "$TMP19/out.txt"
  exit 1
fi
assert_contains "$TMP19/out.txt" "invalid schema" "pipeline preflight: invalid schema"
echo "  Test 19 passed: invalid pipeline.json schema fails preflight"

# Test 20: loop phase hitting max_iters with non-empty queue exits 0 AND skips downstream wrap-up
# Real run (not DRY_RUN): need a git repo for git_checkpoint, and a mock agent that does NOT flip checkboxes
mkdir -p "$TMP20/.ralph/demo/phases" "$TMP20/.ralph/demo/queues"
init_git_repo "$TMP20"
render_pipeline_script "$TMP20/.ralph/demo.sh" "custom" "" "demo"
cat > "$TMP20/.ralph/demo/pipeline.json" <<'JSON'
{
  "name": "demo",
  "phases": [
    { "id": "p01", "type": "loop",    "prompt": "phases/p01.md", "queue": "queues/work.md", "commit_prefix": "iter" },
    { "id": "p02", "type": "oneshot", "prompt": "phases/p02.md", "commit": "wrap" }
  ]
}
JSON
cat > "$TMP20/.ralph/demo/phases/p01.md" <<'PROMPT'
loop-prompt
PROMPT
cat > "$TMP20/.ralph/demo/phases/p02.md" <<'PROMPT'
WRAPUP_SHOULD_NOT_RUN
PROMPT
cat > "$TMP20/.ralph/demo/queues/work.md" <<'Q'
- [ ] item-one
- [ ] item-two
Q

# max_iters=1 from CLI arg. Mock agent echoes but does not flip checkbox.
if ! (cd "$TMP20" && CUSTOM_CMD='echo "mock-agent-noop"' ./.ralph/demo.sh 1 >"$TMP20/out.txt" 2>&1); then
  echo "FAIL: pipeline hit-max-iters should exit 0"
  cat "$TMP20/out.txt"
  exit 1
fi
assert_contains "$TMP20/out.txt" "Phase p01 hit max_iters" "pipeline: loop max_iters detected"
assert_contains "$TMP20/out.txt" "Downstream phases skipped" "pipeline: wrap-up skip warning shown"
if grep -q "WRAPUP_SHOULD_NOT_RUN" "$TMP20/out.txt"; then
  echo "FAIL: wrap-up phase must not run when loop is incomplete"
  cat "$TMP20/out.txt"
  exit 1
fi
echo "  Test 20 passed: incomplete loop skips downstream wrap-up phase"

# Test 21: shared-includes in pipeline phases (.ralph/<name>/_shared/*.md prepended)
mkdir -p "$TMP21/.ralph/demo/phases" "$TMP21/.ralph/demo/queues" "$TMP21/.ralph/demo/_shared"
render_pipeline_script "$TMP21/.ralph/demo.sh" "custom" "" "demo"
cat > "$TMP21/.ralph/demo/pipeline.json" <<'JSON'
{
  "name": "demo",
  "phases": [
    { "id": "p01", "type": "oneshot", "prompt": "phases/p01.md", "commit": "p01" }
  ]
}
JSON
cat > "$TMP21/.ralph/demo/phases/p01.md" <<'PROMPT'
BASE_PHASE_PROMPT_BODY
PROMPT
cat > "$TMP21/.ralph/demo/_shared/01-policy.md" <<'PROMPT'
PIPELINE_SHARED_POLICY_LINE
PROMPT

if ! (cd "$TMP21" && DRY_RUN=1 CUSTOM_CMD='echo "noop"' ./.ralph/demo.sh 1 >"$TMP21/out.txt" 2>&1); then
  echo "FAIL: pipeline shared-includes DRY_RUN should exit 0"
  cat "$TMP21/out.txt"
  exit 1
fi
assert_contains "$TMP21/out.txt" "PIPELINE_SHARED_POLICY_LINE" "pipeline shared: _shared content prepended"
assert_contains "$TMP21/out.txt" "BASE_PHASE_PROMPT_BODY" "pipeline shared: base prompt still present"
shared_line=$(grep -n "PIPELINE_SHARED_POLICY_LINE" "$TMP21/out.txt" | head -1 | cut -d: -f1)
base_line=$(grep -n "BASE_PHASE_PROMPT_BODY" "$TMP21/out.txt" | head -1 | cut -d: -f1)
if [ -z "$shared_line" ] || [ -z "$base_line" ] || [ "$shared_line" -ge "$base_line" ]; then
  echo "FAIL: pipeline shared content must appear before base prompt"
  cat "$TMP21/out.txt"
  exit 1
fi
echo "  Test 21 passed: pipeline shared-includes prepend per-phase"

echo ""
echo "All pipeline mode smoke tests passed."

# ═══════════════════════════════════════════════════════
# Shell-phase tests (pipeline.sh) + prefetcher tests (prefetch.sh)
# ═══════════════════════════════════════════════════════

PREFETCH_SCRIPT="$ROOT_DIR/scripts/prefetch.sh"

echo ""
echo "Running shell-phase + prefetcher smoke tests..."

# Test 22: pipeline shell phase under DRY_RUN prints what would run; does not execute the script
mkdir -p "$TMP22/.ralph/demo/phases"
render_pipeline_script "$TMP22/.ralph/demo.sh" "custom" "" "demo"
cat > "$TMP22/.ralph/demo/pipeline.json" <<'JSON'
{
  "name": "demo",
  "phases": [
    { "id": "p01", "type": "shell", "script": "phases/p01.sh", "commit": "shell phase" }
  ]
}
JSON
cat > "$TMP22/.ralph/demo/phases/p01.sh" <<'SH'
#!/usr/bin/env bash
echo "SHELL_PHASE_SCRIPT_RAN" > "$TMP22/shell-marker.txt"
SH
chmod +x "$TMP22/.ralph/demo/phases/p01.sh"

if ! (cd "$TMP22" && DRY_RUN=1 CUSTOM_CMD='echo noop' ./.ralph/demo.sh 1 >"$TMP22/out.txt" 2>&1); then
  echo "FAIL: shell-phase DRY_RUN should exit 0"
  cat "$TMP22/out.txt"
  exit 1
fi
assert_contains "$TMP22/out.txt" "would run shell script" "shell DRY_RUN: banner shown"
assert_contains "$TMP22/out.txt" "phases/p01.sh" "shell DRY_RUN: script path shown"
if [ -f "$TMP22/shell-marker.txt" ]; then
  echo "FAIL: shell script must not execute under DRY_RUN"
  exit 1
fi
echo "  Test 22 passed: shell-phase DRY_RUN does not execute"

# Test 23: pipeline shell phase real run executes script and commits changes
mkdir -p "$TMP23/.ralph/demo/phases"
init_git_repo "$TMP23"
render_pipeline_script "$TMP23/.ralph/demo.sh" "custom" "" "demo"
cat > "$TMP23/.ralph/demo/pipeline.json" <<'JSON'
{
  "name": "demo",
  "phases": [
    { "id": "p01", "type": "shell", "script": "phases/p01.sh", "commit": "shell: write file" }
  ]
}
JSON
cat > "$TMP23/.ralph/demo/phases/p01.sh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
mkdir -p "${PROJECT_DIR}/evidence"
echo "fetched content from $(date)" > "${PROJECT_DIR}/evidence/sample.md"
echo "  shell script ran in pipeline $PIPELINE_NAME, wrote evidence/sample.md"
SH
chmod +x "$TMP23/.ralph/demo/phases/p01.sh"

if ! (cd "$TMP23" && CUSTOM_CMD='echo noop' ./.ralph/demo.sh 1 >"$TMP23/out.txt" 2>&1); then
  echo "FAIL: shell-phase real run should exit 0"
  cat "$TMP23/out.txt"
  exit 1
fi
assert_contains "$TMP23/out.txt" "Phase p01 (shell)" "shell real: phase header"
if [ ! -f "$TMP23/evidence/sample.md" ]; then
  echo "FAIL: shell script should have written evidence/sample.md"
  ls -la "$TMP23/" "$TMP23/evidence/" 2>&1
  cat "$TMP23/out.txt"
  exit 1
fi
# Verify the commit landed
last_commit_msg=$(git -C "$TMP23" log -1 --pretty=%s)
if [ "$last_commit_msg" != "shell: write file" ]; then
  echo "FAIL: expected commit 'shell: write file', got: $last_commit_msg"
  exit 1
fi
echo "  Test 23 passed: shell-phase real run executes script and commits"

# Test 24: shell phase with missing script fails preflight
mkdir -p "$TMP24/.ralph/demo"
render_pipeline_script "$TMP24/.ralph/demo.sh" "custom" "" "demo"
cat > "$TMP24/.ralph/demo/pipeline.json" <<'JSON'
{
  "name": "demo",
  "phases": [
    { "id": "p01", "type": "shell", "script": "phases/does-not-exist.sh", "commit": "x" }
  ]
}
JSON

if (cd "$TMP24" && CUSTOM_CMD='echo noop' ./.ralph/demo.sh 1 >"$TMP24/out.txt" 2>&1); then
  echo "FAIL: missing shell script should fail"
  cat "$TMP24/out.txt"
  exit 1
fi
assert_contains "$TMP24/out.txt" "not found" "shell preflight: missing script error"
echo "  Test 24 passed: shell phase missing script fails preflight"

# Test 25: prefetch.sh local_file class copies a local file to evidence/<class>/<slug>
# Tests only local_file class — http_get_md, github_* classes need network and are skipped here.
mkdir -p "$TMP25/source"
echo "LOCAL_FILE_CONTENT_FOR_PREFETCH" > "$TMP25/source/internal-doc.md"
cat > "$TMP25/manifest.tsv" <<TSV
class	slug	identifier	notes
local_file	internal-doc	source/internal-doc.md	an internal doc
TSV

if ! (cd "$TMP25" && "$PREFETCH_SCRIPT" "$TMP25/manifest.tsv" "$TMP25/evidence" >"$TMP25/out.txt" 2>&1); then
  echo "FAIL: prefetch.sh on local_file should exit 0"
  cat "$TMP25/out.txt"
  exit 1
fi
if [ ! -f "$TMP25/evidence/local_file/internal-doc.md" ]; then
  echo "FAIL: prefetch did not produce evidence/local_file/internal-doc.md"
  ls -laR "$TMP25/evidence" 2>&1 || true
  cat "$TMP25/out.txt"
  exit 1
fi
if ! grep -q "LOCAL_FILE_CONTENT_FOR_PREFETCH" "$TMP25/evidence/local_file/internal-doc.md"; then
  echo "FAIL: prefetched local_file content does not match source"
  cat "$TMP25/evidence/local_file/internal-doc.md"
  exit 1
fi
echo "  Test 25 passed: prefetch.sh handles local_file class"

echo ""
echo "All shell-phase + prefetcher smoke tests passed."

# ═══════════════════════════════════════════════════════
# Provenance + taint guardrail template tests
# ═══════════════════════════════════════════════════════

echo ""
echo "Running provenance + taint template smoke tests..."

# Test 26: opt-in templates (provenance-rules + forbidden-paths) compose via shared-includes
# Dropping them in .ralph/<pipeline-name>/_shared/ should prepend to every phase prompt.
PROVENANCE_TEMPLATE="$ROOT_DIR/scripts/phases/provenance-rules.md"
FORBIDDEN_TEMPLATE="$ROOT_DIR/scripts/phases/forbidden-paths.md"
RED_TEAM_TEMPLATE="$ROOT_DIR/scripts/phases/red-team-wrapup.md"
PROV_BOOTSTRAP_TEMPLATE="$ROOT_DIR/scripts/phases/provenance-bootstrap.md"

# All four opt-in templates must exist
for t in "$PROVENANCE_TEMPLATE" "$FORBIDDEN_TEMPLATE" "$RED_TEAM_TEMPLATE" "$PROV_BOOTSTRAP_TEMPLATE"; do
  if [ ! -f "$t" ]; then
    echo "FAIL: opt-in template missing: $t"
    exit 1
  fi
done

mkdir -p "$TMP26/.ralph/demo/phases" "$TMP26/.ralph/demo/_shared"
render_pipeline_script "$TMP26/.ralph/demo.sh" "custom" "" "demo"
cat > "$TMP26/.ralph/demo/pipeline.json" <<'JSON'
{
  "name": "demo",
  "phases": [
    { "id": "p01", "type": "oneshot", "prompt": "phases/p01.md", "commit": "p01" }
  ]
}
JSON
cat > "$TMP26/.ralph/demo/phases/p01.md" <<'PROMPT'
PHASE_P01_BODY_FOR_PROVENANCE_TEST
PROMPT
# Drop the two opt-in shared templates into _shared/ exactly like a real user would.
cp "$PROVENANCE_TEMPLATE" "$TMP26/.ralph/demo/_shared/10-provenance-rules.md"
cp "$FORBIDDEN_TEMPLATE"  "$TMP26/.ralph/demo/_shared/20-forbidden-paths.md"

if ! (cd "$TMP26" && DRY_RUN=1 CUSTOM_CMD='echo noop' ./.ralph/demo.sh 1 >"$TMP26/out.txt" 2>&1); then
  echo "FAIL: provenance/taint shared DRY_RUN should exit 0"
  cat "$TMP26/out.txt"
  exit 1
fi
# Distinctive lines from each template should appear before the base prompt body.
assert_contains "$TMP26/out.txt" "Provenance and Source-Citation Rules" "guardrails: provenance rules prepended"
assert_contains "$TMP26/out.txt" "Forbidden Sources and Contamination Protocol" "guardrails: forbidden paths prepended"
assert_contains "$TMP26/out.txt" "PHASE_P01_BODY_FOR_PROVENANCE_TEST" "guardrails: base prompt still present"
prov_line=$(grep -n "Provenance and Source-Citation Rules" "$TMP26/out.txt" | head -1 | cut -d: -f1)
forb_line=$(grep -n "Forbidden Sources and Contamination Protocol" "$TMP26/out.txt" | head -1 | cut -d: -f1)
base_line=$(grep -n "PHASE_P01_BODY_FOR_PROVENANCE_TEST" "$TMP26/out.txt" | head -1 | cut -d: -f1)
if [ -z "$prov_line" ] || [ -z "$forb_line" ] || [ -z "$base_line" ] || [ "$prov_line" -ge "$base_line" ] || [ "$forb_line" -ge "$base_line" ]; then
  echo "FAIL: opt-in templates must appear before the base prompt"
  cat "$TMP26/out.txt"
  exit 1
fi
echo "  Test 26 passed: provenance + forbidden-paths templates compose via shared-includes"

echo ""
echo "All provenance + taint template smoke tests passed."

# ═══════════════════════════════════════════════════════
# finalize() auto-push tests (forward ralph.sh)
# ═══════════════════════════════════════════════════════

echo ""
echo "Running finalize() auto-push smoke tests..."

# Test 27: AUTO_PUSH_PR=true + agent emits COMPLETE → branch is pushed to remote.
# Uses a local bare repo as the remote so `git push` actually succeeds offline.
# gh CLI may or may not be present; either way the push should land. If gh is
# missing or PR creation fails, the script must still exit 0 (graceful failure).
mkdir -p "$TMP27/project/.ralph"
git init -q --bare "$TMP27/remote.git"
git -C "$TMP27/project" init -q
git -C "$TMP27/project" config user.email "test@example.com"
git -C "$TMP27/project" config user.name "Test"
git -C "$TMP27/project" config commit.gpgsign false
git -C "$TMP27/project" config tag.gpgsign false
git -C "$TMP27/project" config gpg.format ""
git -C "$TMP27/project" remote add origin "$TMP27/remote.git"

# Seed: initial commit on main + push, then branch
echo "init" > "$TMP27/project/seed.txt"
git -C "$TMP27/project" add -A
git -C "$TMP27/project" -c commit.gpgsign=false commit -q --no-gpg-sign -m "init"
git -C "$TMP27/project" branch -M main
git -C "$TMP27/project" push -q -u origin main 2>/dev/null || true
git -C "$TMP27/project" checkout -q -b forge/auto-push-smoke

# Render the script and flip AUTO_PUSH_PR to true; bake a base branch of "main".
render_script \
  "$TMP27/project/.ralph/smoke.sh" \
  "bash" \
  "bash -lc 'echo \"<promise>COMPLETE</promise>\"'"
sed -i 's|AUTO_PUSH_PR="false"|AUTO_PUSH_PR="true"|' "$TMP27/project/.ralph/smoke.sh"
sed -i 's|DEFAULT_BRANCH="main"|DEFAULT_BRANCH="main"|' "$TMP27/project/.ralph/smoke.sh"

cat > "$TMP27/project/prd.json" <<'JSON'
{"branchName":"forge/auto-push-smoke","userStories":[]}
JSON

# Make a commit on the feature branch so finalize() has something to push.
echo "work" > "$TMP27/project/work.txt"
git -C "$TMP27/project" add -A
git -C "$TMP27/project" -c commit.gpgsign=false commit -q --no-gpg-sign -m "work"

if ! (cd "$TMP27/project" && ./.ralph/smoke.sh 1 >"$TMP27/out.txt" 2>&1); then
  echo "FAIL: auto-push smoke should exit 0"
  cat "$TMP27/out.txt"
  exit 1
fi
# Loop must have completed.
assert_contains "$TMP27/out.txt" "Forge completed all tasks!" "auto-push: loop completion"
# finalize() must have attempted push (look for either success or graceful gh-missing message).
if ! grep -qE "Pushing branch and creating PR|push failed|gh CLI not found|PR created|PR creation failed|already exists for branch" "$TMP27/out.txt"; then
  echo "FAIL: finalize() did not run (no push/PR output found)"
  cat "$TMP27/out.txt"
  exit 1
fi
# Verify the branch landed in the remote.
if ! git --git-dir="$TMP27/remote.git" show-ref --verify --quiet refs/heads/forge/auto-push-smoke; then
  echo "FAIL: branch forge/auto-push-smoke not present in remote $TMP27/remote.git"
  echo "--- script output ---"
  cat "$TMP27/out.txt"
  echo "--- remote refs ---"
  git --git-dir="$TMP27/remote.git" for-each-ref --format='%(refname)'
  exit 1
fi
echo "  Test 27 passed: AUTO_PUSH_PR=true pushes branch to remote on completion"

# Test 28: AUTO_PUSH_PR=true with gh missing — push still succeeds, gh-missing
# fallback message is printed, script exits 0 (the "push failure / missing tool
# never masks loop success" guarantee).
mkdir -p "$TMP28/project/.ralph"
git init -q --bare "$TMP28/remote.git"
git -C "$TMP28/project" init -q
git -C "$TMP28/project" config user.email "test@example.com"
git -C "$TMP28/project" config user.name "Test"
git -C "$TMP28/project" config commit.gpgsign false
git -C "$TMP28/project" config tag.gpgsign false
git -C "$TMP28/project" config gpg.format ""
git -C "$TMP28/project" remote add origin "$TMP28/remote.git"

echo "init" > "$TMP28/project/seed.txt"
git -C "$TMP28/project" add -A
git -C "$TMP28/project" -c commit.gpgsign=false commit -q --no-gpg-sign -m "init"
git -C "$TMP28/project" branch -M main
git -C "$TMP28/project" push -q -u origin main 2>/dev/null || true
git -C "$TMP28/project" checkout -q -b forge/gh-missing-smoke

render_script \
  "$TMP28/project/.ralph/smoke.sh" \
  "bash" \
  "bash -c 'echo \"<promise>COMPLETE</promise>\"'"
sed -i 's|AUTO_PUSH_PR="false"|AUTO_PUSH_PR="true"|' "$TMP28/project/.ralph/smoke.sh"

cat > "$TMP28/project/prd.json" <<'JSON'
{"branchName":"forge/gh-missing-smoke","userStories":[]}
JSON

echo "work" > "$TMP28/project/work.txt"
git -C "$TMP28/project" add -A
git -C "$TMP28/project" -c commit.gpgsign=false commit -q --no-gpg-sign -m "work"

# Build a fake PATH containing every standard utility EXCEPT gh.
# Easier than enumerating: symlink the contents of /usr/bin and /bin, then
# remove the gh symlink if it exists.
FAKE_BIN_28="$TMP28/fake-bin"
mkdir -p "$FAKE_BIN_28"
for srcdir in /usr/local/bin /usr/bin /bin; do
  [ -d "$srcdir" ] || continue
  for f in "$srcdir"/*; do
    [ -e "$f" ] || continue
    base="$(basename "$f")"
    [ "$base" = "gh" ] && continue
    [ -e "$FAKE_BIN_28/$base" ] || ln -sf "$f" "$FAKE_BIN_28/$base"
  done
done
# Belt and suspenders: ensure gh is NOT in the fake bin even if a tool with
# that name existed in a directory we scanned.
rm -f "$FAKE_BIN_28/gh"

if ! (cd "$TMP28/project" && PATH="$FAKE_BIN_28" ./.ralph/smoke.sh 1 >"$TMP28/out.txt" 2>&1); then
  echo "FAIL: gh-missing smoke should still exit 0 (graceful fallback)"
  cat "$TMP28/out.txt"
  exit 1
fi
assert_contains "$TMP28/out.txt" "Forge completed all tasks!" "gh-missing: loop completion"
assert_contains "$TMP28/out.txt" "gh CLI not found" "gh-missing: documented fallback message"
# Push must still have succeeded.
if ! git --git-dir="$TMP28/remote.git" show-ref --verify --quiet refs/heads/forge/gh-missing-smoke; then
  echo "FAIL: branch forge/gh-missing-smoke not in remote (push should have succeeded even without gh)"
  cat "$TMP28/out.txt"
  exit 1
fi
echo "  Test 28 passed: gh missing → branch still pushed, graceful fallback message, exit 0"

echo ""
echo "All finalize() auto-push smoke tests passed."

# ═══════════════════════════════════════════════════════
# Pipeline loop multi-iteration progression test
# ═══════════════════════════════════════════════════════

echo ""
echo "Running pipeline loop multi-iteration smoke tests..."

# Test 29: pipeline loop phase actually progresses through a multi-item queue.
# Mock agent flips the first `- [ ]` to `- [x]` per iteration (the contract
# loop-prompt-markdown-queue.md teaches real agents to follow). Verifies:
#   - both queue items get flipped
#   - loop exits via "queue empty" (not via max_iters)
#   - one commit per iteration
#   - script exits 0
mkdir -p "$TMP29/.ralph/demo/phases" "$TMP29/.ralph/demo/queues"
init_git_repo "$TMP29"
render_pipeline_script "$TMP29/.ralph/demo.sh" "custom" "" "demo"
cat > "$TMP29/.ralph/demo/pipeline.json" <<'JSON'
{
  "name": "demo",
  "phases": [
    { "id": "p01", "type": "loop", "prompt": "phases/p01.md", "queue": "queues/work.md", "commit_prefix": "iter" }
  ]
}
JSON
cat > "$TMP29/.ralph/demo/phases/p01.md" <<'PROMPT'
loop-prompt-body
PROMPT
cat > "$TMP29/.ralph/demo/queues/work.md" <<'Q'
- [ ] item-alpha
- [ ] item-beta
Q

# Mock agent: flip the first `- [ ]` in the queue file to `- [x]`. The driver
# computes the queue path from pipeline.json, but the agent (in production)
# would be told the path via the prompt. For test purposes we hardcode it
# relative to the project dir.
MOCK_FLIP="sed -i '0,/^- \\[ \\]/{s//- [x]/}' '$TMP29/.ralph/demo/queues/work.md'"

# Drive max_iters=3 (1 above queue size) so the loop exits via queue-empty
# rather than via max_iters.
if ! (cd "$TMP29" && CUSTOM_CMD="$MOCK_FLIP" ./.ralph/demo.sh 3 >"$TMP29/out.txt" 2>&1); then
  echo "FAIL: multi-iteration loop should exit 0"
  cat "$TMP29/out.txt"
  exit 1
fi
# Loop must exit via queue-empty (after exactly 2 iterations).
assert_contains "$TMP29/out.txt" "Queue empty after 2 iterations" "multi-iter: queue-empty exit after 2"
# Queue file should have zero pending items left.
if grep -q '^- \[ \]' "$TMP29/.ralph/demo/queues/work.md"; then
  echo "FAIL: queue should be fully drained"
  cat "$TMP29/.ralph/demo/queues/work.md"
  exit 1
fi
# Both checkboxes should be flipped.
if [ "$(grep -c '^- \[x\]' "$TMP29/.ralph/demo/queues/work.md")" -ne 2 ]; then
  echo "FAIL: expected exactly 2 flipped checkboxes"
  cat "$TMP29/.ralph/demo/queues/work.md"
  exit 1
fi
# Exactly two `iter:` commits should land.
iter_commits=$(git -C "$TMP29" log --pretty=%s | grep -c '^iter:' || true)
if [ "$iter_commits" -ne 2 ]; then
  echo "FAIL: expected exactly 2 'iter:' commits, got $iter_commits"
  git -C "$TMP29" log --oneline
  exit 1
fi
# Specifically: one commit per item, in queue order.
git -C "$TMP29" log --pretty=%s | head -2 | grep -q 'iter: item-beta' || { echo "FAIL: most recent commit not iter: item-beta"; git -C "$TMP29" log --oneline; exit 1; }
git -C "$TMP29" log --pretty=%s | head -2 | tail -1 | grep -q 'iter: item-alpha' || { echo "FAIL: second-most-recent commit not iter: item-alpha"; git -C "$TMP29" log --oneline; exit 1; }
echo "  Test 29 passed: loop progressed through 2-item queue (2 flips, 2 commits, queue-empty exit)"

echo ""
echo "All pipeline loop multi-iteration smoke tests passed."

# ═══════════════════════════════════════════════════════
# Branch prefix / archive naming tests
# ═══════════════════════════════════════════════════════

echo ""
echo "Running branch prefix smoke tests..."

# Test 30: archive folder strips forge/ prefix (not forge/old-feature in path)
mkdir -p "$TMP30/.ralph"
init_git_repo "$TMP30"
render_script \
  "$TMP30/.ralph/smoke.sh" \
  "bash" \
  "bash -lc 'echo \"<promise>COMPLETE</promise>\"'"

git -C "$TMP30" checkout -q -b forge/old-feature
cat > "$TMP30/prd.json" <<'JSON'
{"branchName":"forge/old-feature","userStories":[]}
JSON
echo "# old progress" > "$TMP30/progress.txt"
git -C "$TMP30" add -A
git -C "$TMP30" -c commit.gpgsign=false commit -q --no-gpg-sign -m "old feature run"

echo "forge/old-feature" > "$TMP30/.ralph-last-branch"

cat > "$TMP30/prd.json" <<'JSON'
{"branchName":"forge/new-feature","userStories":[]}
JSON

if ! (cd "$TMP30" && ./.ralph/smoke.sh 1 >"$TMP30/out.txt" 2>&1); then
  echo "FAIL: archive smoke should exit 0"
  cat "$TMP30/out.txt"
  exit 1
fi
archive_dir=$(find "$TMP30/.ralph-archive" -maxdepth 1 -type d -name '*-old-feature' 2>/dev/null | head -1)
if [ -z "$archive_dir" ]; then
  echo "FAIL: expected archive dir ending in -old-feature under .ralph-archive/"
  ls -la "$TMP30/.ralph-archive/" 2>/dev/null || echo "(no archive dir)"
  cat "$TMP30/out.txt"
  exit 1
fi
archive_base=$(basename "$archive_dir")
case "$archive_base" in
  *forge*)
    echo "FAIL: archive folder name should not contain forge/ prefix (got: $archive_base)"
    exit 1
    ;;
  *-old-feature) ;;
  *)
    echo "FAIL: unexpected archive folder name (got: $archive_base)"
    exit 1
    ;;
esac
if [ ! -f "$archive_dir/prd.json" ]; then
  echo "FAIL: archived prd.json missing from $archive_dir"
  exit 1
fi
echo "  Test 30 passed: forge/ branch prefix stripped in archive folder name"

echo ""
echo "All branch prefix smoke tests passed."
