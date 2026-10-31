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
bats tests/                               # helper (fodo.sh, semver.sh), release and dashboard-server tests
shellcheck plugins/fodo/scripts/*.sh
php -l plugins/fodo/dashboard/index.php
claude plugin validate --strict plugins/fodo
claude plugin validate --strict .         # marketplace.json
```

The cheatsheet PDF is rendered from `assets/cheatsheet.html` (edit the HTML, then re-render):

```bash
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless=new --disable-gpu --no-pdf-header-footer \
  --print-to-pdf="$PWD/assets/fodo-cheatsheet.pdf" "file://$PWD/assets/cheatsheet.html"
```

Release with `bin/release.sh [patch|minor|major]`: it keeps `VERSION.md` and every `plugin.json`
version equal, runs the checks, tags and pushes. Details and directory-submission steps:
[docs/publishing.md](docs/publishing.md).

## Add a plugin

1. Create `plugins/<name>/` with its own `.claude-plugin/plugin.json` (name, version, description,
   author, license), a `README.md` of at least 40 words and a `LICENSE`.
2. Add an entry to `.claude-plugin/marketplace.json`:
   `{"name": "<name>", "source": "./plugins/<name>", "description": "…", "category": "…"}`.
   Keep the version out of `marketplace.json`; `bin/release.sh` sets it in `plugin.json`.
3. Add a `## Plugin: <NAME>` chapter to `README.md`, before `## License`, in the same shape as
   the FODO chapter: a short description, `### Install` (`/plugin install <name>@pforret-claude`)
   and `### Use` with example commands and a link to `plugins/<name>/README.md`. README images go in
   `assets/`.
4. Run `claude plugin validate --strict plugins/<name>` and `claude plugin validate --strict .`.

## Layout

```text
.claude-plugin/marketplace.json   marketplace "pforret-claude": one entry per plugin
plugins/fodo/                     the fodo plugin (manifest, skills, scripts, reference, dashboard)
bin/release.sh                    bump VERSION.md + plugin.json, check, tag, push
tests/                            bats tests
assets/                           README images (not part of any plugin)
docs/                             project docs (mkdocs), publishing steps, this repo's own docs/todo items
```
