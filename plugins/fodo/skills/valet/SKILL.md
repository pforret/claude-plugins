---
name: valet
description: '[setup once, all repos] Serve the fodo dashboard permanently as http://fodo.test with Laravel Valet (macOS), or show its status or remove it. Use when asked to "set up fodo.test", "link the dashboard in Valet" or "remove the fodo Valet site".'
argument-hint: "[status|unlink]"
---

Arguments: $ARGUMENTS

## VALET

Run `bash "${CLAUDE_PLUGIN_ROOT}/scripts/valet.sh" <args>` with the arguments passed through:

- no arguments → link the dashboard as `fodo.<tld>` (idempotent; safe to run again)
- `status` → whether the site is linked, where it points and which `claude` the `/agents` page uses
- `unlink` → remove the site

Never run `valet` or `sudo` yourself: every `valet` command asks for a password, which a Claude
session cannot type. The script writes the same symlink `valet link fodo` would.

Report the URL it prints and mention `/fodo:valet unlink`. Then handle these output lines:

- `https: …` → tell the user they can run `! valet secure fodo` themselves for https.
- `todolist: …` → the old todo skill's `todolist` site still exists. Ask the user (AskUserQuestion,
  options "Remove it" / "Keep it") whether to remove it; only on "Remove it" run
  `bash "${CLAUDE_PLUGIN_ROOT}/scripts/valet.sh" unlink-todolist` and report its output.
- `note: claude is not on the PATH …` → `/agents` on fodo.test will show a notice instead of sessions.

If it fails with `Laravel Valet not found`, say that `/fodo:web` serves the same dashboard without
Valet. If it says Valet does not serve the Sites folder yet, or that `fodo` already points elsewhere,
pass the message on verbatim; do not work around it.
