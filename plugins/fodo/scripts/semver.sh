#!/usr/bin/env bash
# Version helper for the fodo Claude Code plugin, used by /fodo:commit. It mirrors what
# pforret/setver does with version numbers, plus Claude plugin manifests, so a bump lands in every
# file that carries the version. It never commits and never pushes.
#
# Commands:
#   semver.sh current            print the current version: VERSION.md, else the highest v?x.y.z git tag,
#                                else composer.json, package.json, a root shell script; 0.0.0 when none
#                                (the source goes to stderr)
#   semver.sh next <patch|minor|major> [current]   print the bumped version (minor and major reset lower parts)
#   semver.sh files              list the version files present in this repo, one per line
#   semver.sh set <x.y.z>        write the version into every version file; one line per file written;
#                                exit 1 when there was nothing to write
#   semver.sh tag <x.y.z>        create the annotated tag v<x.y.z> on HEAD; refuses when it exists
#
# Version files (all optional): VERSION.md, composer.json and package.json (only their existing
# top-level "version" line, so formatting is kept; package-lock.json follows package.json),
# .env.example (VERSION= / APP_VERSION= lines), one *.sh in the repo root with a version= or
# VERSION= line, and every .claude-plugin/plugin.json or plugins/*/.claude-plugin/plugin.json.
set -euo pipefail

die() { echo "semver: $*" >&2; exit 1; }

semver_re='^[0-9]+\.[0-9]+\.[0-9]+$'

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$ROOT"

is_semver() { [[ $1 =~ $semver_re ]]; }

json_has_version() { # json_has_version <file>  -> true when the file has a top-level-looking "version" line
  grep -q -E '^[[:space:]]*"version":[[:space:]]*"[^"]*"' "$1" 2>/dev/null
}

json_version() { # json_version <file>  -> value of the first "version" line
  sed -n -E 's/^[[:space:]]*"version":[[:space:]]*"([^"]*)".*/\1/p' "$1" | head -1
}

json_set_version() { # json_set_version <file> <version>  rewrite only the first "version" line (release.sh pattern)
  awk -v v="$2" '!done && /^[[:space:]]*"version":[[:space:]]*"[^"]*"/ { sub(/"version":[[:space:]]*"[^"]*"/, "\"version\": \"" v "\""); done = 1 } { print }' \
    "$1" > "$1.tmp" && mv "$1.tmp" "$1"
  grep -q "\"version\": \"$2\"" "$1" || die "could not set version in $1"
}

kv_set_version() { # kv_set_version <file> <version> <key-regex> [quoted]  rewrite KEY=value lines; true when changed
  local f=$1 v=$2 keys=$3 q=${4:-}
  awk -F= -v version="$v" -v keys="$keys" -v q="$q" '
    $1 ~ ("^(" keys ")$") { print $1 "=" q version q; next } { print }' "$f" > "$f.tmp"
  if cmp -s "$f" "$f.tmp"; then rm -f "$f.tmp"; return 1; fi
  mv "$f.tmp" "$f"
}

root_script() { # the single *.sh in the repo root with a version= or VERSION= line, if exactly one
  local hits=() f
  for f in ./*.sh; do
    [ -f "$f" ] || continue
    grep -q -E '^(version|VERSION)=' "$f" && hits+=("${f#./}")
  done
  [ ${#hits[@]} -eq 1 ] && echo "${hits[0]}"
  return 0
}

script_version() { # script_version <file>
  sed -n -E 's/^(version|VERSION)="?([^"]*)"?.*/\2/p' "$1" | head -1
}

tag_version() { # highest v?x.y.z tag, without the v (plain `git tag` sorts 1.10.0 before 1.6.0)
  git rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 0
  git tag --sort=version:refname 2>/dev/null | { grep -E '^v?[0-9]+\.[0-9]+\.[0-9]+$' || true; } | tail -1 | sed 's/^v//'
}

manifests() { # every Claude plugin manifest
  { [ -f .claude-plugin/plugin.json ] && echo .claude-plugin/plugin.json
    find plugins -path '*/.claude-plugin/plugin.json' 2>/dev/null | sort; } || true
}

files() {
  [ -f VERSION.md ] && echo VERSION.md
  [ -f composer.json ] && json_has_version composer.json && echo composer.json
  [ -f package.json ] && json_has_version package.json && echo package.json
  [ -f .env.example ] && grep -q -E '^(VERSION|APP_VERSION)=' .env.example && echo .env.example
  local sh; sh=$(root_script); [ -n "$sh" ] && echo "$sh"
  manifests
  return 0
}

current() {
  local v
  if [ -f VERSION.md ]; then
    v=$(tr -d '[:space:]' < VERSION.md)
    is_semver "$v" && { echo "source: VERSION.md" >&2; echo "$v"; return; }
  fi
  v=$(tag_version); [ -n "$v" ] && { echo "source: git tag v$v" >&2; echo "$v"; return; }
  if [ -f composer.json ] && json_has_version composer.json; then
    v=$(json_version composer.json); is_semver "$v" && { echo "source: composer.json" >&2; echo "$v"; return; }
  fi
  if [ -f package.json ] && json_has_version package.json; then
    v=$(json_version package.json); is_semver "$v" && { echo "source: package.json" >&2; echo "$v"; return; }
  fi
  local sh; sh=$(root_script)
  if [ -n "$sh" ]; then
    v=$(script_version "$sh"); is_semver "$v" && { echo "source: $sh" >&2; echo "$v"; return; }
  fi
  echo "source: none" >&2
  echo 0.0.0
}

next() { # next <patch|minor|major> [current]
  local level=${1:-} cur=${2:-}
  [ -n "$level" ] || die "next needs patch, minor or major"
  [ -n "$cur" ] || cur=$(current 2>/dev/null)
  is_semver "$cur" || die "'$cur' is not x.y.z"
  local ma mi pa
  IFS=. read -r ma mi pa <<< "$cur"
  case "$level" in
  patch) echo "$ma.$mi.$((pa + 1))" ;;
  minor) echo "$ma.$((mi + 1)).0" ;;
  major) echo "$((ma + 1)).0.0" ;;
  *) die "unknown level '$level' (patch, minor or major)" ;;
  esac
}

set_version() { # set_version <x.y.z>
  local v=${1:-} n=0 f old
  is_semver "$v" || die "'$v' is not x.y.z"
  if [ -f VERSION.md ]; then
    echo "$v" > VERSION.md; echo "set version in VERSION.md"; n=$((n + 1))
  fi
  if [ -f composer.json ] && json_has_version composer.json; then
    json_set_version composer.json "$v"; echo "set version in composer.json"; n=$((n + 1))
  fi
  if [ -f package.json ] && json_has_version package.json; then
    old=$(json_version package.json)
    json_set_version package.json "$v"; echo "set version in package.json"; n=$((n + 1))
    if [ -f package-lock.json ] && [ -n "$old" ]; then
      # the lock repeats the package's own version twice (top level and packages[""]); npm does the same
      awk -v o="\"version\": \"$old\"" -v nv="\"version\": \"$v\"" 'c < 2 && index($0, o) { sub(/"version": *"[^"]*"/, nv); c++ } { print }' \
        package-lock.json > package-lock.json.tmp && mv package-lock.json.tmp package-lock.json
      echo "set version in package-lock.json"
    fi
  fi
  if [ -f .env.example ] && kv_set_version .env.example "$v" 'VERSION|APP_VERSION'; then
    echo "set version in .env.example"; n=$((n + 1))
  fi
  local sh; sh=$(root_script)
  if [ -n "$sh" ] && kv_set_version "$sh" "$v" 'version|VERSION' '"'; then
    echo "set version in $sh"; n=$((n + 1))
  fi
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    json_set_version "$f" "$v"; echo "set version in $f"; n=$((n + 1))
  done < <(manifests)
  [ "$n" -gt 0 ] || die "no version file found in $ROOT (VERSION.md, composer.json, package.json, .env.example, *.sh, plugin.json)"
}

tag() { # tag <x.y.z>
  local v=${1:-}
  is_semver "$v" || die "'$v' is not x.y.z"
  git rev-parse --is-inside-work-tree >/dev/null 2>&1 || die "not a git repository"
  git rev-parse -q --verify "refs/tags/v$v" >/dev/null && die "tag v$v already exists"
  git tag -a "v$v" -m "v$v"
  echo "tagged v$v"
}

help() { sed -n '2,19p' "$0" | sed 's/^# \{0,1\}//'; }

case "${1:-help}" in
current) current ;;
next) shift; next "$@" ;;
files) files ;;
set) shift; set_version "$@" ;;
tag) shift; tag "$@" ;;
help | -h | --help) help ;;
*) die "unknown command '$1' (current, next, files, set, tag)" ;;
esac
