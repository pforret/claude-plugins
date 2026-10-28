---
name: skip
description: '[this repo] Skip a docs/todo/ item (planned, plan or busy). Ask for the reason, record it in the item and move it to docs/todo/skipped/. Use when asked to "skip todo 3", "drop this item" or "won''t do B1".'
argument-hint: "[n|Pn|Bn]"
---

Helper: `bash "${CLAUDE_PLUGIN_ROOT}/scripts/fodo.sh"` (run from the repo root; below written as `fodo.sh`).
Read `${CLAUDE_PLUGIN_ROOT}/reference/conventions.md` first: layout, IDs, auto-init and rules.

Arguments (item id; empty = the current item): $ARGUMENTS

## SKIP

Empty id = current item. Any table is allowed.

1. **Ask the user for the reason** (AskUserQuestion, free text). Never guess or skip without one.
2. Append `## Skipped\n\n<reason>` to the item file (resolve it with `fodo.sh path <id>`).
3. Move: `fodo.sh move-file <path> skipped` (works for planned, plan or busy items). Report the new path.
