# CHANGELOG.md rules (used by /fodo:changelog and by /fodo:commit step 6)

One changelog per repo: `CHANGELOG.md` at the repo root, in the
[Keep a Changelog 1.1.0](https://keepachangelog.com/en/1.1.0/) format. `/fodo:changelog` creates and
fills it; `/fodo:commit` adds one entry per commit to an existing file and never creates one. Both
follow the rules below, so the file never has two styles.

## File format

```markdown
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- New thing, one line, what the user sees (the fodo plugin: name the plugin or skill)

## [1.2.0] - 2026-11-06

### Fixed
- Bug fix, one line

## [1.1.0] - 2026-10-30 [YANKED]

[Unreleased]: https://github.com/owner/repo/compare/v1.2.0...HEAD
[1.2.0]: https://github.com/owner/repo/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/owner/repo/releases/tag/v1.1.0
```

- Versions newest first; `## [Unreleased]` is always the first section, right under the intro.
- Version heading: `## [x.y.z] - yyyy-mm-dd` (ISO date, the tag or release date). A pulled release
  gets ` [YANKED]` after the date and keeps its entries.
- Groups, in this order and only the ones that have entries: `### Added`, `### Changed`,
  `### Deprecated`, `### Removed`, `### Fixed`, `### Security`. Never write an empty group.
- Entries: `- ` plus one sentence, imperative or noun phrase, no trailing period, no commit hash,
  no type prefix. A breaking change goes under `### Changed` as `- **Breaking:** …`.
- Footer links, only when `git remote get-url origin` is on github.com or gitlab.com (ssh or
  https) and the tags exist: `[Unreleased]: <web url>/compare/v<last>...HEAD`, then one
  `[x.y.z]: <web url>/compare/v<prev>...v<x.y.z>` per version, the oldest as
  `<web url>/releases/tag/v<x.y.z>` (GitHub) or `<web url>/-/tags/v<x.y.z>` (GitLab). No remote or
  no tags: no footer.

## Sources and mapping

The range is everything after the last version: the last `## [x.y.z]` heading in the file, else
the highest `v?x.y.z` tag (`semver.sh current` finds it), else the whole history.

| Source | Maps to |
|--------|---------|
| commit `feat:` | Added |
| commit `fix:` | Fixed |
| commit `perf:`, `refactor:`, `style:` | Changed |
| commit `type!:` or a `BREAKING CHANGE` footer | its group, plus `- **Breaking:** …` under Changed |
| commit `chore:`, `docs:`, `test:`, `ci:`, `build:` | Changed, but only when the user asked for housekeeping |
| commit subject that says remove/drop/delete | Removed |
| commit subject that says deprecate | Deprecated |
| commit subject that says security, CVE, vulnerability | Security |
| commit with no prefix | by its subject text, as above; else Changed |
| done item `type: bug` | Fixed |
| done item `type: feature` | Added |
| done item `type: change` | Changed (Removed/Deprecated when its title says so) |

Dropped without asking (bookkeeping): `release: set version …`, `chore: commit N changed files
before release`, merge commits, and commits that only touch `docs/todo/**`, `CHANGELOG.md` or
version files.

A fodo `done/` item whose `done_at` lies in the range (between the date of the first commit
after the range start and today, inclusive) is the better source for the change it describes: use
its `title` (and its `## Result` for detail) as the entry text and skip the commits that belong to
it (the commits touching its `files:` in that range, or whose subject matches its title). A done
item with no matching commit still gets an entry, mapped by its type. A range with no usable
commits and no done items yields no change to the file: say "nothing to add".

Entries that already exist in the file for a commit or done item in range (same subject or title,
case-insensitive) are kept as they are and the source is skipped.

## Insertion rules

- Never reorder, rewrite or delete existing lines. Only insert under `## [Unreleased]`, create
  the group headings that are missing (in the order above), or promote the Unreleased heading.
- No `## [Unreleased]` in an existing file: insert one right under the intro (before the first
  `## [` heading).
- Promotion (a new version is released): rename `## [Unreleased]` to `## [<x.y.z>] - <today>`,
  then insert a fresh, empty `## [Unreleased]` above it. When a footer exists, add the
  `[x.y.z]: …/compare/v<prev>...v<x.y.z>` line and change the base of the `[Unreleased]:` line to
  `v<x.y.z>`; that footer line is the one existing line a promotion may rewrite. The version must
  be higher than the last heading (`semver.sh next` gives candidates).
- Uncommitted work (`git status`, `git diff`) is only read when the user asks for it in the same
  run; its entries go under Unreleased like any other and are marked nowhere (the next run skips them
  because they are already in the file).

Both skills never run `git commit`, `git tag` or `git push` as part of writing the changelog;
`/fodo:commit` commits it as part of its own commit step.
