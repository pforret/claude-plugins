---
name: web
description: [setup once, all repos] Open the fodo dashboard, a local web page showing the docs/todo/ items of every registered repo, served by PHP's built-in server on 127.0.0.1; also stop it or show its status. Use when asked to "open the todo dashboard", "start the todo website" or "stop the dashboard".
argument-hint: "[stop|status|<port>]"
---

Arguments: $ARGUMENTS

## WEB

Run `bash "${CLAUDE_PLUGIN_ROOT}/scripts/web.sh" <args>` with the arguments passed through:

- no arguments → start on port 7787 (or `$TODO_WEB_PORT`), or reuse the server that already runs
- a number → start on that port
- `stop` → stop the server
- `status` → whether it runs and where

The server runs detached and keeps running after this session; its pid, port and log live in
`~/.claude/todo/web.{pid,port,log}`. Report the URL it prints (`http://127.0.0.1:<port>/`; add
`?all=1` to include done and skipped items; `/agents` lists the Claude Code sessions) and mention
`/fodo:web stop` (with Laravel Valet, `/fodo:valet` serves it permanently as `http://fodo.test`). If it says `php not
found`, tell the user the dashboard needs PHP 8.1+ (e.g. `brew install php`); everything else in
fodo works without PHP.
