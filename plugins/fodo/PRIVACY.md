# Fodo privacy policy

Fodo is a Claude Code plugin by Peter Forret. It runs entirely on your own computer. It collects no
personal data, has no server, uses no analytics or tracking, and sends nothing to the author or to
anyone else.

## What Fodo reads and writes on your computer

- **Your repositories:** the todo items as markdown files in each repo's `docs/todo/` folder. Fodo
  creates, moves and edits these files when you run a `/fodo:` command. It never commits or pushes.
- **Registry:** `~/.claude/todo/repos.csv` lists the repos that used Fodo (path, folder name, first and
  last use date), so the dashboard can show them together.
- **Dashboard settings:** `~/.claude/todo/config.json` stores the fonts and color scheme you pick on
  the dashboard's settings page. The server's pid, port and log files are also kept in
  `~/.claude/todo/`.
- **Claude Code session files:** the dashboard reads `~/.claude/sessions/<pid>.json` to show which
  repos have a Claude Code session running. It uses only the working folder, session name and
  busy/idle status, and does not store them.
- **Repo details for the dashboard:** the time of the last git activity from `.git/logs/HEAD` and the
  repo's favicon file, if it has one.

The dashboard is served by PHP's built-in web server on `127.0.0.1` only, so other computers can't
reach it. It loads no external fonts, scripts or images.

## Data shared with Anthropic

Fodo itself shares nothing. When you use it inside Claude Code, your conversation, including the
todo files and code that Claude reads, is processed by Claude under
[Anthropic's privacy policy](https://www.anthropic.com/legal/privacy), like any other Claude Code
session.

## Removing your data

Delete `~/.claude/todo/` to remove the registry and dashboard settings. Each repo's `docs/todo/`
folder holds only your own todo items; delete or keep it as you like.

## Contact

Questions or issues: https://github.com/pforret/claude-plugins/issues
