#!/usr/bin/env bats
# Tests for plugins/fodo/scripts/web.sh (needs php and curl).

setup() {
  command -v php >/dev/null 2>&1 || skip "php not installed"
  T="$(mktemp -d)"   # own temp dir: works on old bats without BATS_TEST_TMPDIR
  WEB="$BATS_TEST_DIRNAME/../plugins/fodo/scripts/web.sh"
  export TODO_REGISTRY_DIR="$T/reg"
  export TODO_WEB_PORT=$((20000 + RANDOM % 20000))
  # stub the browser openers so no window pops up
  mkdir -p "$T/bin"
  printf '#!/bin/sh\nexit 0\n' > "$T/bin/open"
  cp "$T/bin/open" "$T/bin/xdg-open"
  chmod +x "$T/bin/open" "$T/bin/xdg-open"
  export PATH="$T/bin:$PATH"
}

teardown() {
  [ -n "${WEB:-}" ] && bash "$WEB" stop >/dev/null 2>&1 || true
  [ -n "${T:-}" ] && rm -rf "$T" || true
}

code() { curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:$TODO_WEB_PORT/$1" || true; }

@test "start serves the dashboard and its stylesheet" {
  run bash "$WEB"
  [ "$status" -eq 0 ]
  [ "$output" = "running: http://127.0.0.1:$TODO_WEB_PORT/" ]
  [ "$(code)" = 200 ]
  [ "$(code style.css)" = 200 ]
  [ -f "$TODO_REGISTRY_DIR/web.pid" ]
}

@test "dashboard makes no external requests" {
  bash "$WEB" >/dev/null
  run curl -s "http://127.0.0.1:$TODO_WEB_PORT/"
  [[ "$output" != *"googleapis"* ]]
  [[ "$output" != *"gstatic"* ]]
}

@test "a second start reuses the running server" {
  bash "$WEB" >/dev/null
  run bash "$WEB" start
  [ "$status" -eq 0 ]
  [[ "$output" == "already running: http://127.0.0.1:$TODO_WEB_PORT/" ]]
}

@test "status reports running and not running" {
  run bash "$WEB" status
  [ "$output" = "not running" ]
  bash "$WEB" >/dev/null
  run bash "$WEB" status
  [[ "$output" == "running: http://127.0.0.1:$TODO_WEB_PORT/ (pid "* ]]
}

@test "stop stops the server and removes the pidfile" {
  bash "$WEB" >/dev/null
  run bash "$WEB" stop
  [ "$output" = "stopped" ]
  [ ! -f "$TODO_REGISTRY_DIR/web.pid" ]
  [ "$(code)" != 200 ]
  run bash "$WEB" stop
  [ "$output" = "not running" ]
}

@test "a numeric argument starts on that port" {
  port=$((TODO_WEB_PORT + 1))
  run bash "$WEB" "$port"
  [ "$output" = "running: http://127.0.0.1:$port/" ]
}

@test "a bad argument is rejected" {
  run bash "$WEB" frobnicate
  [ "$status" -eq 1 ]
}

@test "config page saves scheme and fonts, refuses other origins" {
  bash "$WEB" >/dev/null
  u="http://127.0.0.1:$TODO_WEB_PORT"
  [ "$(code config)" = 200 ]
  run curl -s -o /dev/null -w '%{http_code}' -X POST -H "Origin: http://evil.example" -d scheme=dark-mono "$u/config"
  [ "$output" = 403 ]
  [ ! -f "$TODO_REGISTRY_DIR/config.json" ]
  run curl -s -o /dev/null -w '%{http_code}' -X POST -H "Origin: $u" -d 'scheme=dark-mono&font_head=avenir&font_body=bogus' "$u/config"
  [ "$output" = 303 ]
  grep -q '"scheme": "dark-mono"' "$TODO_REGISTRY_DIR/config.json"
  grep -q '"font_head": "avenir"' "$TODO_REGISTRY_DIR/config.json"
  grep -q '"font_body": "palatino"' "$TODO_REGISTRY_DIR/config.json"
  run curl -s "$u/"
  [[ "$output" == *'data-scheme="dark-mono"'* ]]
}

@test "footer shows the plugin version" {
  bash "$WEB" >/dev/null
  v=$(sed -n 's/.*"version": *"\([^"]*\)".*/\1/p' "$BATS_TEST_DIRNAME/../plugins/fodo/.claude-plugin/plugin.json")
  run curl -s "http://127.0.0.1:$TODO_WEB_PORT/"
  [[ "$output" == *"fodo v$v"* ]]
}
