# Fodo

Fodo is a Claude Code plugin that keeps a todo list for each repo as plain markdown files in
`docs/todo/`, and walks every item through a fixed lifecycle: you add it, Claude plans it into a
PRP (Product Requirements Prompt) by researching the code and asking you clarifying questions until
it is 9/10 confident, then implements it, verifies it against its acceptance criteria and archives
it. A local dashboard shows the items of all your repos on one page.

FODO stands for *Fear Of Dozing Off*. The name was chosen to be quick to type: on a QWERTY keyboard,
`f-o-d-o` alternates hands (left, right, left, right) with very little finger travel.

## Install

```text
/plugin marketplace add pforret/claude-plugins
/plugin install fodo@pforret-claude
```

Once it is listed, you can also add Fodo from the Claude plugin directory.

Supported surface: **Claude Code** (terminal, IDE, desktop Code tab). Fodo works on files in your
local repository with bash and git, so it does nothing useful in claude.ai chat.
The dashboard additionally needs PHP 8.1 or newer.

## Commands

| Command | What it does |
|---------|--------------|
| `/fodo:init` | create `docs/todo/` with `plan/`, `busy/`, `done/`, `skipped/`, `someday/` and their index files |
| `/fodo:list` | show the planned items (IDs `1`, `2`, …) plus the plan (`P1`…) and busy (`B1`…) tables |
| `/fodo:add [--quick] <text>` | add a bug, change or feature; Claude classifies it, sizes it from the code and writes a plan, and offers to do trivial items right away. `--quick` or several lines capture items without research, to clarify later |
| `/fodo:plan <n>` | research item `n`, ask clarifying questions, write a PRP, move it to `plan/` |
| `/fodo:start <n\|Pn>` | move the item to `busy/` and implement it (following the PRP when there is one) |
| `/fodo:done [Bn]` | verify the acceptance criteria, append a Result section, move it to `done/` |
| `/fodo:skip [id]` | ask for the reason, record it, move the item to `skipped/` |
| `/fodo:someday [id [note] \| S<n> back]` | park an idea in `someday/` (GTD someday/maybe), list parked items (`S1`…), or bring one back to the backlog |
| `/fodo:show [id]` | print an item |
| `/fodo:busy [--all]` | items in progress and planned items, for this repo or every registered repo |
| `/fodo:wait [Bn] <reason> \| [Bn] resume` | mark a busy item as waiting for something (GTD waiting for), or clear it; the busy table and the dashboard show the reason |
| `/fodo:review [planned-days [busy-days]]` | weekly review (GTD): flag backlog items older than 30 days, busy items with no commits to their files for 14 days and PRPs whose code changed since planning, then keep, re-plan, park, skip or start each one |
| `/fodo:repos [prune]` | list the registered repos, or drop the ones that no longer have `docs/todo/` |
| `/fodo:web [stop\|status\|port]` | start, stop or check the dashboard |
| `/fodo:valet [status\|unlink]` | serve the dashboard permanently as `http://fodo.test` with Laravel Valet |

An empty id in `done`, `skip` and `show` means the item you started last. Claude can also run
these commands by itself when you ask in plain words, such as "add this to the todo list".

When a session starts in a repo that has items in `docs/todo/busy/`, a SessionStart hook tells
Claude which ones are in progress (ID, title, since when, what they wait on), so it can pick up
where you left off. The hook prints nothing in repos without busy items.

## Lifecycle and files

`planned → plan (optional) → busy → done | skipped`, with `someday/` on the side for parked ideas
(planned or plan items go there and come back to planned). A busy item that is blocked can be marked
as waiting with `/fodo:wait` (`waiting_on` + `waiting_since` in its frontmatter); it keeps its `B<n>` ID and
loses the marker when it leaves busy. `/fodo:review` walks the stale items; keeping one sets `reviewed`
in its frontmatter, which restarts its age clock, and re-planning sends a plan item back to planned.
Every item is one markdown file named
`<yyyy-mm-dd>.<bug|change|feature>.<slug>.md`, with frontmatter (title, type, size, status, dates,
confidence) and sections for the request, analysis, plan, acceptance criteria, PRP and result.
Each folder has an `index.md` table that the plugin rebuilds from the files, so you can browse the
list on GitHub or in any markdown viewer.

## Dashboard

`/fodo:web` serves a page at `http://127.0.0.1:7787/` with the planned, plan and busy items of
every registered repo; `?all=1` adds someday, done and skipped items. Pass another port as the argument or set
`TODO_WEB_PORT`. The server keeps running after the session ends; stop it with `/fodo:web stop`.

With [Laravel Valet](https://laravel.com/docs/valet) on macOS, `/fodo:valet` serves the same
dashboard permanently as `http://fodo.test`, with no server to start. It keeps working after plugin
updates: every fodo command points the site at the current version. For https, run
`valet secure fodo` yourself (it asks for your password). `/fodo:valet unlink` removes the site.

- Busy items get a spinning marker; waiting items (`/fodo:wait`) get a grey pause marker and their reason,
  and are listed after the active ones in the busy panel. Each repo card shows a badge for the Claude Code sessions running
  in that repo ("agent working" or "agent idle"). The busy panel also lists sessions in repos that
  have no busy item. The overview reloads itself every minute; the `/config` page does not.
- A repo's page (click its name) shows its items as a read-only kanban board: Backlog → Plan → Busy
  (with `?all=1` also Someday on the left, and Done → Skipped, the 10 latest of each). Click a card to open its details beside the board
  (`?repo=1#B1`): file, dates, the `/fodo:` command that moves it on and the whole item, rendered.
  `Table view` switches to the full tables.
- The `?` icon in the top bar opens `/faq`: why the list lives in `docs/todo/`, the happy path, the
  ID forms and every command in detail.
- `/agents` (the Agents button) is a web version of `claude agents`: every Claude Code session on
  this machine, grouped by state (needs input, working, idle, completed) or by repo, with the busy
  item of the session's repo. Click a session to see its title, last prompt and last reply. The page
  is read-only and reloads itself every 15 seconds.
- Repos with nothing in backlog, plan or busy are hidden behind a "Show n empty repos" button.
- `/config` (the gear icon) sets the header font, the body font and the color scheme: Light Colors,
  Light Monochrome, Dark Colors or Dark Monochrome. The fonts are system fonts, with Futura for
  headers and Palatino for body text by default.

## What this plugin runs and writes

- **Bash helper** `scripts/fodo.sh`, run by Claude in your repo: creates and moves files under
  `docs/todo/` (with `git mv` when the file is tracked) and rewrites the `index.md` files. For
  `/fodo:review` it reads `git log` of the files an item lists. It never commits or pushes.
- **SessionStart hook** `scripts/session-start.sh` (`hooks/hooks.json`): runs once when a Claude
  Code session starts, resumes or compacts. It only reads the files in `docs/todo/busy/` and
  `docs/todo/.current` of the current repo and prints a few lines into the session context. It
  writes nothing, runs no other command and exits silently when there is nothing in progress.
- **Registry** `~/.claude/todo/repos.csv`: one line per repo that used the plugin (path, name, first
  and last use). Change the folder with `TODO_REGISTRY_DIR`. On first use the plugin copies in, once,
  the repos listed in `~/.claude/state/todo-projects.tsv` (the file of older versions of the `todo`
  skill) whose folder still exists, and writes a `.legacy-imported` marker. That file is only read.
- **Dashboard server** `scripts/web.sh`: starts `php -S 127.0.0.1:<port>` on the plugin's
  `dashboard/` folder, bound to localhost only, writes `web.pid`, `web.port` and `web.log` next to
  the registry, and opens the page in your browser. The page reads the registry, the markdown files
  in each registered repo's `docs/todo/`, the tail of `.git/logs/HEAD` (last activity time) and
  the repo's favicon file if there is one. It executes nothing from those repos. It also reads
  the Claude Code session files `~/.claude/sessions/<pid>.json` (working folder, name, busy/idle)
  and checks with signal 0 that each process is still alive. That check sends no signal. If
  `CLAUDE_CONFIG_DIR` is set, the files are read from there instead of `~/.claude`.
- **Valet site** `scripts/valet.sh` (`/fodo:valet`): never runs `valet` or `sudo`. It creates the
  symlinks `~/.config/valet/Sites/fodo` → `~/.claude/todo/dashboard` → the plugin's `dashboard/`
  (the same link `valet link fodo` makes) and writes the absolute path of `claude` to
  `~/.claude/todo/claude-bin` for the agents page. The other helpers re-point
  `~/.claude/todo/dashboard` at the current plugin version when it exists. `unlink` removes all three;
  `unlink-todolist` removes an old `todolist` Valet link into `~/.claude/skills/todo` after you confirm.
- **Agents page** `/agents`: runs one command, `claude agents --json --all`, each time the page
  loads (no shell, 5-second timeout; point it at another binary with `FODO_CLAUDE_BIN`). This is
  the only command the dashboard runs. The binary is your locally installed Claude Code CLI: the
  path stored in `~/.claude/todo/claude-bin` is used only when it is an absolute path to an
  executable named `claude`. Nothing is downloaded and no fetched code is ever executed. When you open a session, it reads the last 512 KB of that
  session's transcript under `~/.claude/projects/` to show its title, last prompt and last reply.
  Nothing is stored.
- **Dashboard settings** `~/.claude/todo/config.json`: written by `/config` when you save (scheme
  and fonts). Saves are refused unless they come from the dashboard's own origin. The browser keeps
  the "show empty repos" choice in local storage.
- **No network access**: the plugin and the dashboard send nothing anywhere and load no external
  fonts, scripts or images.

## Your data stays yours

Items are plain markdown files in your repo, readable and editable without the plugin. Any other
tool that follows the same `docs/todo/` layout can work on the same repos. Uninstalling the plugin
leaves your `docs/todo/` items and the registry in place. Privacy policy: [PRIVACY.md](PRIVACY.md).
Questions and bug reports: [GitHub issues](https://github.com/pforret/claude-plugins/issues).

## License

MIT, see [LICENSE](LICENSE).
