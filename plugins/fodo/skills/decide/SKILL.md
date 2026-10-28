---
name: decide
description: '[this repo] Record a decision (why we chose this) as a file in docs/todo/decisions/, or a one-line gotcha in docs/todo/decisions/gotchas.md, or list them. Use when the user says "we decided", "record this decision", "write an ADR", "why did we", "note this gotcha", "remember that the X table is append-only" or asks "what did we decide".'
argument-hint: "[<decision> | --gotcha <text> | gotcha: <text>]"
---

Helper: `bash "${CLAUDE_PLUGIN_ROOT}/scripts/fodo.sh"` (run from the repo root; below written as `fodo.sh`).
Read `${CLAUDE_PLUGIN_ROOT}/reference/conventions.md` first: layout, IDs, auto-init and rules, and
`${CLAUDE_PLUGIN_ROOT}/reference/decision_template.md` for the file formats.

Arguments (empty, a decision, or a gotcha): $ARGUMENTS

## DECIDE

Decisions are records, never items: they are not moved, and only the helper writes them.

- **No arguments: list.** Run `fodo.sh reindex`, show `docs/todo/decisions/index.md` verbatim and,
  when it exists, `docs/todo/decisions/gotchas.md`. If both are empty say so and show the forms
  `/fodo:decide <decision>` and `/fodo:decide --gotcha <text>`.
- **`--gotcha <text>` or text starting with `gotcha:`: record a gotcha.** If the text names a file
  or folder of this repo, put that path first as `path/to/file:` so the SessionStart hook can match
  it against the diff. Run `fodo.sh gotcha "<text>"` and report the file path. Do not ask anything.
- **Anything else: record a decision.**
  1. The title is the decision itself as one sentence (the user's words, trimmed, no "we decided
     to"). When a busy item is current (`fodo.sh current` succeeds), pass it as `--item <path>`.
  2. `fodo.sh decide "<title>" [--item <path>] --by decide` → prints the new file path. If it says
     `exists:`, a decision with that slug was recorded today: show it (`fodo.sh path <filename>`)
     and ask whether to update it or pick another title.
  3. Fill the file: replace the `<…>` placeholders under `## Context`, `## Options considered` and
     `## Consequences` with what the conversation says. Ask one question only when the options
     considered are genuinely unknown; otherwise write what you know and leave "none known" where
     you know nothing.
  4. `fodo.sh reindex`, then report the path and its `D<n>` ID from `docs/todo/decisions/index.md`.
     `/fodo:show D<n>` prints it later.
