[![Version](https://img.shields.io/github/v/tag/pforret/claude-plugins?label=version&sort=semver)](https://github.com/pforret/claude-plugins/tags) [![License: MIT](https://img.shields.io/github/license/pforret/claude-plugins)](LICENSE) [![Last commit](https://img.shields.io/github/last-commit/pforret/claude-plugins)](https://github.com/pforret/claude-plugins/commits/main) [![Issues](https://img.shields.io/github/issues/pforret/claude-plugins)](https://github.com/pforret/claude-plugins/issues) [![Stars](https://img.shields.io/github/stars/pforret/claude-plugins?style=flat)](https://github.com/pforret/claude-plugins/stargazers) [![Claude Code plugin](https://img.shields.io/badge/Claude_Code-plugin_marketplace-D97757)](https://code.claude.com/docs/en/plugin-marketplaces)

# claude-plugins

Peter Forret's Claude Code plugins. Add the marketplace **`pforret-claude`** once, then install the
plugins you want from it.

```text
/plugin marketplace add pforret/claude-plugins
```

To get new versions, run `/plugin marketplace update pforret-claude`, or turn on auto-update for the
marketplace in `/plugin`.

## Plugin: FODO

Per-repo todo workflow in `docs/todo/`: add items, plan them into PRPs, implement, verify and archive
them, with a local dashboard across all your repos.

FODO stands for *Fear Of Dozing Off*. The name was chosen to be quick to type: on a QWERTY keyboard,
`f-o-d-o` alternates hands (left, right, left, right) with very little finger travel.

![The fodo dashboard (/fodo:web): busy items and running Claude Code agents across all repos, then one card per repo](assets/dashboard.png)

### Install

```text
/plugin install fodo@pforret-claude
```

### Use

Run these inside a git repo. The first command creates `docs/todo/` if it isn't there yet.

```text
/fodo:add fix the login redirect after password reset    # Claude classifies, sizes and plans it
/fodo:list                                               # planned items 1, 2, … plus plan (P1…) and busy (B1…)
/fodo:plan 1                                             # research + clarifying questions → PRP, item becomes P1
/fodo:start P1                                           # implement it, item becomes B1
/fodo:done                                               # verify the acceptance criteria and archive it
/fodo:skip 2                                             # drop an item, with a reason
/fodo:web                                                # open the dashboard of all your repos
/fodo:valet                                              # or serve it permanently as http://fodo.test (Laravel Valet)
```

Small items can skip planning: `/fodo:start 1`. Items are plain markdown files, so the todo list is
readable on GitHub too.

### All commands

**Once, after installing the plugin:** set up the dashboard, which shows all your repos. Pick one:

| Command | What it does |
|---------|--------------|
| `/fodo:web [stop\|status\|<port>]` | start, stop or check the local dashboard (`http://127.0.0.1:7787/`); the server keeps running until you stop it |
| `/fodo:valet [status\|unlink]` | or serve it permanently as `http://fodo.test` with Laravel Valet; nothing to start again |

**Once per repo:**

| Command | What it does |
|---------|--------------|
| `/fodo:init` | create `docs/todo/` and its folders. Optional: the first other fodo command in a new repo does it too |

**Day to day, in the current repo.** These only read and change the `docs/todo/` of the repo you are
in. IDs: `1`, `2`, … = backlog · `P1` = planned with a PRP · `B1` = busy · `S1` = someday. An empty
id means the item you started last.

| Command | What it does |
|---------|--------------|
| `/fodo:add [--quick] <text>` | add a bug, change or feature; Claude classifies, sizes and plans it. `--quick` captures without research |
| `/fodo:list` | show the backlog, plus the plan and busy tables |
| `/fodo:show [id]` | print an item |
| `/fodo:plan <n>` | research the item, ask clarifying questions, write a PRP; it becomes `P<n>` |
| `/fodo:start <n\|Pn>` | implement the item (following its PRP if it has one); it becomes `B<n>` |
| `/fodo:done [Bn]` | verify the acceptance criteria, write the result, archive it |
| `/fodo:skip [id]` | drop an item, with a reason |
| `/fodo:someday [id [note] \| S<n> back]` | park an idea for later, list parked ideas, or bring one back |
| `/fodo:wait [Bn] <reason> \| [Bn] resume` | mark a busy item as blocked (waiting for a review, an answer, …), or clear it |
| `/fodo:busy` | what is in progress and planned in this repo |

**Across all your repos.** fodo remembers every repo you use it in (in `~/.claude/todo/repos.csv`,
on this machine only):

| Command | What it does |
|---------|--------------|
| `/fodo:busy --all` | what is in progress and planned, in every repo |
| `/fodo:repos [prune]` | list all the repos fodo knows about, or drop the ones that are gone |

The dashboard (`/fodo:web` or `http://fodo.test`) shows the same overview of all repos in the browser.

The [fodo README](plugins/fodo/README.md) has the details: lifecycle, the dashboard (PHP 8.1+), and
what the plugin reads and writes.

## License

MIT. Working on the plugins themselves: see [DEVELOP.md](DEVELOP.md).
