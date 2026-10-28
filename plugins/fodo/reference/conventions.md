# fodo conventions (shared by every /fodo:* skill)

## Layout

All state lives in the current repo under `docs/todo/`:

```
docs/todo/
  index.md                       planned items (numbered table)   ← source for "/fodo:list"
  <yyyy-mm-dd>.<type>.<slug>.md  one planned item per file
  plan/index.md  + items         planned in depth (PRP written, confidence ≥ 9/10), waiting for start
  busy/index.md  + items         in progress
  done/index.md  + items         finished
  skipped/index.md + items       deliberately not done (with reason)
  someday/index.md + items       parked ideas (GTD someday/maybe): kept, not committed to
  decisions/index.md + records   why things are the way they are (one <yyyy-mm-dd>.<slug>.md per decision)
  decisions/gotchas.md           one dated line per gotcha; never indexed
```

Lifecycle: `planned → (plan) → busy → done | skipped`. The `plan` stage is optional: small,
unambiguous items go straight from planned to busy with `/fodo:start <n>`. Side branch: planned or
plan ⇄ someday (`/fodo:someday <id>` parks, `/fodo:someday S<n> back` returns to planned). A plan
item can also go back to planned for re-planning (`/fodo:review`); its old PRP stays in the file until
`/fodo:plan` replaces it.

**Waiting items** are busy items marked with `/fodo:wait`: frontmatter `waiting_on: "<reason>"` and
`waiting_since: <yyyy-mm-dd>`. They stay in `busy/` with their `B<n>` ID; the busy table shows the
reason in its "Waiting on" column and the dashboard shows them as blocked. The helper removes both
fields when the item leaves busy; `/fodo:start B<n>` on a waiting item resumes it.

**Review** (`/fodo:review`, GTD weekly review): `fodo.sh stale` flags planned items older than 30 days,
busy items with no activity for 14 days (no commit to their `files:` paths and no newer `busy_at` or
`reviewed`), and plan items whose `files:` paths have commits after `plan_at`. Thresholds are flags.
Keeping an item sets `reviewed: <yyyy-mm-dd>` in its frontmatter, which restarts its clock; the item
is otherwise untouched. The review never runs `/fodo:plan`, `/fodo:start` or `/fodo:done` itself.

**Quick items** have `size: unknown` and only a `## Request` section (captured by `/fodo:add --quick`
or by giving `/fodo:add` several lines). `/fodo:plan` and `/fodo:start` fill in the rest first.

`<type>` is one of `bug`, `change`, `feature`.

**Decisions** are records, not items: `docs/todo/decisions/<yyyy-mm-dd>.<slug>.md` (no type
segment) with `title`, `date`, `status: accepted | superseded`, optional `item:` (the item it came
from) and `recorded_by:` (the skill). They are never moved. `decisions/gotchas.md` holds one-line
gotchas (`- <date> path/to/file: <text>`). Only `fodo.sh decide` and `fodo.sh gotcha` write them;
see `reference/decision_template.md` for the formats and for when each skill records one.

## IDs

IDs are positional per table and carry a table prefix so they are never ambiguous:

| ID form | Table | Example |
|---------|-------|---------|
| `1`, `2`, … | planned (`docs/todo/`) | `/fodo:plan 2` |
| `P1`, `P2`, … | plan (`docs/todo/plan/`) | `/fodo:start P1` |
| `B1`, `B2`, … | busy (`docs/todo/busy/`) | `/fodo:done B1` |
| `S1`, `S2`, … | someday (`docs/todo/someday/`) | `/fodo:someday S1 back` |
| `D1`, `D2`, … | decisions (`docs/todo/decisions/`) | `/fodo:show D1` |
| `<filename>.md` | any table | `/fodo:done 2026-10-14.feature.add-login.md` |
| (none) | the item last started | `/fodo:done`, `/fodo:skip`, `/fodo:show` |

The n-th row of a table is the n-th file sorted by name (i.e. by date). IDs shift when items move,
so always re-list after a move and never store an ID inside an item. `fodo.sh path <id>` resolves
any of these forms to a file path; use it instead of parsing tables yourself. An `<id>` may be
prefixed with `#`. If `path` prints an error (out of range, unknown table, no current item), show
the list (`fodo.sh list`) and stop.

`docs/todo/.current` holds the filename of the item last moved to busy (written by the helper on
every move to busy, cleared when that item leaves busy). An empty id means that item; if the file
is missing and exactly one item is busy, that one is meant; otherwise ask which `B<n>`.

## The helper

Always use the helper script `scripts/fodo.sh` that ships with this plugin. Each skill gives its
exact path. Use it for folder setup, listing, moving, frontmatter edits and index rebuilding. It
rewrites every `index.md` from the files on disk, so indexes never drift. Run it from the repo
root (it also finds the git toplevel itself).

```
fodo.sh init | list | reindex
fodo.sh path <id>                           → file path for 1 / P1 / B1 / S1 / filename / "" (= current)
fodo.sh current                             → file path of the item last started
fodo.sh move <id> <plan|busy|done|skipped|someday|planned>  → move item <id>
fodo.sh move-file <file> <plan|busy|done|skipped|someday|planned>
                                            (someday: only from planned/plan; planned: only from someday or plan)
fodo.sh set <file> <key> <value>            → set a frontmatter field (e.g. confidence) and reindex
fodo.sh unset <file> <key>                  → remove a frontmatter field and reindex
fodo.sh wait <file> <reason>                → mark a busy item as waiting (refuses other items)
fodo.sh resume <file>                       → clear the waiting marker
fodo.sh retype <file> <bug|change|feature>  → correct the type of a quick item (renames it, prints the new path)
fodo.sh decide <title> [--item <file>] [--by <skill>]  → write a decision skeleton into decisions/, print its path
fodo.sh gotcha <text>                       → append "- <date> <text>" to decisions/gotchas.md, print the path
fodo.sh busy [--all]                        → busy + plan tables of this repo (--all: of every registered repo)
fodo.sh repos [prune]                       → print the global registry / drop repos whose path or docs/todo/ is gone
fodo.sh pick                                → terminal only: choose a backlog/plan/busy item (fzf or a number) and open
                                              Claude Code with /fodo:plan or /fodo:start on it; skills never call it
fodo.sh stale [--planned <days>] [--busy <days>]  → table of stale planned/plan/busy items for /fodo:review (read-only)
```

## Auto-init

Before any command other than `/fodo:init`: if `docs/todo/index.md` does not exist, run
`fodo.sh init` first and mention that you did. (`init` is also safe to run on an older
`docs/todo/` that has no `plan/` folder yet; it just adds it.)

## Global registry and dashboard

Every repo that runs `init`, `list`, `reindex` or a move is upserted into
`~/.claude/todo/repos.csv` (columns `"path","name","registered","last_seen"`; override the folder
with `TODO_REGISTRY_DIR`). Rows of `~/.claude/state/todo-projects.tsv` (older `todo` skill:
`path<TAB>name<TAB>date`, no header; override with `TODO_LEGACY_REGISTRY`) are converted once, on
first use, when the path is not registered yet and still exists; the marker
`.legacy-imported` in the registry folder stops later imports. That file is only read. The registry is machine-local. `/fodo:busy --all` prints the busy and
plan tables of every registered repo, grouped by repo; repos with neither are omitted, repos
whose path or `docs/todo/` is gone give a warning and `/fodo:repos prune` removes them.

`/fodo:web` serves the dashboard (PHP built-in server on `http://127.0.0.1:7787/`), which renders
the same registry: per repo the planned, plan and busy tables, with `?all=1` adding done and
skipped. It reads the markdown files at request time, so it is always current. `/config` on the
dashboard sets the header font, the body font and the color scheme (Light Colors = default, Light
Monochrome, Dark Colors, Dark Monochrome) and saves them in `~/.claude/todo/config.json`, next to the
registry. The overview also shows live Claude Code sessions per repo ("agent working" / "agent
idle", read from `~/.claude/sessions/<pid>.json`). The overview reloads itself every
minute.

`/fodo:valet` serves the same dashboard permanently through Laravel Valet as `http://fodo.<tld>`:
`<valet home>/Sites/fodo` → `~/.claude/todo/dashboard` → the plugin's `dashboard/`. It never runs
`valet` or `sudo`. `fodo.sh` and `web.sh` re-point `~/.claude/todo/dashboard` at their own plugin
version whenever that link exists, so the site follows plugin updates (and, while developing with
`--plugin-dir`, the working copy). `~/.claude/todo/claude-bin` holds the absolute `claude` path for
`/agents`, because Valet's PHP-FPM has no shell PATH.

`/fodo:cli` puts the helper on the PATH as `fodo`, so `fodo list` or `fodo busy --all` work in any
terminal: `<chosen dir>/fodo` → `~/.claude/todo/fodo.sh` → the plugin's `scripts/fodo.sh`. The skill
asks which writable PATH directory to use (`cli.sh candidates`); it never runs `sudo` or edits
shell profiles, and never replaces a `fodo` it did not make. `~/.claude/todo/cli-bin` holds the
installed path. `fodo.sh` and `web.sh` re-point `~/.claude/todo/fodo.sh` like the dashboard link.
Run as `fodo`, the helper never auto-inits: in a repo without `docs/todo/` every command except
`init`, `repos`, `busy --all` and help exits with a hint to run `fodo init`.
`fodo pick` lists the backlog, plan and busy items (fzf with a preview when installed, else a
numbered prompt); a backlog item asks plan or start, plan and busy items go to `/fodo:start`. With
`claude` on the PATH and a terminal it runs `claude "/fodo:<cmd> <id>"` (interactive, never `-p`),
otherwise it prints `Run in Claude Code: /fodo:<cmd> <id>`.

## Stage rules

- `/fodo:plan` takes planned items only. On a `Pn` or `Bn` item it is a no-op: say the item is
  already in that stage.
- `/fodo:start` takes `n` or `Pn`. On a `Bn` item it is a no-op: say it is already busy.

## Rules

- Never delete item files; every item ends in `done/` or `skipped/`.
- Never hand-edit an `index.md` or `.current`; always go through the helper.
- Never create a file in `decisions/` by hand; `fodo.sh decide` and `fodo.sh gotcha` do it. Editing
  the body of a decision afterwards is fine. Never store a `D<n>` in a file; link by filename.
- Item filenames are immutable once created (they are the stable identity). Single exception:
  the skill that first clarifies a quick item (`/fodo:plan` or `/fodo:start`) may correct its
  guessed type with `fodo.sh retype`, before it sets the size.
- The helper uses `git mv` when the file is tracked, so history follows the file.
- Do not commit unless the user asks.
