#!/usr/bin/env bash
# SessionStart hook of the fodo Claude Code plugin.
# Prints the busy (in progress) items of the current repo so Claude knows about them from the first
# prompt, preceded by a one-line summary of docs/todo/decisions/ and the gotchas (decisions/gotchas.md)
# whose file is in the current diff. Prints nothing when the repo has none of these. Read-only, never fails the session.
#
# Input: the hook JSON on stdin (only "cwd" is used; falls back to $PWD). Output: plain text, added to
# the session context by Claude Code. Honours TODO_ROOT like fodo.sh.
set -uo pipefail

input=$(cat 2>/dev/null || true)
cwd=$(printf '%s' "$input" | sed -nE 's/.*"cwd"[[:space:]]*:[[:space:]]*"([^"]*)".*/\1/p' | head -1)
if [ -n "$cwd" ] && [ -d "$cwd" ]; then cd "$cwd" 2>/dev/null || exit 0; fi

ROOT="${TODO_ROOT:-docs/todo}"
case "$ROOT" in /*) ;; *) cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)" 2>/dev/null || exit 0 ;; esac
BUSY="$ROOT/busy"
DEC="$ROOT/decisions"
[ -d "$BUSY" ] || [ -d "$DEC" ] || exit 0

field() { sed -n '/^---$/,/^---$/p' "$1" | grep -E "^$2:" | head -1 | sed -E "s/^$2:[[:space:]]*//; s/^\"(.*)\"$/\1/"; return 0; }

# ---- decisions: one summary line, plus the gotchas that mention a file in the current diff
decisions=$(find "$DEC" -maxdepth 1 -type f -name '20*.md' 2>/dev/null | sort)
if [ -n "$decisions" ]; then
  n=$(printf '%s\n' "$decisions" | grep -c .)
  last=$(printf '%s\n' "$decisions" | tail -1)
  title=$(field "$last" title); [ -n "$title" ] || { title=$(basename "$last" .md); title=${title#*.}; }
  if [ "$n" = 1 ]; then echo "Fodo: 1 decision is recorded in $DEC/, last: $title ($(basename "$last" | cut -c1-10)); /fodo:show D1 prints it, /fodo:decide records a new one."
  else echo "Fodo: $n decisions are recorded in $DEC/, last: $title ($(basename "$last" | cut -c1-10)); /fodo:show D<n> prints one, /fodo:decide records a new one."; fi
fi
if [ -f "$DEC/gotchas.md" ]; then
  changed=$( { git diff --name-only HEAD 2>/dev/null; git status --porcelain 2>/dev/null | cut -c4- | sed 's/^.* -> //'; } | grep . | sort -u || true)
  if [ -n "$changed" ]; then
    hits=""
    while IFS= read -r line; do
      case "$line" in "- "*) ;; *) continue ;; esac
      gpath=$(printf '%s' "$line" | sed -nE 's/^- [0-9]{4}-[0-9]{2}-[0-9]{2} ([^: ]+):.*/\1/p')
      [ -n "$gpath" ] || continue
      if printf '%s\n' "$changed" | grep -qF -- "$gpath"; then hits="$hits$line"$'\n'; fi
    done < "$DEC/gotchas.md"
    if [ -n "$hits" ]; then
      echo "Gotchas for files in your current diff ($DEC/gotchas.md):"
      printf '%s' "$hits"
    fi
  fi
fi

# ---- busy items
[ -d "$BUSY" ] || exit 0
files=$(find "$BUSY" -maxdepth 1 -type f -name '20*.md' 2>/dev/null | sort)
[ -n "$files" ] || exit 0

current=""
[ -f "$ROOT/.current" ] && current=$(cat "$ROOT/.current")

n=0
lines=""
while IFS= read -r f; do
  n=$((n + 1))
  title=$(field "$f" title); [ -n "$title" ] || title=$(basename "$f" .md)
  since=$(field "$f" busy_at)
  waiting=$(field "$f" waiting_on)
  line="- B$n: $title"
  [ -n "$since" ] && line="$line (since $since"
  [ -n "$since" ] && [ -n "$waiting" ] && line="$line, waiting on: $waiting"
  [ -n "$since" ] && line="$line)"
  [ -z "$since" ] && [ -n "$waiting" ] && line="$line (waiting on: $waiting)"
  [ "$(basename "$f")" = "$current" ] && line="$line [current]"
  lines="$lines$line"$'\n'
done <<< "$files"

if [ "$n" = 1 ]; then echo "Fodo: 1 todo item is in progress in this repo ($BUSY/):"
else echo "Fodo: $n todo items are in progress in this repo ($BUSY/):"; fi
printf '%s' "$lines"
echo "Mention it when relevant; /fodo:show B<n> prints an item, /fodo:done B<n> verifies and archives it."
exit 0
