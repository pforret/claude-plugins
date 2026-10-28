---
name: init
description: '[once per repo] Set up todo tracking for this repo by creating docs/todo/ with plan/, busy/, done/, skipped/, someday/ and decisions/ folders and their index files. Use when asked to "init fodo", "set up todo tracking" or "create docs/todo".'
---

Helper: `bash "${CLAUDE_PLUGIN_ROOT}/scripts/fodo.sh"` (run from the repo root; below written as `fodo.sh`).
Read `${CLAUDE_PLUGIN_ROOT}/reference/conventions.md` first: layout, IDs, auto-init and rules.

Arguments: $ARGUMENTS

## INIT

Run `bash "${CLAUDE_PLUGIN_ROOT}/scripts/fodo.sh" init`. Creates `docs/todo/` with `plan/`, `busy/`,
`done/`, `skipped/`, `someday/` and `decisions/` plus an `index.md` in each. Idempotent: creates only missing folders and
(re)builds indexes, never deletes items. Report the resulting path. If the repo has a CLAUDE.md,
offer nothing else, do not edit it.
