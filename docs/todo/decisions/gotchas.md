# Gotchas

One line each, newest last. Start a line with `path/to/file:` and the session-start hook shows it when that file is in your diff.

- 2026-10-28 plugins/fodo/scripts/fodo.sh: reindex writes an index.md into every stage folder under set -e, so mkdir -p every folder in reindex first; old repos lack the newer ones
- 2026-10-28 plugins/fodo/scripts/session-start.sh: the busy block exits 0 early; anything that must print without busy items goes before it
