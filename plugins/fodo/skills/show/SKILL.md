---
name: show
description: '[this repo] Print one docs/todo/ item file (request, analysis, plan or PRP, notes). Use when asked to "show todo 3", "show the current item" or "what does B1 say".'
argument-hint: "[n|Pn|Bn]"
---

Helper: `bash "${CLAUDE_PLUGIN_ROOT}/scripts/fodo.sh"` (run from the repo root; below written as `fodo.sh`).
Read `${CLAUDE_PLUGIN_ROOT}/reference/conventions.md` first: layout, IDs, auto-init and rules.

Arguments (item id; empty = the current item): $ARGUMENTS

## SHOW

Resolve the id with `fodo.sh path <id>` (empty = current item) and print the file content verbatim.
