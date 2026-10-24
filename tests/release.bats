#!/usr/bin/env bats
# Tests for bin/release.sh, each in a fresh temporary repo with a bare "origin".

setup() {
  T="$(mktemp -d)"
  ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  REPO="$T/repo"
  git init -q --bare "$T/origin.git"
  git init -q -b main "$REPO"
  cd "$REPO"
  git config user.email t@example.com
  git config user.name t
  mkdir -p bin plugins/demo/.claude-plugin
  cp "$ROOT/bin/release.sh" bin/
  echo 0.1.0 > VERSION.md
  printf '{\n  "name": "demo",\n  "version": "0.1.0",\n  "keywords": ["a", "b"]\n}\n' > plugins/demo/.claude-plugin/plugin.json
  git add -A && git commit -q -m init
  git remote add origin "$T/origin.git"
  git push -q origin main
}

teardown() {
  [ -n "${T:-}" ] && rm -rf "$T" || true
}

pv() { sed -n 's/.*"version": *"\([^"]*\)".*/\1/p' plugins/demo/.claude-plugin/plugin.json; }

@test "repo: VERSION.md matches every plugin.json version" {
  v="$(tr -d '[:space:]' < "$ROOT/VERSION.md")"
  for f in "$ROOT"/plugins/*/.claude-plugin/plugin.json; do
    [ "$(sed -n 's/.*"version": *"\([^"]*\)".*/\1/p' "$f" | head -1)" = "$v" ]
  done
}

@test "patch bumps VERSION.md and plugin.json, tags and pushes" {
  run bash bin/release.sh patch --no-check
  [ "$status" -eq 0 ]
  [ "$(cat VERSION.md)" = 0.1.1 ]
  [ "$(pv)" = 0.1.1 ]
  grep -q '"keywords": \["a", "b"\]' plugins/demo/.claude-plugin/plugin.json
  [ "$(git --git-dir="$T/origin.git" rev-parse main)" = "$(git rev-parse HEAD)" ]
  git --git-dir="$T/origin.git" rev-parse -q --verify refs/tags/v0.1.1
}

@test "minor, major and explicit versions" {
  bash bin/release.sh minor --no-check
  [ "$(pv)" = 0.2.0 ]
  bash bin/release.sh major --no-check
  [ "$(pv)" = 1.0.0 ]
  bash bin/release.sh 1.2.3 --no-check
  [ "$(pv)" = 1.2.3 ] && [ "$(cat VERSION.md)" = 1.2.3 ]
}

@test "dry run changes nothing" {
  run bash bin/release.sh minor --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"0.1.0 -> 0.2.0"* ]]
  [ "$(pv)" = 0.1.0 ] && [ -z "$(git status --porcelain)" ] && [ -z "$(git tag)" ]
}

@test "refuses a dirty tree, a lower version and a main that is behind origin" {
  echo x > dirt
  run bash bin/release.sh --no-check < /dev/null
  [ "$status" -ne 0 ] && [[ "$output" == *"not clean"* ]] && [[ "$output" == *"--commit"* ]]
  [ -n "$(git status --porcelain)" ]
  rm dirt
  run bash bin/release.sh 0.0.9 --no-check
  [ "$status" -ne 0 ] && [[ "$output" == *"must be higher"* ]]
  # someone else pushed: local main is behind origin/main
  git clone -q "$T/origin.git" "$T/other"
  (cd "$T/other" && git -c user.email=o@e -c user.name=o commit -q --allow-empty -m remote && git push -q origin main)
  run bash bin/release.sh --no-check
  [ "$status" -ne 0 ] && [[ "$output" == *"behind or has diverged"* ]]
}

@test "unpushed local commits go out with the release" {
  git commit -q --allow-empty -m "local work"
  run bash bin/release.sh --no-check
  [ "$status" -eq 0 ]
  [ "$(git --git-dir="$T/origin.git" rev-parse main)" = "$(git rev-parse HEAD)" ]
  git --git-dir="$T/origin.git" log --format=%s main | grep -q "local work"
}

@test "--commit commits dirty work with the file list, then releases" {
  echo a > notes.txt && echo b > old.txt
  git add -A && git commit -q -m "two files"
  echo x >> notes.txt
  echo new > untracked.txt
  git mv old.txt renamed.txt
  run bash bin/release.sh --commit --no-check < /dev/null
  [ "$status" -eq 0 ]
  [ "$(git log -1 --format=%s HEAD~1)" = "chore: commit 3 changed files before release" ]
  [ "$(git log -1 --format=%s)" = "release: set version to 0.1.1" ]
  body="$(git log -1 --format=%b HEAD~1)"
  [[ "$body" == *"- notes.txt"* ]]
  [[ "$body" == *"- untracked.txt"* ]]
  [[ "$body" == *"- old.txt -> renamed.txt"* ]]
  [ -z "$(git status --porcelain)" ]
  [ "$(git --git-dir="$T/origin.git" rev-parse main)" = "$(git rev-parse HEAD)" ]
  git --git-dir="$T/origin.git" rev-parse -q --verify refs/tags/v0.1.1
}

@test "-m and --message= override the commit message" {
  echo x > dirt
  run bash bin/release.sh -m "my work" --no-check < /dev/null
  [ "$status" -eq 0 ]
  [ "$(git log -1 --format=%B HEAD~1)" = "my work" ]
  echo y > dirt
  run bash bin/release.sh --message="more work" --no-check < /dev/null
  [ "$status" -eq 0 ]
  [ "$(git log -1 --format=%s HEAD~1)" = "more work" ]
  [ "$(pv)" = 0.1.2 ]
}

@test "dry run with a dirty tree reports and changes nothing" {
  echo x > dirt
  run bash bin/release.sh --dry-run < /dev/null
  [ "$status" -eq 0 ]
  [[ "$output" == *"would commit 1 changed files"* ]]
  [ "$(git status --porcelain)" = "?? dirt" ] && [ -z "$(git tag)" ]
}

@test "-m without a message fails" {
  run bash bin/release.sh -m
  [ "$status" -ne 0 ] && [[ "$output" == *"needs a message"* ]]
}

@test "a failing check after the work commit says it is not pushed" {
  echo x > dirt
  # with checks on, shellcheck fails here: the temp repo has no plugins/*/scripts/*.sh
  run bash bin/release.sh --commit < /dev/null
  [ "$status" -ne 0 ]
  [[ "$output" == *"work commit is local and not pushed"* ]]
  [ "$(git --git-dir="$T/origin.git" rev-parse main)" != "$(git rev-parse HEAD)" ]
}
