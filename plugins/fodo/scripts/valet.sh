#!/usr/bin/env bash
# Laravel Valet site for the fodo Claude Code plugin (/fodo:valet): serves the dashboard as http://fodo.<tld>.
# Never runs valet or sudo: it writes the symlink `valet link fodo` would write.
#
# Usage:
#   valet.sh [link]          link the dashboard as fodo.<tld> (idempotent)
#   valet.sh status          print whether it is linked and where
#   valet.sh unlink          remove the fodo site
#   valet.sh unlink-todolist remove the old todo skill's todolist site (only if it points into ~/.claude/skills/todo)
#
# Links: <valet home>/Sites/fodo -> ~/.claude/todo/dashboard -> <plugin>/dashboard (re-pointed by fodo.sh/web.sh
# after plugin updates). ~/.claude/todo/claude-bin holds the absolute path of `claude` for the /agents page.
set -euo pipefail

DASH="$(cd "$(dirname "$0")/../dashboard" && pwd)"
STATE="${TODO_REGISTRY_DIR:-}"
[ -n "$STATE" ] || STATE="$HOME/.claude/todo"
VHOME="${FODO_VALET_HOME:-}"
if [ -z "$VHOME" ]; then
  VHOME="$HOME/.config/valet"
  [ -d "$VHOME" ] || [ ! -d "$HOME/.valet" ] || VHOME="$HOME/.valet"
fi
SITES="$VHOME/Sites"
CFG="$VHOME/config.json"
SITE="$SITES/fodo"
STABLE="$STATE/dashboard"
OLD_SKILL="$HOME/.claude/skills/todo"

die() { echo "$*" >&2; exit 1; }

need_valet() {
  command -v valet >/dev/null 2>&1 || [ -f "$CFG" ] ||
    die "Laravel Valet not found (https://laravel.com/docs/valet); use /fodo:web for the dashboard instead"
  [ -f "$CFG" ] || die "Valet is installed but $CFG is missing; run 'valet install' in a terminal first"
}

cfg() { # cfg tld|paths -> the tld, or one parked path per line
  # shellcheck disable=SC2016 # PHP code, not shell
  php -r '$c = json_decode((string) @file_get_contents($argv[1]), true) ?: [];
    if ($argv[2] === "tld") { echo $c["tld"] ?? "test"; } else { foreach ($c["paths"] ?? [] as $p) { echo $p, "\n"; } }' \
    "$CFG" "$1" 2>/dev/null || { [ "$1" = tld ] && echo test; }
}

site_url() { # http or https, depending on a Valet certificate for fodo.<tld>
  local tld
  tld=$(cfg tld)
  if [ -f "$VHOME/Certificates/fodo.$tld.crt" ]; then echo "https://fodo.$tld/"; else echo "http://fodo.$tld/"; fi
}

todolist_target() { # prints the target of an old todolist link into the todo skill, or nothing
  local t
  [ -L "$SITES/todolist" ] || return 0
  t=$(readlink "$SITES/todolist")
  case "$t" in "$OLD_SKILL"/*|"$OLD_SKILL") echo "$t" ;; esac
  return 0
}

link() {
  local c t
  need_valet
  cfg paths | grep -qxF "$SITES" ||
    die "Valet does not serve $SITES yet; run once in a terminal: mkdir -p ~/.claude/todo && ln -sfn '$DASH' ~/.claude/todo/dashboard && cd ~/.claude/todo/dashboard && valet link fodo"
  if [ -e "$SITE" ] || [ -L "$SITE" ]; then
    [ -L "$SITE" ] && [ "$(readlink "$SITE")" = "$STABLE" ] ||
      die "fodo is already a Valet site pointing at $(readlink "$SITE" 2>/dev/null || echo "$SITE"); not touching it"
  fi
  mkdir -p "$STATE" "$SITES"
  ln -sfn "$DASH" "$STABLE"
  [ -L "$SITE" ] || ln -s "$STABLE" "$SITE"
  c=$(command -v claude || true)
  if [ -n "$c" ]; then echo "$c" > "$STATE/claude-bin"; fi
  echo "linked: $(site_url)"
  case "$(site_url)" in https:*) ;; *) echo "https: run 'valet secure fodo' in a terminal (it asks for your password)" ;; esac
  [ -n "$c" ] || echo "note: claude is not on the PATH, so /agents cannot list sessions"
  t=$(todolist_target)
  [ -z "$t" ] || echo "todolist: http://todolist.$(cfg tld)/ still points at the old todo skill ($t); remove it with: valet.sh unlink-todolist"
  return 0
}

status() {
  if [ -L "$SITE" ] && [ "$(readlink "$SITE")" = "$STABLE" ]; then
    echo "linked: $(site_url)"
    echo "  $SITE -> $STABLE -> $(readlink "$STABLE" 2>/dev/null || echo '(missing)')"
    if [ -f "$STATE/claude-bin" ]; then echo "  claude: $(cat "$STATE/claude-bin")"; else echo "  claude: not stored (/agents uses the PATH)"; fi
  elif [ -e "$SITE" ] || [ -L "$SITE" ]; then
    echo "not linked by fodo: $SITE points at $(readlink "$SITE" 2>/dev/null || echo 'a folder')"
  else
    echo "not linked"
  fi
}

unlink_site() {
  if [ -L "$SITE" ] && [ "$(readlink "$SITE")" = "$STABLE" ]; then
    rm -f "$SITE" "$STABLE" "$STATE/claude-bin"
    echo "unlinked"
  elif [ -e "$SITE" ] || [ -L "$SITE" ]; then
    die "$SITE was not made by fodo; not touching it"
  else
    rm -f "$STABLE" "$STATE/claude-bin"
    echo "not linked"
  fi
}

unlink_todolist() {
  local t
  t=$(todolist_target)
  [ -n "$t" ] || die "no todolist link into $OLD_SKILL; nothing removed"
  rm -f "$SITES/todolist"
  echo "removed todolist ($t)"
}

cmd="${1:-link}"
case "$cmd" in
  link) link ;;
  status) status ;;
  unlink) unlink_site ;;
  unlink-todolist) unlink_todolist ;;
  -h|--help|help) sed -n '5,9p' "$0" | sed 's/^# \{0,1\}//' ;;
  *) echo "unknown command: $cmd (use link, status, unlink or unlink-todolist)" >&2; exit 1 ;;
esac
