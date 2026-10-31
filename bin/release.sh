#!/usr/bin/env bash
# Publish a new version: bump VERSION.md and every plugins/*/.claude-plugin/plugin.json to the same
# semver, run the release checks, commit, tag v<version> and push commit + tag in one push.
# The plugin directory and `claude plugin update` only look at plugin.json, so both must move together.
# Uncommitted work is listed and, after confirmation (or with --commit / -m), committed before the release.
# /fodo:commit (plugins/fodo/scripts/semver.sh) can also bump VERSION.md + plugin.json and tag; after such a
# commit do not run this script (it would bump again): run the checks and `git push --follow-tags` instead.
#
#   bin/release.sh [patch|minor|major|x.y.z] [--dry-run] [--no-check] [--commit | -m <msg>]
set -euo pipefail

usage() {
  sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'
  exit "${1:-0}"
}

die() { echo "release: $*" >&2; exit 1; }

level=patch dry=0 check=1 commit="" msg=""
while (($#)); do
  case "$1" in
  -h | --help) usage ;;
  -n | --dry-run) dry=1 ;;
  --no-check) check=0 ;;
  --commit) commit=default ;;
  -m | --message)
    shift
    (($#)) || die "-m / --message needs a message"
    msg=$1 commit=custom
    ;;
  --message=*) msg=${1#*=} commit=custom ;;
  patch | minor | major) level=$1 ;;
  [0-9]*.[0-9]*.[0-9]*) level=$1 ;;
  *) echo "release: unknown argument '$1'" >&2; usage 1 ;;
  esac
  shift
done

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

semver_re='^[0-9]+\.[0-9]+\.[0-9]+$'
current="$(tr -d '[:space:]' < VERSION.md)"
[[ $current =~ $semver_re ]] || die "VERSION.md holds '$current', not x.y.z"
IFS=. read -r ma mi pa <<< "$current"
case "$level" in
patch) new="$ma.$mi.$((pa + 1))" ;;
minor) new="$ma.$((mi + 1)).0" ;;
major) new="$((ma + 1)).0.0" ;;
*) new="$level" ;;
esac
[[ $new =~ $semver_re ]] || die "'$new' is not x.y.z"
[[ "$(printf '%s\n%s\n' "$current" "$new" | sort -t. -k1,1n -k2,2n -k3,3n | tail -1)" == "$new" && $new != "$current" ]] ||
  die "new version $new must be higher than $current"

manifests=()
while IFS= read -r f; do manifests+=("$f"); done < <(find plugins -path '*/.claude-plugin/plugin.json' | sort)
((${#manifests[@]})) || die "no plugins/*/.claude-plugin/plugin.json found"

branch="$(git rev-parse --abbrev-ref HEAD)"
[[ $branch == main ]] || die "on branch '$branch'; releases go out from main"
changes="$(git -c core.quotePath=false status --porcelain --untracked-files=all)"
if [[ -n $changes ]]; then
  files="$(cut -c4- <<< "$changes")"
  n="$(wc -l <<< "$files" | tr -d ' ')"
  echo "release: $n uncommitted file(s):"
  while IFS= read -r f; do echo "  $f"; done <<< "$files"
  subject="chore: commit $n changed files before release"
  body="$(while IFS= read -r f; do echo "- $f"; done <<< "$files")"
  if ((dry)); then
    echo "release: would commit $n changed files"
  elif [[ -z $commit ]]; then
    [[ -t 0 ]] || die "working tree not clean; commit first, or pass --commit / -m <msg>"
    read -r -p "Commit them? [Enter = default message, n = abort, or type a message] " ans || ans=n
    case "$ans" in
    '') commit=default ;;
    [nN] | [nN][oO]) die "aborted; working tree not clean" ;;
    *) commit=custom msg=$ans ;;
    esac
  fi
else
  commit="" # nothing to commit; --commit / -m are no-ops
fi
git rev-parse -q --verify "refs/tags/v$new" > /dev/null && die "tag v$new already exists"
git fetch -q origin main
# ahead is fine (the release push takes those commits along); behind or diverged is not
git merge-base --is-ancestor origin/main HEAD ||
  die "main is behind or has diverged from origin/main; pull (or rebase) first"

echo "release: $current -> $new (${manifests[*]})"
if ((dry)); then
  echo "release: dry run, nothing changed"
  exit 0
fi

if [[ -n $commit ]]; then
  git add -A
  if [[ $commit == default ]]; then
    git commit -q -m "$subject" -m "$body"
  else
    git commit -q -m "$msg"
  fi
  echo "release: committed $n file(s): $(git log -1 --format=%s)"
  trap 'echo "release: work commit is local and not pushed" >&2' EXIT
fi

find plugins -name .DS_Store -delete
if ((check)); then
  shellcheck plugins/*/scripts/*.sh bin/*.sh
  find plugins -name '*.php' -exec php -l {} \; > /dev/null
  bats tests/
  for f in "${manifests[@]}"; do claude plugin validate --strict "$(dirname "$(dirname "$f")")"; done
  claude plugin validate --strict .
fi

echo "$new" > VERSION.md
for f in "${manifests[@]}"; do
  # rewrite only the top-level "version" line, so the file keeps its own formatting
  awk -v v="$new" '!done && /^  "version": *"[^"]*"/ { sub(/"version": *"[^"]*"/, "\"version\": \"" v "\""); done = 1 } { print }' \
    "$f" > "$f.tmp" && mv "$f.tmp" "$f"
  grep -q "\"version\": \"$new\"" "$f" || die "could not set version in $f"
done

git add VERSION.md "${manifests[@]}"
git commit -q -m "release: set version to $new"
git tag "v$new"
git push -q origin main "v$new"
trap - EXIT
echo "release: pushed v$new; the plugin directory picks it up from the push webhook"
