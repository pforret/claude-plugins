#!/usr/bin/env bash
# Dashboard server for the fodo Claude Code plugin (/fodo:web).
# Serves the plugin's dashboard/ folder with PHP's built-in server on 127.0.0.1 only.
#
# Usage:
#   web.sh [start] [port]   start in the background (default port $TODO_WEB_PORT or 7787); reuses a running server
#   web.sh <port>           same as start <port>
#   web.sh stop             stop the server
#   web.sh status           print whether it runs and where
#
# State (pid, port, log) lives next to the registry in ${TODO_REGISTRY_DIR:-~/.claude/todo}.
set -euo pipefail

DIR="$(cd "$(dirname "$0")/../dashboard" && pwd)"
STATE="${TODO_REGISTRY_DIR:-}"
[ -n "$STATE" ] || STATE="$HOME/.claude/todo"
PIDFILE="$STATE/web.pid"
PORTFILE="$STATE/web.port"
LOG="$STATE/web.log"

running_pid() { # prints the pid of a live server, or nothing
  local pid
  [ -f "$PIDFILE" ] || return 0
  pid=$(cat "$PIDFILE")
  if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then echo "$pid"; fi
  return 0
}

url() { echo "http://127.0.0.1:$1/"; }

open_browser() { # never fails the caller
  if command -v open >/dev/null 2>&1; then open "$1" >/dev/null 2>&1 || true
  elif command -v xdg-open >/dev/null 2>&1; then xdg-open "$1" >/dev/null 2>&1 || true
  fi
}

start() {
  local port="${1:-}" pid
  # after a plugin update, re-point the /fodo:valet link at this version's dashboard
  if [ -L "$STATE/dashboard" ] && [ "$(readlink "$STATE/dashboard")" != "$DIR" ]; then ln -sfn "$DIR" "$STATE/dashboard"; fi
  [ -n "$port" ] || port="${TODO_WEB_PORT:-7787}"
  case "$port" in ''|*[!0-9]*) echo "bad port: $port" >&2; exit 1 ;; esac
  pid=$(running_pid)
  if [ -n "$pid" ]; then
    echo "already running: $(url "$(cat "$PORTFILE" 2>/dev/null || echo "$port")")"
    return 0
  fi
  command -v php >/dev/null 2>&1 || { echo "php not found; install PHP 8.1+ to use the dashboard" >&2; exit 1; }
  mkdir -p "$STATE"
  nohup php -S "127.0.0.1:$port" -t "$DIR" >"$LOG" 2>&1 &
  echo $! > "$PIDFILE"
  echo "$port" > "$PORTFILE"
  if ! curl -s -o /dev/null --retry 10 --retry-connrefused --retry-delay 1 "$(url "$port")"; then
    echo "dashboard did not start on port $port; log:" >&2
    tail -n 5 "$LOG" >&2 || true
    stop >/dev/null
    exit 1
  fi
  echo "running: $(url "$port")"
  open_browser "$(url "$port")"
}

stop() {
  local pid
  pid=$(running_pid)
  if [ -n "$pid" ]; then
    kill "$pid" 2>/dev/null || true
    echo "stopped"
  else
    echo "not running"
  fi
  rm -f "$PIDFILE" "$PORTFILE"
}

status() {
  local pid
  pid=$(running_pid)
  if [ -n "$pid" ]; then echo "running: $(url "$(cat "$PORTFILE" 2>/dev/null || echo '?')") (pid $pid)"
  else echo "not running"; fi
}

cmd="${1:-start}"
case "$cmd" in
  start) start "${2:-}" ;;
  stop) stop ;;
  status) status ;;
  -h|--help|help) sed -n '5,9p' "$0" | sed 's/^# \{0,1\}//' ;;
  *[!0-9]*) echo "unknown command: $cmd (use start [port], stop, status)" >&2; exit 1 ;;
  *) start "$cmd" ;;
esac
