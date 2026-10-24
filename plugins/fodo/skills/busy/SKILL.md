---
name: busy
description: Show the docs/todo/ items in progress (busy) and waiting with a PRP (plan) for this repo, or with --all for every registered repo on this machine. Use when asked "what am I working on", "show busy todos" or "busy items in all repos".
argument-hint: "[--all]"
---

Helper: `bash "${CLAUDE_PLUGIN_ROOT}/scripts/fodo.sh"` (run from the repo root; below written as `fodo.sh`).
Read `${CLAUDE_PLUGIN_ROOT}/reference/conventions.md` first: layout, IDs, auto-init and rules.

Arguments: $ARGUMENTS

## BUSY

Run `bash "${CLAUDE_PLUGIN_ROOT}/scripts/fodo.sh" busy` (append `--all` when the arguments contain
`--all` or `-a`) and show its output verbatim.
