#!/usr/bin/env bats
# Tests for plugins/fodo/scripts/valet.sh: a fake Valet home, stub `valet` and `claude`, no real Valet touched.

setup() {
  command -v php >/dev/null 2>&1 || skip "php not installed"
  T="$(mktemp -d)"
  SCRIPTS="$(cd "$BATS_TEST_DIRNAME/../plugins/fodo/scripts" && pwd)"
  V="$SCRIPTS/valet.sh"
  DASH="$(cd "$SCRIPTS/../dashboard" && pwd)"
  export HOME="$T/home"
  export TODO_REGISTRY_DIR="$T/reg"
  export FODO_VALET_HOME="$T/valet"
  mkdir -p "$HOME" "$T/bin" "$FODO_VALET_HOME/Sites"
  # a PATH with php and git but without the real valet/claude
  ln -s "$(command -v php)" "$T/bin/php"
  printf '#!/bin/sh\nexit 0\n' > "$T/bin/valet"
  printf '#!/bin/sh\necho "[]"\n' > "$T/bin/claude"
  chmod +x "$T/bin/valet" "$T/bin/claude"
  export PATH="$T/bin:/usr/bin:/bin"
  valet_config test
}

teardown() {
  [ -n "${T:-}" ] && rm -rf "$T" || true
}

valet_config() { # valet_config <tld> [sites-path]
  printf '{"tld": "%s", "paths": ["%s"]}\n' "$1" "${2:-$FODO_VALET_HOME/Sites}" > "$FODO_VALET_HOME/config.json"
}

@test "link creates the site and the stable link, stores claude, prints the url" {
  run bash "$V"
  [ "$status" -eq 0 ]
  [[ "$output" == *"linked: http://fodo.test/"* ]]
  [[ "$output" == *"valet secure fodo"* ]]
  [ "$(readlink "$FODO_VALET_HOME/Sites/fodo")" = "$TODO_REGISTRY_DIR/dashboard" ]
  [ "$(readlink "$TODO_REGISTRY_DIR/dashboard")" = "$DASH" ]
  [ "$(cat "$TODO_REGISTRY_DIR/claude-bin")" = "$T/bin/claude" ]
  [ -f "$FODO_VALET_HOME/Sites/fodo/index.php" ]
}

@test "link is idempotent, status reports it, unlink removes everything" {
  bash "$V" >/dev/null
  run bash "$V" link
  [ "$status" -eq 0 ]
  run bash "$V" status
  [[ "$output" == "linked: http://fodo.test/"* ]]
  [[ "$output" == *"claude: $T/bin/claude"* ]]
  run bash "$V" unlink
  [ "$output" = unlinked ]
  [ ! -e "$FODO_VALET_HOME/Sites/fodo" ] && [ ! -L "$TODO_REGISTRY_DIR/dashboard" ] && [ ! -f "$TODO_REGISTRY_DIR/claude-bin" ]
  run bash "$V" status
  [ "$output" = "not linked" ]
}

@test "without Valet it points at /fodo:web" {
  rm "$T/bin/valet" "$FODO_VALET_HOME/config.json"
  run bash "$V"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Laravel Valet not found"*"/fodo:web"* ]]
  [ ! -e "$FODO_VALET_HOME/Sites/fodo" ]
}

@test "an existing fodo site elsewhere is left alone" {
  mkdir -p "$T/other"
  ln -s "$T/other" "$FODO_VALET_HOME/Sites/fodo"
  run bash "$V"
  [ "$status" -eq 1 ]
  [[ "$output" == *"already a Valet site pointing at $T/other"* ]]
  [ "$(readlink "$FODO_VALET_HOME/Sites/fodo")" = "$T/other" ]
  run bash "$V" unlink
  [ "$status" -eq 1 ]
  [ -L "$FODO_VALET_HOME/Sites/fodo" ]
}

@test "a Sites folder that Valet does not serve gives the manual command" {
  valet_config test "$T/elsewhere"
  run bash "$V"
  [ "$status" -eq 1 ]
  [[ "$output" == *"valet link fodo"* ]]
  [ ! -e "$FODO_VALET_HOME/Sites/fodo" ]
}

@test "the tld comes from the Valet config, https when a certificate exists" {
  valet_config localhost
  run bash "$V"
  [[ "$output" == *"linked: http://fodo.localhost/"* ]]
  mkdir -p "$FODO_VALET_HOME/Certificates" && touch "$FODO_VALET_HOME/Certificates/fodo.localhost.crt"
  run bash "$V" status
  [[ "$output" == "linked: https://fodo.localhost/"* ]]
}

@test "an old todolist link into the todo skill is reported and removed on request only" {
  mkdir -p "$HOME/.claude/skills/todo/web"
  ln -s "$HOME/.claude/skills/todo/web" "$FODO_VALET_HOME/Sites/todolist"
  run bash "$V"
  [[ "$output" == *"todolist: http://todolist.test/"* ]]
  [ -L "$FODO_VALET_HOME/Sites/todolist" ]
  run bash "$V" unlink-todolist
  [ "$status" -eq 0 ]
  [ ! -e "$FODO_VALET_HOME/Sites/todolist" ]
  mkdir -p "$T/mine" && ln -s "$T/mine" "$FODO_VALET_HOME/Sites/todolist"
  run bash "$V" unlink-todolist
  [ "$status" -eq 1 ]
  [ -L "$FODO_VALET_HOME/Sites/todolist" ]
}

@test "fodo.sh and web.sh re-point the stable link after an update, and create none without it" {
  git init -q "$T/repo"
  cd "$T/repo"
  bash "$SCRIPTS/fodo.sh" list >/dev/null
  [ ! -e "$TODO_REGISTRY_DIR/dashboard" ]
  mkdir -p "$T/old" && ln -sfn "$T/old" "$TODO_REGISTRY_DIR/dashboard"
  bash "$SCRIPTS/fodo.sh" list >/dev/null
  [ "$(readlink "$TODO_REGISTRY_DIR/dashboard")" = "$DASH" ]
  ln -sfn "$T/old" "$TODO_REGISTRY_DIR/dashboard"
  TODO_WEB_PORT=$((20000 + RANDOM % 20000)) bash "$SCRIPTS/web.sh" status >/dev/null
  [ "$(readlink "$TODO_REGISTRY_DIR/dashboard")" = "$T/old" ]   # status does not touch it
  printf '#!/bin/sh\nexit 0\n' > "$T/bin/open"; chmod +x "$T/bin/open"
  TODO_WEB_PORT=$((20000 + RANDOM % 20000)) bash "$SCRIPTS/web.sh" start >/dev/null
  bash "$SCRIPTS/web.sh" stop >/dev/null
  [ "$(readlink "$TODO_REGISTRY_DIR/dashboard")" = "$DASH" ]
}
