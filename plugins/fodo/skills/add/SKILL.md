---
name: add
description: Add a new item (bug, change or feature) to the docs/todo/ todo list, with type and size estimated from the codebase, an analysis, impacted files, a plan and acceptance criteria. Use when asked to "add a todo", "put this on the todo list" or "note this for later".
argument-hint: <text>
---

Helper: `bash "${CLAUDE_PLUGIN_ROOT}/scripts/fodo.sh"` (run from the repo root; below written as `fodo.sh`).
Read `${CLAUDE_PLUGIN_ROOT}/reference/conventions.md` first: layout, IDs, auto-init and rules.

Arguments (the item text): $ARGUMENTS

## ADD

1. **Classify the type** from the text:
   - `bug`: something existing behaves wrongly
   - `change`: modify/improve/refactor existing behaviour
   - `feature`: net-new capability
2. **Estimate the size** by actually looking at the codebase (grep/read the areas the text
   mentions) and listing the files that would plausibly change:
   - `small`: 1–2 files
   - `medium`: 3–10 files
   - `large`: >10 files or architectural change (new subsystem, schema/API redesign, framework swap)
3. **Slug**: 2–6 lowercase words, hyphenated, from the title (e.g. `fix-login-redirect`).
4. **Write** `docs/todo/<yyyy-mm-dd>.<type>.<slug>.md` (today's date, ISO) using the template in
   `${CLAUDE_PLUGIN_ROOT}/reference/item_template.md`. Put the user's text verbatim under `## Request`.
5. Run `bash "${CLAUDE_PLUGIN_ROOT}/scripts/fodo.sh" reindex`, then show the new item's reference
   number and one-line summary. If the same title already exists as a planned item, append to it
   instead of creating a duplicate and say so. For `medium`/`large` items, suggest `/fodo:plan <n>`
   before starting.
