---
name: start
description: [this repo] Start implementing a docs/todo/ item. Move it to docs/todo/busy/, then follow its PRP blueprint and validation loop, or its plan when there is no PRP. Use when asked to "start todo 3", "execute the PRP", "work on item P1" or "implement todo 2".
argument-hint: <n|Pn> [execute]
---

Helper: `bash "${CLAUDE_PLUGIN_ROOT}/scripts/fodo.sh"` (run from the repo root; below written as `fodo.sh`).
Read `${CLAUDE_PLUGIN_ROOT}/reference/conventions.md` first: layout, IDs, auto-init and rules.

Arguments (item id, optionally followed by the word "execute"): $ARGUMENTS

## START

`<id>` is `n` (planned) or `Pn` (plan); a trailing `execute` is accepted and ignored. On a `Bn` item
that has `waiting_on` (marked with `/fodo:wait`), run `fodo.sh resume <path>`, say it is no longer
waiting and continue with step 3 on it. On any other `Bn` item say it is already busy and stop.

1. `fodo.sh path <id>` → read the item file fully. If it is a quick item (`size: unknown`), first
   fill it in as in steps 1–4 of `${CLAUDE_PLUGIN_ROOT}/skills/add/SKILL.md` (Analysis, Impacted
   files, Plan, Acceptance criteria). If the guessed type is wrong, correct it with
   `fodo.sh retype <path> <type>` and use the path it prints; this must happen before the size is
   set, since retype only works while `size: unknown`. Then `fodo.sh set <path> size <size>` and
   `fodo.sh reindex`. If it comes out `medium` or `large`, stop here and suggest `/fodo:plan <n>`;
   it stays planned.
2. `fodo.sh move-file <path> busy` (sets `status: busy`, adds `busy_at`, moves the file, rebuilds
   indexes and records it as the current item). Print the new path and its new `B<n>` ID.
3. **If the item has a `## PRP` section**: follow it. Read every file and URL under "Context the
   implementer MUST read", extend the research only where the PRP points at something that has
   changed, then execute the blueprint tasks in order, tracking them with your task list. Run the
   validation loop level by level; fix and re-run until each level passes (never mock to pass).
   Re-read the PRP at the end to check nothing was skipped.
   **If it has no PRP**: execute the item's `## Plan` directly: implement the change, run the
   relevant tests/linters.
   In both cases update the item file's plan/blueprint with checkmarks and notes as you go, and
   jot down deviations from the spec and discoveries the moment they happen (a `## Notes` section
   is fine); `/fodo:done` turns them into the Result section.
   If the item is `large` or you find an open design decision mid-way and it has no PRP,
   suggest `/fodo:plan <n>` instead of guessing.
4. Do not mark it done automatically. The user decides with `/fodo:done` (current item) or
   `/fodo:done B<n>`.
