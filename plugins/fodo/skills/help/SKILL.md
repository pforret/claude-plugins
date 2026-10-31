---
name: help
description: '[any repo] Show a one-screen overview of every fodo command, one line each, grouped into installation and per-repo use, with the happy path and a link to the cheatsheet. Use when asked "fodo help", "what can fodo do", "which fodo commands are there" or "how do I use fodo".'
argument-hint: ""
---

Print the text below verbatim, as one markdown message, and nothing else. Do not run any command,
do not read the repo, do not add commentary before or after it.

```markdown
# fodo — per-repo todos, PRPs and decisions as markdown in docs/todo/

**Happy path:** `/fodo:add <text>` → `/fodo:plan 1` → `/fodo:start P1` → `/fodo:done` → `/fodo:commit`
Small, clear items skip the plan: `/fodo:start 1`. Once a week: `/fodo:review`.

**Install once**
- `/plugin marketplace add pforret/claude-plugins` then `/plugin install fodo@pforret-claude` — install; updates with `/plugin marketplace update pforret-claude`
- `/fodo:web [stop|status|<port>]` — the dashboard of all your repos on http://127.0.0.1:7787 (PHP 8.1+)
- `/fodo:valet [status|unlink]` — or serve it permanently as http://fodo.test with Laravel Valet (macOS)
- `/fodo:cli [status|unlink|<dir>]` — a `fodo` command on your PATH: `fodo list`, `fodo busy --all`, `fodo pick` in any terminal
- Dashboard → /config — pick the header font, body font and color scheme (Light/Dark × Colors/Monochrome)
- `/fodo:init` — create docs/todo/ in a repo; optional, the first other fodo command does it too

**Per repo: items** (IDs: `1`, `2` backlog · `P1` planned with a PRP · `B1` busy · `S1` someday · `D1` decision · empty = the item you started last)
- `/fodo:add [--quick] <text>` — add a bug, change or feature, sized from the code; `--quick` captures now, clarifies later
- `/fodo:list` — the backlog plus the plan and busy tables
- `/fodo:show [id]` — print an item, or a decision (`D2`)
- `/fodo:plan <n>` — research, ask clarifying questions, write a PRP; the item becomes `P<n>`
- `/fodo:start <n|Pn>` — implement it (following the PRP if there is one); the item becomes `B<n>`
- `/fodo:done [Bn]` — verify the acceptance criteria, write the Result, archive to done/
- `/fodo:skip [id]` — drop an item, with a reason
- `/fodo:someday [id [note] | Sn back]` — park an idea, list parked ideas, or bring one back
- `/fodo:wait [Bn] <reason> | [Bn] resume` — mark a busy item as waiting for something, or clear it
- `/fodo:busy [--all]` — what is in progress and planned, in this repo or in every registered repo

**Per repo: memory, review, git**
- `/fodo:decide [<decision> | --gotcha <text>]` — record why you chose something (small ADR, `D1`…) or a one-line gotcha; no arguments: list them
- `/fodo:review [planned-days [busy-days]]` — weekly review: flag stale items and keep, re-plan, park, skip or start each one
- `/fodo:commit [<message>]` — stage all, generated commit message, setver-style version bump (asks once), CHANGELOG.md, commit and tag; never pushes
- `/fodo:repos [prune]` — the repos fodo knows on this machine, or drop the ones that are gone
- `/fodo:help` — this overview

Cheatsheet (one page, PDF): https://github.com/pforret/claude-plugins/blob/main/assets/fodo-cheatsheet.pdf
Docs: https://github.com/pforret/claude-plugins/blob/main/plugins/fodo/README.md
```
