You are running one iteration of a Reverse Ralph decomposition loop.

Your job is to process a single node in `decomp.json` and update the file on disk.
Do NOT implement any code. Do NOT create any files other than updating `decomp.json`.
Make exactly ONE write to `decomp.json` before exiting.

## Your task this iteration

Process node ID: __NEXT_NODE_ID__

Read the current `decomp.json` (appended at the end of this prompt). Find the node with
id `__NEXT_NODE_ID__`. Then do ONE of the following based on its status:

---

### If the node status is `needs_split`

Decide: can this node be expressed as a small set of atomic user stories right now, or is
it still too coarse?

A node is too coarse if writing user stories for it would require the implementing agent
to make architectural decisions — things like "which module handles this", "what data
structure is used", "how is state persisted". If you are not sure what those decisions
would be, the node is too coarse.

**If too coarse:** Split it. Change its status to `split` and add 2–6 child nodes to its
`children` array. Each child represents a distinct behavioral sub-capability. Set each
child's status to `needs_split`. Add each child node to the top-level `nodes` array with
`parent_id` set to this node's id.

**If granular enough:** Change the node's status from `needs_split` to `needs_stories`.
Do not add children.

---

### If the node status is `needs_stories`

Write atomic user stories for this node. A story is atomic when:
- A single headless coding agent with no prior codebase context could read it and
  implement it completely in one pass
- The agent would not need to make any architectural decisions to complete it
- All acceptance criteria are specific and verifiable ("the command X returns Y when Z",
  not "works correctly")
- The story describes behavior and function only — not implementation details

Write 1–5 stories. Add them to the node's `stories` array. Set the node's status to
`atomic`.

For each story, include:
- `id`: format US-NNN (auto-increment from the highest existing story ID in the file)
- `node_id`: this node's id
- `title`: short imperative title
- `description`: "As a [user/agent/system], I want [behavior] so that [outcome]."
- `acceptance_criteria`: array of specific, verifiable strings
- `depends_on`: array of story IDs that must be complete before this one (empty if none)
- `priority`: integer; lower = higher priority; infer from dependency ordering

---

## Atomicity self-check

Before writing anything, ask yourself about each story or child node:

> "If I handed this to a fresh coding agent with no context, would it know exactly
> what to build without making any design decisions?"

If the answer is no for a story → the node needs further splitting, not story writing.
If the answer is no for a child node → that is fine; it will be split in a future iteration.

---

## Output instructions

Update `decomp.json` in place. Only modify:
- The target node's `status` field
- The target node's `children` array (if splitting)
- The target node's `stories` array (if writing stories)
- The top-level `nodes` array (add new child nodes if splitting)

Do not modify any other nodes. Do not change `capability_surface`, `feature_name`,
`source_urls`, or `completed_at`.

Write the updated file to disk and exit.
