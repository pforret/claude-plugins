# Developing claude-plugins

How to work on the plugins in this repository (`pforret/claude-plugins`, marketplace `pforret-claude`).
For how to use them, see [README.md](README.md).

## Setup

```bash
git clone git@github.com:pforret/claude-plugins.git && cd claude-plugins
```

You need `bats`, `shellcheck` and `php` (8.1+) for the tests, and the `claude` CLI for loading
and validating the plugins.

## Work on fodo

```bash
claude --plugin-dir plugins/fodo          # load the working copy for one session (/reload-plugins after edits)
bats tests/                               # helper and dashboard-server tests
shellcheck plugins/fodo/scripts/*.sh
php -l plugins/fodo/dashboard/index.php
claude plugin validate --strict plugins/fodo
claude plugin validate --strict .         # marketplace.json
```

Release and directory-submission steps: [docs/publishing.md](docs/publishing.md).

## Add a plugin

1. Create `plugins/<name>/` with its own `.claude-plugin/plugin.json` (name, version, description,
   author, license), a `README.md` of at least 40 words and a `LICENSE`.
2. Add an entry to `.claude-plugin/marketplace.json`:
   `{"name": "<name>", "source": "./plugins/<name>", "description": "…", "category": "…"}`.
   Keep the version in `plugin.json` only.
3. Add a row to the plugins table in `README.md`.
4. Run `claude plugin validate --strict plugins/<name>` and `claude plugin validate --strict .`.

## Layout

```text
.claude-plugin/marketplace.json   marketplace "pforret-claude": one entry per plugin
plugins/fodo/                     the fodo plugin (manifest, skills, scripts, reference, dashboard)
tests/                            bats tests
assets/                           README images (not part of any plugin)
docs/                             project docs (mkdocs), publishing steps, this repo's own docs/todo items
```
