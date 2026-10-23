#!/usr/bin/env bats
# Tests for plugins/fodo/scripts/todo.sh, each in a fresh temporary git repo.

setup() {
  T="$(mktemp -d)"   # own temp dir: works on old bats without BATS_TEST_TMPDIR
  H="$(cd "$BATS_TEST_DIRNAME/../plugins/fodo/scripts" && pwd)/todo.sh"
  REPO="$T/repo"
  export TODO_REGISTRY_DIR="$T/reg"
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

@test "init creates the five index files" {
  run bash "$H" init
  [ "$status" -eq 0 ]
  for d in docs/todo docs/todo/plan docs/todo/busy docs/todo/done docs/todo/skipped; do
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
  [[ "${lines[3]}" == "| 1 | 2026-10-01 | bug | small | First |"* ]]
  [[ "${lines[4]}" == "| 2 | 2026-10-02 | feature | small | Second |"* ]]
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

@test "repos prune drops repos whose folder is gone" {
  bash "$H" init
  mkdir -p "$T/gone" && (cd "$T/gone" && git init -q && bash "$H" init)
  rm -rf "$T/gone"
  run bash "$H" repos prune
  [[ "$output" == *"pruned:"*"gone"* ]]
  run bash "$H" repos
  [[ "$output" != *"/gone"* ]]
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
  [[ "$output" == *"todo.sh move-file"* ]]
}

@test "output matches the /work skill helper when it is installed" {
  work="$HOME/.claude/skills/work/work.sh"
  [ -f "$work" ] || skip "work.sh not installed"
  bash "$H" init
  item docs/todo 2026-10-01.bug.a.md Alpha
  item docs/todo/plan 2026-10-02.feature.b.md Beta
  bash "$H" reindex
  plugin_out=$(bash "$H" list; bash "$H" busy)
  bash "$work" reindex
  work_out=$(bash "$work" list; bash "$work" busy)
  [ "$plugin_out" = "$work_out" ]
}

@test "parallel runs in one repo do not break the registry" {
  bash "$H" init
  for i in 1 2 3 4 5 6 7 8 9 10; do bash "$H" list >/dev/null 2>"$T/err.$i" & done
  wait
  [ -z "$(cat "$T"/err.*)" ]
  [ "$(grep -vc '^"path"' "$TODO_REGISTRY_DIR/repos.csv")" -eq 1 ]
  [ -z "$(ls "$TODO_REGISTRY_DIR" | grep tmp)" ]
}
