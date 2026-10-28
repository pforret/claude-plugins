---
name: add
description: '[this repo] Add a new item (bug, change or feature) to the docs/todo/ todo list, with type and size estimated from the codebase, an analysis, impacted files, a plan and acceptance criteria. Use when asked to "add a todo", "put this on the todo list" or "note this for later". Offers to do trivial items (one file, a few lines) right away, GTD two-minute rule. "--quick" or several lines capture items without research ("jot these down").'
argument-hint: "[--quick] <text>"
---

Helper: `bash "${CLAUDE_PLUGIN_ROOT}/scripts/fodo.sh"` (run from the repo root; below written as `fodo.sh`).
Read `${CLAUDE_PLUGIN_ROOT}/reference/conventions.md` first: layout, IDs, auto-init and rules.

Arguments (the item text): $ARGUMENTS

## Quick capture

Use quick capture instead of the steps below when the arguments start with `--quick`, when they
hold several non-empty lines or list items, or when the user asks to just jot things down. For each
line (the `--quick` flag and list markers `-`, `*`, `1.` stripped):

- **Guess the type** from the words only, checking in this order: `bug` when it says broken, bug,
  error, fails, crash, wrong, fix, typo or doesn't/does not/can't/cannot (anything); `feature` when
  it says add, new, support, allow, introduce, export or show; otherwise `change`.
- Make the title and slug from the text and write the **quick item** template from
  `${CLAUDE_PLUGIN_ROOT}/reference/item_template.md` (`size: unknown`, only `## Request`).
- Apply the duplicate check of step 5 (same title as a planned item: append the request to it).

Do not read or search the codebase. Run `fodo.sh reindex` once at the end and show the new items
(ID, type, title). Say that `/fodo:plan <n>` or `/fodo:start <n>` will clarify them. No sizing
happens, so there is no two-minute offer (step 6).

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
6. **Two-minute rule.** Only for a newly written item (not the append case) that is trivial: size
   `small`, exactly one file in `files:`, about 10 changed lines or fewer, no open question in the
   Analysis and no new test needed. The offer depends on the sizing in step 2, so items added without
   it never get one. Skip this step when the user asked to defer ("for later", "later", "note this",
   "remind me", "someday", "backlog", "don't do it now", `--later`) or added several items at once.
   Ask with AskUserQuestion, "This looks like a two-minute item. Do it now?", with the options
   "Do it now (Recommended)" (implement, verify and archive it to `done/` now) and "Keep it filed"
   (leave it in the backlog).
   - **Keep it filed**: stop; the add is complete.
   - **Do it now**: `fodo.sh move-file <path> busy`, then implement it as in step 3 of
     `${CLAUDE_PLUGIN_ROOT}/skills/start/SKILL.md` (no PRP: follow the item's Plan and run the
     relevant checks), then follow steps 1–4 of `${CLAUDE_PLUGIN_ROOT}/skills/done/SKILL.md` for the
     current item. The user's click is the go-ahead for done. If it turns out not to be trivial
     (more files, a decision to make), stop with the item in busy, add a `## Notes` line saying why,
     and point the user to `/fodo:done` or `/fodo:plan`. Do not commit.
