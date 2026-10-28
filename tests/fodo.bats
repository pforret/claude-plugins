#!/usr/bin/env bats
# Tests for plugins/fodo/scripts/fodo.sh, each in a fresh temporary git repo.

setup() {
  T="$(mktemp -d)"   # own temp dir: works on old bats without BATS_TEST_TMPDIR
  H="$(cd "$BATS_TEST_DIRNAME/../plugins/fodo/scripts" && pwd)/fodo.sh"
  REPO="$T/repo"
  export TODO_REGISTRY_DIR="$T/reg"
  export TODO_LEGACY_REGISTRY="$T/legacy.tsv"
  mkdir -p "$REPO"
  cd "$REPO"
  git init -q
  git config user.email t@example.com
  git config user.name t
}

teardown() {
  [ -n "${T:-}" ] && rm -rf "$T" || true
}

item() { # item <dir> <filename> [title]
  mkdir -p "$1"
  printf -- '---\ntitle: %s\ntype: feature\nsize: small\nstatus: planned\ncreated: 2026-10-01\n---\n\n# x\n' "${3:-$2}" > "$1/$2"
}

@test "init creates the seven index files" {
  run bash "$H" init
  [ "$status" -eq 0 ]
  for d in docs/todo docs/todo/plan docs/todo/busy docs/todo/done docs/todo/skipped docs/todo/someday docs/todo/decisions; do
    [ -f "$d/index.md" ]
  done
}

@test "list on an empty repo says there are no planned items" {
  run bash "$H" list
  [ "$status" -eq 0 ]
  [[ "$output" == *"_No planned items._"* ]]
}

@test "reindex numbers items by filename" {
  bash "$H" init
  item docs/todo 2026-10-02.feature.second.md Second
  item docs/todo 2026-10-01.bug.first.md First
  bash "$H" reindex
  run cat docs/todo/index.md
  [ "${lines[1]}" = "| ID | T | S | Title |" ]
  [ "${lines[3]}" = "| 1  | 🐞 | 🟢 | [First](2026-10-01.bug.first.md) |" ]
  [ "${lines[4]}" = "| 2  | ✨ | 🟢 | [Second](2026-10-02.feature.second.md) |" ]
}

@test "list keeps .md in a frontmatter title, strips it from the filename fallback" {
  bash "$H" init
  item docs/todo 2026-10-01.bug.readme-typo.md 'Fix typo in README.md'
  printf -- '---\ntype: bug\nsize: small\n---\n' > docs/todo/2026-10-02.bug.no-title.md
  bash "$H" reindex
  run bash "$H" list
  [[ "$output" == *"| [Fix typo in README.md](2026-10-01.bug.readme-typo.md) |"* ]]
  [[ "$output" == *"| [no-title](2026-10-02.bug.no-title.md) |"* ]]
}

@test "path resolves planned, plan, busy and filename ids" {
  bash "$H" init
  item docs/todo 2026-10-01.bug.a.md
  item docs/todo/plan 2026-10-02.bug.b.md
  item docs/todo/busy 2026-10-03.bug.c.md
  [ "$(bash "$H" path 1)" = "docs/todo/2026-10-01.bug.a.md" ]
  [ "$(bash "$H" path '#1')" = "docs/todo/2026-10-01.bug.a.md" ]
  [ "$(bash "$H" path P1)" = "docs/todo/plan/2026-10-02.bug.b.md" ]
  [ "$(bash "$H" path b1)" = "docs/todo/busy/2026-10-03.bug.c.md" ]
  [ "$(bash "$H" path 2026-10-02.bug.b.md)" = "docs/todo/plan/2026-10-02.bug.b.md" ]
}

@test "path fails for an unknown id" {
  bash "$H" init
  run bash "$H" path 9
  [ "$status" -ne 0 ]
  run bash "$H" path X1
  [ "$status" -ne 0 ]
}

@test "move to plan sets status and plan_at and moves the file" {
  bash "$H" init
  item docs/todo 2026-10-01.bug.a.md
  run bash "$H" move 1 plan
  [ "$status" -eq 0 ]
  [ "$output" = "docs/todo/plan/2026-10-01.bug.a.md" ]
  grep -q '^status: plan$' docs/todo/plan/2026-10-01.bug.a.md
  grep -q "^plan_at: $(date +%Y-%m-%d)$" docs/todo/plan/2026-10-01.bug.a.md
  [ ! -f docs/todo/2026-10-01.bug.a.md ]
}

@test "move uses git mv for tracked files" {
  bash "$H" init
  item docs/todo 2026-10-01.bug.a.md
  git add docs && git commit -qm init
  bash "$H" move 1 busy
  run git status --porcelain docs/todo
  [[ "$output" == *"R"?" docs/todo/2026-10-01.bug.a.md -> docs/todo/busy/2026-10-01.bug.a.md"* ]]
}

@test "moving to busy records the current item and done clears it" {
  bash "$H" init
  item docs/todo 2026-10-01.bug.a.md
  bash "$H" move-file docs/todo/2026-10-01.bug.a.md busy
  [ "$(cat docs/todo/.current)" = "2026-10-01.bug.a.md" ]
  [ "$(bash "$H" path '')" = "docs/todo/busy/2026-10-01.bug.a.md" ]
  bash "$H" move-file docs/todo/busy/2026-10-01.bug.a.md done
  [ ! -f docs/todo/.current ]
  grep -q '^status: done$' docs/todo/done/2026-10-01.bug.a.md
}

@test "current falls back to the single busy item" {
  bash "$H" init
  item docs/todo/busy 2026-10-01.bug.a.md
  [ "$(bash "$H" current)" = "docs/todo/busy/2026-10-01.bug.a.md" ]
  item docs/todo/busy 2026-10-02.bug.b.md
  run bash "$H" current
  [ "$status" -ne 0 ]
}

@test "set adds a missing field after status, then replaces it, without leftovers" {
  bash "$H" init
  item docs/todo 2026-10-01.bug.a.md
  f=docs/todo/2026-10-01.bug.a.md
  bash "$H" set "$f" confidence 7
  run sed -n '6p' "$f"
  [ "$output" = "confidence: 7" ]
  bash "$H" set "$f" confidence 9
  [ "$(grep -c '^confidence:' "$f")" -eq 1 ]
  grep -q '^confidence: 9$' "$f"
  [ ! -e "$f.tmp" ]
}

@test "set rebuilds the index, so the list shows the new value" {
  bash "$H" init
  item docs/todo 2026-10-01.bug.a.md First
  bash "$H" reindex
  bash "$H" set docs/todo/2026-10-01.bug.a.md size large
  run bash "$H" list
  [[ "$output" == *"| 1  | 🐞 | 🔴 | [First](2026-10-01.bug.a.md) |"* ]]
}

@test "reindex creates someday/ in an older docs/todo/" {
  bash "$H" init
  rm -rf docs/todo/someday
  run bash "$H" reindex
  [ "$status" -eq 0 ]
  [ -f docs/todo/someday/index.md ]
}

@test "move parks planned and plan items in someday and S<n> resolves" {
  bash "$H" init
  item docs/todo 2026-10-01.bug.a.md
  item docs/todo/plan 2026-10-02.feature.b.md
  run bash "$H" move 1 someday
  [ "$status" -eq 0 ]
  [ "$output" = "docs/todo/someday/2026-10-01.bug.a.md" ]
  grep -q '^status: someday$' docs/todo/someday/2026-10-01.bug.a.md
  grep -q '^someday_at: ' docs/todo/someday/2026-10-01.bug.a.md
  [ "$(bash "$H" path S1)" = "docs/todo/someday/2026-10-01.bug.a.md" ]
  [ "$(bash "$H" path s1)" = "docs/todo/someday/2026-10-01.bug.a.md" ]
  run bash "$H" move P1 someday
  [ "$status" -eq 0 ]
  [ "$(bash "$H" path S2)" = "docs/todo/someday/2026-10-02.feature.b.md" ]
  grep -q '| S2  |' docs/todo/someday/index.md
}

@test "move refuses parking busy items and un-parking non-someday items" {
  bash "$H" init
  item docs/todo/busy 2026-10-01.bug.a.md
  item docs/todo 2026-10-02.bug.b.md
  run bash "$H" move B1 someday
  [ "$status" -eq 1 ]
  [[ "$output" == *"only planned or plan items can be parked"* ]]
  [ -f docs/todo/busy/2026-10-01.bug.a.md ]
  run bash "$H" move 1 planned
  [ "$status" -eq 1 ]
  [[ "$output" == *"only someday or plan items can go back to planned"* ]]
}

@test "move P1 planned sends a plan item back to the backlog" {
  bash "$H" init
  item docs/todo/plan 2026-10-01.feature.a.md A
  bash "$H" set docs/todo/plan/2026-10-01.feature.a.md plan_at 2026-10-02
  run bash "$H" move P1 planned
  [ "$status" -eq 0 ]
  [ -f docs/todo/2026-10-01.feature.a.md ]
  grep -qx 'status: planned' docs/todo/2026-10-01.feature.a.md
  grep -qx 'plan_at: 2026-10-02' docs/todo/2026-10-01.feature.a.md
  [ "$(bash "$H" path 1)" = docs/todo/2026-10-01.feature.a.md ]
}

@test "move S1 planned brings it back without a date field" {
  bash "$H" init
  item docs/todo 2026-10-01.bug.a.md
  bash "$H" move 1 someday
  run bash "$H" move S1 planned
  [ "$status" -eq 0 ]
  [ "$output" = "docs/todo/2026-10-01.bug.a.md" ]
  grep -q '^status: planned$' docs/todo/2026-10-01.bug.a.md
  run grep -c '^planned_at:' docs/todo/2026-10-01.bug.a.md
  [ "$output" = 0 ]
  grep -q '^someday_at: ' docs/todo/2026-10-01.bug.a.md
  [ "$(bash "$H" path 1)" = "docs/todo/2026-10-01.bug.a.md" ]
}

@test "list shows a someday count line" {
  bash "$H" init
  item docs/todo 2026-10-01.bug.a.md
  item docs/todo 2026-10-02.bug.b.md
  run bash "$H" list
  [[ "$output" != *"in someday/"* ]]
  bash "$H" move 1 someday
  bash "$H" move 1 someday
  run bash "$H" list
  [[ "$output" == *"_2 items in someday/ (/fodo:someday to list them)._"* ]]
}

quick() { # quick <dir> <filename>: a quick item (size: unknown, only a Request)
  mkdir -p "$1"
  printf -- '---\ntitle: Quick one\ntype: change\nsize: unknown\nstatus: planned\ncreated: 2026-10-01\nfiles:\n  - (unknown)\n---\n\n# Quick one\n\n## Request\nit crashes\n' > "$1/$2"
}

@test "reindex creates decisions/ in an older docs/todo/" {
  bash "$H" init
  rm -rf docs/todo/decisions
  run bash "$H" reindex
  [ "$status" -eq 0 ]
  [ -f docs/todo/decisions/index.md ]
}

@test "decide writes a decision file, links the item and D<n> resolves" {
  bash "$H" init
  run bash "$H" decide "Use Valet for the dashboard!" --item docs/todo/busy/2026-10-28.feature.x.md --by plan
  [ "$status" -eq 0 ]
  f="docs/todo/decisions/$(date +%Y-%m-%d).use-valet-for-the-dashboard.md"
  [ "$output" = "$f" ]
  [ -f "$f" ]
  grep -q '^title: Use Valet for the dashboard!$' "$f"
  grep -q '^status: accepted$' "$f"
  grep -q '^item: 2026-10-28.feature.x.md$' "$f"
  grep -q '^recorded_by: plan$' "$f"
  for h in '## Context' '## Options considered' '## Decision' '## Consequences'; do grep -q "^$h\$" "$f"; done
  run cat docs/todo/decisions/index.md
  [[ "$output" == *"| D1  | accepted | [Use Valet for the dashboard!]($(basename "$f")) |"* ]]
  run bash "$H" path D1
  [ "$status" -eq 0 ]
  [ "$output" = "$f" ]
  run bash "$H" path d1
  [ "$output" = "$f" ]
}

@test "decide refuses an existing slug and an empty title" {
  bash "$H" decide "Keep it simple"
  run bash "$H" decide "keep it SIMPLE"
  [ "$status" -eq 1 ]
  [[ "$output" == *"exists:"* ]]
  run bash "$H" decide --by plan
  [ "$status" -eq 1 ]
  [[ "$output" == *"usage:"* ]]
}

@test "decisions index shows superseded_by and falls back to the slug as title" {
  bash "$H" init
  printf -- '---\ndate: 2026-10-01\nstatus: superseded\nsuperseded_by: 2026-10-02.new-way.md\n---\n' > docs/todo/decisions/2026-10-01.old-way.md
  run bash "$H" reindex
  run cat docs/todo/decisions/index.md
  [[ "$output" == *"| D1  | superseded → 2026-10-02.new-way.md | [old-way](2026-10-01.old-way.md) |"* ]]
}

@test "gotcha creates gotchas.md, appends dated lines and is never indexed" {
  run bash "$H" gotcha 'src/a.php: the "cache" is append-only'
  [ "$status" -eq 0 ]
  [ "$output" = docs/todo/decisions/gotchas.md ]
  bash "$H" gotcha "second one"
  run cat docs/todo/decisions/gotchas.md
  [[ "$output" == "# Gotchas"* ]]
  [[ "$output" == *"- $(date +%Y-%m-%d) src/a.php: the 'cache' is append-only"$'\n'"- $(date +%Y-%m-%d) second one" ]]
  run bash "$H" reindex
  run cat docs/todo/decisions/index.md
  [[ "$output" == *"_No decision items._"* ]]
  run bash "$H" gotcha "   "
  [ "$status" -eq 1 ]
}

@test "list shows a decisions count line" {
  bash "$H" decide "One"
  bash "$H" decide "Two"
  run bash "$H" list
  [[ "$output" == *"_2 decisions in decisions/ (/fodo:decide to list them)._"* ]]
}

@test "move refuses decisions as source or target" {
  bash "$H" decide "Stay put"
  item docs/todo 2026-10-01.feature.a.md
  run bash "$H" move D1 busy
  [ "$status" -eq 1 ]
  [[ "$output" == *"never moved"* ]]
  run bash "$H" move 1 decisions
  [ "$status" -eq 1 ]
  [ -f docs/todo/decisions/*.stay-put.md ]
}

@test "retype renames a quick item and updates its type" {
  bash "$H" init
  quick docs/todo 2026-10-01.change.quick-one.md
  git add -A && git commit -qm items
  run bash "$H" retype docs/todo/2026-10-01.change.quick-one.md bug
  [ "$status" -eq 0 ]
  [ "${lines[${#lines[@]}-1]}" = "docs/todo/2026-10-01.bug.quick-one.md" ]
  [ ! -e docs/todo/2026-10-01.change.quick-one.md ]
  grep -q '^type: bug$' docs/todo/2026-10-01.bug.quick-one.md
  [[ "$(git status --short)" == *"R"?" docs/todo/2026-10-01.change.quick-one.md -> docs/todo/2026-10-01.bug.quick-one.md"* ]]
  grep -q '2026-10-01.bug.quick-one.md' docs/todo/index.md
}

@test "retype refuses sized items, bad types and missing files" {
  bash "$H" init
  item docs/todo 2026-10-01.bug.a.md
  run bash "$H" retype docs/todo/2026-10-01.bug.a.md feature
  [ "$status" -eq 1 ]
  [[ "$output" == *"only quick items"* ]]
  quick docs/todo 2026-10-02.change.quick-one.md
  run bash "$H" retype docs/todo/2026-10-02.change.quick-one.md chore
  [ "$status" -eq 1 ]
  [[ "$output" == *"bad type: chore"* ]]
  run bash "$H" retype docs/todo/nope.md bug
  [ "$status" -eq 1 ]
  [ -e docs/todo/2026-10-02.change.quick-one.md ]
}

@test "retype to the same type is a no-op" {
  bash "$H" init
  quick docs/todo 2026-10-01.change.quick-one.md
  run bash "$H" retype docs/todo/2026-10-01.change.quick-one.md change
  [ "$status" -eq 0 ]
  [ "$output" = "docs/todo/2026-10-01.change.quick-one.md" ]
}

@test "a quick item lists with size unknown" {
  bash "$H" init
  quick docs/todo 2026-10-01.change.quick-one.md
  bash "$H" reindex
  run bash "$H" list
  [[ "$output" == *"| 1  | 🔧 | ❔ | [Quick one](2026-10-01.change.quick-one.md) |"* ]]
}

@test "registry keeps registered and updates last_seen" {
  bash "$H" init
  reg="$TODO_REGISTRY_DIR/repos.csv"
  top=$(git rev-parse --show-toplevel)
  grep -q "^\"$top\",\"repo\"," "$reg"
  sed -i.bak -E 's/,"[0-9-]+","[0-9-]+"$/,"2000-01-01","2000-01-01"/' "$reg"
  bash "$H" list >/dev/null
  run grep "^\"$top\"," "$reg"
  [[ "$output" == *'"2000-01-01","'"$(date +%Y-%m-%d)"'"' ]]
  [ "$(grep -c "^\"$top\"," "$reg")" -eq 1 ]
}

@test "the legacy todo-projects.tsv is converted once, the tsv is left alone" {
  mkdir -p "$T/old1" "$T/old2"
  printf '%s\told1\t2026-09-26\n%s\told2\t2026-10-05\n%s\tgone\t2026-10-06\n' "$T/old1" "$T/old2" "$T/gone" > "$T/legacy.tsv"
  cp "$T/legacy.tsv" "$T/legacy.orig"
  bash "$H" init
  reg="$TODO_REGISTRY_DIR/repos.csv"
  grep -q "^\"$T/old1\",\"old1\",\"2026-09-26\",\"2026-09-26\"$" "$reg"
  grep -q "^\"$T/old2\",\"old2\",\"2026-10-05\"," "$reg"
  run grep -c '/gone"' "$reg" # `! grep` would never fail the test under errexit
  [ "$output" = 0 ]
  [ -f "$TODO_REGISTRY_DIR/.legacy-imported" ]
  cmp "$T/legacy.tsv" "$T/legacy.orig"
  # later rows in the tsv are not picked up any more
  mkdir -p "$T/old3" && printf '%s\told3\t2026-10-07\n' "$T/old3" >> "$T/legacy.tsv"
  bash "$H" list >/dev/null
  run bash "$H" repos
  [ "$(grep -c "^\"$T/old1\"," "$reg")" -eq 1 ]
  [[ "$output" == *"old2"* ]]
  [[ "$output" != *"old3"* ]]
}

@test "repos prune drops repos whose folder or docs/todo is gone" {
  bash "$H" init
  mkdir -p "$T/gone" && (cd "$T/gone" && git init -q && bash "$H" init)
  rm -rf "$T/gone"
  mkdir -p "$T/notodo" && (cd "$T/notodo" && git init -q && bash "$H" init)
  rm -rf "$T/notodo/docs"
  run bash "$H" repos prune
  [[ "$output" == *"pruned:"*"gone"* ]]
  [[ "$output" == *"pruned:"*"notodo"* ]]
  run bash "$H" repos
  [[ "$output" != *"/gone"* ]]
  [[ "$output" != *"/notodo"* ]]
  [[ "$output" == *"\"$REPO\","* ]] || [[ "$output" == *"/repo\","* ]]
}

@test "busy --all lists repos with busy items and skips the others" {
  bash "$H" init
  item docs/todo/busy 2026-10-01.bug.active.md Active
  bash "$H" reindex
  other="$T/quiet"
  mkdir -p "$other" && (cd "$other" && git init -q && bash "$H" init)
  run bash "$H" busy --all
  [[ "$output" == *"## repo"* ]]
  [[ "$output" == *"Active"* ]]
  [[ "$output" != *"## quiet"* ]]
}

@test "works from a subdirectory of the repo" {
  bash "$H" init
  mkdir -p src/deep && cd src/deep
  run bash "$H" list
  [ "$status" -eq 0 ]
  [ ! -d docs ]
}

@test "unknown command exits 1, help exits 0" {
  run bash "$H" frobnicate
  [ "$status" -eq 1 ]
  run bash "$H" help
  [ "$status" -eq 0 ]
  [[ "$output" == *"fodo.sh move-file"* ]]
}

@test "parallel runs in one repo do not break the registry" {
  bash "$H" init
  for i in 1 2 3 4 5 6 7 8 9 10; do bash "$H" list >/dev/null 2>"$T/err.$i" & done
  wait
  [ -z "$(cat "$T"/err.*)" ]
  [ "$(grep -vc '^"path"' "$TODO_REGISTRY_DIR/repos.csv")" -eq 1 ]
  [ -z "$(ls "$TODO_REGISTRY_DIR" | grep tmp)" ]
}

@test "set keeps special characters and leaves the body alone" {
  bash "$H" init
  item docs/todo 2026-10-01.feature.a.md A
  printf 'status: body line\ntitle: body title\n' >> docs/todo/2026-10-01.feature.a.md
  run bash "$H" set docs/todo/2026-10-01.feature.a.md title 'a | b & c \ d / e'
  [ "$status" -eq 0 ]
  grep -qxF 'title: a | b & c \ d / e' docs/todo/2026-10-01.feature.a.md
  grep -qx 'status: body line' docs/todo/2026-10-01.feature.a.md
  grep -qx 'title: body title' docs/todo/2026-10-01.feature.a.md
  [ ! -e docs/todo/2026-10-01.feature.a.md.tmp ]
}

@test "unset removes a frontmatter field only" {
  bash "$H" init
  item docs/todo 2026-10-01.feature.a.md A
  printf 'size: in the body\n' >> docs/todo/2026-10-01.feature.a.md
  run bash "$H" unset docs/todo/2026-10-01.feature.a.md size
  [ "$status" -eq 0 ]
  [ "$(grep -c '^size:' docs/todo/2026-10-01.feature.a.md)" = 1 ]
  grep -qx 'size: in the body' docs/todo/2026-10-01.feature.a.md
}

@test "wait marks a busy item, the busy table shows it, resume clears it" {
  bash "$H" init
  item docs/todo/busy 2026-10-01.bug.blocked.md Blocked
  f=docs/todo/busy/2026-10-01.bug.blocked.md
  run bash "$H" wait "$f" 'PR #12 | review "now"'
  [ "$status" -eq 0 ]
  today=$(date +%Y-%m-%d)
  grep -qxF "waiting_on: \"PR #12 | review 'now'\"" "$f"
  grep -qx "waiting_since: $today" "$f"
  [ "$(sed -n '/^status:/{n;p;}' "$f")" = "waiting_on: \"PR #12 | review 'now'\"" ]
  grep -q '| ID | T | S | Title |' docs/todo/busy/index.md
  grep -qF "| B1  | 🐞 | 🟢 | [Blocked](2026-10-01.bug.blocked.md) ⏸ PR #12 \\| review 'now' (since $today) |" docs/todo/busy/index.md
  run bash "$H" busy
  [[ "$output" == *"⏸ PR #12"* ]]
  run bash "$H" resume "$f"
  [ "$status" -eq 0 ]
  ! grep -q '^waiting_' "$f"
  grep -qF '| B1  | 🐞 | 🟢 | [Blocked](2026-10-01.bug.blocked.md) |' docs/todo/busy/index.md
}

@test "wait refuses items that are not busy and an empty reason" {
  bash "$H" init
  item docs/todo 2026-10-01.feature.a.md A
  run bash "$H" wait docs/todo/2026-10-01.feature.a.md "some reason"
  [ "$status" -ne 0 ] && [[ "$output" == *"only busy items can wait"* ]]
  ! grep -q '^waiting_' docs/todo/2026-10-01.feature.a.md
  item docs/todo/busy 2026-10-02.feature.b.md B
  run bash "$H" wait docs/todo/busy/2026-10-02.feature.b.md "   "
  [ "$status" -ne 0 ] && [[ "$output" == *"usage"* ]]
}

@test "moving a waiting item to done drops the waiting fields" {
  bash "$H" init
  item docs/todo/busy 2026-10-01.bug.blocked.md Blocked
  bash "$H" wait docs/todo/busy/2026-10-01.bug.blocked.md upstream fix
  run bash "$H" move B1 done
  [ "$status" -eq 0 ]
  ! grep -q '^waiting_' docs/todo/done/2026-10-01.bug.blocked.md
  grep -qx 'status: done' docs/todo/done/2026-10-01.bug.blocked.md
}

stale_item() { # stale_item <dir> <filename> <status> <extra frontmatter lines...>
  mkdir -p "$1"
  { printf -- '---\ntitle: %s\ntype: feature\nsize: small\nstatus: %s\n' "$2" "$3"; shift 3; printf '%s\n' "$@"; printf -- '---\n\n# x\n'; } > "$1/$2"
}
old_commit() { # old_commit <path>  commit a file with a 2020 date
  mkdir -p "$(dirname "$1")"; echo "v$RANDOM" >> "$1"; git add "$1"
  GIT_AUTHOR_DATE="2020-01-05T12:00:00" GIT_COMMITTER_DATE="2020-01-05T12:00:00" git commit -qm "old $1"
}
new_commit() { mkdir -p "$(dirname "$1")"; echo "v$RANDOM" >> "$1"; git add "$1"; git commit -qm "new $1"; }

@test "stale on fresh items says nothing is stale" {
  bash "$H" init
  today=$(date +%Y-%m-%d)
  stale_item docs/todo 2026-10-01.feature.a.md planned "created: $today"
  stale_item docs/todo/busy 2026-10-02.feature.b.md busy "created: $today" "busy_at: $today"
  stale_item docs/todo/plan 2026-10-03.feature.c.md plan "created: $today" "plan_at: $today"
  run bash "$H" stale
  [ "$status" -eq 0 ]
  [ "$output" = "_Nothing stale._" ]
}

@test "stale flags old planned items and reviewed: resets the clock" {
  bash "$H" init
  stale_item docs/todo 2026-10-01.feature.a.md planned "created: 2020-01-01"
  run bash "$H" stale
  [ "$status" -eq 0 ]
  [[ "${lines[0]}" == "| ID | Stage | Why flagged | File |" ]]
  [[ "$output" == *"| 1 | planned | planned "*" days ago | docs/todo/2026-10-01.feature.a.md |"* ]]
  bash "$H" set docs/todo/2026-10-01.feature.a.md reviewed "$(date +%Y-%m-%d)"
  run bash "$H" stale
  [ "$output" = "_Nothing stale._" ]
  bash "$H" set docs/todo/2026-10-01.feature.a.md reviewed 2021-01-01
  run bash "$H" stale
  [[ "$output" == *"| 1 | planned | reviewed "*" days ago |"* ]]
}

@test "stale --planned changes the threshold and falls back to the filename date" {
  bash "$H" init
  printf -- '---\ntitle: a\ntype: bug\nsize: small\nstatus: planned\n---\n' > docs/todo/2020-01-01.bug.a.md
  run bash "$H" stale
  [[ "$output" == *"| 1 | planned |"* ]]
  run bash "$H" stale --planned 100000
  [ "$output" = "_Nothing stale._" ]
}

@test "stale flags plan items whose files changed after plan_at" {
  bash "$H" init
  stale_item docs/todo/plan 2026-10-01.feature.a.md plan "created: 2020-01-01" "plan_at: 2020-01-01" "files:" "  - src/a.txt" "  - src/new.txt"
  run bash "$H" stale
  [ "$output" = "_Nothing stale._" ]            # no commits at all
  new_commit src/other.txt
  run bash "$H" stale
  [ "$output" = "_Nothing stale._" ]            # unlisted file
  new_commit src/a.txt
  run bash "$H" stale
  [[ "$output" == *"| P1 | plan | 1 commit to its files since 2020-01-01 | docs/todo/plan/2026-10-01.feature.a.md |"* ]]
  new_commit src/a.txt
  run bash "$H" stale
  [[ "$output" == *"| P1 | plan | 2 commits to its files"* ]]
  bash "$H" set docs/todo/plan/2026-10-01.feature.a.md plan_at "$(date +%Y-%m-%d)"
  run bash "$H" stale
  [ "$output" = "_Nothing stale._" ]            # planned today: today's commits do not count
}

@test "stale flags busy items without recent activity and shows the waiting reason" {
  bash "$H" init
  old_commit src/b.txt
  stale_item docs/todo/busy 2026-10-01.feature.b.md busy "created: 2020-01-01" "busy_at: 2020-01-01" "files:" "  - src/b.txt"
  run bash "$H" stale
  [[ "$output" == *"| B1 | busy | no activity for "*" days (last: 2020-01-05) | docs/todo/busy/2026-10-01.feature.b.md |"* ]]
  bash "$H" wait docs/todo/busy/2026-10-01.feature.b.md 'client | answer'
  run bash "$H" stale
  [[ "$output" == *"— waiting on: client \\| answer |"* ]]
  run bash "$H" stale --busy 100000
  [ "$output" = "_Nothing stale._" ]
  new_commit src/b.txt
  run bash "$H" stale
  [ "$output" = "_Nothing stale._" ]
}

@test "stale tolerates missing files: and paths that never existed" {
  bash "$H" init
  stale_item docs/todo/busy 2026-10-01.feature.b.md busy "created: 2020-01-01" "busy_at: 2020-01-01"
  stale_item docs/todo/plan 2026-10-02.feature.c.md plan "created: 2020-01-01" "plan_at: 2020-01-01" "files:" "  - does/not/exist.txt" "  - (unknown)"
  run bash "$H" stale
  [ "$status" -eq 0 ]
  [[ "$output" == *"| B1 | busy | no activity for "*" (last: 2020-01-01)"* ]]
  [[ "$output" != *"| P1 |"* ]]
}

@test "stale rejects a bad threshold" {
  bash "$H" init
  run bash "$H" stale --busy abc
  [ "$status" -eq 1 ]
  [[ "$output" == *"usage: fodo.sh stale"* ]]
  run bash "$H" stale --bogus
  [ "$status" -eq 1 ]
}

pick_fixture() { # backlog 1, plan P1 (confidence 9), busy B1 (waiting), and a stub claude that must never run
  bash "$H" init >/dev/null
  item docs/todo 2026-10-01.feature.backlog-one.md 'Backlog one'
  item docs/todo/plan 2026-10-02.feature.plan-one.md 'Plan one'
  bash "$H" set docs/todo/plan/2026-10-02.feature.plan-one.md confidence 9 >/dev/null
  item docs/todo/busy 2026-10-03.bug.busy-one.md 'Busy one'
  bash "$H" set docs/todo/busy/2026-10-03.bug.busy-one.md waiting_on 'the PR review' >/dev/null
  mkdir -p "$T/stub"
  printf '#!/bin/sh\ntouch "%s/claude-ran"\n' "$T" > "$T/stub/claude"
  chmod +x "$T/stub/claude"
  export PATH="$T/stub:$PATH"
}

@test "pick with no items says there is nothing to pick" {
  bash "$H" init >/dev/null
  run bash "$H" pick < /dev/null
  [ "$status" -eq 0 ]
  [[ "$output" == *"nothing to pick"* ]]
}

@test "pick lists backlog, plan and busy items in that order" {
  pick_fixture
  run bash "$H" pick < /dev/null
  [ "$status" -eq 0 ]
  [[ "${lines[0]}" == *"1) 1"*"Backlog one"* ]]
  [[ "${lines[1]}" == *"2) P1"*"9/10 Plan one"* ]]
  [[ "${lines[2]}" == *"3) B1"*"⏸ the PR review Busy one"* ]]
  [[ "$output" == *"cancelled"* ]]
  [ ! -e "$T/claude-ran" ]
}

@test "pick hands plan and busy items to /fodo:start without asking" {
  pick_fixture
  run bash "$H" pick <<< "2"
  [ "$status" -eq 0 ]
  [ "${lines[${#lines[@]}-1]}" = "Run in Claude Code: /fodo:start P1" ]
  run bash "$H" pick <<< "3"
  [ "${lines[${#lines[@]}-1]}" = "Run in Claude Code: /fodo:start B1" ]
  [ ! -e "$T/claude-ran" ]
}

@test "pick asks plan or start for a backlog item" {
  pick_fixture
  run bash "$H" pick <<< $'1\np'
  [ "$status" -eq 0 ]
  [[ "$output" == *"Item 1: [p]lan or [s]tart?"* ]]
  [ "${lines[${#lines[@]}-1]}" = "Run in Claude Code: /fodo:plan 1" ]
  run bash "$H" pick <<< $'1\nstart'
  [ "${lines[${#lines[@]}-1]}" = "Run in Claude Code: /fodo:start 1" ]
  run bash "$H" pick <<< $'1\n'
  [ "${lines[${#lines[@]}-1]}" = "cancelled" ]
  [ ! -e "$T/claude-ran" ]
}

@test "pick cancels on q, a bad or an out-of-range answer" {
  pick_fixture
  for a in q x 9; do
    run bash "$H" pick <<< "$a"
    [ "$status" -eq 0 ]
    [[ "$output" != *"Run in Claude Code"* ]]
    [ "${lines[${#lines[@]}-1]}" = "cancelled" ]
  done
  run bash "$H" pick <<< "9"
  [[ "$output" == *"no item 9"* ]]
}

@test "help lists pick" {
  run bash "$H" help
  [[ "$output" == *"fodo.sh pick"* ]]
}

@test "index rows: plan confidence, unknown type, escaped title, long title on one row, 2-wide IDs" {
  bash "$H" init
  item docs/todo/plan 2026-10-01.feature.p.md 'Plan me'
  bash "$H" set docs/todo/plan/2026-10-01.feature.p.md confidence 9 >/dev/null
  bash "$H" set docs/todo/plan/2026-10-01.feature.p.md size medium >/dev/null
  item docs/todo 2026-10-01.chore.odd.md 'Pipe | and [bracket] title'
  long=$(printf 'word%.0s ' $(seq 1 30))
  item docs/todo 2026-10-02.bug.long.md "$long"
  for i in $(seq 3 10); do item docs/todo "2026-10-$(printf %02d "$i").bug.n$i.md" "n$i"; done
  bash "$H" reindex
  grep -qxF '| ID | T | S | Conf | Title |' docs/todo/plan/index.md
  grep -qxF '| P1  | ✨ | 🟡 | 9/10 | [Plan me](2026-10-01.feature.p.md) |' docs/todo/plan/index.md
  grep -qxF '| 1  | ❔ | 🟢 | [Pipe \| and [bracket\] title](2026-10-01.chore.odd.md) |' docs/todo/index.md
  [ "$(grep -c 'word word' docs/todo/index.md)" -eq 1 ]
  grep -q '^| 9  | ' docs/todo/index.md
  grep -q '^| 10 | ' docs/todo/index.md
}

@test "list and busy print the legend once, an empty repo none" {
  legend='_🐞 bug · 🔧 change · ✨ feature — 🟢 small · 🟡 medium · 🔴 large · ❔ not sized_'
  bash "$H" init
  run bash "$H" list
  [[ "$output" != *"🐞 bug"* ]]
  run bash "$H" busy
  [[ "$output" != *"🐞 bug"* ]]
  item docs/todo 2026-10-01.bug.a.md A
  item docs/todo/plan 2026-10-02.bug.b.md B
  item docs/todo/busy 2026-10-03.bug.c.md C
  bash "$H" reindex
  run bash "$H" list
  [ "$(grep -cxF "$legend" <<< "$output")" -eq 1 ]
  [ "${lines[${#lines[@]}-1]}" = "$legend" ]
  run bash "$H" busy
  [ "$(grep -cxF "$legend" <<< "$output")" -eq 1 ]
  run bash "$H" busy --all
  [ "$(grep -cxF "$legend" <<< "$output")" -eq 1 ]
  ! grep -q '🐞 bug' docs/todo/index.md docs/todo/plan/index.md docs/todo/busy/index.md
}
