---
name: changelog
description: '[this repo] Create CHANGELOG.md (Keep a Changelog 1.1.0) when the repo has none, or add the changes since the last version under Unreleased, grouped into Added, Changed, Deprecated, Removed, Fixed and Security, from the commits in range and the fodo done/ items completed in it. Optionally promotes Unreleased to a new version heading. Asks a few questions, shows the diff, never commits. Use when asked to "write the changelog", "update CHANGELOG.md", "create a changelog", "what changed since the last release" or "release notes".'
argument-hint: ""
---

Helpers: `bash "${CLAUDE_PLUGIN_ROOT}/scripts/fodo.sh"` (below `fodo.sh`) and
`bash "${CLAUDE_PLUGIN_ROOT}/scripts/semver.sh"` (below `semver.sh`), run from the repo root.
Read `${CLAUDE_PLUGIN_ROOT}/reference/conventions.md` for the rules and
`${CLAUDE_PLUGIN_ROOT}/reference/changelog.md` for the file format, the source mapping and the
insertion rules; this skill is the flow, the reference is the law.

Arguments: none; everything is asked below. $ARGUMENTS

## CHANGELOG

1. **Mode.** `CHANGELOG.md` at the repo root (`git rev-parse --show-toplevel`) exists → *update*;
   else → *create*. Not a git repo: say so and stop.

2. **Range.** Update: the last `## [x.y.z]` heading in the file is the range start (`v<x.y.z>`
   when that tag exists, else the commit of the release line `release: set version to x.y.z`, else
   the date of the heading as `--since`). Create, or no version heading: `semver.sh current` and
   its tag; `0.0.0` means the whole history. Collect, in that order:
   - commits: `git log --no-merges --date=short --format='%h%x09%ad%x09%s' <start>..HEAD`
     (whole history: drop `<start>..`), each with `git show --stat --format= <hash>` only when the
     subject is not self-explanatory;
   - done items: `docs/todo/done/*.md` whose `done_at` is between the date of the first commit in
     range and today (`grep -l '^done_at:'`, read `title`, `type`, `files:` and `## Result`);
   - tags, for back-fill and the footer: `git tag --list 'v[0-9]*' --sort=version:refname` with
     `git log -1 --format=%ad --date=short <tag>`.
   Apply the bookkeeping filter and the done-item merge from the reference before asking anything,
   so the questions can say how many entries there are.

3. **Ask once** (one AskUserQuestion call, only the questions that apply, each with the
   recommended option first):
   - *create only:* "Back-fill history?" → "Unreleased only (Recommended)" | "One section per tag
     (<n> tags)". With more than 20 tags the recommendation is Unreleased only and the description
     says why (a long back-fill is slow and mostly bookkeeping).
   - *when the range has `chore`/`docs`/`refactor`/`test`/`ci`/`build` commits:* "Include <n>
     housekeeping commits?" → "No (Recommended)" | "Yes".
   - *when `git status --porcelain` is not empty:* "Include the <n> uncommitted changes?" →
     "No (Recommended)" | "Yes (read git diff)".
   - *always:* "Release the Unreleased section as a version?" → "Leave under Unreleased
     (Recommended)" | `<next patch>` | `<next minor>` | `<next major>` from `semver.sh next`;
     the description names today's date. Choosing a version does not touch version files, tags or
     commits; that is `/fodo:commit`'s job.
   Nothing to add (no commits, no done items, no uncommitted work selected): say "nothing to add
   since <range start>" and stop, without writing anything, unless the file does not exist yet.

4. **Write.** Create mode: the full file from the reference's format section, with the selected
   back-fill sections and the footer when the remote allows it. Update mode: insert only, per the
   insertion rules; promote when a version was chosen. Entry text: the done item's title when it
   has one, else the commit subject without its type prefix, reworded to one plain line; in a repo
   with several plugins or packages name the one the change belongs to. Keep every existing line
   byte-identical.

5. **Report.** `git diff --stat -- CHANGELOG.md` (or "created CHANGELOG.md, <n> lines") and the
   inserted block verbatim. End with: "Review the diff; `/fodo:commit` commits it." Never say to
   run `bin/release.sh`.

Guardrails: never `git commit`, `git tag`, `git push` or `git add`; never run `bin/release.sh` or
`semver.sh set`/`tag`; never reorder, rewrite or delete an existing changelog line (the `[Unreleased]:` footer link on a
promotion is the only exception); never write an
empty group heading; never write anywhere but the root `CHANGELOG.md`.
