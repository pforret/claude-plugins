# ClaudePluginTodo

This repository is a Claude Code plugin marketplace (`pforret-todo`) with one plugin:
**[fodo](plugins/fodo/README.md)**, a per-repo todo workflow in `docs/todo/` (add → plan as a PRP →
start → done or skip) with a local dashboard across all your repos.

## Install

```text
/plugin marketplace add pforret/ClaudePluginTodo
/plugin install fodo@pforret-todo
```

## Develop

```bash
claude --plugin-dir plugins/fodo          # load the working copy for one session (/reload-plugins after edits)
bats tests/                               # helper and dashboard-server tests
shellcheck plugins/fodo/scripts/*.sh
claude plugin validate --strict plugins/fodo
claude plugin validate --strict .         # marketplace.json
```

Release and directory-submission steps: [docs/publishing.md](docs/publishing.md).

## Layout

```text
.claude-plugin/marketplace.json   marketplace "pforret-todo" → ./plugins/fodo
plugins/fodo/                     the plugin (manifest, skills, scripts, reference, dashboard)
tests/                            bats tests
docs/                             project docs (mkdocs) and this repo's own docs/todo items
```

## License

MIT
