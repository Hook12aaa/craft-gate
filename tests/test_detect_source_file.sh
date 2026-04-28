#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
source "${PLUGIN_ROOT}/config.sh"
source "${PLUGIN_ROOT}/hooks/lib/detect-source-file.sh"
fail=0

assert_match() {
  local desc="$1" path="$2"
  if craft_path_triggers "$path"; then
    echo "PASS: $desc"
  else
    echo "FAIL: $desc — expected match for path: $path"
    fail=1
  fi
}

assert_no_match() {
  local desc="$1" path="$2"
  if craft_path_triggers "$path"; then
    echo "FAIL: $desc — expected NO match for path: $path"
    fail=1
  else
    echo "PASS: $desc"
  fi
}

assert_match     ".py file matches"           "/abs/path/src/foo.py"
assert_match     ".ts file matches"           "/abs/path/src/foo.ts"
assert_match     ".tsx nested matches"        "/abs/path/src/components/Foo.tsx"
assert_match     ".go file matches"           "/abs/path/main.go"
assert_match     ".rs file matches"           "/abs/path/src/lib.rs"
assert_no_match  ".md file does not match"   "/abs/path/README.md"
assert_no_match  ".json file does not match" "/abs/path/package.json"
assert_no_match  ".csv file does not match"  "/abs/path/data.csv"
assert_no_match  "no extension"              "/abs/path/Makefile"

# Regression: empty CRAFT_SOURCE_GLOBS (project override sentinel) returns no-match
out=$(bash -c '
  source "'"${PLUGIN_ROOT}"'/config.sh"
  CRAFT_SOURCE_GLOBS=()
  source "'"${PLUGIN_ROOT}"'/hooks/lib/detect-source-file.sh"
  craft_path_triggers /abs/path/foo.py && echo MATCH || echo NO_MATCH
')
if [ "$out" = "NO_MATCH" ]; then
  echo "PASS: empty CRAFT_SOURCE_GLOBS disables gate (sentinel works)"
else
  echo "FAIL: empty CRAFT_SOURCE_GLOBS expected NO_MATCH, got: $out"
  fail=1
fi

exit $fail
