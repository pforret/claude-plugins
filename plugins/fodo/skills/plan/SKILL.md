---
name: plan
description: '[this repo] Plan a docs/todo/ item in depth. Research the codebase and docs, ask clarifying questions until 9/10 confidence, and write a PRP (Product Requirements Prompt) into the item, which then moves to docs/todo/plan/. Use when asked to "plan todo 3", "write a PRP for item 2" or "generate a PRP".'
argument-hint: '<n>'
---

Helper: `bash "${CLAUDE_PLUGIN_ROOT}/scripts/fodo.sh"` (run from the repo root; below written as `fodo.sh`).
Read `${CLAUDE_PLUGIN_ROOT}/reference/conventions.md` first: layout, IDs, auto-init and rules.

Arguments (the planned item id): $ARGUMENTS

## PLAN

Turns a planned item into a PRP: a self-contained brief that lets an agent implement the item in
one pass with only the item file and the repo. Only planned items (`n`) can be planned; on a `Pn`
or `Bn` item say it is already in that stage and stop.

1. `fodo.sh path <id>` → read the item file fully. If it is a quick item (`size: unknown`), first
   do the research of steps 1–4 of `${CLAUDE_PLUGIN_ROOT}/skills/add/SKILL.md` and fill in its
   Analysis, Impacted files, Plan and Acceptance criteria (keep the Request). If the guessed type is
   wrong, correct it with `fodo.sh retype <path> <type>` and use the path it prints; do this before
   any size is set, since retype only works while `size: unknown`. The size is set in step 6 as usual.
2. `fodo.sh move <id> plan` → print the new path. From now on the item has a `P<n>` ID
   (re-list to show it).
3. **Research** (do all of this before writing anything):
   - *Codebase*: find similar features/patterns and the conventions they follow, the files to
     reference or mirror, the test patterns and the lint/test commands that exist (package.json,
     composer.json, Makefile, CI config). Read CLAUDE.md and any `docs/agents/` knowledge base.
   - *External*: for libraries/APIs involved, find the documentation URLs with the specific
     sections, known pitfalls and version quirks. Pass URLs, not summaries.
   - *Options*: list every decision that is genuinely open: architecture, library choice, data
     model, UX behaviour, scope boundaries, backwards compatibility, naming the user may care about.
4. **Score your confidence** 1–10 that an agent can implement this in one pass from the PRP alone.
   Be honest: an open design decision, an unknown integration, or no executable validation each
   cost points.
5. **Ask until ≥ 9/10.** While confidence < 9, use AskUserQuestion with the open options
   (up to 4 questions per round, each with 2–4 concrete options, your recommendation first and
   marked "(Recommended)", with the trade-off in each description). Record every answer under
   `### Decisions taken`. Re-score, and repeat rounds until ≥ 9. Never pad the score to escape
   the loop; if the user says "just pick", use your recommendation and note that in the decision.
   When the user cannot answer (needs to check something), stop here, leave the item in `plan/`
   with its current confidence, and say what is still open.
6. **Write the PRP**: append the sections from `${CLAUDE_PLUGIN_ROOT}/reference/prp_template.md` to
   the item file (after `## Acceptance criteria`), fully filled in. If the item already has a `## PRP`
   (it was sent back by `/fodo:review` for re-planning), replace that section, from `## PRP` up to the
   next `## ` heading or the end of the file, instead of appending a second one; use its old Decisions
   taken as input in step 3 and re-ask only what the changed code made open again. Update the earlier sections
   so they agree with the decisions (`## Plan` becomes a short pointer to the PRP, `files:` and
   `size:` are corrected). Then `fodo.sh set <path> confidence <n>` and `fodo.sh reindex`.
   Quality gate before saving: all needed context included · validation commands are real and
   executable in this repo · existing patterns referenced by path · every acceptance criterion has
   a check in the validation loop · gotchas are repo-specific, not generic advice · the approach
   describes the shape, not a step-by-step script.
6b. **Offer the decisions as records** (see `${CLAUDE_PLUGIN_ROOT}/reference/decision_template.md`):
   one multi-select AskUserQuestion listing the `### Decisions taken` rows (max 4 per question,
   several questions in one call when there are more), preselect the rows marked "(user)" and the
   ones that pick an architecture, library, data model or scope; leave naming and defaults
   unselected. For each selected row run `fodo.sh decide "<the decision>" --item <path> --by plan`,
   fill Context (the question), Options considered (the alternatives offered, with trade-offs) and
   Consequences, and append `(recorded: decisions/<file>)` to the row in the PRP. Skip the question
   when there are no Decisions taken.
7. **Finish** by re-listing and telling the user, verbatim in form:
   `Plan ready (<n>/10). Start the implementation with "/fodo:start P<k>".`
   where `P<k>` is the item's ID in the plan table. Do **not** start implementing.
