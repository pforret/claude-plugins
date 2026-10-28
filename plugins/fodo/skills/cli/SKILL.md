---
name: cli
description: '[setup once, all repos] Put a `fodo` command on your PATH, so you can run "fodo list" or "fodo busy --all" in any repo terminal, or show its status or remove it. Use when asked to "install the fodo command", "link fodo.sh in my PATH" or "remove the fodo command".'
argument-hint: "[status|unlink|<dir>]"
---

Arguments: $ARGUMENTS

## CLI

The script is `bash "${CLAUDE_PLUGIN_ROOT}/scripts/cli.sh"` (below written as `cli.sh`).

- no arguments → ask where to put the command:
  1. Run `cli.sh candidates`: the writable directories on the PATH, one per line, best first.
  2. Ask with AskUserQuestion, "Where should the fodo command go?", with up to 4 of those
     directories as options (the first marked "(Recommended)" when it is `~/.local/bin` or `~/bin`).
     When there are none, offer `~/.local/bin` (it is created, and the script prints the PATH line
     to add). "Other" lets the user type a directory.
  3. Run `cli.sh link <dir>` with the chosen absolute directory.
- a directory → `cli.sh link <dir>` without asking.
- `status` → `cli.sh status`: where `fodo` is and which plugin version it runs.
- `unlink` → `cli.sh unlink`: remove the command.

Never run `sudo` and never edit the user's shell profile. If the script says a directory is not
writable or that a `fodo` exists that fodo did not make, pass the message on verbatim and offer
another directory; do not work around it.

Report the linked path, then handle these output lines:

- `path: …` → the directory is not on the PATH: show the `export PATH=…` line to add to their
  shell profile (`~/.zshrc` on macOS).
- `shadowed: …` → another `fodo` comes first on the PATH and will run instead.

Finish with a short example: `fodo list`, `fodo busy --all`, `fodo path 3`, and say that an open
terminal may need `hash -r` (or a new tab) to find it. In a repo without `docs/todo/` the command
refuses to create it; run `fodo init` or `/fodo:init` there first. The command follows plugin
updates by itself; `/fodo:cli unlink` removes it.
