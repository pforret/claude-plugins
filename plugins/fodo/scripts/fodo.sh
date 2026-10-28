#!/usr/bin/env bash
# Helper for the fodo Claude Code plugin (/fodo:* skills). Not a user-facing CLI:
# the skills run it as  bash "${CLAUDE_PLUGIN_ROOT}/scripts/fodo.sh" <command>  from the repo root.
#
# Commands:
#   fodo.sh init                 create docs/todo/{plan,busy,done,skipped,someday,decisions} + index files (idempotent)
#   fodo.sh list                 print planned items with reference numbers (+ plan/busy tables if non-empty)
#   fodo.sh reindex              rebuild every index.md from the files on disk
#   fodo.sh path <id>            print the file path of item <id> (1 / P1 / B1 / S1 / filename / "" = current)
#   fodo.sh current              print the file path of the item last moved to busy
#   fodo.sh move <id> <plan|busy|done|skipped|someday|planned>   move item <id> and reindex
#   fodo.sh move-file <file> <plan|busy|done|skipped|someday|planned>
#   fodo.sh set <file> <key> <value>               set/replace a frontmatter field and reindex
#   fodo.sh unset <file> <key>                     remove a frontmatter field and reindex
#   fodo.sh wait <file> <reason>                   mark a busy item as waiting (waiting_on + waiting_since)
#   fodo.sh resume <file>                          clear the waiting marker of an item
#   fodo.sh retype <file> <bug|change|feature>     correct the type of a quick item (size: unknown); renames it
#   fodo.sh busy [--all]         busy + plan tables of this repo (or of all registered repos)
#   fodo.sh repos [prune]        print the registry / remove rows whose path has no docs/todo/ any more
#   fodo.sh stale [--planned <days>] [--busy <days>]   stale planned/plan/busy items (/fodo:review); read-only
#   fodo.sh decide <title> [--item <file>] [--by <skill>]   write a decision skeleton into decisions/ and print its path
#   fodo.sh gotcha <text>        append a dated line to decisions/gotchas.md ("path/to/file: text" ties it to a file)
# IDs: 1,2,.. = planned table   P1,P2,.. = plan table   B1,B2,.. = busy table   S1,S2,.. = someday table
#      D1,D2,.. = decisions table (docs/todo/decisions/, never moved)
#
# Environment: TODO_ROOT (default docs/todo, relative to the git toplevel),
#   TODO_REGISTRY_DIR (default ~/.claude/todo).
# Global registry: every repo that runs init/list/reindex/move is upserted into
#   $TODO_REGISTRY_DIR/repos.csv (default ~/.claude/todo/repos.csv), columns "path","name","registered","last_seen".
#   The older todo skill's ~/.claude/state/todo-projects.tsv (TODO_LEGACY_REGISTRY) is copied in once
#   (marker $TODO_REGISTRY_DIR/.legacy-imported).
# ROOT is reassigned on purpose inside the per-repo subshell of busy_all
# shellcheck disable=SC2030,SC2031
set -euo pipefail
ROOT="${TODO_ROOT:-docs/todo}"
# a relative ROOT is always taken from the repo root, so the command works from any subdirectory
case "$ROOT" in /*) ;; *) cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)" ;; esac

field() { # field <file> <key>  -> frontmatter value
  sed -n '/^---$/,/^---$/p' "$1" | grep -E "^$2:" | head -1 | sed -E "s/^$2:[[:space:]]*//; s/^\"(.*)\"$/\1/"
  return 0
}

item_files() { # item_files <dir>
  find "$1" -maxdepth 1 -type f -name '20*.md' 2>/dev/null | sort
}

files_of() { # files_of <file>  -> the paths of the "files:" list in the frontmatter, one per line
  sed -n '/^---$/,/^---$/p' "$1" | awk '
    /^files:/ { f=1; next }
    f && /^[[:space:]]*-[[:space:]]+/ { sub(/^[[:space:]]*-[[:space:]]+/, ""); sub(/[[:space:]]+#.*$/, ""); gsub(/^["`'"'"']+|["`'"'"']+$/, ""); if ($0 != "" && $0 != "(unknown)") print; next }
    f { exit }'
  return 0
}

epoch() { # epoch <yyyy-mm-dd>  -> seconds since 1970 (BSD date first, GNU fallback); empty when unparsable
  [ -n "${1:-}" ] || return 0
  date -j -f %Y-%m-%d "$1" +%s 2>/dev/null || date -d "$1" +%s 2>/dev/null || true
}

days_since() { # days_since <yyyy-mm-dd>  -> whole days between that date and today; empty when unparsable
  local past now
  past=$(epoch "${1:-}"); now=$(epoch "$(date +%Y-%m-%d)")
  [ -n "$past" ] && [ -n "$now" ] || return 0
  echo $(( (now - past) / 86400 ))
}

later() { # later <a> <b>  -> the later of two yyyy-mm-dd strings (either may be empty)
  if [ -z "${1:-}" ]; then echo "${2:-}"; elif [ -z "${2:-}" ]; then echo "$1"; elif [[ "$1" > "$2" ]]; then echo "$1"; else echo "$2"; fi
}

in_git() { git rev-parse --is-inside-work-tree >/dev/null 2>&1; }

last_commit() { # last_commit <file>  -> date of the last commit touching any of its files: paths; empty if none / no git
  local paths; paths=$(files_of "$1")
  [ -n "$paths" ] && in_git || return 0
  # shellcheck disable=SC2086
  git log -1 --format=%cs -- $paths 2>/dev/null || true
}

commits_after() { # commits_after <file> <yyyy-mm-dd>  -> number of commits to its files: paths after that day
  local paths; paths=$(files_of "$1")
  { [ -n "$paths" ] && [ -n "$2" ] && in_git; } || { echo 0; return 0; }
  # shellcheck disable=SC2086
  git log --oneline --after="$2 23:59:59" -- $paths 2>/dev/null | grep -c . || true
}

stale() { # stale [--planned <days>] [--busy <days>]  -> markdown table of stale items (never writes)
  local planned_max=30 busy_max=14 use="usage: fodo.sh stale [--planned <days>] [--busy <days>]"
  while [ $# -gt 0 ]; do
    case "$1" in
      --planned) [[ "${2:-}" =~ ^[0-9]+$ ]] || { echo "$use" >&2; exit 1; }; planned_max=$2; shift 2 ;;
      --busy)    [[ "${2:-}" =~ ^[0-9]+$ ]] || { echo "$use" >&2; exit 1; }; busy_max=$2; shift 2 ;;
      *) echo "$use" >&2; exit 1 ;;
    esac
  done
  [ -f "$ROOT/index.md" ] || init >/dev/null
  local rows="" n f base ref reviewed created since last d c why reason
  n=0
  while IFS= read -r f; do
    [ -z "$f" ] && continue; n=$((n+1)); base=$(basename "$f")
    created=$(field "$f" created); created=${created:-${base:0:10}}; reviewed=$(field "$f" reviewed)
    ref=$(later "$created" "$reviewed"); d=$(days_since "$ref")
    if [ -n "$d" ] && [ "$d" -gt "$planned_max" ]; then
      if [ -n "$reviewed" ] && [ "$ref" = "$reviewed" ]; then why="reviewed $d days ago"; else why="planned $d days ago"; fi
      rows+="| $n | planned | $why | $ROOT/$base |"$'\n'
    fi
  done <<< "$(item_files "$ROOT")"
  n=0
  while IFS= read -r f; do
    [ -z "$f" ] && continue; n=$((n+1)); base=$(basename "$f")
    since=$(field "$f" plan_at); [ -n "$since" ] || { since=$(field "$f" created); since=${since:-${base:0:10}}; }
    since=$(later "$since" "$(field "$f" reviewed)"); c=$(commits_after "$f" "$since")
    if [ "${c:-0}" -gt 0 ]; then
      rows+="| P$n | plan | $c commit$([ "$c" = 1 ] || echo s) to its files since $since | $ROOT/plan/$base |"$'\n'
    fi
  done <<< "$(item_files "$ROOT/plan")"
  n=0
  while IFS= read -r f; do
    [ -z "$f" ] && continue; n=$((n+1)); base=$(basename "$f")
    last=$(later "$(later "$(field "$f" busy_at)" "$(field "$f" reviewed)")" "$(last_commit "$f")")
    [ -n "$last" ] || last=$(field "$f" created); last=${last:-${base:0:10}}
    d=$(days_since "$last")
    if [ -n "$d" ] && [ "$d" -gt "$busy_max" ]; then
      why="no activity for $d days (last: $last)"
      reason=$(field "$f" waiting_on); [ -z "$reason" ] || why+=" — waiting on: ${reason//|/\\|}"
      rows+="| B$n | busy | $why | $ROOT/busy/$base |"$'\n'
    fi
  done <<< "$(item_files "$ROOT/busy")"
  if [ -z "$rows" ]; then echo "_Nothing stale._"; else
    echo "| ID | Stage | Why flagged | File |"; echo "|----|-------|-------------|------|"; printf '%s' "$rows"
  fi
}

dir_for() { # dir_for <planned|plan|busy|done|skipped|someday|decisions>
  case "$1" in planned|"") echo "$ROOT" ;; plan|busy|done|skipped|someday|decisions) echo "$ROOT/$1" ;; *) echo "bad dir: $1" >&2; exit 1 ;; esac
}

# ---------------------------------------------------------------- global registry

REG_DIR="${TODO_REGISTRY_DIR:-}"
[ -n "$REG_DIR" ] || REG_DIR="$HOME/.claude/todo"
REG="$REG_DIR/repos.csv"
REG_HEADER='"path","name","registered","last_seen"'
# older versions of the todo skill kept path<TAB>name<TAB>date lines here; converted once, never written
LEGACY_REG="${TODO_LEGACY_REGISTRY:-}"
[ -n "$LEGACY_REG" ] || LEGACY_REG="$HOME/.claude/state/todo-projects.tsv"
LEGACY_DONE="$REG_DIR/.legacy-imported"

reg_import_legacy() { # one-time: add legacy rows whose path is not registered yet and still exists
  local path name date added=""
  [ -f "$LEGACY_REG" ] && [ ! -f "$LEGACY_DONE" ] || return 0
  mkdir -p "$REG_DIR"
  [ -f "$REG" ] || echo "$REG_HEADER" > "$REG"
  while IFS=$'\t' read -r path name date _; do
    [ -n "$path" ] && [ -d "$path" ] || continue
    grep -q -F "\"$path\"," "$REG" && continue
    case "$added" in *$'\n'"$path"$'\n'*) continue ;; esac
    [ -n "$name" ] || name=$(basename "$path")
    [ -n "$date" ] || date=$(date +%Y-%m-%d)
    printf '"%s","%s","%s","%s"\n' "$path" "$name" "$date" "$date" >> "$REG"
    added="$added"$'\n'"$path"$'\n'
  done < "$LEGACY_REG"
  echo "$(date +%Y-%m-%d) imported $LEGACY_REG" > "$LEGACY_DONE"
}

refresh_dashboard_link() { # after a plugin update, re-point the /fodo:valet link at this version's dashboard
  local d
  [ -L "$REG_DIR/dashboard" ] || return 0
  d=$(cd "$(dirname "$0")/../dashboard" 2>/dev/null && pwd) || return 0
  [ "$(readlink "$REG_DIR/dashboard")" = "$d" ] || ln -sfn "$d" "$REG_DIR/dashboard"
  return 0
}

register_repo() { # upsert the current repo; never fails the caller
  local path name today old registered
  reg_import_legacy
  refresh_dashboard_link
  case "$ROOT" in /*) return 0 ;; esac     # custom absolute ROOT = not a repo
  path=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
  name=$(basename "$path")
  today=$(date +%Y-%m-%d)
  mkdir -p "$REG_DIR"
  [ -f "$REG" ] || echo "$REG_HEADER" > "$REG"
  old=$(grep -F "\"$path\"," "$REG" 2>/dev/null | head -1 || true)
  registered=$today
  if [ -n "$old" ]; then
    registered=$(printf '%s' "$old" | sed -E 's/^"[^"]*","[^"]*","([^"]*)".*/\1/')
    [ -n "$registered" ] || registered=$today
  fi
  { echo "$REG_HEADER"; grep -v -F -e "$REG_HEADER" -e "\"$path\"," "$REG" 2>/dev/null || true
    printf '"%s","%s","%s","%s"\n' "$path" "$name" "$registered" "$today"; } > "$REG.tmp.$$" && mv "$REG.tmp.$$" "$REG"
}

reg_repos() { # prints: path<TAB>name  (one per registered repo)
  [ -f "$REG" ] || return 0
  grep -v -F "$REG_HEADER" "$REG" 2>/dev/null | sed -E 's/^"([^"]*)","([^"]*)".*/\1\t\2/' || true
}

reg_prune() { # drop rows whose path is gone or no longer has docs/todo/
  [ -f "$REG" ] || { echo "no registry at $REG"; return 0; }
  local path name
  { echo "$REG_HEADER"
    while IFS=$'\t' read -r path name; do
      [ -z "$path" ] && continue
      if [ -d "$path/docs/todo" ]; then grep -F "\"$path\"," "$REG" | head -1
      else echo "pruned: $path ($name)" >&2; fi
    done <<< "$(reg_repos)"
  } > "$REG.tmp.$$" && mv "$REG.tmp.$$" "$REG"
}

print_busy() { # busy + plan tables of $ROOT
  local any=0
  if [ -n "$(item_files "$ROOT/busy")" ]; then cat "$ROOT/busy/index.md"; any=1; fi
  if [ -n "$(item_files "$ROOT/plan")" ]; then [ $any = 1 ] && echo; cat "$ROOT/plan/index.md"; any=1; fi
  [ $any = 1 ] || echo "_No busy or plan items._"
}

busy_all() { # busy + plan tables of every registered repo
  local path name
  [ -f "$REG" ] || { echo "no registered repos yet (registry: $REG)"; return 0; }
  while IFS=$'\t' read -r path name; do
    [ -z "$path" ] && continue
    [ -d "$path/docs/todo" ] || { echo "⚠ missing: $path ($name) — run /fodo:repos prune to drop it" >&2; continue; }
    ( cd "$path" && ROOT=docs/todo
      if [ -n "$(item_files "$ROOT/busy")" ] || [ -n "$(item_files "$ROOT/plan")" ]; then
        echo "## $name  ($path)"; echo; print_busy; echo
      fi )
  done <<< "$(reg_repos)"
}

busy_cmd() { if [ "${1:-}" = "--all" ] || [ "${1:-}" = "-a" ]; then reg_import_legacy; busy_all; else [ -f "$ROOT/index.md" ] || init >/dev/null; print_busy; fi; }
repos_cmd() { reg_import_legacy; case "${1:-}" in prune) reg_prune ;; *) [ -f "$REG" ] && cat "$REG" || echo "no registry at $REG" ;; esac; }

write_index() { # write_index <dir> <heading> <status-word> [extra-column] [id-prefix]
  local dir="$1" heading="$2" status="$3" extra="${4:-}" prefix="${5:-}" n=0 f
  {
    echo "# $heading"
    echo
    if [ -z "$(item_files "$dir")" ]; then
      echo "_No $status items._"
    else
      if [ "$extra" = "confidence" ]; then
        echo "| ID | Date | Type | Size | Confidence | Title | File |"
        echo "|----|------|------|------|------------|-------|------|"
      elif [ "$extra" = "waiting" ]; then
        echo "| ID | Date | Type | Size | Waiting on | Title | File |"
        echo "|----|------|------|------|------------|-------|------|"
      elif [ "$extra" = "decisions" ]; then
        echo "| ID | Date | Status | Item | Title | File |"
        echo "|----|------|--------|------|-------|------|"
      else
        echo "| ID | Date | Type | Size | Title | File |"
        echo "|----|------|------|------|-------|------|"
      fi
      while IFS= read -r f; do
        [ -z "$f" ] && continue
        n=$((n+1))
        local base date type size title conf wait since dstatus by item
        base=$(basename "$f")
        date=${base:0:10}
        if [ "$extra" = "decisions" ]; then # <date>.<slug>.md: no type segment, title falls back to the slug
          dstatus=$(field "$f" status); dstatus=${dstatus:-accepted}
          by=$(field "$f" superseded_by); [ -z "$by" ] || dstatus="$dstatus → $by"
          item=$(field "$f" item)
          title=$(field "$f" title); [ -n "$title" ] || { title=${base#*.}; title=${title%.md}; }
          echo "| $prefix$n | $date | $dstatus | $item | $title | [$base]($base) |"
          continue
        fi
        type=$(echo "$base" | cut -d. -f2)
        size=$(field "$f" size); size=${size:-?}
        title=$(field "$f" title); [ -n "$title" ] || { title=${base#*.*.}; title=${title%.md}; } # .md only off the filename fallback
        if [ "$extra" = "confidence" ]; then
          conf=$(field "$f" confidence); conf=${conf:-?}
          echo "| $prefix$n | $date | $type | $size | $conf/10 | $title | [$base]($base) |"
        elif [ "$extra" = "waiting" ]; then
          wait=$(field "$f" waiting_on); since=$(field "$f" waiting_since)
          [ -z "$wait" ] || wait="⏸ ${wait//|/\\|}${since:+ (since $since)}"
          echo "| $prefix$n | $date | $type | $size | $wait | $title | [$base]($base) |"
        else
          echo "| $prefix$n | $date | $type | $size | $title | [$base]($base) |"
        fi
      done <<< "$(item_files "$dir")"
    fi
  } > "$dir/index.md"
}

init() {
  mkdir -p "$ROOT/plan" "$ROOT/busy" "$ROOT/done" "$ROOT/skipped" "$ROOT/someday" "$ROOT/decisions"
  reindex
}

reindex() {
  mkdir -p "$ROOT/someday" "$ROOT/decisions" # repos from before these folders existed get them on their next reindex
  write_index "$ROOT" "Todo — planned" "planned"
  write_index "$ROOT/plan" "Todo — plan (PRP ready, waiting for execute; IDs P1, P2, …)" "plan" confidence P
  write_index "$ROOT/busy" "Todo — busy (in progress; IDs B1, B2, …)" "busy" waiting B
  write_index "$ROOT/done" "Todo — done" "done"
  write_index "$ROOT/skipped" "Todo — skipped" "skipped"
  write_index "$ROOT/someday" "Todo — someday (parked; IDs S1, S2, …)" "someday" "" S
  write_index "$ROOT/decisions" "Todo — decisions (why things are the way they are; IDs D1, D2, …)" "decision" decisions D
  register_repo || true
}

nth() { # nth <dir> <n>
  item_files "$1" | sed -n "${2}p"
}

list() {
  [ -f "$ROOT/index.md" ] || init
  register_repo || true
  cat "$ROOT/index.md"
  if [ -n "$(item_files "$ROOT/plan")" ]; then
    echo; cat "$ROOT/plan/index.md"
  fi
  if [ -n "$(item_files "$ROOT/busy")" ]; then
    echo; cat "$ROOT/busy/index.md"
  fi
  local parked; parked=$(item_files "$ROOT/someday" | grep -c . || true)
  if [ "$parked" -gt 0 ]; then
    echo; echo "_$parked item$([ "$parked" = 1 ] || echo s) in someday/ (/fodo:someday to list them)._"
  fi
  local decided; decided=$(item_files "$ROOT/decisions" | grep -c . || true)
  if [ "$decided" -gt 0 ]; then
    echo; echo "_$decided decision$([ "$decided" = 1 ] || echo s) in decisions/ (/fodo:decide to list them)._"
  fi
}

# ---------------------------------------------------------------- decisions

slugify() { # slugify <text>  -> 2–6 lowercase hyphenated words (at least one)
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//' \
    | awk -F- '{ n = NF < 6 ? NF : 6; out = ""; for (i = 1; i <= n; i++) if ($i != "") out = out (out == "" ? "" : "-") $i; print out }'
}

flatten() { # flatten <text...>  -> one line, trimmed, double quotes made single (safe in frontmatter)
  printf '%s' "$*" | tr '\n\r' '  ' | tr '"' "'" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//'
}

decide() { # decide <title> [--item <file>] [--by <skill>]  -> writes decisions/<today>.<slug>.md and prints its path
  local title="" item="" by="decide" use="usage: fodo.sh decide <title> [--item <file>] [--by <skill>]"
  while [ $# -gt 0 ]; do
    case "$1" in
      --item) [ -n "${2:-}" ] || { echo "$use" >&2; exit 1; }; item=$(basename "$2"); shift 2 ;;
      --by)   [ -n "${2:-}" ] || { echo "$use" >&2; exit 1; }; by=$2; shift 2 ;;
      *) title="${title:+$title }$1"; shift ;;
    esac
  done
  title=$(flatten "$title")
  [ -n "$title" ] || { echo "$use" >&2; exit 1; }
  local slug today f
  slug=$(slugify "$title"); [ -n "$slug" ] || slug=decision
  today=$(date +%Y-%m-%d)
  [ -f "$ROOT/index.md" ] || init >/dev/null
  mkdir -p "$ROOT/decisions"
  f="$ROOT/decisions/$today.$slug.md"
  [ -e "$f" ] && { echo "exists: $f (pick another title)" >&2; exit 1; }
  {
    echo "---"
    echo "title: $title"
    echo "date: $today"
    echo "status: accepted"
    [ -z "$item" ] || echo "item: $item"
    echo "recorded_by: $by"
    echo "---"
    echo
    echo "# $title"
    echo
    echo "## Context"
    echo "<what made this decision necessary; the item, the constraint, the question that came up>"
    echo
    echo "## Options considered"
    echo "<one bullet per option, with its trade-off>"
    echo
    echo "## Decision"
    echo "$title"
    echo
    echo "## Consequences"
    echo "<what becomes easier or harder; what to remember when touching this area>"
  } > "$f"
  reindex
  echo "$f"
}

gotcha() { # gotcha <text...>  -> appends "- <today> <text>" to decisions/gotchas.md and prints the file path
  local text f
  text=$(flatten "$@")
  [ -n "$text" ] || { echo "usage: fodo.sh gotcha <text>  (start with path/to/file: to tie it to a file)" >&2; exit 1; }
  [ -f "$ROOT/index.md" ] || init >/dev/null
  mkdir -p "$ROOT/decisions"
  f="$ROOT/decisions/gotchas.md"
  # shellcheck disable=SC2016 # the backticks are markdown
  [ -f "$f" ] || printf '# Gotchas\n\nOne line each, newest last. Start a line with `path/to/file:` and the session-start hook shows it when that file is in your diff.\n\n' > "$f"
  echo "- $(date +%Y-%m-%d) $text" >> "$f"
  echo "$f"
}

set_field() { # set_field <file> <key> <value>  (frontmatter only; key and value go through ENVIRON, so any text is safe)
  local f="$1" key="$2" value="$3"
  [ -f "$f" ] || { echo "not found: $f" >&2; exit 1; }
  if sed -n '/^---$/,/^---$/p' "$f" | grep -qE "^${key}:"; then
    K="$key" V="$value" awk 'BEGIN{k=ENVIRON["K"]":"} /^---$/{fm++} fm==1 && index($0,k)==1 && !d {print ENVIRON["K"] ": " ENVIRON["V"]; d=1; next} {print}' \
      "$f" > "$f.tmp" && mv "$f.tmp" "$f"
  else
    K="$key" V="$value" awk '/^---$/{fm++} {print} fm==1 && /^status:/ && !d {print ENVIRON["K"] ": " ENVIRON["V"]; d=1}' \
      "$f" > "$f.tmp" && mv "$f.tmp" "$f"
  fi
}

unset_field() { # unset_field <file> <key>  drop the key from the frontmatter; a missing key is fine
  local f="$1"
  [ -f "$f" ] || { echo "not found: $f" >&2; exit 1; }
  K="$2" awk 'BEGIN{k=ENVIRON["K"]":"} /^---$/{fm++} fm==1 && index($0,k)==1 {next} {print}' "$f" > "$f.tmp" && mv "$f.tmp" "$f"
}

in_dir() { # in_dir <file> <dir>  true when the file sits directly in dir
  [ "$(cd "$(dirname "$1")" && pwd)" = "$(cd "$2" 2>/dev/null && pwd)" ]
}

wait_item() { # wait_item <file> <reason...>
  local f="$1"; shift
  [ -f "$f" ] || { echo "not found: $f" >&2; exit 1; }
  in_dir "$f" "$ROOT/busy" || { echo "only busy items can wait (move it to busy first: /fodo:start)" >&2; exit 1; }
  local reason="$*"
  reason=$(printf '%s' "$reason" | tr '\n\r' '  ' | tr '"' "'" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')
  [ -n "$reason" ] || { echo "usage: fodo.sh wait <file> <reason>" >&2; exit 1; }
  set_field "$f" waiting_since "$(date +%Y-%m-%d)" # new keys go right after status:, so set this one first
  set_field "$f" waiting_on "\"$reason\""
  reindex
  echo "$f"
}

resume_item() { # resume_item <file>
  unset_field "$1" waiting_on
  unset_field "$1" waiting_since
  reindex
  echo "$1"
}

move_file() { # move_file <file> <target>
  local f="$1" target="$2"
  [ -f "$f" ] || { echo "not found: $f" >&2; exit 1; }
  case "$target" in plan|busy|done|skipped|someday|planned) ;; *) echo "bad target: $target" >&2; exit 1;; esac
  local src root dest today
  src=$(cd "$(dirname "$f")" && pwd); root=$(cd "$ROOT" && pwd)
  if [ "$src" = "$root/decisions" ]; then
    echo "decisions are never moved (they are records, not items)" >&2; exit 1
  fi
  if [ "$target" = someday ] && [ "$src" != "$root" ] && [ "$src" != "$root/plan" ]; then
    echo "only planned or plan items can be parked in someday/" >&2; exit 1
  fi
  if [ "$target" = planned ] && [ "$src" != "$root/someday" ] && [ "$src" != "$root/plan" ]; then
    echo "only someday or plan items can go back to planned" >&2; exit 1
  fi
  today=$(date +%Y-%m-%d)
  dest=$(dir_for "$target")
  if [ "$src" = "$root/busy" ] && [ "$target" != busy ]; then # leaving busy: it is not waiting any more
    unset_field "$f" waiting_on
    unset_field "$f" waiting_since
  fi
  set_field "$f" status "$target"
  [ "$target" = planned ] || set_field "$f" "${target}_at" "$today" # no planned_at: it would read like plan_at
  if git -C "$(dirname "$f")" rev-parse --is-inside-work-tree >/dev/null 2>&1 && git ls-files --error-unmatch "$f" >/dev/null 2>&1; then
    git mv "$f" "$dest/"
  else
    mv "$f" "$dest/"
  fi
  reindex
  if [ "$target" = busy ]; then
    basename "$f" > "$ROOT/.current"
  elif [ -f "$ROOT/.current" ] && [ "$(cat "$ROOT/.current")" = "$(basename "$f")" ]; then
    rm -f "$ROOT/.current"
  fi
  echo "$dest/$(basename "$f")"
}

retype() { # retype <file> <bug|change|feature>  correct the guessed type of a quick item (size: unknown) by renaming it
  local f="$1" type="$2" base old new dir
  [ -f "$f" ] || { echo "not found: $f" >&2; exit 1; }
  case "$type" in bug|change|feature) ;; *) echo "bad type: $type (use bug, change or feature)" >&2; exit 1 ;; esac
  [ "$(field "$f" size)" = unknown ] || { echo "only quick items (size: unknown) can be retyped" >&2; exit 1; }
  base=$(basename "$f"); dir=$(dirname "$f")
  old=$(echo "$base" | cut -d. -f2)
  if [ "$old" = "$type" ]; then echo "$f"; return 0; fi
  new="${base%%.*}.$type.${base#*.*.}"
  [ -e "$dir/$new" ] && { echo "exists: $dir/$new" >&2; exit 1; }
  set_field "$f" type "$type"
  if git -C "$dir" rev-parse --is-inside-work-tree >/dev/null 2>&1 && git ls-files --error-unmatch "$f" >/dev/null 2>&1; then
    git mv "$f" "$dir/$new"
  else
    mv "$f" "$dir/$new"
  fi
  reindex
  if [ -f "$ROOT/.current" ] && [ "$(cat "$ROOT/.current")" = "$base" ]; then echo "$new" > "$ROOT/.current"; fi
  echo "$dir/$new"
}

current() { # path of the item last moved to busy; falls back to the only busy item
  local base
  if [ -f "$ROOT/.current" ]; then
    base=$(cat "$ROOT/.current")
    [ -f "$ROOT/busy/$base" ] && { echo "$ROOT/busy/$base"; return 0; }
  fi
  if [ "$(item_files "$ROOT/busy" | wc -l | tr -d ' ')" = 1 ]; then
    item_files "$ROOT/busy"; return 0
  fi
  echo "no current item (nothing in busy, or several; use B<n>)" >&2; return 1
}

resolve() { # resolve <id>  -> file path. 1 = planned, P1 = plan, B1 = busy, S1 = someday, D1 = decision, filename, or empty = current
  local spec="${1:-}" f
  spec="${spec#\#}"
  case "$spec" in
    "")            current; return $? ;;
    *.md)          f=$(find "$ROOT" -name "$(basename "$spec")" -type f | head -1) ;;
    [Pp][0-9]*)    f=$(nth "$ROOT/plan" "${spec#[Pp]}") ;;
    [Bb][0-9]*)    f=$(nth "$ROOT/busy" "${spec#[Bb]}") ;;
    [Ss][0-9]*)    f=$(nth "$ROOT/someday" "${spec#[Ss]}") ;;
    [Dd][0-9]*)    f=$(nth "$ROOT/decisions" "${spec#[Dd]}") ;;
    [0-9]*)        f=$(nth "$ROOT" "$spec") ;;
    *)             echo "bad id: $spec (use 1, P1, B1, S1, D1 or a filename)" >&2; return 1 ;;
  esac
  [ -n "$f" ] || { echo "no item $spec" >&2; return 1; }
  echo "$f"
}

usage() {
  sed -n '5,23p' "$0" | sed 's/^# \{0,1\}//'
}

# ---------------------------------------------------------------- dispatch

cmd="${1:-}"; shift || true
case "$cmd" in
  init) init ;;
  list) list ;;
  reindex) reindex ;;
  path|resolve) resolve "${1:-}" ;;
  current) current ;;
  move) [ $# -ge 2 ] || { echo "usage: fodo.sh move <id> <plan|busy|done|skipped|someday|planned>" >&2; exit 1; }
        f=$(resolve "$1"); move_file "$f" "$2" ;;
  move-file) [ $# -ge 2 ] || { echo "usage: fodo.sh move-file <file> <plan|busy|done|skipped|someday|planned>" >&2; exit 1; }
        move_file "$1" "$2" ;;
  set) [ $# -ge 3 ] || { echo "usage: fodo.sh set <file> <key> <value>" >&2; exit 1; }
       set_field "$1" "$2" "$3" && reindex ;; # the tables show size and confidence, so keep them current
  unset) [ $# -ge 2 ] || { echo "usage: fodo.sh unset <file> <key>" >&2; exit 1; }
         unset_field "$1" "$2" && reindex ;;
  wait) [ $# -ge 2 ] || { echo "usage: fodo.sh wait <file> <reason>" >&2; exit 1; }
        wait_item "$@" ;;
  resume) [ $# -ge 1 ] || { echo "usage: fodo.sh resume <file>" >&2; exit 1; }
          [ -f "$1" ] || { echo "not found: $1" >&2; exit 1; }
          resume_item "$1" ;;
  retype) [ $# -ge 2 ] || { echo "usage: fodo.sh retype <file> <bug|change|feature>" >&2; exit 1; }
          retype "$1" "$2" ;;
  busy) busy_cmd "${1:-}" ;;
  repos) repos_cmd "${1:-}" ;;
  stale) stale "$@" ;;
  decide) decide "$@" ;;
  gotcha) gotcha "$@" ;;
  ""|-h|--help|help) usage ;;
  *) echo "unknown command: $cmd" >&2; usage >&2; exit 1 ;;
esac
