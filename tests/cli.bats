#!/usr/bin/env bats
# Tests for plugins/fodo/scripts/cli.sh and the `fodo` command it links: temp HOME, registry and bin dirs.

setup() {
  T="$(mktemp -d)"
  T="$(cd "$T" && pwd -P)"   # macOS: /var -> /private/var, keep paths comparable
  SCRIPTS="$(cd "$BATS_TEST_DIRNAME/../plugins/fodo/scripts" && pwd)"
  C="$SCRIPTS/cli.sh"
  H="$SCRIPTS/fodo.sh"
  export HOME="$T/home"
  export TODO_REGISTRY_DIR="$T/reg"
  export TODO_LEGACY_REGISTRY="$T/legacy.tsv"
  BIN="$T/bin"
  mkdir -p "$HOME" "$BIN" "$T/sys"
  # a PATH with git and the test bin dir, without any real fodo
  ln -s "$(command -v git)" "$T/sys/git"
  export PATH="$BIN:$T/sys:/usr/bin:/bin"
  REPO="$T/repo"
  mkdir -p "$REPO/sub"
  git -C "$REPO" init -q
}

teardown() {
  [ -n "${T:-}" ] && rm -rf "$T" || true
}

@test "candidates lists writable PATH dirs, ~/.local/bin first" {
  mkdir -p "$HOME/.local/bin" "$T/ro"
  chmod a-w "$T/ro"
  PATH="$T/ro:$PATH:$HOME/.local/bin:relative/dir" run bash "$C" candidates
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "$HOME/.local/bin" ]
  [[ "$output" == *"$BIN"* ]]
  [[ "$output" != *"$T/ro"* ]]
  [[ "$output" != *"relative/dir"* ]]
  [ "$(grep -c "^$HOME/.local/bin\$" <<< "$output")" -eq 1 ]
}

@test "link creates both links and cli-bin, is idempotent, status reports it" {
  run bash "$C" link "$BIN"
  [ "$status" -eq 0 ]
  [ "$output" = "linked: $BIN/fodo" ]
  [ "$(readlink "$BIN/fodo")" = "$TODO_REGISTRY_DIR/fodo.sh" ]
  [ "$(readlink "$TODO_REGISTRY_DIR/fodo.sh")" = "$H" ]
  [ "$(cat "$TODO_REGISTRY_DIR/cli-bin")" = "$BIN/fodo" ]
  run bash "$C" link "$BIN/"
  [ "$status" -eq 0 ]
  run bash "$C" status
  [[ "$output" == "linked: $BIN/fodo"* ]]
  [[ "$output" == *"-> $H"* ]]
}

@test "fodo list via the link from a repo subdir equals fodo.sh list" {
  bash "$C" link "$BIN" >/dev/null
  (cd "$REPO" && bash "$H" init >/dev/null)
  expected=$(cd "$REPO" && bash "$H" list)
  cd "$REPO/sub"
  run fodo list
  [ "$status" -eq 0 ]
  [ "$output" = "$expected" ]
}

@test "bare fodo prints the help" {
  bash "$C" link "$BIN" >/dev/null
  cd "$REPO"
  run fodo
  [ "$status" -eq 0 ]
  [[ "$output" == *"Commands:"* ]]
  [ ! -d "$REPO/docs" ]
}

@test "fodo refuses to create docs/todo/, fodo init and fodo.sh still do" {
  bash "$C" link "$BIN" >/dev/null
  cd "$REPO"
  for c in list "busy" reindex "path 1" stale "gotcha x"; do
    # shellcheck disable=SC2086
    run fodo $c
    [ "$status" -eq 1 ]
    [[ "$output" == *"no docs/todo/ in $REPO"*"fodo init"* ]]
  done
  [ ! -d "$REPO/docs" ]
  run fodo busy --all
  [ "$status" -eq 0 ]
  run fodo init
  [ "$status" -eq 0 ]
  [ -f "$REPO/docs/todo/index.md" ]
  rm -rf "$REPO/docs"
  run bash "$H" list
  [ "$status" -eq 0 ]
  [ -f "$REPO/docs/todo/index.md" ]
}

@test "a foreign fodo is refused and left intact" {
  printf '#!/bin/sh\necho mine\n' > "$BIN/fodo"
  run bash "$C" link "$BIN"
  [ "$status" -ne 0 ]
  [[ "$output" == *"not made by fodo; not touching it"* ]]
  [ "$(cat "$BIN/fodo")" = $'#!/bin/sh\necho mine' ]
}

@test "unlink removes only our links" {
  bash "$C" link "$BIN" >/dev/null
  run bash "$C" unlink
  [ "$output" = unlinked ]
  [ ! -e "$BIN/fodo" ] && [ ! -L "$BIN/fodo" ]
  [ ! -L "$TODO_REGISTRY_DIR/fodo.sh" ]
  [ ! -f "$TODO_REGISTRY_DIR/cli-bin" ]
  run bash "$C" unlink
  [ "$output" = "not linked" ]
  echo "$BIN/fodo" > "$TODO_REGISTRY_DIR/cli-bin"
  printf 'x\n' > "$BIN/fodo"
  run bash "$C" unlink
  [ "$status" -ne 0 ]
  [ -f "$BIN/fodo" ]
}

@test "relinking into another dir removes the old link" {
  mkdir -p "$T/bin2"
  bash "$C" link "$BIN" >/dev/null
  PATH="$T/bin2:$PATH" run bash "$C" link "$T/bin2"
  [ "$status" -eq 0 ]
  [ ! -L "$BIN/fodo" ]
  [ -L "$T/bin2/fodo" ]
}

@test "a dir not on the PATH gets a hint, a dir outside HOME is not created" {
  run bash "$C" link "$HOME/.local/bin"
  [ "$status" -eq 0 ]
  [ -L "$HOME/.local/bin/fodo" ]
  [[ "$output" == *"path: $HOME/.local/bin is not on your PATH"* ]]
  run bash "$C" link "$T/nope"
  [ "$status" -ne 0 ]
  [ ! -d "$T/nope" ]
  run bash "$C" link relative/bin
  [ "$status" -ne 0 ]
}

@test "fodo.sh re-points a stale cli link, also when run through it" {
  bash "$C" link "$BIN" >/dev/null
  ln -sfn "$T/old/scripts/fodo.sh" "$TODO_REGISTRY_DIR/fodo.sh"
  (cd "$REPO" && bash "$H" list >/dev/null)
  [ "$(readlink "$TODO_REGISTRY_DIR/fodo.sh")" = "$H" ]
  # through the links: the dashboard link must point at the plugin's dashboard, not <bin>/../dashboard
  ln -sfn "$T/old/dashboard" "$TODO_REGISTRY_DIR/dashboard"
  (cd "$REPO" && fodo list >/dev/null)
  [ "$(readlink "$TODO_REGISTRY_DIR/dashboard")" = "$(cd "$SCRIPTS/../dashboard" && pwd)" ]
  [ "$(readlink "$TODO_REGISTRY_DIR/fodo.sh")" = "$H" ]
}
