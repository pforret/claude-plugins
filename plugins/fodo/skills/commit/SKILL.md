---
name: commit
description: '[this repo] Commit the working tree in one step: stage new files, write a short conventional-commit message (or take the given one), estimate whether the change is a patch, minor or major bump, ask once, write the new version into every version file like setver does (VERSION.md, composer.json, package.json, .env.example, plugin.json), update an existing CHANGELOG.md, commit and tag v<x.y.z>. Never pushes. Use when asked to "commit this", "commit and bump the version", "make a release commit" or "setver auto".'
argument-hint: "[<commit message>]"
---

Helpers: `bash "${CLAUDE_PLUGIN_ROOT}/scripts/semver.sh"` (below `semver.sh`) for everything that
touches a version number; run it from the repo root. Read `${CLAUDE_PLUGIN_ROOT}/reference/conventions.md`
for the rules; this skill is the one exception to "do not commit unless the user asks": running it
is that ask. It never runs `git push`.

Arguments (optional commit subject): $ARGUMENTS

## COMMIT

1. **Look.** `git status --short` (from the repo root). Clean tree: say "nothing to commit" and stop.
   Otherwise `git add -A` (never `-f`) and show the staged list from `git diff --cached --stat`.
   Safety: if a staged path matches `.env`, `.env.*` (except `.env.example`), `*.pem`, `*.key`,
   `id_rsa*`, or a staged file is larger than 5 MB, unstage it (`git reset -q -- <path>`), say which
   and why, and stop. The user decides.

2. **Subject.** With arguments: use them as the subject verbatim. Without: read `git diff --cached`
   and write one conventional-commit subject in the style of this repo's `git log --oneline -15`
   (`feat: …`, `fix: …`, `chore: …`, `docs: …`, `refactor: …`; `type!: …` for a breaking change),
   at most 72 characters, imperative, no trailing period. Add a body (blank line, a few `- ` lines)
   only when the diff spans several concerns. End the message with the attribution trailer Claude
   Code's session instructions prescribe, when there is one.

3. **Bump estimate** (setver's mapping, `suggest_next_version_bump`):
   - subject prefix ends in `!` or the body says `BREAKING CHANGE` → `major`
   - `feat` → `minor`
   - `fix` and every other type → `patch`
   - **none** when every staged path is bookkeeping: `docs/todo/**`, `CHANGELOG.md`, or `*.md`
     under `docs/`. Mention that the version stays.
   Then `current=$(semver.sh current)` and, unless none, `next=$(semver.sh next <level> "$current")`.
   If `semver.sh files` prints nothing, the repo has no version file: propose none and say so.

4. **Ask once** with AskUserQuestion: "Commit as `<subject>` and bump <current> → <next>
   (<reason>)?" Options, the proposal first and marked "(Recommended)": the proposed level, the
   other two levels with their resulting version, and "No bump". The user's choice is final; do not
   re-ask. "Other" with text replaces the subject.

5. **Version files** (only after a confirmed bump): `semver.sh set <next>`; it prints one line per
   file it wrote and fails when there is none. Show those lines.

6. **CHANGELOG.md**, only when the file exists at the repo root (creating one is `/fodo:changelog`'s
   job). The entry is `- <subject without the type prefix>`. Group by type (Keep a Changelog 1.1.0):
   `feat` → `### Added`, `fix` → `### Fixed`, `perf`/`refactor`/`chore`/`docs`/other → `### Changed`;
   `type!` also gets a line under `### Changed` starting with `**Breaking:**`.
   - No bump: add the entry under `## [Unreleased]` in its group, creating the group heading when
     missing. Create `## [Unreleased]` right under the intro when the file has none.
   - Bump: rename `## [Unreleased]` to `## [<next>] - <today, yyyy-mm-dd>`, add the entry there in
     its group, then insert a fresh empty `## [Unreleased]` above it. Without an Unreleased section,
     insert the new version section above the first `## [` heading.
   Never reorder, rewrite or delete existing lines. Then `git add CHANGELOG.md`.

7. **Commit.** `git add -A` again (version files, changelog), then `git commit -q -m "<subject>"`
   with `-m "<body>"` when there is one. On a bump: `semver.sh tag <next>` (annotated `v<next>`;
   it refuses an existing tag, in which case report it and leave the commit as is).

8. **Report.** Print `git log -1 --stat` and, when a remote exists, one line:
   "Not pushed. Push with `git push --follow-tags`." In this plugin's own repo (bin/release.sh exists) also say: run the
   checks from DEVELOP.md and push with `git push --follow-tags`; do not run `bin/release.sh` after a
   bump, it would bump a second time.

Guardrails: never `git push`, never `git add -f`, never amend or rewrite history, never create an
empty commit, never edit a version file by hand (always `semver.sh set`), never create CHANGELOG.md.
