---
name: someday
description: [this repo] Park a docs/todo/ item in docs/todo/someday/ (GTD someday/maybe), list the parked items, or bring one back to the backlog. Use when asked to "park todo 3", "someday/maybe this", "what is in someday" or "bring S1 back".
argument-hint: "[n|Pn [note] | S<n> back]"
---

Helper: `bash "${CLAUDE_PLUGIN_ROOT}/scripts/fodo.sh"` (run from the repo root; below written as `fodo.sh`).
Read `${CLAUDE_PLUGIN_ROOT}/reference/conventions.md` first: layout, IDs, auto-init and rules.

Arguments (empty, an item id with an optional note, or `S<n> back`): $ARGUMENTS

## SOMEDAY

Someday holds ideas worth keeping but not committed to. It is not `skipped/`: skipped means
rejected, someday means "maybe later".

- **No arguments: list.** Run `fodo.sh reindex`, then show `docs/todo/someday/index.md` verbatim.
  If it is empty, say so and show the forms `/fodo:someday <n>` and `/fodo:someday S<n> back`.
- **`<n|Pn> [note]`: park.** Only backlog (`n`) and plan (`Pn`) items can be parked; the helper
  refuses others, so show its message and stop (busy items are finished with `/fodo:done` or
  dropped with `/fodo:skip`). Resolve with `fodo.sh path <id>`. If a note follows the id, append
  `## Someday\n\n<note>` to the item. Do not ask for a reason. Then `fodo.sh move-file <path> someday`
  and report the new path and its `S<n>` ID (re-list with `fodo.sh reindex` and read the someday index).
- **`S<n> back`: un-park.** `fodo.sh path S<n>`, then `fodo.sh move-file <path> planned`. Report its
  new backlog number (`fodo.sh list`). If the item has a `## PRP` section, say that `/fodo:start <n>`
  will follow it.
