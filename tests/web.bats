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
  # /agents: a stub claude CLI that prints $T/agents.json, and a private Claude config dir for transcripts
  export FODO_CLAUDE_BIN="$T/bin/claude"
  export CLAUDE_CONFIG_DIR="$T/cc"
  printf '#!/bin/sh\ncat "%s/agents.json"\n' "$T" > "$T/bin/claude"
  chmod +x "$T/bin/claude"
  echo '[]' > "$T/agents.json"
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

@test "start refuses a port another server already answers on" {
  mkdir -p "$T/other" && echo other > "$T/other/index.html"
  php -S "127.0.0.1:$TODO_WEB_PORT" -t "$T/other" >/dev/null 2>&1 &
  blocker=$!
  curl -s -o /dev/null --retry 10 --retry-connrefused --retry-delay 1 "http://127.0.0.1:$TODO_WEB_PORT/"
  run bash "$WEB"
  kill "$blocker" 2>/dev/null || true
  [ "$status" -eq 1 ]
  [[ "$output" == *"port $TODO_WEB_PORT is already in use"* ]]
  [ ! -f "$TODO_REGISTRY_DIR/web.pid" ]
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

SID1=11111111-1111-4111-8111-111111111111
SID2=22222222-2222-4222-8222-222222222222
SID3=33333333-3333-4333-8333-333333333333

agents_fixture() { # three sessions: interactive busy, background blocked, background done
  cat > "$T/agents.json" <<JSON
[
  {"pid":1,"cwd":"$T/repo","kind":"interactive","startedAt":1700000000000,"sessionId":"$SID1","name":"alpha-busy","status":"busy"},
  {"id":"bg2","cwd":"$T/elsewhere","kind":"bg","startedAt":1700000100000,"sessionId":"$SID2","name":"beta-blocked","state":"blocked","status":"waiting","waitingFor":"permission: Bash"},
  {"id":"bg3","cwd":"$T/elsewhere","kind":"bg","startedAt":1700000200000,"sessionId":"$SID3","name":"gamma-done","state":"done","status":"idle"}
]
JSON
}

@test "agents page lists sessions grouped by state" {
  agents_fixture
  bash "$WEB" >/dev/null
  run curl -s "http://127.0.0.1:$TODO_WEB_PORT/agents"
  [[ "$output" == *"alpha-busy"* ]]
  [[ "$output" == *"beta-blocked"* ]]
  [[ "$output" == *"gamma-done"* ]]
  [[ "$output" == *"Needs input"* ]]
  [[ "$output" == *"Working"* ]]
  [[ "$output" == *"Completed"* ]]
  [[ "$output" == *"permission: Bash"* ]]
  [ "$(code agents/)" = 301 ]
}

@test "agents page peeks at a transcript, escaped" {
  agents_fixture
  mkdir -p "$T/cc/projects/-x"
  cat > "$T/cc/projects/-x/$SID2.jsonl" <<'JSONL'
{"type":"ai-title","aiTitle":"Fix the flaky test","sessionId":"x"}
{"type":"last-prompt","lastPrompt":"why does test 3 fail?","sessionId":"x"}
{"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"It races on <b>startup</b>."},{"type":"tool_use","name":"Bash"}]}}
JSONL
  bash "$WEB" >/dev/null
  run curl -s "http://127.0.0.1:$TODO_WEB_PORT/agents?s=$SID2"
  [[ "$output" == *'class="card peek"'* ]]
  [[ "$output" == *"Fix the flaky test"* ]]
  [[ "$output" == *"why does test 3 fail?"* ]]
  [[ "$output" == *"It races on &lt;b&gt;startup&lt;/b&gt;."* ]]
  [[ "$output" == *"claude attach bg2"* ]]
}

@test "agents page survives a missing, failing or garbled claude" {
  bash "$WEB" >/dev/null
  u="http://127.0.0.1:$TODO_WEB_PORT/agents"
  [ "$(code agents)" = 200 ]
  run curl -s "$u"
  [[ "$output" == *"No Claude Code sessions running."* ]]
  printf '#!/bin/sh\necho boom >&2\nexit 1\n' > "$T/bin/claude"
  run curl -s "$u"
  [[ "$output" == *"claude agents failed (exit 1): boom"* ]]
  printf '#!/bin/sh\necho garbage\n' > "$T/bin/claude"
  run curl -s "$u"
  [[ "$output" == *"unexpected output"* ]]
  rm "$T/bin/claude"
  run curl -s "$u"
  [[ "$output" == *"claude CLI not found"* ]]
  [[ "$output" != *"Warning:"* ]]
}

@test "agents page ignores a bad or unknown session id" {
  agents_fixture
  bash "$WEB" >/dev/null
  run curl -s "http://127.0.0.1:$TODO_WEB_PORT/agents?s=../../etc/passwd"
  [[ "$output" == *"alpha-busy"* ]]
  [[ "$output" != *'class="card peek"'* ]]
  [[ "$output" != *"Warning:"* ]]
  run curl -s "http://127.0.0.1:$TODO_WEB_PORT/agents?s=44444444-4444-4444-8444-444444444444"
  [[ "$output" != *'class="card peek"'* ]]
}

@test "agents page groups by repo and shows the busy item" {
  agents_fixture
  mkdir -p "$T/repo/docs/todo/busy" "$TODO_REGISTRY_DIR"
  printf -- '---\ntitle: Ship the widget\nstatus: busy\n---\n' > "$T/repo/docs/todo/busy/2026-01-01.feature.ship-widget.md"
  echo "2026-01-01.feature.ship-widget.md" > "$T/repo/docs/todo/.current"
  printf '"path","name","registered","last_seen"\n"%s","widgetrepo","2026-01-01","2026-01-01"\n' "$T/repo" > "$TODO_REGISTRY_DIR/repos.csv"
  bash "$WEB" >/dev/null
  run curl -s "http://127.0.0.1:$TODO_WEB_PORT/agents?by=repo"
  [[ "$output" == *"widgetrepo"* ]]
  [[ "$output" == *"Ship the widget"* ]]
  [[ "$output" == *"Other folders"* ]]
}

@test "agents page uses the claude path stored by /fodo:valet when FODO_CLAUDE_BIN is unset" {
  agents_fixture
  mv "$T/bin/claude" "$T/stored-claude"          # not on PATH any more
  mkdir -p "$TODO_REGISTRY_DIR" && echo "$T/stored-claude" > "$TODO_REGISTRY_DIR/claude-bin"
  FODO_CLAUDE_BIN= bash "$WEB" >/dev/null
  run curl -s "http://127.0.0.1:$TODO_WEB_PORT/agents"
  [[ "$output" == *"alpha-busy"* ]]
  bash "$WEB" stop >/dev/null
  echo "$T/nope" > "$TODO_REGISTRY_DIR/claude-bin"   # stale path: falls back to a PATH without claude
  ln -s "$(command -v php)" "$T/bin/php"
  FODO_CLAUDE_BIN= PATH="$T/bin:/usr/bin:/bin" bash "$WEB" >/dev/null
  run curl -s "http://127.0.0.1:$TODO_WEB_PORT/agents"
  [[ "$output" == *"claude CLI not found"*"/fodo:valet"* ]]
}

kanban_fixture() { # one backlog, plan and busy item plus 12 done items in $T/repo, registered as ?repo=0
  local d="$T/repo/docs/todo" n
  mkdir -p "$d/plan" "$d/busy" "$d/done" "$d/someday" "$TODO_REGISTRY_DIR"
  printf -- '---\ntitle: Someday thing\nsize: small\nsomeday_at: 2026-01-06\n---\n' > "$d/someday/2026-01-05.feature.someday-thing.md"
  printf -- '---\ntitle: Backlog thing\nsize: small\n---\n\n# Backlog thing\n\n## Request\nPlease do the <backlog> thing.\n\n## Analysis\nnot shown\n' > "$d/2026-01-01.feature.backlog-thing.md"
  printf -- '---\ntitle: Plan thing\nsize: medium\nconfidence: 9\nplan_at: 2026-01-03\n---\n' > "$d/plan/2026-01-02.change.plan-thing.md"
  printf -- '---\ntitle: Busy thing\nsize: small\nbusy_at: 2026-01-04\n---\n' > "$d/busy/2026-01-03.bug.busy-thing.md"
  for n in 01 02 03 04 05 06 07 08 09 10 11 12; do
    printf -- '---\ntitle: Done %s\nsize: small\ndone_at: 2026-02-%s\n---\n' "$n" "$n" > "$d/done/2026-02-$n.feature.done-$n.md"
  done
  printf '"path","name","registered","last_seen"\n"%s","kanbanrepo","2026-01-01","2026-01-01"\n' "$T/repo" > "$TODO_REGISTRY_DIR/repos.csv"
}

@test "repo page shows a read-only kanban by default" {
  kanban_fixture
  bash "$WEB" >/dev/null
  run curl -s "http://127.0.0.1:$TODO_WEB_PORT/?repo=0"
  [[ "$output" == *'class="kanban"'* ]]
  [[ "$output" == *'class="overline planned">Backlog'*'class="overline plan">Plan'*'class="overline busy">Busy'* ]]
  [[ "$output" == *'>P1</mark>'* ]]
  [[ "$output" == *'>B1</mark>'* ]]
  [[ "$output" == *'9/10'* ]]
  [[ "$output" != *'<code>2026-01-01.feature.backlog-thing.md</code>'* ]]
  [[ "$output" == *'title="2026-01-01.feature.backlog-thing.md'* ]]
  [[ "$output" == *'Please do the &lt;backlog&gt; thing.'* ]]
  [[ "$output" != *'not shown'* ]]
  [[ "$output" == *'next: /fodo:start P1'* ]]
  [[ "$output" == *'next: /fodo:done B1'* ]]
  [[ "$output" == *'Table view'* ]]
  [[ "$output" != *'<form'* ]]
  [[ "$output" != *'draggable'* ]]
  [[ "$output" != *'method="post"'* ]]
  [[ "$output" != *'Done 12'* ]]   # done column only with ?all=1
}

@test "kanban caps done at 10 and links to the table" {
  kanban_fixture
  bash "$WEB" >/dev/null
  run curl -s "http://127.0.0.1:$TODO_WEB_PORT/?repo=0&all=1"
  [[ "$output" == *'class="overline done">Done <small>(12)</small>'* ]]
  [[ "$output" == *'>Done 12<'*'>Done 03<'* ]]   # newest first
  [[ "$output" != *'>Done 01<'* ]]
  [[ "$output" != *'>Done 02<'* ]]
  [[ "$output" == *'>12</mark>'* ]]               # positional ID of the newest item, as in the table view
  [[ "$output" == *'+2 older, see table view'* ]]
  [[ "$output" == *'view=table&amp;all=1'* ]]
}

@test "view=table keeps the tables and the toggle" {
  kanban_fixture
  bash "$WEB" >/dev/null
  run curl -s "http://127.0.0.1:$TODO_WEB_PORT/?repo=0&view=table"
  [[ "$output" == *'class="detail"'* ]]
  [[ "$output" == *'<code>2026-01-01.feature.backlog-thing.md</code>'* ]]
  [[ "$output" != *'class="kanban"'* ]]
  [[ "$output" == *'Kanban view'* ]]
  [[ "$output" == *'href="./?repo=0&amp;view=table&amp;all=1" class="btn">Show someday / done / skipped'* ]]
}

@test "someday shows only with all=1, as its own column" {
  kanban_fixture
  bash "$WEB" >/dev/null
  run curl -s "http://127.0.0.1:$TODO_WEB_PORT/?repo=0"
  [[ "$output" != *'Someday thing'* ]]
  [[ "$output" == *'Show someday / done / skipped'* ]]
  run curl -s "http://127.0.0.1:$TODO_WEB_PORT/?repo=0&all=1"
  [[ "$output" == *'class="overline someday">Someday <small>(1)</small>'* ]]
  [[ "$output" == *'>S1</mark>'* ]]
  [[ "$output" == *'next: /fodo:someday S1 back'* ]]
  [[ "$output" == *'parked 2026-01-06'* ]]
  run curl -s "http://127.0.0.1:$TODO_WEB_PORT/?repo=0&all=1&view=table"
  [[ "$output" == *'class="overline someday">Someday'* ]]
  [[ "$output" == *'<code>2026-01-05.feature.someday-thing.md</code>'* ]]
}
