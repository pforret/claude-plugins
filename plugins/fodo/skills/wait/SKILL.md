---
name: wait
description: '[this repo] Mark a busy docs/todo/ item as waiting for something (GTD waiting for), with the reason, clear the marker again, or list what is waiting. Use when asked "B1 is blocked on the PR review", "waiting for the client", "resume B2" or "what am I waiting on".'
argument-hint: "[Bn] <reason> | [Bn] resume"
---

Helper: `bash "${CLAUDE_PLUGIN_ROOT}/scripts/fodo.sh"` (run from the repo root; below written as `fodo.sh`).
Read `${CLAUDE_PLUGIN_ROOT}/reference/conventions.md` first: layout, IDs, auto-init and rules.

Arguments (optional busy id, then a reason or the word `resume`): $ARGUMENTS

## WAIT

A waiting item stays in `busy/` with its `B<n>` ID; it only carries `waiting_on` (the reason) and
`waiting_since` (the date it was marked). The busy table shows them after the title (`⏸ reason (since <date>)`) and
the dashboard shows the item as blocked instead of active. The helper drops both fields when the item
leaves busy, so `/fodo:done` and `/fodo:skip` need nothing extra.

- **No arguments: list.** Run `fodo.sh busy` and show its output verbatim; the rows with `⏸` are
  the list. If no busy item has a reason, say nothing is waiting.
- **`[Bn] resume` (or `clear`): un-mark.** Resolve the item with `fodo.sh path <id>` (no id = the
  current item, `fodo.sh path ""`), then `fodo.sh resume <path>`. Say it is no longer waiting.
- **`[Bn] <reason>`: mark.** If the first word is an id (`B<n>`, `#B<n>` or a `.md` filename), resolve
  it; otherwise use the current item and take all arguments as the reason. With no reason, ask for it
  (AskUserQuestion, free text); never invent one. Run `fodo.sh wait <path> <reason>`. The helper
  refuses items that are not busy: show its message and stop. Report the item's row from the busy
  table (`fodo.sh busy`).
