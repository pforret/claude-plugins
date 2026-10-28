---
name: list
description: '[this repo] Show the docs/todo/ todo list of this repo, the planned items with reference numbers plus the plan and busy tables. Use when asked to "show the todo list", "what''s on the todo list" or "list todos".'
---

Helper: `bash "${CLAUDE_PLUGIN_ROOT}/scripts/fodo.sh"` (run from the repo root; below written as `fodo.sh`).
Read `${CLAUDE_PLUGIN_ROOT}/reference/conventions.md` first: layout, IDs, auto-init and rules.

Arguments: $ARGUMENTS

## LIST

Run `bash "${CLAUDE_PLUGIN_ROOT}/scripts/fodo.sh" list` and show its output verbatim (the planned
table, plus the plan and busy tables if anything is there, and one-line counts of the items in
`someday/` and the records in `decisions/` when there are any, and the emoji legend line at the end).
Do not paraphrase the tables. If empty,
say so and show the usage forms `/fodo:add <text>`, `/fodo:plan <n>` and `/fodo:start <n>`.
