---
name: show
description: '[this repo] Print one docs/todo/ item file (request, analysis, plan or PRP, notes). Use when asked to "show todo 3", "show the current item", "what does B1 say" or "show decision D2".'
argument-hint: "[n|Pn|Bn|Sn|Dn]"
---

Helper: `bash "${CLAUDE_PLUGIN_ROOT}/scripts/fodo.sh"` (run from the repo root; below written as `fodo.sh`).
Read `${CLAUDE_PLUGIN_ROOT}/reference/conventions.md` first: layout, IDs, auto-init and rules.

Arguments (item id; empty = the current item): $ARGUMENTS

## SHOW

Resolve the id with `fodo.sh path <id>` (empty = current item; `D<n>` = a decision record in
`docs/todo/decisions/`) and print the file content verbatim.
