#!/usr/bin/env bats
# Tests for plugins/fodo/scripts/session-start.sh (SessionStart hook), each in a fresh temporary git repo.

setup() {
  T="$(mktemp -d)"
  S="$(cd "$BATS_TEST_DIRNAME/../plugins/fodo/scripts" && pwd)"
  H="$S/session-start.sh"
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

item() { # item <dir> <filename> [title] [extra frontmatter lines]
  mkdir -p "$1"
  printf -- '---\ntitle: %s\ntype: feature\nsize: small\nstatus: busy\ncreated: 2026-10-01\n%s---\n\n# x\n' "${3:-$2}" "${4:-}" > "$1/$2"
}

@test "hooks.json declares a SessionStart command hook" {
  run cat "$S/../hooks/hooks.json"
  [ "$status" -eq 0 ]
  [[ "$output" == *'"SessionStart"'* ]]
  [[ "$output" == *'session-start.sh'* ]]
}

@test "prints nothing outside a fodo repo" {
  run bash "$H" < /dev/null
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "prints nothing when busy/ is empty" {
  mkdir -p docs/todo/busy
  run bash "$H" < /dev/null
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "lists busy items with their ids, dates and the current marker" {
  item docs/todo/busy 2026-10-02.feature.b.md "Second thing" $'busy_at: 2026-10-20\n'
  item docs/todo/busy 2026-10-01.feature.a.md "First thing" $'busy_at: 2026-10-19\nwaiting_on: "a review"\n'
  echo 2026-10-02.feature.b.md > docs/todo/.current
  run bash "$H" < /dev/null
  [ "$status" -eq 0 ]
  [[ "$output" == *"2 todo items are in progress"* ]]
  [[ "$output" == *"- B1: First thing (since 2026-10-19, waiting on: a review)"* ]]
  [[ "$output" == *"- B2: Second thing (since 2026-10-20) [current]"* ]]
}

@test "uses the cwd from the hook input and works from a subdirectory" {
  item docs/todo/busy 2026-10-01.feature.a.md "Only thing"
  mkdir -p src/deep
  cd "$T"
  run bash "$H" <<< "{\"session_id\":\"x\",\"cwd\":\"$REPO/src/deep\",\"hook_event_name\":\"SessionStart\"}"
  [ "$status" -eq 0 ]
  [[ "$output" == *"1 todo item is in progress"* ]]
  [[ "$output" == *"- B1: Only thing"* ]]
}

@test "ids match the busy index written by fodo.sh" {
  item docs/todo/busy 2026-10-02.feature.b.md "Second thing"
  item docs/todo/busy 2026-10-01.feature.a.md "First thing"
  bash "$S/fodo.sh" init >/dev/null
  run bash "$H" < /dev/null
  [[ "$output" == *"- B1: First thing"* ]]
  grep -q '| B1  | .*First thing' docs/todo/busy/index.md
}

@test "prints nothing when decisions/ is empty and busy/ is missing" {
  mkdir -p docs/todo/decisions
  run bash "$H" < /dev/null
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "prints the decisions line without any busy item" {
  mkdir -p docs/todo/decisions
  printf -- '---\ntitle: Use Valet\ndate: 2026-10-02\nstatus: accepted\n---\n' > docs/todo/decisions/2026-10-02.use-valet.md
  printf -- '---\ndate: 2026-10-01\n---\n' > docs/todo/decisions/2026-10-01.first-slug.md
  run bash "$H" < /dev/null
  [ "$status" -eq 0 ]
  [[ "$output" == "Fodo: 2 decisions are recorded in docs/todo/decisions/, last: Use Valet (2026-10-02); /fodo:show D<n> prints one"* ]]
  [[ "$output" != *"in progress"* ]]
}

@test "prints only the gotchas whose file is in the diff, before the busy items" {
  mkdir -p docs/todo/decisions src
  echo a > src/a.php; echo b > src/b.php; git add -A; git commit -qm init
  echo changed >> src/a.php            # modified, tracked
  echo new > src/c.php                 # untracked
  cat > docs/todo/decisions/gotchas.md <<'EOF'
# Gotchas

- 2026-10-01 src/a.php: the cache is append-only
- 2026-10-02 src/b.php: not touched
- 2026-10-03 src/c.php: brand new file
- 2026-10-04 a gotcha without a path
EOF
  item docs/todo/busy 2026-10-01.feature.a.md "Only thing"
  run bash "$H" < /dev/null
  [ "$status" -eq 0 ]
  [[ "$output" == *"Gotchas for files in your current diff"* ]]
  [[ "$output" == *"- 2026-10-01 src/a.php: the cache is append-only"* ]]
  [[ "$output" == *"- 2026-10-03 src/c.php: brand new file"* ]]
  [[ "$output" != *"src/b.php"* ]]
  [[ "$output" != *"without a path"* ]]
  [[ "${output%%Fodo: 1 todo item*}" == *"append-only"* ]]   # gotchas come before the busy block
  git add -A; git commit -qm all
  run bash "$H" < /dev/null
  [[ "$output" != *"Gotchas for"* ]]
}
