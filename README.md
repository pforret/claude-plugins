# claude-plugins

This repository is the Claude Code plugin marketplace `pforret-claude`. It currently holds one plugin:
**[fodo](plugins/fodo/README.md)**, a per-repo todo workflow in `docs/todo/` (add → plan as a PRP →
start → done or skip) with a local dashboard across all your repos.

![The fodo dashboard (/fodo:web): busy items and running Claude Code agents across all repos, then one card per repo](assets/dashboard.png)

## Install

```text
/plugin marketplace add pforret/claude-plugins
/plugin install fodo@pforret-claude
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
.claude-plugin/marketplace.json   marketplace "pforret-claude" → ./plugins/fodo
plugins/fodo/                     the plugin (manifest, skills, scripts, reference, dashboard)
tests/                            bats tests
assets/                           README images (not part of the plugin)
docs/                             project docs (mkdocs) and this repo's own docs/todo items
```

## License

MIT
