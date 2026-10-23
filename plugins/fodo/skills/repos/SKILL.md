---
name: repos
description: Show the machine-local registry of repos that use docs/todo/ (~/.claude/todo/repos.csv), or with prune drop the repos whose folder no longer exists. Use when asked "which repos have todos" or "prune the todo registry".
argument-hint: "[prune]"
---

Helper: `bash "${CLAUDE_PLUGIN_ROOT}/scripts/todo.sh"` (run from the repo root; below written as `todo.sh`).
Read `${CLAUDE_PLUGIN_ROOT}/reference/conventions.md` first: layout, IDs, auto-init and rules.

Arguments: $ARGUMENTS

## REPOS

Run `bash "${CLAUDE_PLUGIN_ROOT}/scripts/todo.sh" repos` (append `prune` when the arguments say
`prune`) and show its output verbatim.
