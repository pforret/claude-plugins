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
  grep -q '| B1 | .*First thing' docs/todo/busy/index.md
}
