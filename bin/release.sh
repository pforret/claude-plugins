#!/usr/bin/env bash
# Publish a new version: bump VERSION.md and every plugins/*/.claude-plugin/plugin.json to the same
# semver, run the release checks, commit, tag v<version> and push commit + tag in one push.
# The plugin directory and `claude plugin update` only look at plugin.json, so both must move together.
#
#   bin/release.sh [patch|minor|major|x.y.z] [--dry-run] [--no-check]
set -euo pipefail

usage() {
  sed -n '2,6p' "$0" | sed 's/^# \{0,1\}//'
  exit "${1:-0}"
}

die() { echo "release: $*" >&2; exit 1; }

level=patch dry=0 check=1
for a in "$@"; do
  case "$a" in
  -h | --help) usage ;;
  -n | --dry-run) dry=1 ;;
  --no-check) check=0 ;;
  patch | minor | major) level=$a ;;
  [0-9]*.[0-9]*.[0-9]*) level=$a ;;
  *) echo "release: unknown argument '$a'" >&2; usage 1 ;;
  esac
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
[[ -z "$(git status --porcelain)" ]] || die "working tree not clean; commit or stash first (git status)"
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
echo "release: pushed v$new; the plugin directory picks it up from the push webhook"
