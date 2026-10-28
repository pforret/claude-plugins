---
name: review
description: '[this repo] Weekly review (GTD) of the docs/todo/ items. Flag planned items that have been waiting too long, busy items with no recent commits to their files and PRPs whose code has changed since planning, then keep, re-plan, park, skip or start each one. Use when asked to "review the todo list", "weekly review" or "what has gone stale".'
argument-hint: "[planned-days [busy-days]]"
---

Helper: `bash "${CLAUDE_PLUGIN_ROOT}/scripts/fodo.sh"` (run from the repo root; below written as `fodo.sh`).
Read `${CLAUDE_PLUGIN_ROOT}/reference/conventions.md` first: layout, IDs, auto-init and rules.

Arguments (optional: planned-days, then busy-days, both positive integers): $ARGUMENTS

## REVIEW

The review only decides what happens to stale items. It never plans, implements or finishes one
itself: those are queued as follow-up commands for the user.

1. **Find the stale items.** Map the arguments to flags (`<planned-days>` → `--planned N`,
   `<busy-days>` → `--busy M`; defaults 30 and 14) and run `fodo.sh stale [flags]`. If it prints
   `_Nothing stale._`, say so, mention the thresholds used, and stop.
2. **Show the table verbatim.** From here on hold every item by its **file path** (the File column),
   never by its ID: IDs shift after every move.
3. **Understand each item**: read it (title, size, Request, Goal if it has a PRP). For a plan item
   run `git log --oneline --after="<since> 23:59:59" -- <its files: paths>` (`<since>` is the date in
   its "Why flagged" cell) and summarise in one line what changed in that code.
4. **Ask**, with AskUserQuestion, up to 4 items per round, one question per item: header = its ID,
   question = title + why it was flagged (+ the change summary for plan items). Options per stage,
   Keep first and marked "(Recommended)" unless the facts say otherwise:
   - planned: **Keep** · **Plan/Start** (Plan when size is medium, large or unknown, else Start) ·
     **Park** · **Skip**
   - plan: **Keep** · **Re-plan** · **Start** · **Park**; mention that "Other: skip <reason>" skips it
   - busy: **Keep** · **Finish** · **Wait** · **Skip**
5. **Act right after each round**, per item:
   - Keep → `fodo.sh set <path> reviewed <today>` (`today` = `date +%Y-%m-%d`). A waiting busy item
     keeps its `waiting_on`.
   - Park → `fodo.sh move-file <path> someday`
   - Skip → take the reason from the "Other" text or ask for it (free text, never invent one), append
     `## Skipped\n\n<reason>` to the item, then `fodo.sh move-file <path> skipped`
   - Wait (busy) → ask for the reason, then `fodo.sh wait <path> <reason>`
   - Re-plan (plan item) → `fodo.sh move-file <path> planned` now; queue `plan <filename>`
   - Plan/Start (planned) → queue `plan <filename>` or `start <filename>`; do not move the item
   - Start (plan item) → queue `start <filename>`; Finish (busy) → queue `done <filename>`; do not
     move the item (`/fodo:start` and `/fodo:done` do that)
5b. **Review the decisions** (`docs/todo/decisions/`, see
   `${CLAUDE_PLUGIN_ROOT}/reference/decision_template.md`). Skip silently when the folder has no
   records. Otherwise, oldest first, up to 4 per round, one question per decision whose `status`
   is `accepted` and whose `reviewed` is older than the planned-days threshold (or absent): header =
   `D<n>`, question = title + date (+ item). Options: **Keep (Recommended)** · **Superseded** ·
   **Make a rule or test**. Act per decision: Keep → `fodo.sh set <path> reviewed <today>`;
   Superseded → ask which decision replaces it (a `D<n>`, a filename, or free text), then
   `fodo.sh set <path> status superseded` and `fodo.sh set <path> superseded_by <filename or text>`;
   Make a rule or test → queue `add <title>` as a follow-up. Then, if `decisions/gotchas.md`
   exists, list the lines whose `path/to/file:` prefix no longer exists in the repo as "stale
   gotchas" for the user to delete by hand; do not edit the file.
6. **Finish.** Run `fodo.sh list` and map every queued filename to its current ID: `fodo.sh path
   <filename>` gives its folder, its row in that folder's table gives the ID (`n`, `P<n>` or `B<n>`).
   Print a summary table (ID · title · action taken) and then the follow-up commands, one per line,
   e.g. `/fodo:plan 3`, `/fodo:start P1`, `/fodo:done B2`, `/fodo:add <title>`. Do not run them.
