# Todo — decisions (why things are the way they are; IDs D1, D2, …)

| ID | Status | Title |
|----|--------|-------|
| D1  | accepted | [All item tables (planned, plan, busy, someday, done, skipped) share the compact format](2026-10-28.all-item-tables-planned-plan-busy.md) |
| D2  | accepted | [fodo pick also lists busy items and resumes them with /fodo:start B<n>](2026-10-28.fodo-pick-also-lists-busy-items.md) |
| D3  | accepted | [fodo pick launches an interactive claude session, never claude -p](2026-10-28.fodo-pick-launches-an-interactive-claude.md) |
| D4  | accepted | [fodo pick prints its list and prompts on stderr, only the result on stdout](2026-10-28.fodo-pick-prints-its-list-and.md) |
| D5  | accepted | [fodo pick prints the Claude command when claude or a terminal is missing](2026-10-28.fodo-pick-prints-the-claude-command.md) |
| D6  | accepted | [fodo pick shows an fzf preview of the item file](2026-10-28.fodo-pick-shows-an-fzf-preview.md) |
| D7  | accepted | [Keep decision records inside fodo as /fodo:decide and docs/todo/decisions/, not a separate companion plugin](2026-10-28.keep-decision-records-inside-fodo-as.md) |
| D8  | accepted | [The decisions table is compact too: ID, Status, linked Title](2026-10-28.the-decisions-table-is-compact-too.md) |
| D9  | accepted | [The emoji legend is printed once by list and busy, not stored in index.md](2026-10-28.the-emoji-legend-is-printed-once.md) |
| D10 | accepted | [The ID column pads the number to at least 2 characters so rows stay aligned from 9 to 10](2026-10-28.the-id-column-pads-the-number.md) |
| D11 | accepted | [The index.md tables themselves use the compact format, one format for terminal, GitHub and MkDocs](2026-10-28.the-index-md-tables-themselves-use.md) |
| D12 | accepted | [Type and size are shown as emojis: 🐞 🔧 ✨ for type, 🟢 🟡 🔴 ❔ for size](2026-10-28.type-and-size-are-shown-as.md) |
| D13 | accepted | [A repo counts as Bash when it has a .sh file in its root or bin/ and nothing else matched](2026-10-29.a-repo-counts-as-bash-when.md) |
| D14 | accepted | [A repo with .claude-plugin/marketplace.json is a Claude marketplace project and outranks every other type](2026-10-29.a-repo-with-claude-plugin-marketplace.md) |
| D15 | accepted | [busy --all prints nothing at all when no repo has busy or plan items](2026-10-29.busy-all-prints-nothing-at-all.md) |
| D16 | accepted | [busy decides on the legend from its captured output, since busy --all renders each repo in a subshell](2026-10-29.busy-decides-on-the-legend-from.md) |
| D17 | accepted | [Dashboard tests check removed files on disk, not by expecting a 404 from the dev server](2026-10-29.dashboard-tests-check-removed-files-on.md) |
| D18 | accepted | [docs/publishing.md lists the dashboard's SVG files and is updated when icons move](2026-10-29.docs-publishing-md-lists-the-dashboard.md) |
| D19 | accepted | [Project-type icons come from Simple Icons (CC0), committed into the dashboard](2026-10-29.project-type-icons-come-from-simple.md) |
| D20 | accepted | [The dashboard also detects Flutter, iOS and Android app repos, ranked right after Laravel](2026-10-29.the-dashboard-also-detects-flutter-ios.md) |
| D21 | accepted | [The dashboard detects Laravel, PHP, Node, Python, Java, Go, Rust, Ruby and Bash repos](2026-10-29.the-dashboard-detects-laravel-php-node.md) |
| D22 | accepted | [The dashboard shows one project-type icon per repo, the most specific](2026-10-29.the-dashboard-shows-one-project-type.md) |
| D23 | accepted | [/fodo:commit estimates the semver bump from the diff and asks once before writing version files](2026-10-30.fodo-commit-estimates-the-semver-bump.md) |
| D24 | accepted | [/fodo:commit maps commit types to bumps like setver, with no bump for bookkeeping-only commits](2026-10-30.fodo-commit-maps-commit-types-to.md) |
| D25 | accepted | [/fodo:commit tags v<x.y.z> locally after a bump and never pushes](2026-10-30.fodo-commit-tags-v-x-y.md) |
| D26 | accepted | [/fodo:commit updates an existing CHANGELOG.md but never creates one](2026-10-30.fodo-commit-updates-an-existing-changelog.md) |
| D27 | accepted | [/fodo:commit writes the version into setver's file set plus every .claude-plugin/plugin.json](2026-10-30.fodo-commit-writes-the-version-into.md) |
| D28 | accepted | [ICM is investigated hands-on, by running its workspace-builder, not by desk research alone](2026-10-30.icm-is-investigated-hands-on-by.md) |
| D29 | accepted | [ICM is judged as a docs/ convention for any repo, with this repo as the test case](2026-10-30.icm-is-judged-as-a-docs.md) |
| D30 | accepted | [Only a standalone icm plugin is weighed; folding ICM into fodo is out of scope](2026-10-30.only-a-standalone-icm-plugin-is.md) |
| D31 | accepted | [The ICM investigation delivers a docs/research/icm.md page plus a decision record](2026-10-30.the-icm-investigation-delivers-a-docs.md) |
