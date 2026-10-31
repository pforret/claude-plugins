# Gotchas

One line each, newest last. Start a line with `path/to/file:` and the session-start hook shows it when that file is in your diff.

- 2026-10-28 plugins/fodo/scripts/fodo.sh: reindex writes an index.md into every stage folder under set -e, so mkdir -p every folder in reindex first; old repos lack the newer ones
- 2026-10-28 plugins/fodo/scripts/session-start.sh: the busy block exits 0 early; anything that must print without busy items goes before it
- 2026-10-28 plugins/fodo/scripts/fodo.sh: inside $(…), [ -t 1 ] is always false and stdout is captured; check the terminal before the substitution and print prompts to stderr (see pick/pick_one)
- 2026-10-28 plugins/fodo/scripts/fodo.sh: fzf under `script -q /dev/null` draws nothing until the pty has a size; run `stty rows 40 cols 140` first when checking fzf output (selection keys still work without it)
- 2026-10-28 plugins/fodo/scripts/fodo.sh: fzf `--with-nth 1..-2` also hides the last field (item path) from search, but the chosen line comes back whole, so `{-1}` in --preview and the row parsing still get the path
- 2026-10-29 plugins/fodo/scripts/web.sh: php -S without a router serves index.php (200) for any missing path, so tests cannot assert a 404; check removed files on disk
- 2026-10-29 tests/web.bats: ?repo=N indexes do not follow repos.csv order; look a repo's index up from the card links (?repo=N'>name<)
- 2026-10-29 plugins/fodo/dashboard/icons: rust, java (openjdk) and ios are #000000 and need the dark-scheme filter:invert rule in style.css; Simple Icons has no Java mark
- 2026-10-29 docs/todo/: the index.md files are rewritten by whichever fodo.sh runs last; a session on an older installed plugin reverts the table format, so reindex with the working copy before checking them
- 2026-10-29 tests/fodo.bats: index rows pad the ID to 2 digits (`| B1  |`, `| 1  |`), so greps like `| B1 |` no longer match
- 2026-10-30 plugins/fodo/dashboard/faq.md: every skills/<name>/ needs a '### /fodo:<name>' section and a '(#fodo-<name>)' link here, or tests/web.bats fails
