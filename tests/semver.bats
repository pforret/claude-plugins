#!/usr/bin/env bats
# Tests for plugins/fodo/scripts/semver.sh, each in a fresh temporary git repo.

setup() {
  T="$(mktemp -d)"
  S="$(cd "$BATS_TEST_DIRNAME/../plugins/fodo/scripts" && pwd)/semver.sh"
  REPO="$T/repo"
  mkdir -p "$REPO"
  cd "$REPO"
  git init -q -b main
  git config user.email t@example.com
  git config user.name t
  git commit -q --allow-empty -m init
}

teardown() {
  [ -n "${T:-}" ] && rm -rf "$T" || true
}

pv() { sed -n 's/.*"version": *"\([^"]*\)".*/\1/p' "$1" | head -1; }

@test "current: 0.0.0 when nothing carries a version" {
  run bash "$S" current
  [ "$status" -eq 0 ]
  [[ "$output" == *"source: none"* ]]
  [ "${lines[${#lines[@]}-1]}" = 0.0.0 ]
}

@test "current: VERSION.md wins over tags and manifests" {
  echo 1.2.3 > VERSION.md
  git tag v9.9.9
  printf '{\n  "name": "x",\n  "version": "5.5.5"\n}\n' > package.json
  [ "$(bash "$S" current 2>/dev/null)" = 1.2.3 ]
}

@test "current: highest semver tag, sorted numerically, v stripped" {
  git tag v1.6.0
  git tag v1.10.0
  git tag not-a-version
  [ "$(bash "$S" current 2>/dev/null)" = 1.10.0 ]
}

@test "current: composer.json, then package.json, then a root script" {
  printf '{\n    "name": "a/b",\n    "version": "2.0.1"\n}\n' > composer.json
  [ "$(bash "$S" current 2>/dev/null)" = 2.0.1 ]
  rm composer.json
  printf '{\n  "name": "x",\n  "version": "3.0.0"\n}\n' > package.json
  [ "$(bash "$S" current 2>/dev/null)" = 3.0.0 ]
  rm package.json
  printf '#!/usr/bin/env bash\nversion="4.0.0"\necho hi\n' > tool.sh
  [ "$(bash "$S" current 2>/dev/null)" = 4.0.0 ]
}

@test "next: patch, minor and major reset the lower parts" {
  [ "$(bash "$S" next patch 1.2.3)" = 1.2.4 ]
  [ "$(bash "$S" next minor 1.2.3)" = 1.3.0 ]
  [ "$(bash "$S" next major 1.2.3)" = 2.0.0 ]
}

@test "next: uses the detected version and rejects bad input" {
  echo 0.1.14 > VERSION.md
  [ "$(bash "$S" next patch)" = 0.1.15 ]
  run bash "$S" next huge 1.0.0
  [ "$status" -ne 0 ]
  run bash "$S" next patch 1.0
  [ "$status" -ne 0 ]
}

@test "set: VERSION.md and every plugin.json, formatting kept" {
  echo 0.1.0 > VERSION.md
  mkdir -p .claude-plugin plugins/demo/.claude-plugin plugins/other/.claude-plugin
  printf '{\n  "name": "mp",\n  "version": "0.1.0"\n}\n' > .claude-plugin/plugin.json
  printf '{\n  "name": "demo",\n  "version": "0.1.0",\n  "keywords": ["a", "b"]\n}\n' > plugins/demo/.claude-plugin/plugin.json
  printf '{\n  "name": "other",\n  "version": "0.1.0"\n}\n' > plugins/other/.claude-plugin/plugin.json
  run bash "$S" set 0.2.0
  [ "$status" -eq 0 ]
  [[ "$output" == *"set version in VERSION.md"* ]]
  [[ "$output" == *"set version in plugins/demo/.claude-plugin/plugin.json"* ]]
  [ "$(cat VERSION.md)" = 0.2.0 ]
  [ "$(pv .claude-plugin/plugin.json)" = 0.2.0 ]
  [ "$(pv plugins/demo/.claude-plugin/plugin.json)" = 0.2.0 ]
  [ "$(pv plugins/other/.claude-plugin/plugin.json)" = 0.2.0 ]
  grep -q '"keywords": \["a", "b"\]' plugins/demo/.claude-plugin/plugin.json
  [ "$(wc -l < plugins/demo/.claude-plugin/plugin.json)" -eq 5 ]
}

@test "set: composer.json, package.json with lock, .env.example and a root script" {
  printf '{\n    "name": "a/b",\n    "description": "version \\"inside\\" a string",\n    "version": "1.0.0"\n}\n' > composer.json
  printf '{\n  "name": "x",\n  "version": "1.0.0",\n  "dependencies": {\n    "left-pad": {\n      "version": "1.0.0"\n    }\n  }\n}\n' > package.json
  printf '{\n  "name": "x",\n  "version": "1.0.0",\n  "packages": {\n    "": {\n      "version": "1.0.0"\n    },\n    "node_modules/left-pad": {\n      "version": "1.0.0"\n    }\n  }\n}\n' > package-lock.json
  printf 'APP_NAME=x\nVERSION=1.0.0\nAPP_VERSION=1.0.0\nOTHER_VERSION=1.0.0\n' > .env.example
  printf '#!/usr/bin/env bash\nversion="1.0.0"\nreadonly VERSION_NAME=x\n' > tool.sh
  run bash "$S" set 1.1.0
  [ "$status" -eq 0 ]
  [ "$(pv composer.json)" = 1.1.0 ]
  [ "$(pv package.json)" = 1.1.0 ]
  grep -q '"left-pad": {' package.json
  [ "$(grep -c '"version": "1.1.0"' package.json)" -eq 1 ]
  [ "$(grep -c '"version": "1.1.0"' package-lock.json)" -eq 2 ]
  grep -q 'node_modules/left-pad' package-lock.json
  grep -q '^VERSION=1.1.0$' .env.example
  grep -q '^APP_VERSION=1.1.0$' .env.example
  grep -q '^OTHER_VERSION=1.0.0$' .env.example
  grep -q '^version="1.1.0"$' tool.sh
  grep -q '^readonly VERSION_NAME=x$' tool.sh
}

@test "set: a manifest without a version line is left alone, a json without one is skipped" {
  printf '{\n  "name": "x"\n}\n' > package.json
  echo 0.1.0 > VERSION.md
  run bash "$S" set 0.1.1
  [ "$status" -eq 0 ]
  [[ "$output" != *"package.json"* ]]
  [ "$(cat package.json)" = "$(printf '{\n  "name": "x"\n}')" ]
}

@test "set: fails when nothing carries a version, and on a bad version" {
  run bash "$S" set 0.1.1
  [ "$status" -ne 0 ]
  echo 0.1.0 > VERSION.md
  run bash "$S" set 0.1
  [ "$status" -ne 0 ]
  [ "$(cat VERSION.md)" = 0.1.0 ]
}

@test "files: lists what is present" {
  echo 0.1.0 > VERSION.md
  mkdir -p plugins/demo/.claude-plugin
  printf '{\n  "version": "0.1.0"\n}\n' > plugins/demo/.claude-plugin/plugin.json
  run bash "$S" files
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = VERSION.md ]
  [ "${lines[1]}" = plugins/demo/.claude-plugin/plugin.json ]
  [ "${#lines[@]}" -eq 2 ]
}

@test "tag: creates an annotated v-tag once and refuses a duplicate" {
  run bash "$S" tag 0.2.0
  [ "$status" -eq 0 ]
  [ "$(git tag)" = v0.2.0 ]
  [ "$(git cat-file -t v0.2.0)" = tag ]
  run bash "$S" tag 0.2.0
  [ "$status" -ne 0 ]
  [[ "$output" == *"already exists"* ]]
  run bash "$S" tag 1.0
  [ "$status" -ne 0 ]
}

@test "never pushes: no remote is needed and none is touched" {
  echo 0.1.0 > VERSION.md
  bash "$S" set 0.1.1 >/dev/null
  bash "$S" tag 0.1.1 >/dev/null
  [ -z "$(git remote)" ]
}
