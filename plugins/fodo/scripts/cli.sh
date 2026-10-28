#!/usr/bin/env bash
# `fodo` command for the fodo Claude Code plugin (/fodo:cli): run "fodo list" etc. in any repo terminal.
# Never runs sudo and never edits shell profiles.
#
# Usage:
#   cli.sh candidates        print the writable directories on the PATH, ~/.local/bin and ~/bin first
#   cli.sh link <dir>        link <dir>/fodo (idempotent; replaces only a link made by fodo)
#   cli.sh status            print whether it is linked and where
#   cli.sh unlink            remove the fodo command
#
# Links: <dir>/fodo -> ~/.claude/todo/fodo.sh -> <plugin>/scripts/fodo.sh (re-pointed by fodo.sh/web.sh
# after plugin updates). ~/.claude/todo/cli-bin holds the absolute path of the installed <dir>/fodo.
set -euo pipefail

SH="$(cd "$(dirname "$0")" && pwd)/fodo.sh"
STATE="${TODO_REGISTRY_DIR:-}"
[ -n "$STATE" ] || STATE="$HOME/.claude/todo"
STABLE="$STATE/fodo.sh"
BINFILE="$STATE/cli-bin"

die() { echo "$*" >&2; exit 1; }

ours() { # ours <file>  -> true when <file> is a link to the stable fodo.sh link
  [ -L "$1" ] && [ "$(readlink "$1")" = "$STABLE" ]
}

on_path() { # on_path <dir>
  case ":$PATH:" in *":$1:"*) return 0 ;; esac
  return 1
}

installed() { # path of the installed fodo command, or nothing
  [ -f "$BINFILE" ] && cat "$BINFILE"
  return 0
}

candidates() {
  local d seen=":"
  for d in "$HOME/.local/bin" "$HOME/bin"; do
    on_path "$d" || continue
    [ -d "$d" ] && [ -w "$d" ] || continue
    echo "$d"; seen="$seen$d:"
  done
  local IFS=:
  for d in $PATH; do
    case "$d" in /*) ;; *) continue ;; esac
    case "$seen" in *":$d:"*) continue ;; esac
    [ -d "$d" ] && [ -w "$d" ] || continue
    echo "$d"; seen="$seen$d:"
  done
  return 0
}

link() {
  local dir="${1:-}" bin old other
  [ -n "$dir" ] || die "usage: cli.sh link <dir>  (see: cli.sh candidates)"
  dir="${dir%/}"
  case "$dir" in /*) ;; *) die "not an absolute path: $dir" ;; esac
  if [ ! -d "$dir" ]; then
    case "$dir" in "$HOME"/*) mkdir -p "$dir" ;; *) die "$dir does not exist; not creating it outside your home folder" ;; esac
  fi
  [ -w "$dir" ] || die "$dir is not writable; pick another directory (never sudo)"
  bin="$dir/fodo"
  if [ -e "$bin" ] || [ -L "$bin" ]; then
    ours "$bin" || die "$bin already exists and was not made by fodo; not touching it"
  fi
  mkdir -p "$STATE"
  ln -sfn "$SH" "$STABLE"
  old=$(installed)
  if [ -n "$old" ] && [ "$old" != "$bin" ] && ours "$old"; then rm -f "$old"; fi
  [ -L "$bin" ] || ln -s "$STABLE" "$bin"
  echo "$bin" > "$BINFILE"
  echo "linked: $bin"
  if ! on_path "$dir"; then
    echo "path: $dir is not on your PATH; add  export PATH=\"$dir:\$PATH\"  to your shell profile"
  else
    other=$(command -v fodo 2>/dev/null || true)
    [ -z "$other" ] || [ "$other" = "$bin" ] || echo "shadowed: $other comes first on your PATH"
  fi
  return 0
}

status() {
  local bin
  bin=$(installed)
  if [ -n "$bin" ] && ours "$bin"; then
    echo "linked: $bin"
    echo "  $bin -> $STABLE -> $(readlink "$STABLE" 2>/dev/null || echo '(missing)')"
    on_path "$(dirname "$bin")" || echo "  path: $(dirname "$bin") is not on your PATH"
  elif [ -n "$bin" ] && { [ -e "$bin" ] || [ -L "$bin" ]; }; then
    echo "not linked by fodo: $bin points at $(readlink "$bin" 2>/dev/null || echo 'a file')"
  else
    echo "not linked"
  fi
}

unlink_cli() {
  local bin
  bin=$(installed)
  if [ -n "$bin" ] && ours "$bin"; then
    rm -f "$bin" "$STABLE" "$BINFILE"
    echo "unlinked"
  elif [ -n "$bin" ] && { [ -e "$bin" ] || [ -L "$bin" ]; }; then
    die "$bin was not made by fodo; not touching it"
  else
    rm -f "$STABLE" "$BINFILE"
    echo "not linked"
  fi
}

cmd="${1:-status}"
case "$cmd" in
  candidates) candidates ;;
  link) link "${2:-}" ;;
  status) status ;;
  unlink) unlink_cli ;;
  -h|--help|help) sed -n '5,9p' "$0" | sed 's/^# \{0,1\}//' ;;
  *) echo "unknown command: $cmd (use candidates, link <dir>, status or unlink)" >&2; exit 1 ;;
esac
