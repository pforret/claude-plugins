# fodo FAQ

Contents: [Why docs/todo/?](#why-keep-the-todo-list-in-docs-todo-inside-each-repo) · [The happy path](#what-is-the-happy-path) · [IDs](#how-do-the-ids-work) · [Every command](#what-does-each-command-do) · [Other questions](#other-questions)

## Why keep the todo list in docs/todo/ inside each repo?

Because the list belongs to the project, not to a tool.

- **It is versioned with the code.** Items are plain files in the repo: they travel with branches and pull requests, reviewers see the plan next to the diff, and `git log` shows when an item was added, started and finished. fodo moves items with `git mv` when they are tracked, so their history follows them.
- **It is plain markdown.** Every item is a `.md` file and every folder has a generated `index.md` table, so the list reads well on GitHub, in any editor, and in docs generators such as **MkDocs** or **pforret/mkdox**: put `docs/` in your MkDocs site and the todo list, the plans (PRPs) and the results become part of the project documentation.
- **No service, no account.** Nothing leaves your machine; it works offline and costs nothing. Deleting the folder removes fodo from the repo.
- **One list per repo.** Claude only reads and changes the `docs/todo/` of the repo it runs in. The dashboard and `/fodo:busy --all` give you the overview across repos.
- **Claude gets the context for free.** A PRP written by `/fodo:plan` sits in the repo, so any later session (or another developer) can pick it up with `/fodo:start`.

## What is the happy path?

1. **Capture**: `/fodo:add fix the login redirect after password reset`. Claude classifies it (bug, change or feature), sizes it from the code and writes an analysis, the impacted files, a plan and acceptance criteria. It becomes backlog item `1`.
2. **Look**: `/fodo:list` shows the backlog with numbers, plus the plan and busy tables.
3. **Plan** (for medium and large items): `/fodo:plan 1`. Claude researches the code, asks you clarifying questions until it is at least 9/10 confident, and writes a PRP (Product Requirements Prompt) into the item. It moves to `plan/` and becomes `P1`.
4. **Build**: `/fodo:start P1` (or `/fodo:start 1` for a small item without a plan). The item moves to `busy/`, becomes `B1`, and Claude implements it, ticking off the plan and noting deviations as it goes.
5. **Finish**: `/fodo:done`. Claude checks every acceptance criterion and validation command, appends a Result section (verification, deviations, discoveries, changes) and archives the item in `done/`.

Side roads:

- `/fodo:add --quick …` (or several lines at once) jots items down without research; plan or start them later.
- A trivial item (one file, a few lines) gets the two-minute offer right after `/fodo:add`: do it now, verify it and archive it in one go.
- `/fodo:wait B1 waiting for the API key` marks a busy item as blocked; `/fodo:start B1` or `/fodo:wait B1 resume` picks it up again.
- `/fodo:someday 3` parks an idea you don't want to commit to; `/fodo:someday S1 back` brings it back.
- `/fodo:skip 2` drops an item for good, with a reason.

fodo never commits: you decide when the code and the `docs/todo/` changes go into git.

## How do the IDs work?

| ID | Table | Example |
|----|-------|---------|
| `1`, `2`, … | backlog (`docs/todo/`) | `/fodo:plan 2` |
| `P1`, `P2`, … | plan (`docs/todo/plan/`), PRP written | `/fodo:start P1` |
| `B1`, `B2`, … | busy (`docs/todo/busy/`) | `/fodo:done B1` |
| `S1`, `S2`, … | someday (`docs/todo/someday/`) | `/fodo:someday S1 back` |
| `<file>.md` | any table | `/fodo:show 2026-10-14.feature.add-login.md` |
| (empty) | the item you started last | `/fodo:done` |

IDs are positions in their table, sorted by date, so they shift when items move: after `/fodo:start P1` the item is `B1` (or `B2` …), and the next plan item becomes `P1`. Re-list when in doubt. The filename never changes and always works.

## What does each command do?

Once, after installing the plugin: [/fodo:web](#fodo-web) or [/fodo:valet](#fodo-valet).
Once per repo (optional): [/fodo:init](#fodo-init).
Day to day, in the current repo: [/fodo:add](#fodo-add) · [/fodo:list](#fodo-list) · [/fodo:show](#fodo-show) · [/fodo:plan](#fodo-plan) · [/fodo:start](#fodo-start) · [/fodo:done](#fodo-done) · [/fodo:skip](#fodo-skip) · [/fodo:someday](#fodo-someday) · [/fodo:wait](#fodo-wait) · [/fodo:busy](#fodo-busy).
Across all your repos: [/fodo:busy --all](#fodo-busy) · [/fodo:repos](#fodo-repos).

You can also ask in plain words ("put this on the todo list", "what am I working on", "close B1"); Claude picks the matching command.

### /fodo:init

Usage: `/fodo:init`

Creates `docs/todo/` with the folders `plan/`, `busy/`, `done/`, `skipped/` and `someday/`, each with an `index.md`. Safe to run again: it only adds what is missing and rebuilds the indexes, it never deletes items. You rarely need it: the first other fodo command in a repo does the same. It also registers the repo for the dashboard.

```text
/fodo:init
```

### /fodo:add

Usage: `/fodo:add [--quick] <text>`

Adds a bug, change or feature to the backlog as `docs/todo/<date>.<type>.<slug>.md`. Claude:

- classifies the type: `bug` (existing behaviour is wrong), `change` (improve or refactor) or `feature` (new capability);
- sizes it by reading the code: `small` (1–2 files), `medium` (3–10) or `large` (more, or an architectural change);
- writes the Request (your words, verbatim), Analysis, Impacted files, Plan and Acceptance criteria.

If an item with the same title is already in the backlog, the request is appended to it instead. For medium and large items it suggests `/fodo:plan` first. A trivial item (small, one file, about 10 lines, no open question) gets the **two-minute offer**: do it now, verify it and archive it, unless you said "later", "note this", "someday" or `--later`.

**Quick capture**: with `--quick`, or when the text has several lines or list items, every line becomes its own item without any code research: the type is guessed from the words, the size stays `unknown` and only the Request is kept. `/fodo:plan` or `/fodo:start` fill in the rest later.

```text
/fodo:add the export to CSV drops the last row
/fodo:add --quick dark mode for the settings page
/fodo:add rename the config key for later
```

### /fodo:list

Usage: `/fodo:list`

Shows the backlog with its numbers, plus the plan table (`P1`…, with confidence) and the busy table (`B1`…, with what they wait on) when they have items, and a count of the parked someday items. When everything is empty it shows the forms of `/fodo:add`, `/fodo:plan` and `/fodo:start`.

```text
/fodo:list
```

### /fodo:show

Usage: `/fodo:show [id]`

Prints one item file: request, analysis, plan or PRP, notes and result. Any ID works (`3`, `P1`, `B2`, `S1`, a filename); without an ID it shows the item you started last.

```text
/fodo:show 3
/fodo:show
```

### /fodo:plan

Usage: `/fodo:plan <n>`

Turns backlog item `n` into a PRP, a self-contained brief that lets Claude implement it in one pass. The item moves to `plan/` and becomes `P<k>`. Claude:

1. fills in a quick item first (analysis, files, plan, acceptance criteria; corrects a wrongly guessed type);
2. researches the code (patterns to mirror, test commands) and the documentation of the libraries involved;
3. scores its confidence from 1 to 10 and asks you multiple-choice questions until it reaches 9/10, recording every answer under "Decisions taken";
4. appends the PRP: goal, why, decisions, context to read, gotchas, an ordered implementation blueprint, and an executable validation loop.

If you can't answer a question yet, the item stays in `plan/` with its current confidence. Only backlog items can be planned; on a `P` or `B` item it says so and stops. It never starts implementing.

```text
/fodo:plan 2
```

### /fodo:start

Usage: `/fodo:start <n|Pn> [execute]`

Moves the item to `busy/` (it becomes `B<k>` and the "current item") and implements it:

- with a PRP: reads the context it lists, follows the blueprint task by task and runs the validation loop until every level passes;
- without a PRP: follows the item's Plan and runs the relevant tests and linters.

It ticks off steps and writes deviations and discoveries into the item while it works. A quick item is filled in first; if it turns out medium or large, Claude stops and suggests `/fodo:plan`. On a busy item that waits (see `/fodo:wait`) it clears the waiting marker and continues. It never marks the item done by itself.

```text
/fodo:start 1
/fodo:start P1
/fodo:start B2        # resume a waiting item
```

### /fodo:done

Usage: `/fodo:done [Bn]`

Verifies a busy item: checks every acceptance criterion and runs the validation commands. If anything is unmet it says what and stops. Otherwise it appends a **Result** section (Verification, Deviations from the spec, Discoveries, Changes) and moves the item to `done/`. Without an ID it takes the item you started last. It offers to `/fodo:add` follow-ups from the discoveries, but never creates them silently.

```text
/fodo:done
/fodo:done B2
```

### /fodo:skip

Usage: `/fodo:skip [id]`

Drops an item for good: Claude asks for the reason (it never guesses one), appends it under `## Skipped` and moves the item to `skipped/`. Works on backlog, plan and busy items; without an ID it takes the item you started last. Skipped means "won't do"; for "maybe later" use `/fodo:someday`.

```text
/fodo:skip 4
```

### /fodo:someday

Usage: `/fodo:someday [<n|Pn> [note] | S<n> back]`

GTD's someday/maybe list: ideas worth keeping that you don't commit to.

- No arguments: lists the parked items (`S1`, `S2`, …).
- `<n|Pn> [note]`: parks a backlog or plan item in `someday/`, with an optional note under `## Someday`. Busy items can't be parked; finish them with `/fodo:done` or drop them with `/fodo:skip`.
- `S<n> back`: returns a parked item to the backlog. A PRP it had is kept, so `/fodo:start <n>` will follow it.

```text
/fodo:someday 5 after the redesign
/fodo:someday
/fodo:someday S1 back
```

### /fodo:wait

Usage: `/fodo:wait [Bn] <reason>` or `/fodo:wait [Bn] resume`

GTD's waiting-for: marks a busy item as blocked on something outside your control. It stays in `busy/` with its `B` ID and gets `waiting_on` and `waiting_since` in its frontmatter; the busy table shows the reason and the dashboard shows the item as paused.

- No arguments: shows the busy table; its "Waiting on" column is the list.
- `[Bn] <reason>`: marks the item (without an ID, the item you started last). Without a reason Claude asks for one.
- `[Bn] resume` (or `clear`): removes the marker. `/fodo:start Bn` does the same and continues working.

The marker disappears by itself when the item leaves busy.

```text
/fodo:wait B1 PR review by the client
/fodo:wait B1 resume
```

### /fodo:busy

Usage: `/fodo:busy [--all]`

Shows what is in progress (busy, with what it waits on) and what is planned with a PRP, for this repo. With `--all` it does this for every repo fodo knows on this machine, grouped by repo; repos with nothing busy or planned are left out, and repos that no longer exist give a warning (clean them up with `/fodo:repos prune`).

```text
/fodo:busy
/fodo:busy --all
```

### /fodo:repos

Usage: `/fodo:repos [prune]`

Lists the registry of repos that use fodo on this machine (`~/.claude/todo/repos.csv`; a repo is added whenever a fodo command runs in it). `prune` removes the repos whose folder or `docs/todo/` is gone. Repos from the older `todo` skill are imported once, automatically.

```text
/fodo:repos
/fodo:repos prune
```

### /fodo:web

Usage: `/fodo:web [stop|status|<port>]`

Starts this dashboard with PHP's built-in server on `http://127.0.0.1:7787/` (or the port you give, or `$TODO_WEB_PORT`), or reuses the one that already runs. The server keeps running after the Claude session ends; `stop` stops it, `status` tells whether and where it runs. Needs PHP 8.1+ (`brew install php`); the rest of fodo works without PHP.

```text
/fodo:web
/fodo:web 8080
/fodo:web stop
```

### /fodo:valet

Usage: `/fodo:valet [status|unlink]`

With Laravel Valet on macOS, serves this dashboard permanently as `http://fodo.test` (your Valet TLD), so there is nothing to start again. It links the site without running `valet` or `sudo` (those ask for a password), and remembers where `claude` lives so the Agents page works. `status` shows the link, `unlink` removes it. For https, run `valet secure fodo` yourself. Without Valet, use `/fodo:web`.

```text
/fodo:valet
/fodo:valet status
```

## Other questions

### What does an item file look like?

One markdown file per item, named `<yyyy-mm-dd>.<bug|change|feature>.<slug>.md`, with frontmatter (title, type, size, status, dates, confidence, waiting) and sections: Request, Analysis, Impacted files, Plan, Acceptance criteria, then PRP and Result when they are written. The filename never changes; only the folder does: backlog → `plan/` → `busy/` → `done/` or `skipped/`, with `someday/` on the side.

### Can I edit the files by hand?

Yes, the items are yours. Leave the `index.md` files and `docs/todo/.current` alone: fodo rebuilds them from the item files on every command.

### Does fodo commit or push anything?

No. It only writes files under `docs/todo/` (and the code changes you ask for in `/fodo:start`). Commit when you are ready.

### What happens when I open a Claude session in a repo with busy items?

A SessionStart hook tells Claude which items are in progress (ID, title, since when, what they wait on), so you can continue with "pick up where we left off". In repos without busy items it says nothing.

### What does this dashboard show, and can it change things?

Every registered repo with its busy, plan and backlog items (`Show someday / done / skipped` adds the rest); click a repo for its kanban board and a card for its details. The Agents page lists your Claude Code sessions. The dashboard only reads files; the one thing it writes is your font and color choice from the settings page (`~/.claude/todo/config.json`).

### Where is my data?

In each repo's `docs/todo/`, plus the machine-local registry and dashboard settings in `~/.claude/todo/`. Nothing is sent anywhere.
